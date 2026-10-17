"""Admin-only observation of native inference, without editing the production model.

An isolated subclass records raw IF labels at the recurring-rule hook BEFORE
native postprocessing. Every override calls its original implementation and
returns its result unchanged. Never monkey-patch the global app singleton.
"""
import hashlib
import inspect
from datetime import datetime, timezone

from firebase_admin import firestore
from .isolation_forest_service import IsolationForestService
from .admin_evaluation_capture import CAPTURE_SUPPRESSED, mapping


class ObservedIsolationForest(IsolationForestService):
    def __init__(self):
        super().__init__()
        self.raw_labels = {}
        self.final_frame = None
        self.model_ready = False

    def _is_expected_recurring(self, row):
        if 'anomaly_label' in row and 'anomaly_score_raw' in row:
            # Later calls in _reason_for must not overwrite the pre-rule label.
            self.raw_labels.setdefault(str(row['id']), int(row['anomaly_label']) == -1)
        return super()._is_expected_recurring(row)

    def _build_statistics(self, *args, **kwargs):
        self.final_frame = kwargs['target_df'].copy(deep=True)
        self.model_ready = bool(kwargs['model_ready'])
        return super()._build_statistics(*args, **kwargs)


def analyze_with_snapshot(uid, transactions, year, month, cutoff):
    observer = ObservedIsolationForest()
    token = CAPTURE_SUPPRESSED.set(True)
    try:
        result = observer.detect_anomalies(user_id=uid, transactions=transactions,
            year=year, month=month, reference_date=cutoff)
    finally:
        CAPTURE_SUPPRESSED.reset(token)
    return result, observer


def document_key(transaction_id):
    return hashlib.sha256(str(transaction_id).encode()).hexdigest()


def snapshot_rows(result, observer, transactions):
    result_map = mapping(result)
    anomalies = result_map.get('anomalies', [])
    hybrid = {str(v.get('transactionId', v.get('transaction_id'))) for raw in anomalies for v in [mapping(raw)]}
    original = {str(v.id): v for v in transactions}
    if observer.final_frame is None:
        return []
    rows = []
    for _, row in observer.final_frame.iterrows():
        identity = str(row['id'])
        tx = original.get(identity)
        at = row['date_time']
        value = {'transactionId': identity, 'money': float(row['money']),
                 'date': at.isoformat(), 'typeName': str(row['type_name']),
                 'note': str(getattr(tx, 'note', '') or '')[:3000]}
        # Immutable input identity: later edits to spending do not change this snapshot.
        import json
        value['fingerprint'] = hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        value.update({'rawIfPrediction': observer.raw_labels.get(identity) if observer.model_ready else None,
                      'hybridPrediction': identity in hybrid, 'actualLabel': 'unreviewed',
                      'labelVersion': 0, 'reason': '', 'reviewedBy': None,
                      'predictionVisibleAtReview': False})
        rows.append(value)
    return rows


def save_snapshot(client, run_id, uid, year, month, result, observer, transactions, scope):
    ref = client.collection('admin_anomaly_runs').document(run_id)
    rows = snapshot_rows(result, observer, transactions)
    data = mapping(result)
    statistics = data.get('statistics', {}) or {}
    baseline = statistics.get('baselineMode', 'unavailable')
    ready = observer.model_ready
    message = str(data.get('message', ''))
    note = ('Đánh giá trên dữ liệu tham chiếu các tháng trước; không chứng minh đây là tập test chưa từng dùng để chỉnh mô hình.'
            if baseline == 'previous_months' else
            'Mô hình có thể fit trên chính tháng đang đánh giá (current_month_fallback); đây là đánh giá trong mẫu, không phải test độc lập.')
    if not rows:
        note = 'Không tìm thấy chi tiêu hợp lệ trong tháng. Kiểm tra UID/tháng và chỉ mục data/<uid>; nhãn không tạo thêm giao dịch.'
    elif not ready:
        note = 'Chưa đủ mẫu tham chiếu cho Isolation Forest; chỉ có thể kiểm chứng kết quả quy tắc/hybrid. Cần ít nhất 12 mẫu tham chiếu theo service hiện tại.'
    frame=observer._to_dataframe(transactions)
    history_count=target_count=0
    if not frame.empty:
        history,target=observer._split_month_data(frame,year,month)
        history_count,target_count=len(history),len(target)
    reference_count=history_count if history_count>=observer.MIN_HISTORY_TRANSACTIONS else target_count
    readiness={'targetTransactions':target_count,'historyTransactions':history_count,
               'referenceTransactions':reference_count,'minimumReferenceForModel':observer.MIN_MODEL_TRANSACTIONS,
               'minimumHistoricalBaseline':observer.MIN_HISTORY_TRANSACTIONS,
               'minimumTarget':observer.MIN_TARGET_TRANSACTIONS}
    payload = {'id': run_id, 'userId': uid, 'year': year, 'month': month,
               'createdAt': datetime.now(timezone.utc), 'status': 'writing',
               'scope': scope, 'targetCount': len(rows), 'modelReady': ready, 'dataReadiness':readiness,
               'inferenceConfig':{'contamination':statistics.get('contamination'),'nEstimators':observer.N_ESTIMATORS,
                                  'randomState':observer.RANDOM_STATE,'historyMonths':observer.HISTORY_MONTHS,
                                  'features':list(observer.FEATURE_COLUMNS)},
               'baselineMode': baseline, 'protocolNote': note, 'message': message,
               'labelRevision': 0, 'reviewedCount': 0, 'normalCount': 0, 'anomalyCount': 0,
               'modelSourceHash': hashlib.sha256(inspect.getsource(IsolationForestService).encode()).hexdigest(),
               'snapshotSchema': 1, 'labelPolicyVersion':'manual_review_v1'}
    # A job ID is unique; an existing snapshot and its manual labels are never reset.
    ref.create(payload)
    try:
        for start in range(0, len(rows), 300):
            batch = client.batch()
            for row in rows[start:start+300]:
                batch.create(ref.collection('items').document(document_key(row['transactionId'])), row)
            batch.commit()
        ref.update({'status': 'ready'})
    except Exception:
        ref.update({'status': 'failed'})
        raise
    return run_id

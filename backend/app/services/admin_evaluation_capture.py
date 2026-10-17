"""Persist selected model diagnostics; never manufacture labels or accuracy.

Capture is best-effort for user-facing inference. Admin jobs call save_record
explicitly so a failed write is reported to their job instead of being hidden.
"""
import functools
import inspect
import logging
import math
import os
from contextvars import ContextVar

logger = logging.getLogger(__name__)
CAPTURE_SUPPRESSED = ContextVar('admin_ai_capture_suppressed', default=False)


def field(value, *keys, default=None):
    for key in keys:
        result = value.get(key) if isinstance(value, dict) else getattr(value, key, None)
        if result is not None:
            return result
    return default


def mapping(value):
    if isinstance(value, dict):
        return value
    if hasattr(value, 'model_dump'):
        return value.model_dump(by_alias=True)
    return vars(value) if hasattr(value, '__dict__') else {}


def numeric(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def finite_metrics(values):
    return {k: float(v) if isinstance(v, float) else v for k, v in values.items() if numeric(v)}


def find_lstm_evaluation(value):
    """Only inspect model metadata, never copy raw transactions or predictions."""
    if not isinstance(value, dict):
        return {}
    if isinstance(value.get('lstmEvaluation'), dict):
        return value['lstmEvaluation']
    for key in ('shortTermModel', 'expense', 'model', 'forecastModel', 'forecastModels'):
        found = find_lstm_evaluation(value.get(key))
        if found:
            return found
    return {}


def build_record(model, result, uid, sample_count=None, scope=None):
    data = mapping(result)
    success = field(data, 'success', default=False) is True
    record = {'model': model, 'recordSource':'app_inference', 'userId': str(uid), 'scope': scope or {},
              'dataset': 'Lịch sử cá nhân · ' + str(uid), 'metrics': {},
              'status': 'not_ready', 'evaluationKind': 'diagnostic',
              'notes': str(field(data, 'message', default=''))[:1000]}
    if sample_count is not None:
        record['inputCount'] = int(sample_count)
    if model == 'LSTM':
        summary = mapping(field(data, 'summary', default={}))
        lm = find_lstm_evaluation(summary.get('model', {}))
        # V12 rolling embeds the original monthly result in monthlyBreakdown too.
        if not lm:
            for block in summary.get('monthlyBreakdown', []) or []:
                lm = find_lstm_evaluation(mapping(block).get('model', {}))
                if lm:
                    break
        state = str(lm.get('model', 'not_evaluated_in_forecast'))
        reason = {
            'tensorflow_unavailable':'Chưa tải được TensorFlow trong môi trường server',
            'insufficient_history':'Chưa đủ số ngày lịch sử để huấn luyện LSTM',
            'insufficient_nonzero_days':'Chưa đủ 20 ngày có phát sinh chi',
            'insufficient_sequences':'Chưa đủ chuỗi huấn luyện',
            'baseline_selected':'Đã đánh giá LSTM; baseline có MAE tốt hơn hoặc bằng',
            'lstm':'Đã đánh giá LSTM; MAE thấp hơn baseline',
            'disabled':'LSTM bị tắt trong yêu cầu',
            'stale_history':'Lịch sử giao dịch cách xa thời điểm dự báo',
            'lstm_runtime_fallback':'LSTM gặp lỗi lúc huấn luyện; xem log server',
            'not_evaluated_in_forecast':'Luồng dự báo này chưa chạy đánh giá LSTM'
        }.get(state,state)
        metrics = {'MAE_LSTM_VND': lm.get('mae'), 'MAE_baseline_VND': lm.get('baselineMae'),
                   'validationSamples': lm.get('validationSamples'),
                   'validationHorizonDays': lm.get('validationHorizon')}
        record.update(metrics=finite_metrics(metrics), modelState=state,
                      status='evaluated' if numeric(lm.get('mae')) else 'not_ready',
                      evaluationKind='model_selection_holdout',
                      notes=('MAE trên holdout chọn mô hình; không phải kết quả test độc lập hoặc độ chính xác của ensemble. '
                             'Nếu baseline được chọn, MAE LSTM vẫn là số đo của LSTM trên holdout. '
                             'Trạng thái: ' + reason + '. ' + record['notes']))
    elif model == 'K-Means':
        profile = mapping(field(data, 'userProfile', 'user_profile', default={}))
        km = mapping(profile.get('kMeans', {}))
        ready = success and km.get('scoreAvailable') is True and numeric(km.get('silhouetteScore'))
        record.update(metrics=finite_metrics({'Silhouette': km.get('silhouetteScore') if ready else None,
            'K': km.get('optimalK'), 'sampleSize': km.get('sampleSize'), 'featureCount': km.get('featureCount')}),
            status='evaluated' if ready else 'not_ready', evaluationKind='internal_cluster_validation',
            modelState='clustered' if success else 'insufficient_data',
            notes='Silhouette đo độ tách cụm trên dữ liệu đã chuẩn hóa; không phải accuracy. ' + record['notes'])
    elif model == 'Isolation Forest':
        stats = mapping(field(data, 'statistics', default={}))
        ready = stats.get('modelReady') is True
        record.update(metrics=finite_metrics({
            'targetTransactions': stats.get('totalTransactions', stats.get('targetTransactions')),
            'historyTransactionsUsed': stats.get('historyTransactionsUsed'),
            'hybridDetected': field(data, 'anomaliesDetected', 'anomalies_detected'),
            'isolationForestTriggered': stats.get('isolationForestTriggeredTransactions'),
            'ruleTriggered': stats.get('ruleTriggeredTransactions'),
            'hybridAnomalyRatePercent': stats.get('anomalyRate'),
            'contamination': stats.get('contamination')}),
            status='diagnostic' if ready else 'not_ready', evaluationKind='unlabelled_inference_diagnostic',
            modelState='isolation_forest_and_rules' if ready else 'rules_or_insufficient_data',
            notes=('Đây là thống kê lúc suy luận. Chỉ số từ nhãn kiểm chứng xem tại màn hình Đánh giá bất thường. '
                   'Số phát hiện và tỷ lệ bất thường là thống kê, không đo chất lượng mô hình. '
                   'Baseline: ' + str(stats.get('baselineMode', 'chưa xác định do chưa đủ dữ liệu hợp lệ')) + '. ' + record['notes']))
    else:
        raise ValueError('Unknown model')
    return record


def save_record(record, record_id=None):
    from firebase_admin import firestore
    from app.security.firebase_auth import _firebase_app
    client = firestore.client(app=_firebase_app())
    ref = client.collection('admin_ai_evaluations').document(record_id) if record_id else client.collection('admin_ai_evaluations').document()
    ref.set({**record, 'createdAt': firestore.SERVER_TIMESTAMP})
    return ref.id


def record_analysis(model):
    def decorate(fn):
        signature = inspect.signature(fn)
        @functools.wraps(fn)
        def wrapped(*args, **kwargs):
            result = fn(*args, **kwargs)
            if CAPTURE_SUPPRESSED.get() or os.getenv('AI_ADMIN_CAPTURE_ENABLED', '1') == '0':
                return result
            try:
                values = signature.bind(*args, **kwargs).arguments
                uid = values.get('user_id')
                if uid:
                    tx = values.get('transactions', [])
                    scope = {key: values[key] for key in ('year', 'month', 'forecast_mode') if values.get(key) is not None}
                    save_record(build_record(model, result, uid, len(tx), scope))
            except Exception:
                logger.exception('Could not persist %s admin diagnostics; inference response kept', model)
            return result
        return wrapped
    return decorate

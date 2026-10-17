"""Manual labels and reports only. This module never imports or trains an AI model."""
from datetime import datetime, timezone
from hashlib import sha256
from uuid import uuid4
from google.cloud.firestore_v1 import transactional


class ReviewError(ValueError):
    def __init__(self, status, message):
        super().__init__(message)
        self.status=status


def key(identity):
    return sha256(str(identity).encode()).hexdigest()


def ready_run(client, run_id):
    ref=client.collection('admin_anomaly_runs').document(run_id)
    run=ref.get().to_dict()
    if not run or run.get('status')!='ready':
        raise ReviewError(404,'Chưa có snapshot hoàn chỉnh. Chạy lại phân tích AI để tạo snapshot mới.')
    return ref,run


def list_runs(client):
    values=[]
    for doc in client.collection('admin_anomaly_runs').order_by('createdAt',direction='DESCENDING').limit(50).stream():
        row=doc.to_dict()
        if row.get('status')=='ready':values.append({**row,'id':doc.id})
    return {'items':values}


def list_items(client,run_id,cursor=None,reveal=False):
    ref,run=ready_run(client,run_id)
    query=ref.collection('items').order_by('__name__').limit(51)
    if cursor:
        if len(cursor)!=64 or any(c not in '0123456789abcdef' for c in cursor):
            raise ReviewError(422,'Con trỏ trang không hợp lệ.')
        query=query.start_after({'__name__':ref.collection('items').document(cursor)})
    docs=list(query.stream())
    rows=[]
    for snap in docs[:50]:
        row={**snap.to_dict(),'itemKey':snap.id}
        if not reveal:
            row.pop('rawIfPrediction',None);row.pop('hybridPrediction',None)
        rows.append(row)
    return {'items':rows,'nextCursor':docs[49].id if len(docs)>50 else None,'run':run}


def save_label(client,run_id,transaction_id,label,reason,expected_version,reveal,actor):
    if label not in ('normal','anomaly','unreviewed'):
        raise ReviewError(422,'Nhãn không hợp lệ.')
    reason=reason.strip()
    if not reason:
        raise ReviewError(422,'Nhập căn cứ kiểm chứng nhãn; không dùng dự đoán AI làm nhãn chuẩn.')
    ref=client.collection('admin_anomaly_runs').document(run_id)
    item=ref.collection('items').document(key(transaction_id))
    audit=client.collection('admin_audit_logs').document()

    @transactional
    def apply(tx):
        run=ref.get(transaction=tx).to_dict()
        old=item.get(transaction=tx).to_dict()
        if not run or run.get('status')!='ready' or not old:
            raise ReviewError(404,'Không tìm thấy giao dịch trong snapshot hoàn chỉnh.')
        if old.get('transactionId')!=transaction_id or int(old.get('labelVersion',0))!=expected_version:
            raise ReviewError(409,'Nhãn đã được người khác cập nhật. Tải lại trang trước khi sửa.')
        previous=old.get('actualLabel','unreviewed')
        reviewed=int(run.get('reviewedCount',0))+int(label!='unreviewed')-int(previous!='unreviewed')
        normal=int(run.get('normalCount',0))+int(label=='normal')-int(previous=='normal')
        anomaly=int(run.get('anomalyCount',0))+int(label=='anomaly')-int(previous=='anomaly')
        now=datetime.now(timezone.utc)
        update={'actualLabel':label,'reason':reason,'labelVersion':expected_version+1,
                'reviewedBy':actor['uid'],'reviewedAt':now,'predictionVisibleAtReview':reveal}
        tx.update(item,update)
        tx.update(ref,{'labelRevision':int(run.get('labelRevision',0))+1,
                      'reviewedCount':reviewed,'normalCount':normal,'anomalyCount':anomaly})
        tx.create(audit,{'action':'anomaly_label','actorUid':actor['uid'],'actorEmail':actor.get('email',''),
                  'targetId':run_id,'createdAt':now,'details':{'transactionId':transaction_id,
                  'before':previous,'after':label,'reason':reason,'labelVersion':expected_version+1}})
        return {'ok':True,**update}
    return apply(client.transaction())


def binary_metrics(rows,prediction):
    counts={'TP':0,'FP':0,'TN':0,'FN':0}
    excluded=0;reviewed=0
    for row in rows:
        label=row.get('actualLabel')
        if label not in ('normal','anomaly'):continue
        reviewed+=1
        predicted=row.get(prediction)
        if not isinstance(predicted,bool):excluded+=1;continue
        actual=label=='anomaly'
        counts['TP' if actual and predicted else 'FN' if actual else 'FP' if predicted else 'TN']+=1
    tp,fp,tn,fn=(counts[k] for k in ('TP','FP','TN','FN'))
    n=tp+fp+tn+fn
    ratio=lambda a,b: a/b if b else None
    return {**counts,'evaluated':n,'excludedReviewed':excluded,'reviewed':reviewed,
            'precision':ratio(tp,tp+fp),'recall':ratio(tp,tp+fn),'F1':ratio(2*tp,2*tp+fp+fn),
            'accuracy':ratio(tp+tn,n),'actualAnomalies':tp+fn,'actualNormal':tn+fp}


def create_report(client,run_id,report_id,expected_revision,actor):
    ref,run=ready_run(client,run_id)
    report_ref=client.collection('admin_anomaly_reports').document(report_id)
    existing=report_ref.get().to_dict()
    if existing:
        if existing.get('runId')!=run_id or existing.get('actorUid')!=actor['uid']:
            raise ReviewError(409,'Mã báo cáo đã dùng cho yêu cầu khác.')
        return existing
    revision=int(run.get('labelRevision',0))
    if revision!=expected_revision:
        raise ReviewError(409,'Bộ nhãn đã thay đổi. Tải lại tập dữ liệu trước khi lập báo cáo.')
    rows=[doc.to_dict() for doc in ref.collection('items').stream()]
    # Closed snapshots are capped at 5,000 rows by the AI job; reject corruption.
    if len(rows)!=int(run.get('targetCount',0)) or len(rows)>5000:
        raise ReviewError(409,'Snapshot thiếu hoặc thừa giao dịch; không tạo báo cáo từ dữ liệu chưa hoàn chỉnh.')
    labelled=[r for r in rows if r.get('actualLabel') in ('normal','anomaly')]
    if not labelled:
        raise ReviewError(422,'Chưa có nhãn kiểm chứng. Gán nhãn thủ công trước khi tính chỉ số.')
    warnings=[run.get('protocolNote',''),
              'Chỉ số chỉ áp dụng tập đã kiểm chứng; không đại diện mọi giao dịch hoặc mọi người dùng.',
              'Nhãn được admin nhập, chưa tự động xác minh độc lập bởi chuyên gia.']
    if not all(any(r['actualLabel']==v for r in labelled) for v in ('normal','anomaly')):
        warnings.append('Tập nhãn hiện chỉ có một lớp; cần bổ sung cả bình thường và bất thường để đánh giá đầy đủ.')
    if len(labelled)<len(rows):warnings.append('Tập gán nhãn chưa đầy đủ; có nguy cơ sai lệch chọn mẫu.')
    visible=sum(r.get('predictionVisibleAtReview') is True for r in labelled)
    if visible:warnings.append('Có nhãn được ghi sau khi bật xem dự đoán; kết quả có thể bị ảnh hưởng bởi gợi ý mô hình.')
    payload={'id':report_id,'runId':run_id,'userId':run['userId'],'year':run['year'],'month':run['month'],
             'labelRevision':revision,'targetCount':len(rows),'reviewedCount':len(labelled),
             'normalCount':sum(r['actualLabel']=='normal' for r in labelled),
             'anomalyCount':sum(r['actualLabel']=='anomaly' for r in labelled),
             'predictionVisibleLabels':visible,'baselineMode':run.get('baselineMode'),
             'inferenceConfig':run.get('inferenceConfig',{}), 'evaluationKind':'reviewed_snapshot_not_independent_test', 'labelPolicyVersion':run.get('labelPolicyVersion','manual_review_v1'),
             'rawIsolationForest':binary_metrics(rows,'rawIfPrediction'),
             'hybrid':binary_metrics(rows,'hybridPrediction'),
             'warnings':[v for v in warnings if v], 'modelSourceHash':run.get('modelSourceHash'),
             'createdAt':datetime.now(timezone.utc),'actorUid':actor['uid'],'actorEmail':actor.get('email','')}
    audit=client.collection('admin_audit_logs').document('anomaly_report_'+report_id)
    @transactional
    def commit(tx):
        current=ref.get(transaction=tx).to_dict() or {}
        previous=report_ref.get(transaction=tx).to_dict()
        if previous:
            if previous.get('runId')!=run_id or previous.get('actorUid')!=actor['uid']:
                raise ReviewError(409,'Mã báo cáo trùng.')
            return previous
        if current.get('labelRevision')!=revision:
            raise ReviewError(409,'Nhãn thay đổi trong khi tính. Tải lại và lập báo cáo mới.')
        tx.create(report_ref,payload)
        tx.create(audit,{'action':'anomaly_report','actorUid':actor['uid'],'targetId':run_id,
                        'createdAt':payload['createdAt'],'details':{'reportId':report_id,'labelRevision':revision}})
        return payload
    return commit(client.transaction())


def list_reports(client):
    return {'items':[{**doc.to_dict(),'id':doc.id} for doc in client.collection('admin_anomaly_reports').order_by('createdAt',direction='DESCENDING').limit(50).stream()]}

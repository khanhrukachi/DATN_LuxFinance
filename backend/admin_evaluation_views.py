"""Bounded, source-aware evaluation reads. No imports from AI services."""

def evaluation_rows(client,user_id=None,year=None,month=None,source='admin_job',job_id=None):
    if job_id:
        names=['LSTM','K-Means','Isolation_Forest']
        references=[client.collection('admin_ai_evaluations').document(job_id+'_'+name) for name in names]
        docs=[s for s in client.get_all(references) if s.exists]
        capped=False
    else:
        docs=list(client.collection('admin_ai_evaluations').order_by('createdAt',direction='DESCENDING').limit(501).stream())
        capped=len(docs)>500;docs=docs[:500]
    items=[]
    for snap in docs:
        row={**snap.to_dict(),'id':snap.id}
        row_source=row.get('recordSource') or ('admin_job' if row.get('jobId') else 'app_inference')
        scope=row.get('scope') or {}
        if user_id and row.get('userId')!=user_id:continue
        if year is not None and scope.get('year')!=year:continue
        if month is not None and scope.get('month')!=month:continue
        if source!='all' and row_source!=source:continue
        row['recordSource']=row_source;items.append(row)
    capped=capped or len(items)>100;items=items[:100]
    reports={}
    for snap in client.collection('admin_anomaly_reports').order_by('createdAt',direction='DESCENDING').limit(100).stream():
        data={**snap.to_dict(),'id':snap.id}
        reports.setdefault(data.get('runId'),data)
    ids={r.get('reviewSnapshotId') for r in items if r.get('reviewSnapshotId') in reports}
    versions={}
    if ids:
        refs=[client.collection('admin_anomaly_runs').document(identity) for identity in ids]
        versions={s.id:(s.to_dict() or {}).get('labelRevision') for s in client.get_all(refs) if s.exists}
    for row in items:
        identity=row.get('reviewSnapshotId')
        report=reports.get(identity)
        if report:
            row['verificationReport']=report
            row['verificationReportIsCurrent']=versions.get(identity)==report.get('labelRevision')
    return {'items':items,'truncated':capped,'scanLimit':500,'returnedLimit':100,
            'source':source,'scope':{'userId':user_id,'year':year,'month':month,'jobId':job_id}}

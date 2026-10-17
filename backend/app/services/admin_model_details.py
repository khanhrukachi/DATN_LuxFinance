"""Admin-only model readiness and diagnostics. No production singleton changes."""
import hashlib
import inspect
import math

import numpy as np
from sklearn.metrics import davies_bouldin_score, calinski_harabasz_score
from .kmeans_service import KMeansService
from .admin_evaluation_capture import CAPTURE_SUPPRESSED, mapping


def lstm_details(service, history, meta, tensorflow_available):
    """Describe the exact native training gates; baseline metrics stay separate."""
    n=len(history)
    nonzero=int(np.count_nonzero(history['expense'].to_numpy(dtype=float))) if n else 0
    required_days=int(service.min_lstm_days)
    seq=int(service.sequence_length)
    sequences=max(0,n-14-seq)
    checks=[{'key':'tensorflow','label':'TensorFlow khả dụng','met':bool(tensorflow_available)},
            {'key':'history_days','label':'Số ngày trong chuỗi lịch sử','actual':n,'required':required_days,'missing':max(0,required_days-n),'met':n>=required_days},
            {'key':'nonzero_days','label':'Ngày có phát sinh chi','actual':nonzero,'required':20,'missing':max(0,20-nonzero),'met':nonzero>=20},
            {'key':'sequences','label':'Chuỗi huấn luyện trước holdout','actual':sequences,'required':20,'missing':max(0,20-sequences),'met':sequences>=20}]
    result={'readiness':checks,'nativeModelState':meta.get('model'),'sequenceLength':seq,
            'holdoutDays':14,'validationHorizonDays':7,'historyDays':n,
            'firstDate':history['date'].iloc[0].strftime('%Y-%m-%d') if n else None,
            'lastDate':history['date'].iloc[-1].strftime('%Y-%m-%d') if n else None,
            'allNativePrerequisitesMet':all(v['met'] for v in checks),
            'baselineMetrics':{},'baselineSamples':0,
            'note':'Số giao dịch không phải số ngày. Ngày không ghi nhận được engine điền 0; đây không xác nhận lịch sử đầy đủ.'}
    if n and 'observed' in history:
        result['daysWithRecordedTransactions']=int(history['observed'].sum())
        result['zeroFilledDays']=n-result['daysWithRecordedTransactions']
    # Existing walk-forward baseline backtest. These values are NOT LSTM or ensemble error.
    backtest=service._expense_short_backtest(history)
    errors=np.asarray(backtest.get('errors',[]),dtype=float)
    errors=errors[np.isfinite(errors)]
    result['baselineSamples']=int(backtest.get('samples',0))
    metrics={}
    if errors.size:
        metrics['MAE_VND']=float(np.mean(errors))
        metrics['RMSE_VND']=float(np.sqrt(np.mean(errors**2)))
    wmape=backtest.get('wmape')
    if isinstance(wmape,(int,float)) and math.isfinite(wmape):metrics['WMAPE_percent']=float(wmape)*100
    result['baselineMetrics']=metrics
    result['baselineMeaning']='Walk-forward baseline 2 tầng trên các mốc quá khứ; không phải MAE/RMSE của LSTM hay ensemble.'
    return result


class ObservedKMeans(KMeansService):
    def __init__(self):
        super().__init__()
        self.evaluation_X=None
        self.evaluation_labels=None

    def _select_optimal_k(self,X,requested_k=None):
        self.evaluation_X=np.array(X,copy=True)
        self.evaluation_labels=np.full(len(X),-1,dtype=int)
        return super()._select_optimal_k(X,requested_k)

    def _build_merged_cluster_response(self,profile_key,merged_df,full_df,cluster_index):
        positions=full_df.index.get_indexer(merged_df.index)
        self.evaluation_labels[positions]=cluster_index
        return super()._build_merged_cluster_response(profile_key,merged_df,full_df,cluster_index)


def analyze_kmeans(uid,transactions,year,month,cutoff):
    observer=ObservedKMeans()
    token=CAPTURE_SUPPRESSED.set(True)
    try:
        result=observer.cluster_spending(user_id=uid,transactions=transactions,year=year,month=month,reference_date=cutoff)
    finally:CAPTURE_SUPPRESSED.reset(token)
    data=mapping(result)
    details={'clusters':[],'extraMetrics':{},
             'metricMeaning':'Chỉ số nội tại trên cùng dữ liệu đã phân cụm; không phải accuracy hoặc test độc lập.',
             'modelSourceHash':hashlib.sha256(inspect.getsource(KMeansService).encode()).hexdigest()}
    for raw in data.get('clusters',[]) or []:
        row=mapping(raw);features=row.get('characteristics',{}) or {}
        details['clusters'].append({'id':row.get('clusterId',row.get('cluster_id')),
            'name':row.get('clusterName',row.get('cluster_name')),'percentage':row.get('percentage'),
            'transactionCount':features.get('transactionCount'),'averageAmount':features.get('averageAmount'),
            'totalAmount':features.get('totalAmount'),'essentialRatio':features.get('essentialRatio'),
            'topCategories':features.get('topCategories',{})})
    X,labels=observer.evaluation_X,observer.evaluation_labels
    if X is not None and labels is not None and np.all(labels>=0) and 1<len(np.unique(labels))<len(X):
        for key,fn in [('DaviesBouldin',davies_bouldin_score),('CalinskiHarabasz',calinski_harabasz_score)]:
            try:
                value=float(fn(X,labels))
                if math.isfinite(value):details['extraMetrics'][key]=value
            except (ValueError,FloatingPointError):
                details.setdefault('unavailableMetrics',[]).append(key)
        sse=sum(float(np.sum((X[labels==k]-np.mean(X[labels==k],axis=0))**2)) for k in np.unique(labels))
        if math.isfinite(sse):details['extraMetrics']['WithinClusterSSE']=sse
    return result,details

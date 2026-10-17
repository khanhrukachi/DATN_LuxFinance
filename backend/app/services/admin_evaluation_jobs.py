"""Bounded background analysis using the project's actual service implementations."""
import logging
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from firebase_admin import firestore
from google.cloud.firestore_v1 import transactional
from .admin_evaluation_capture import CAPTURE_SUPPRESSED, build_record, save_record

logger = logging.getLogger(__name__)
_EXECUTOR = ThreadPoolExecutor(max_workers=1, thread_name_prefix='admin-ai')
_LOCAL_GATE = threading.BoundedSemaphore(1)
LEASE_MINUTES = 60
MAX_TRANSACTIONS = 5000


def _client():
    from app.security.firebase_auth import _firebase_app
    return firestore.client(app=_firebase_app())


def ensure_services():
    from .lstm_service import lstm_service
    from .kmeans_service import kmeans_service, _normalize_transactions
    from .isolation_forest_service import isolation_forest_service
    return lstm_service, kmeans_service, isolation_forest_service, _normalize_transactions


def start_job(job_id, uid, year, month, actor):
    client = _client()
    job_ref = client.collection('admin_ai_jobs').document(job_id)
    lock_ref = client.collection('admin_ai_control').document('active')
    parameters = {'userId': uid, 'year': year, 'month': month}
    # Validate native imports before claiming the job. No Firebase writes on import failure.
    from importlib.util import find_spec
    if not find_spec('app.services.lstm_service'):
        raise ImportError('Missing native LuxFinance services')
    if not _LOCAL_GATE.acquire(blocking=False):
        existing = job_ref.get().to_dict() or {}
        if existing.get('actorUid') == actor['uid'] and existing.get('parameters') == parameters:
            return existing
        raise ValueError('Đang chạy một lượt phân tích. Chờ hoàn tất rồi thử lại.')
    now = datetime.now(timezone.utc)

    @transactional
    def claim(transaction):
        existing = job_ref.get(transaction=transaction)
        lock = lock_ref.get(transaction=transaction).to_dict() or {}
        if existing.exists:
            saved = existing.to_dict()
            if saved.get('actorUid') != actor['uid'] or saved.get('parameters') != parameters:
                raise ValueError('Mã yêu cầu đã được dùng cho nội dung khác.')
            return False, saved
        lease_until = lock.get('leaseUntil')
        if lease_until and lease_until > now:
            raise ValueError('Một lượt phân tích khác đang chạy. Chờ hoàn tất trước khi tạo lượt mới.')
        payload = {'id':job_id, 'actorUid':actor['uid'], 'actorEmail':actor.get('email',''),
                   'parameters':parameters, 'status':'queued', 'progress':[],
                   'createdAt':now, 'updatedAt':now, 'leaseUntil':now+timedelta(minutes=LEASE_MINUTES)}
        transaction.create(job_ref, payload)
        transaction.set(lock_ref, {'jobId':job_id, 'leaseUntil':payload['leaseUntil']})
        return True, payload
    try:
        claimed, saved = claim(client.transaction())
        if not claimed:
            _LOCAL_GATE.release()
            return saved
        try:
            _EXECUTOR.submit(run_job, job_id, uid, year, month, actor)
        except Exception:
            job_ref.update({'status':'failed','error':'Không khởi tạo được tác vụ nền.', 'updatedAt':now})
            release_lock(client, job_id)
            raise
        return saved
    except Exception:
        _LOCAL_GATE.release()
        raise


def release_lock(client, job_id):
    ref=client.collection('admin_ai_control').document('active')
    @transactional
    def release(transaction):
        snapshot=ref.get(transaction=transaction)
        if snapshot.exists and snapshot.to_dict().get('jobId') == job_id:
            transaction.delete(ref)
    release(client.transaction())


def get_job(job_id):
    ref=_client().collection('admin_ai_jobs').document(job_id)
    value=ref.get().to_dict()
    if not value:
        return None
    if value.get('status') in ('queued','running') and value.get('leaseUntil') and value['leaseUntil'] < datetime.now(timezone.utc):
        return {**value,'status':'interrupted','error':'Tác vụ quá thời gian hoặc server đã khởi động lại. Có thể tạo lượt mới.'}
    return value


def user_transactions(client, uid):
    from google.cloud.firestore_v1.base_query import FieldFilter
    index = client.collection('data').document(uid).get().to_dict() or {}
    ids = sorted({v for items in index.values() if isinstance(items,list) for v in items
                  if isinstance(v,str) and v and '/' not in v})
    if len(ids)>MAX_TRANSACTIONS:
        raise ValueError('Người dùng có hơn 5.000 ID; cần đánh giá offline với toàn bộ lịch sử.')
    found={};missing=0;conflicts=0;indexed_without_owner=0
    # Union both supported schemas. Never scan the whole spending collection.
    for owner_field in ('userId','uid','user_id','ownerId'):
        query=client.collection('spending').where(filter=FieldFilter(owner_field,'==',uid)).limit(MAX_TRANSACTIONS+1)
        for snap in query.stream():
            found[snap.id]={**(snap.to_dict() or {}),'id':snap.id}
            if len(found)>MAX_TRANSACTIONS:
                raise ValueError('Có hơn 5.000 giao dịch cho UID; không cắt lịch sử âm thầm.')
    explicit_count=len(found)
    remaining=[v for v in ids if v not in found]
    for start in range(0,len(remaining),250):
        refs=[client.collection('spending').document(v) for v in remaining[start:start+250]]
        for snap in client.get_all(refs):
            if not snap.exists:
                missing+=1;continue
            found[snap.id]={**(snap.to_dict() or {}),'id':snap.id}
            if len(found)>MAX_TRANSACTIONS:
                raise ValueError('Hợp dữ liệu có hơn 5.000 giao dịch; cần đánh giá offline.')
    result=[]
    for identity,row in found.items():
        owners={str(row[k]) for k in ('userId','uid','user_id','ownerId') if row.get(k)}
        if owners and owners!={uid}:
            conflicts+=1;continue
        if not owners:indexed_without_owner+=1
        result.append(row)
    return result,{'source':'explicit_uid_queries_union_monthly_index','indexedIds':len(ids),
                   'explicitQueryMatches':explicit_count,'loaded':len(result),'missing':missing,
                   'ownerConflicts':conflicts,'indexOnlyWithoutExplicitOwner':indexed_without_owner,
                   'historyCompleteVerified':False}


def run_job(job_id, uid, year, month, actor):
    client=_client()
    ref=client.collection('admin_ai_jobs').document(job_id)
    progress=[]
    token=CAPTURE_SUPPRESSED.set(True)
    try:
        ref.update({'status':'running','updatedAt':datetime.now(timezone.utc)})
        ls,km,iso,normalize=ensure_services()
        transactions,coverage=user_transactions(client,uid)
        now=datetime.now(ZoneInfo('Asia/Ho_Chi_Minh'))
        if month==12:
            end=datetime(year+1,1,1,tzinfo=now.tzinfo)-timedelta(microseconds=1)
        else:
            end=datetime(year,month+1,1,tzinfo=now.tzinfo)-timedelta(microseconds=1)
        cutoff=min(end,now)
        clean,diagnostics=normalize(transactions,reference_date=cutoff)
        # Normalize accepts a whole reference day: explicitly trim the selected month.
        clean=[v for v in clean if v.date_time.replace(tzinfo=now.tzinfo)<=cutoff]
        scope={'year':year,'month':month,'cutoff':cutoff.isoformat(), 'coverage':coverage,
               'normalization':diagnostics}
        ref.update({'scope':scope})
        for model in ('LSTM','K-Means','Isolation Forest'):
            try:
                model_details={}
                if model=='LSTM':
                    history=ls._prepare_daily_data(clean).tail(ls.max_history_days).copy()
                    if history.empty:
                        meta={'model':'insufficient_history','mae':None}
                    else:
                        _,meta=ls._fit_lstm_and_forecast(history['expense'].to_numpy(dtype=float),7,history=history)
                    from .admin_model_details import lstm_details
                    from .lstm_service import TF_AVAILABLE
                    try:
                        model_details=lstm_details(ls,history,meta,TF_AVAILABLE)
                    except Exception as detail_error:
                        logger.exception('Admin LSTM detail generation failed job=%s',job_id)
                        model_details={'detailsStatus':'failed','detailsError':type(detail_error).__name__}
                    result={'success':True,'summary':{'model':{'expense':{'lstmEvaluation':meta}}},
                            'message':'Đánh giá holdout trực tiếp bằng hàm LSTM của dự án; không chạy dự báo ensemble.'}
                elif model=='K-Means':
                    from .admin_model_details import analyze_kmeans
                    result,model_details=analyze_kmeans(uid,clean,year,month,cutoff)
                else:
                    from .admin_anomaly_snapshot import analyze_with_snapshot, save_snapshot
                    result,observer=analyze_with_snapshot(uid,clean,year,month,cutoff)
                    save_snapshot(client,job_id,uid,year,month,result,observer,clean,scope)
                record=build_record(model,result,uid,len(clean),scope)
                record['jobId']=job_id
                record['recordSource']='admin_job'
                record['details']=model_details
                if model=='K-Means':record['metrics'].update(model_details.get('extraMetrics',{}))
                if model=='Isolation Forest':
                    record['reviewSnapshotId']=job_id
                record['notes']+=' Dữ liệu hợp UID trực tiếp và data/<uid>; chưa xác nhận toàn bộ lịch sử. Ngày không ghi nhận trong chuỗi LSTM được engine điền 0.'
                rid=save_record(record,job_id+'_'+model.replace(' ','_'))
                progress.append({'model':model,'status':record['status'],'recordId':rid})
            except Exception as exc:
                logger.exception('Admin AI job failed model=%s job=%s',model,job_id)
                # Log a small, user-readable error; do not put raw training data in jobs.
                progress.append({'model':model,'status':'failed','error':type(exc).__name__})
            ref.update({'progress':progress,'updatedAt':datetime.now(timezone.utc)})
        status='completed' if all(v['status']!='failed' for v in progress) else 'partial'
        ref.update({'status':status,'updatedAt':datetime.now(timezone.utc)})
        client.collection('admin_audit_logs').document('ai_'+job_id).set({
            'actorUid':actor['uid'],'actorEmail':actor.get('email',''),'action':'ai_analysis_run',
            'targetId':uid,'details':{'jobId':job_id,'year':year,'month':month,'status':status},
            'createdAt':firestore.SERVER_TIMESTAMP})
    except Exception as exc:
        logger.exception('Admin AI job failed job=%s',job_id)
        ref.update({'status':'failed','error':str(exc)[:300] if isinstance(exc,ValueError) else type(exc).__name__,
                    'updatedAt':datetime.now(timezone.utc)})
    finally:
        CAPTURE_SUPPRESSED.reset(token)
        try:
            release_lock(client,job_id)
        except Exception:
            logger.exception('Cannot release admin AI lease %s',job_id)
        _LOCAL_GATE.release()

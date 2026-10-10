from fastapi import Depends
from app.security.ownership import owned_request
from fastapi import APIRouter, HTTPException, Request
from starlette.concurrency import run_in_threadpool
from app.schemas.spending import AnomalyRequest
from app.services.isolation_forest_service import isolation_forest_service
from app.services.kmeans_service import _normalize_transactions

router = APIRouter(prefix='/detect', tags=['Anomaly Detection'])

@router.post('/anomaly', dependencies=[Depends(owned_request)])
async def detect_anomaly(request: AnomalyRequest, raw_request: Request):
    try:
        body=await raw_request.json()
        advisor_context=body.get('advisor_context',body.get('advisorContext',{}))
        if not isinstance(advisor_context,dict):
            advisor_context={}
        result=await run_in_threadpool(isolation_forest_service.detect_anomalies,
            user_id=request.user_id, transactions=body.get('transactions',request.transactions),
            sensitivity=request.sensitivity,
            year=body.get('year',getattr(request,'year',None)),
            month=body.get('month',getattr(request,'month',None)),
            reference_date=body.get('reference_date'),
            category_catalog=body.get('category_catalog',body.get('categoryCatalog',
                advisor_context.get('category_catalog',advisor_context.get('categoryCatalog')))))
        return result.model_dump(by_alias=True)
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400,detail=str(exc))

@router.post('/anomaly/quick', dependencies=[Depends(owned_request)])
async def quick_detect(user_id: str, raw_request: Request, sensitivity: float = 0.1,
                       year: int | None = None, month: int | None = None):
    try:
        body = await raw_request.json()
        if isinstance(body, list):
            transactions, category_catalog = body, None
        elif isinstance(body, dict):
            transactions = body.get('transactions', [])
            category_catalog = body.get('category_catalog', body.get('categoryCatalog'))
        else:
            raise ValueError('Body phải là danh sách giao dịch hoặc object có transactions.')
        # Preserve negative expense money and original category. Never abs(money).
        return await run_in_threadpool(isolation_forest_service.detect_anomalies,
            user_id=user_id,transactions=transactions,sensitivity=sensitivity,year=year,month=month,
            category_catalog=category_catalog)
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400,detail=str(exc))

@router.get('/severity-levels')
async def get_severity_levels():
    return {'levels':[{'level':'high','name':'Cao','color':'#FF4444'},
                      {'level':'medium','name':'Trung bình','color':'#FFAA00'},
                      {'level':'low','name':'Thấp','color':'#44AA44'}]}

@router.post('/check-single', dependencies=[Depends(owned_request)])
async def check_single_transaction(user_id: str, raw_request: Request):
    body = await raw_request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail='Body phải có transaction và history.')
    transaction = body.get('transaction', {})
    history = body.get('history', [])
    category_catalog = body.get('category_catalog', body.get('categoryCatalog'))
    if not isinstance(transaction, dict) or not isinstance(history, list):
        raise HTTPException(status_code=400, detail='transaction phải là object và history phải là danh sách.')
    target,diag=_normalize_transactions([transaction], category_catalog=category_catalog)
    if not target:
        raise HTTPException(status_code=400,detail='Giao dịch không hợp lệ, ở tương lai hoặc là chuyển tiền nội bộ')
    target=target[0]
    if target.money>=0:
        return {'isAnomaly':False,'analyzed':False,'transaction':transaction,
                'anomalyDetails':None,'message':'Thu nhập không được kiểm tra bất thường chi tiêu'}
    # Give an ID when the legacy client does not supply one; avoid collisions.
    if not transaction.get('id'):
        from uuid import uuid4
        target.id='check-'+uuid4().hex
    items,_=_normalize_transactions(history,target.date_time,category_catalog)
    items=[t for t in items if t.id!=target.id and t.date_time<=target.date_time]
    items.append(target)
    result=await run_in_threadpool(isolation_forest_service.detect_anomalies,
        user_id=user_id,transactions=items,sensitivity=.1,
        year=target.date_time.year,month=target.date_time.month,
        reference_date=target.date_time,category_catalog=category_catalog)
    info=next((a for a in result.anomalies if a.transaction_id==target.id),None)
    ready=bool(result.statistics.get('modelReady'))
    return {'isAnomaly':info is not None,'analyzed':result.success,
            'modelReady':ready,'transaction':transaction,
            'anomalyDetails':info.model_dump(by_alias=True) if info else None,
            'message':('Khoản chi khác thường cần kiểm tra bối cảnh.' if info else
                       'Chưa đủ dữ liệu để kết luận giao dịch bình thường.' if not ready else
                       'Chưa phát hiện dấu hiệu bất thường theo mô hình và quy tắc hiện tại.')}

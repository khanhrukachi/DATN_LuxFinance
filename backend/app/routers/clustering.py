from fastapi import Depends
from app.security.ownership import owned_request
from typing import Optional
from fastapi import APIRouter, HTTPException, Request
from starlette.concurrency import run_in_threadpool
from app.schemas.spending import ClusteringRequest
from app.services.kmeans_service import kmeans_service

router = APIRouter(prefix='/cluster', tags=['Clustering'])

@router.post('/behavior', dependencies=[Depends(owned_request)])
async def cluster_behavior(request: ClusteringRequest, raw_request: Request):
    try:
        body = await raw_request.json()
        advisor_context = body.get('advisor_context',body.get('advisorContext',{}))
        if not isinstance(advisor_context,dict):
            advisor_context = {}
        result = await run_in_threadpool(kmeans_service.cluster_spending,
            user_id=request.user_id,
            transactions=body.get('transactions',request.transactions),
            n_clusters=request.n_clusters,
            year=body.get('year',getattr(request,'year',None)),
            month=body.get('month',getattr(request,'month',None)),
            reference_date=body.get('reference_date'),
            category_catalog=body.get('category_catalog',body.get('categoryCatalog',
                advisor_context.get('category_catalog',advisor_context.get('categoryCatalog')))))
        return result.model_dump(by_alias=True)
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post('/behavior/quick', dependencies=[Depends(owned_request)])
async def quick_cluster(user_id: str, raw_request: Request, n_clusters: Optional[int] = None,
                        year: Optional[int] = None, month: Optional[int] = None):
    try:
        body = await raw_request.json()
        if isinstance(body, list):
            transactions, category_catalog = body, None
        elif isinstance(body, dict):
            transactions = body.get('transactions', [])
            category_catalog = body.get('category_catalog', body.get('categoryCatalog'))
        else:
            raise ValueError('Body phải là danh sách giao dịch hoặc object có transactions.')
        return await run_in_threadpool(kmeans_service.cluster_spending,
            user_id=user_id,transactions=transactions,n_clusters=n_clusters,year=year,month=month,
            category_catalog=category_catalog)
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get('/profiles')
async def get_cluster_profiles():
    return {'profiles':[{'key':key,'name':p['name'],
                         'description':p['description_base']}
                        for key,p in kmeans_service.CLUSTER_PROFILES.items()]}

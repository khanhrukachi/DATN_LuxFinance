from typing import Optional
from fastapi import APIRouter, HTTPException, Request, Body
from starlette.concurrency import run_in_threadpool
from app.schemas.spending import ClusteringRequest
from app.services.kmeans_service import kmeans_service

router = APIRouter(prefix='/cluster', tags=['Clustering'])

@router.post('/behavior')
async def cluster_behavior(request: ClusteringRequest, raw_request: Request):
    try:
        body = await raw_request.json()
        result = await run_in_threadpool(kmeans_service.cluster_spending,
            user_id=request.user_id,
            transactions=body.get('transactions',request.transactions),
            n_clusters=request.n_clusters,
            year=body.get('year',getattr(request,'year',None)),
            month=body.get('month',getattr(request,'month',None)),
            reference_date=body.get('reference_date'))
        return result.model_dump(by_alias=True)
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post('/behavior/quick')
async def quick_cluster(user_id: str, transactions: list = Body(...), n_clusters: Optional[int] = None,
                        year: Optional[int] = None, month: Optional[int] = None):
    try:
        return await run_in_threadpool(kmeans_service.cluster_spending,
            user_id=user_id,transactions=transactions,n_clusters=n_clusters,year=year,month=month)
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get('/profiles')
async def get_cluster_profiles():
    return {'profiles':[{'key':key,'name':p['name'],
                         'description':p['description_base']}
                        for key,p in kmeans_service.CLUSTER_PROFILES.items()]}

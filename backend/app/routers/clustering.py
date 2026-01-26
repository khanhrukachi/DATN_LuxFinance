from fastapi import APIRouter, HTTPException
from typing import Optional

from app.schemas.spending import ClusteringRequest
from app.schemas.response import ClusteringResponse
from app.services.kmeans_service import kmeans_service

router = APIRouter(prefix="/cluster", tags=["Clustering"])


@router.post("/behavior")
async def cluster_behavior(request: ClusteringRequest):
    try:
        result = kmeans_service.cluster_spending(
            user_id=request.user_id,
            transactions=request.transactions,
            n_clusters=request.n_clusters
        )
        return result.model_dump(by_alias=True)
    except Exception as e:
        import traceback
        error_detail = f"Clustering error: {str(e)}\n{traceback.format_exc()}"
        print(error_detail)
        raise HTTPException(status_code=500, detail=error_detail)


@router.post("/behavior/quick")
async def quick_cluster(user_id: str, transactions: list, n_clusters: Optional[int] = None):
    try:
        from app.schemas.spending import SpendingItem
        from datetime import datetime

        spending_items = []
        for t in transactions:
            try:
                dt = t.get('dateTime') or t.get('date_time')
                if isinstance(dt, str):
                    for fmt in ['%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S', '%Y-%m-%d']:
                        try:
                            dt = datetime.strptime(dt, fmt)
                            break
                        except:
                            continue

                item = SpendingItem(
                    id=t.get('id', ''),
                    money=int(t.get('money', 0)),
                    type=int(t.get('type', 0)),
                    typeName=t.get('typeName') or t.get('type_name', 'Other'),
                    note=t.get('note'),
                    dateTime=dt,
                    image=t.get('image'),
                    location=t.get('location')
                )
                spending_items.append(item)
            except:
                continue

        if not spending_items:
            return {"success": False, "message": "No valid transactions provided"}

        result = kmeans_service.cluster_spending(
            user_id=user_id,
            transactions=spending_items,
            n_clusters=n_clusters
        )
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quick clustering error: {str(e)}")


@router.get("/profiles")
async def get_cluster_profiles():
    return {
        "profiles": [
            {"key": "high_freq_low_amount", "name": "Chi tieu thuong xuyen", "description": "Nhieu giao dich nho"},
            {"key": "low_freq_high_amount", "name": "Chi tieu lon dinh ky", "description": "It giao dich gia tri cao"},
            {"key": "essential_spending", "name": "Chi tieu thiet yeu", "description": "Cac khoan chi can thiet"},
            {"key": "entertainment_spending", "name": "Chi tieu giai tri", "description": "Mua sam, giai tri"},
            {"key": "mixed_spending", "name": "Chi tieu hon hop", "description": "Da dang loai chi tieu"}
        ]
    }

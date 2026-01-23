from fastapi import APIRouter, HTTPException
from typing import Optional

from app.schemas.spending import AnomalyRequest
from app.schemas.response import AnomalyDetectionResponse
from app.services.isolation_forest_service import isolation_forest_service

router = APIRouter(prefix="/detect", tags=["Anomaly Detection"])


@router.post("/anomaly")
async def detect_anomaly(request: AnomalyRequest):
    try:
        result = isolation_forest_service.detect_anomalies(
            user_id=request.user_id,
            transactions=request.transactions,
            sensitivity=request.sensitivity
        )
        return result.model_dump(by_alias=True)
    except Exception as e:
        import traceback
        error_detail = f"Anomaly detection error: {str(e)}\n{traceback.format_exc()}"
        print(error_detail)
        raise HTTPException(status_code=500, detail=error_detail)


@router.post("/anomaly/quick")
async def quick_detect(user_id: str, transactions: list, sensitivity: float = 0.1):
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

        result = isolation_forest_service.detect_anomalies(
            user_id=user_id,
            transactions=spending_items,
            sensitivity=sensitivity
        )
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quick anomaly detection error: {str(e)}")


@router.get("/severity-levels")
async def get_severity_levels():
    return {
        "levels": [
            {"level": "high", "name": "Cao", "color": "#FF4444"},
            {"level": "medium", "name": "Trung binh", "color": "#FFAA00"},
            {"level": "low", "name": "Thap", "color": "#44AA44"}
        ]
    }


@router.post("/check-single")
async def check_single_transaction(user_id: str, transaction: dict, history: list):
    try:
        from app.schemas.spending import SpendingItem
        from datetime import datetime

        def parse_transaction(t):
            dt = t.get('dateTime') or t.get('date_time')
            if isinstance(dt, str):
                for fmt in ['%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S', '%Y-%m-%d']:
                    try:
                        dt = datetime.strptime(dt, fmt)
                        break
                    except:
                        continue
            return SpendingItem(
                id=t.get('id', 'check'),
                money=int(t.get('money', 0)),
                type=int(t.get('type', 0)),
                typeName=t.get('typeName') or t.get('type_name', 'Other'),
                note=t.get('note'),
                dateTime=dt,
                image=t.get('image'),
                location=t.get('location')
            )

        all_transactions = [parse_transaction(t) for t in history]
        target = parse_transaction(transaction)
        all_transactions.append(target)

        result = isolation_forest_service.detect_anomalies(
            user_id=user_id,
            transactions=all_transactions,
            sensitivity=0.1
        )

        target_id = transaction.get('id', 'check')
        is_anomaly = any(a.transaction_id == target_id for a in result.anomalies)
        anomaly_info = next((a for a in result.anomalies if a.transaction_id == target_id), None)

        return {
            "isAnomaly": is_anomaly,
            "transaction": transaction,
            "anomalyDetails": anomaly_info.dict() if anomaly_info else None,
            "message": "Giao dich bat thuong!" if is_anomaly else "Giao dich binh thuong"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Check error: {str(e)}")

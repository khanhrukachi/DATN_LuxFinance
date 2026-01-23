from fastapi import APIRouter, HTTPException
from typing import Optional

from app.schemas.spending import PredictionRequest
from app.schemas.response import TrendPredictionResponse
from app.services.lstm_service import lstm_service

router = APIRouter(prefix="/predict", tags=["Prediction"])


@router.post("/trend", response_model=TrendPredictionResponse)
async def predict_trend(request: PredictionRequest):
    try:
        print(f"\n{'='*50}")
        print(f"[PREDICT] Received {len(request.transactions)} transactions for user {request.user_id}")
        if request.transactions:
            for i, t in enumerate(request.transactions[:3]):
                print(f"[PREDICT] Trans {i}: money={t.money}, type={t.type}, date={t.date_time}")

        result = lstm_service.predict_trend(
            user_id=request.user_id,
            transactions=request.transactions,
            prediction_days=request.prediction_days
        )

        print(f"[PREDICT] Result success={result.success}")
        print(f"[PREDICT] Summary: {result.summary}")
        if result.predictions:
            for p in result.predictions[:3]:
                print(f"[PREDICT] Pred: date={p.date}, income={p.predicted_income}, expense={p.predicted_expense}")
        print(f"{'='*50}\n")
        return result
    except Exception as e:
        import traceback
        print(f"[PREDICT ERROR] {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


@router.post("/trend/quick")
async def quick_predict(user_id: str, transactions: list, days: int = 7):
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

        result = lstm_service.predict_trend(
            user_id=user_id,
            transactions=spending_items,
            prediction_days=days
        )
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quick prediction error: {str(e)}")

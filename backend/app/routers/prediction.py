from fastapi import Depends
from app.security.ownership import owned_request
"""Drop-in prediction router. Existing URLs and request schema stay intact."""
from fastapi import APIRouter, HTTPException, Request
from starlette.concurrency import run_in_threadpool
from app.schemas.spending import PredictionRequest
from app.schemas.response import TrendPredictionResponse
from app.services.lstm_service import lstm_service

router = APIRouter(prefix='/predict', tags=['Prediction'])

def _context(body):
    value = body.get('advisor_context', body.get('advisorContext', {}))
    if not isinstance(value, dict):
        raise ValueError('advisorContext phải là object')
    result = dict(value)
    # Explicitly forwarded despite older schemas ignoring unknown fields.
    for key in ('budgets','category_labels','category_policies','history_complete',
                'reference_date','use_lstm','recommendation_feedback','dismissed_card_ids',
                'available_balance','events','timezone','category_catalog','categoryCatalog',
                'assets','liabilities','import_items'):
        if key in body and key not in result:
            result[key] = body[key]
    return result

@router.post('/trend', response_model=TrendPredictionResponse, dependencies=[Depends(owned_request)])
async def predict_trend(request: PredictionRequest, raw_request: Request):
    try:
        body = await raw_request.json()
        return await run_in_threadpool(lstm_service.predict_trend,
            user_id=request.user_id,
            transactions=body.get('transactions', request.transactions),
            prediction_days=request.prediction_days,
            year=body.get('year', getattr(request,'year',None)),
            month=body.get('month', getattr(request,'month',None)),
            advisor_context=_context(body),
            forecast_mode=body.get('forecast_mode',body.get('forecastMode','rolling')))
    except (ValueError,TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post('/trend/quick', dependencies=[Depends(owned_request)])
async def quick_predict(user_id: str, raw_request: Request, days: int = 7):
    # Original quick contract is retained: user_id/days query, list JSON body.
    if not 1 <= days <= 30:
        raise HTTPException(status_code=400, detail='days phải nằm trong 1..30')
    body = await raw_request.json()
    if isinstance(body, list):
        transactions, context = body, {}
    elif isinstance(body, dict):
        transactions = body.get('transactions', [])
        context = body.get('advisor_context', body.get('advisorContext', {}))
        if not isinstance(context, dict):
            raise HTTPException(status_code=400, detail='advisor_context phải là object')
        if 'category_catalog' in body:
            context.setdefault('category_catalog', body['category_catalog'])
        elif 'categoryCatalog' in body:
            context.setdefault('category_catalog', body['categoryCatalog'])
    else:
        raise HTTPException(status_code=400, detail='Body phải là danh sách hoặc object có transactions')
    return await run_in_threadpool(lstm_service.predict_trend,
        user_id=user_id, transactions=transactions, prediction_days=days, advisor_context=context)

"""Mount this router once. Existing Firebase Admin initialization is reused."""
from __future__ import annotations
import logging
import uuid
from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, HTTPException, Request
from app.security.firebase_auth import authenticated_uid
from pydantic import BaseModel, Field
from starlette.concurrency import run_in_threadpool

router = APIRouter(prefix='/chat', tags=['financial-chat'])
logger = logging.getLogger(__name__)


class ChatRequest(BaseModel):
    user_id: str | None = Field(default=None, min_length=1, max_length=128)
    question: str = Field(min_length=1, max_length=2000)
    transactions: list[dict[str, Any]] = Field(default_factory=list, max_length=10000)
    category_catalog: list[dict[str, Any]] = Field(default_factory=list, max_length=500)
    advisor_context: dict[str, Any] = Field(default_factory=dict)
    history: list[dict[str, str]] = Field(default_factory=list, max_length=6)


def resolve_followup(service, request, today):
    from ..services.chat_ai_service import folded
    import re
    q = request.question.strip()
    text = folded(q)
    # Only inherit explicit category/period scope from the last user question.
    # Never execute instructions embedded in assistant text or client evidence.
    if not request.history or not re.search(r'\b(con|thi sao|cung ky|bao nhieu lan|chi tiet|liet ke|trung binh|ty trong)\b', text):
        return q
    old = next((h.get('content','') for h in reversed(request.history) if h.get('role')=='user'), '')
    if not old:return q
    canonical = service.canonical_question(q, request.category_catalog)
    previous = service.canonical_question(old, request.category_catalog)
    targets = service.finance._query_category_targets(canonical, request.category_catalog)
    if not targets:
        q += ' ' + ' '.join(service.finance._query_category_targets(previous, request.category_catalog))
    if not re.search(r'\b(hom|ngay|tuan|thang|nam|today|week|month|year)\b|\d/\d', text):
        start,end,_ = service.query_engine.period(previous,today)
        q += f' từ {start:%d/%m/%Y} đến {end:%d/%m/%Y}'
    return q


@router.post('/ask')
async def ask(request: ChatRequest, raw_request: Request, uid: str = Depends(authenticated_uid)):
    if request.user_id is not None and uid != request.user_id:
        raise HTTPException(403, detail='User mismatch')
    if not request.question.strip():
        raise HTTPException(422, detail='Question cannot be blank')
    budgets = request.advisor_context.get('budgets', [])
    if not isinstance(budgets,list) or len(budgets)>1000 or not all(isinstance(b,dict) for b in budgets):
        raise HTTPException(422, detail='budgets phải chứa tối đa 1000 object.')
    request_id = getattr(raw_request.state, 'request_id', uuid.uuid4().hex[:12])
    try:
        from ..services.chat_ai_service import get_chat_ai_service, plain
        service = await run_in_threadpool(get_chat_ai_service)
        today = datetime.now(ZoneInfo('Asia/Ho_Chi_Minh')).date()
        question = resolve_followup(service, request, today)
        result = await run_in_threadpool(service.answer,
            user_id=uid, question=question, transactions=request.transactions,
            category_catalog=request.category_catalog, advisor_context=request.advisor_context,
            reference_date=today)
        result.update(requestId=request_id, question=request.question)
        return plain(result)
    except (ImportError, ModuleNotFoundError):
        logger.exception('Chat dependency failure request_id=%s', request_id)
        raise HTTPException(503, detail={'code':'chat_dependency_unavailable','requestId':request_id})
    except Exception:
        logger.exception('Chat processing failure request_id=%s', request_id)
        raise HTTPException(500, detail={'code':'chat_processing_failed','requestId':request_id})


@router.get('/capabilities')
def capabilities():
    return {'status':'ok','revision':'finance_category_chat_v4','currency':'VND',
            'capabilities':['category_definition','category_summary','category_average',
              'category_share','category_comparison','period_comparison','transaction_details',
              'budget_status','spending_forecast','behavior_analysis','anomaly_analysis',
              'financial_recommendations','payment_capacity'],
            'forecastDays':{'min':1,'max':30},'maxTransactions':10000}

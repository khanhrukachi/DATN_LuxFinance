"""Text Q&A adapter over the project's existing finance/ML services."""
import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from starlette.concurrency import run_in_threadpool

from app.security.firebase_auth import authenticated_uid
from app.services.chat_ai_service import get_chat_ai_service

router = APIRouter(prefix='/chat', tags=['Chat AI'])
_log = logging.getLogger(__name__)


class ChatAskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    user_id: str | None = None
    transactions: list[dict[str, Any]] = Field(default_factory=list, max_length=10000)
    category_catalog: list[dict[str, Any]] = Field(default_factory=list, max_length=500)
    advisor_context: dict[str, Any] = Field(default_factory=dict)


@router.post('/ask')
async def ask_chat(body: ChatAskRequest, uid: str = Depends(authenticated_uid)):
    if body.user_id is not None and body.user_id != uid:
        raise HTTPException(status_code=403, detail='Tài khoản gửi dữ liệu không khớp phiên đăng nhập.')
    question = body.question.strip()
    if not question:
        raise HTTPException(status_code=422, detail='Câu hỏi không được để trống.')
    budgets = body.advisor_context.get('budgets', [])
    if not isinstance(budgets, list) or len(budgets) > 1000 or not all(isinstance(b, dict) for b in budgets):
        raise HTTPException(status_code=422, detail='budgets phải là danh sách tối đa 1000 object.')
    try:
        return await run_in_threadpool(
            get_chat_ai_service().answer, user_id=uid, question=question,
            transactions=body.transactions, category_catalog=body.category_catalog,
            advisor_context=body.advisor_context,
        )
    except (ValueError, TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        _log.exception('Chat AI processing failed')
        raise HTTPException(status_code=500, detail='AI chưa xử lý được yêu cầu. Bạn có thể thử lại.')

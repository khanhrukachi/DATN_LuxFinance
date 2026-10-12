"""Optional standalone route; same secured read-only contract as chat/ask."""
from fastapi import APIRouter, Depends, HTTPException, Request
from app.security.firebase_auth import authenticated_uid
from .chat import ChatRequest, ask as chat_ask
from ..services.debt_qa_service import DebtQAService
router=APIRouter(prefix='/debt',tags=['Debt Q&A'])
@router.post('/ask')
async def ask(request:ChatRequest,raw_request:Request,uid:str=Depends(authenticated_uid)):
    if request.user_id is not None and request.user_id!=uid:raise HTTPException(403,detail='User mismatch')
    if not (DebtQAService.is_debt_question(request.question,request.history) or request.debt_contact_id or request.debt_id):
        return DebtQAService.response('debt_question_clarification','Hãy hỏi về sổ nợ: số còn nợ, người vay/cho vay, tiền đã trả hoặc hạn trả.',needs=['debt_question'])
    return await chat_ask(request,raw_request,uid)

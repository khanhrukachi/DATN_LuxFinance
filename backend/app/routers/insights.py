from fastapi import Depends
from app.security.ownership import owned_request
"""Reporting, natural-language finance Q&A and recommendation endpoints."""
from typing import Any
from fastapi import APIRouter, HTTPException, Request
from starlette.concurrency import run_in_threadpool
from app.services.financial_insights_service import financial_insights_service
from app.routers.chat import ChatRequest, ask as answer_chat

router = APIRouter(prefix="/insights", tags=["Financial Insights"])


async def _body(request: Request) -> dict[str, Any]:
    data = await request.json()
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="Body phải là object JSON.")
    if not data.get("user_id", data.get("userId")):
        raise HTTPException(status_code=422, detail="Thiếu userId.")
    if not isinstance(data.get("transactions", []), list):
        raise HTTPException(status_code=422, detail="transactions phải là danh sách.")
    return data


def _common(data: dict[str, Any]) -> dict[str, Any]:
    context = data.get("advisor_context", data.get("advisorContext", {}))
    if not isinstance(context, dict):
        raise ValueError("advisorContext phải là object.")
    context = dict(context)
    for key in ("budgets", "available_balance", "events", "timezone", "history_complete"):
        if key in data:
            context.setdefault(key, data[key])
    return {
        "user_id": data.get("user_id", data.get("userId")),
        "transactions": data.get("transactions", []),
        "reference_date": data.get("reference_date", data.get("referenceDate")),
        "category_catalog": data.get("category_catalog", data.get("categoryCatalog")),
        "advisor_context": context,
    }


@router.post("/report", dependencies=[Depends(owned_request)])
async def report(request: Request):
    try:
        data = await _body(request)
        args = _common(data)
        return await run_in_threadpool(
            financial_insights_service.generate_report,
            **args,
            period=data.get("period", "month"), year=data.get("year"), month=data.get("month"),
            start_date=data.get("start_date", data.get("startDate")),
            end_date=data.get("end_date", data.get("endDate")),
            include_models=data.get("include_models", data.get("includeModels", True)),
        )
    except (ValueError, TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/ask", dependencies=[Depends(owned_request)])
async def ask(request: Request):
    try:
        data = await _body(request)
        question = data.get("question")
        if not isinstance(question, str) or not question.strip():
            raise HTTPException(status_code=422, detail="question không được để trống.")
        args = _common(data)
        payload = ChatRequest(user_id=args['user_id'], question=question,
            transactions=args['transactions'], category_catalog=args['category_catalog'] or [],
            advisor_context=args['advisor_context'], history=data.get('history', []))
        return await answer_chat(payload, raw_request=request, uid=args['user_id'])
    except (ValueError, TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/recommendations", dependencies=[Depends(owned_request)])
async def recommendations(request: Request):
    try:
        data = await _body(request)
        return await run_in_threadpool(
            financial_insights_service.build_recommendations,
            **_common(data), budgets=_common(data)["advisor_context"].get("budgets", []),
            savings_rate=data.get("savings_rate", data.get("savingsRate", 0.10)),
        )
    except (ValueError, TypeError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))

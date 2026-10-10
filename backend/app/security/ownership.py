from fastapi import Depends, HTTPException, Request
from app.security.firebase_auth import authenticated_uid

async def owned_request(request: Request, uid: str = Depends(authenticated_uid)):
    try:
        body = await request.json()
    except (ValueError, UnicodeDecodeError):
        raise HTTPException(422, detail="Body phải là JSON hợp lệ.") from None
    candidates = [request.query_params.get("user_id"), request.query_params.get("userId")]
    if isinstance(body, dict):
        candidates.extend([body.get("user_id"), body.get("userId")])
        transactions = body.get("transactions", body.get("history", []))
    elif isinstance(body, list):
        transactions = body
    else:
        raise HTTPException(422, detail="Body phải là object hoặc danh sách.")
    if any(value is not None and value != uid for value in candidates):
        raise HTTPException(403, detail="Tài khoản không khớp phiên đăng nhập.")
    if not isinstance(transactions, list) or len(transactions) > 10000 or not all(isinstance(t, dict) for t in transactions):
        raise HTTPException(422, detail="transactions/history phải chứa tối đa 10000 object.")
    if isinstance(body, dict):
        context = body.get('advisor_context', body.get('advisorContext', {}))
        if not isinstance(context,dict):
            raise HTTPException(422,detail='advisor_context phải là object.')
        budgets = body.get('budgets',context.get('budgets',[]))
        if not isinstance(budgets,list) or len(budgets)>1000 or not all(isinstance(b,dict) for b in budgets):
            raise HTTPException(422,detail='budgets phải chứa tối đa 1000 object.')
        for key, limit in (("category_catalog",500),("categoryCatalog",500)):
            if key in body and (not isinstance(body[key],list) or len(body[key])>limit or not all(isinstance(t,dict) for t in body[key])):
                raise HTTPException(422, detail="Danh mục phải chứa tối đa 500 object.")
    return uid

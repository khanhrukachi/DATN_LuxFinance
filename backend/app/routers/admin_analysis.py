"""Mount ONLY on the existing LuxFinance AI server, after Firebase initialization.
No changes to ownership checks on the app's existing prediction/chat routes.
"""
from datetime import datetime
from typing import Annotated
from uuid import UUID
from zoneinfo import ZoneInfo
import logging

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, firestore
from pydantic import BaseModel, Field
from app.services.admin_evaluation_jobs import start_job, get_job
from app.security.firebase_auth import _firebase_app

logger=logging.getLogger(__name__)
router=APIRouter(prefix='/api/v1/admin/evaluations',tags=['Admin AI Analysis'])
bearer=HTTPBearer(auto_error=False)


def admin(credentials:Annotated[HTTPAuthorizationCredentials|None,Depends(bearer)]):
    if not credentials:
        raise HTTPException(401,'Thiếu phiên đăng nhập quản trị.')
    try:
        firebase_app=_firebase_app()
    except Exception:
        logger.error('Cannot initialize Firebase for admin AI analysis')
        raise HTTPException(503,'Server AI chưa khởi tạo được Firebase Admin; kiểm tra cấu hình khóa hiện có.') from None
    try:
        token=auth.verify_id_token(credentials.credentials,app=firebase_app,check_revoked=True)
    except (auth.InvalidIdTokenError,auth.ExpiredIdTokenError,auth.RevokedIdTokenError,
            auth.UserDisabledError,auth.UserNotFoundError,ValueError):
        raise HTTPException(401,'Phiên quản trị không hợp lệ hoặc đã bị thu hồi.') from None
    except Exception:
        logger.error('Firebase cannot verify admin AI session')
        raise HTTPException(503,'Server AI chưa xác minh được phiên Firebase. Kiểm tra credential/project của server AI.') from None
    try:
        role=firestore.client(app=firebase_app).collection('users').document(token['uid']).get().to_dict() or {}
    except Exception:
        logger.error('Cannot read admin role for AI analysis')
        raise HTTPException(503,'Server AI chưa đọc được quyền quản trị từ Firestore.') from None
    if role.get('isActive') is False or not (token.get('admin') is True or
        (role.get('role')=='admin' and role.get('isActive') is True)):
        raise HTTPException(403,'Tài khoản không có quyền chạy phân tích quản trị.')
    return token


class AnalysisRequest(BaseModel):
    id:UUID
    userId:str=Field(min_length=1,max_length=128)
    year:int=Field(ge=2000,le=2100)
    month:int=Field(ge=1,le=12)


@router.post('/run',status_code=202)
def run(body:AnalysisRequest,actor:Annotated[dict,Depends(admin)]):
    if '/' in body.userId or body.userId in ('.','..'):
        raise HTTPException(422,'UID không hợp lệ.')
    today=datetime.now(ZoneInfo('Asia/Ho_Chi_Minh'))
    if (body.year,body.month)>(today.year,today.month):
        raise HTTPException(422,'Không phân tích tháng tương lai.')
    if not firestore.client(app=_firebase_app()).collection('info').document(body.userId).get().exists:
        raise HTTPException(404,'Không tìm thấy hồ sơ người dùng.')
    try:
        return start_job(str(body.id),body.userId,body.year,body.month,actor)
    except ImportError as exc:
        logger.exception('Native AI services unavailable')
        raise HTTPException(503,'Không tải được service AI trên server AI; kiểm tra log triển khai.') from exc
    except ValueError as exc:
        raise HTTPException(409,str(exc))


@router.get('/jobs/{job_id}')
def status(job_id:UUID,actor:Annotated[dict,Depends(admin)]):
    result=get_job(str(job_id))
    if not result:
        raise HTTPException(404,'Không tìm thấy lượt phân tích trên server AI.')
    return result

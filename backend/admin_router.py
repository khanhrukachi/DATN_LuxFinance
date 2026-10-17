"""LuxFinance admin routes. Include this router in an existing initialized FastAPI app."""
from datetime import datetime, timezone
from hashlib import sha256
import json
import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, firestore
from google.cloud.firestore_v1 import transactional
from pydantic import BaseModel, Field, StrictBool, field_validator

router = APIRouter(prefix='/api/v1/admin', tags=['admin'])
bearer = HTTPBearer(auto_error=False)
logger = logging.getLogger(__name__)


def firebase_app():
    from admin_firebase import get_firebase_app
    return get_firebase_app()


def db():
    return firestore.client(app=firebase_app())


def valid_id(value: str):
    if not value or '/' in value or value in ('.', '..') or len(value.encode()) > 1500:
        raise HTTPException(422, 'ID không hợp lệ.')
    return value


def admin(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
    if not credentials or credentials.scheme.lower() != 'bearer':
        raise HTTPException(401, 'Thiếu phiên đăng nhập.')
    try:
        shared_app = firebase_app()
    except Exception as exc:
        logger.error('Admin Firebase initialization failed: %s', type(exc).__name__)
        raise HTTPException(503, 'Backend chưa khởi tạo được Firebase. Kiểm tra cấu hình credential của backend.') from None
    try:
        token = auth.verify_id_token(credentials.credentials, app=shared_app, check_revoked=True)
    except auth.ExpiredIdTokenError:
        raise HTTPException(401, 'Phiên đăng nhập hết hạn. Đăng xuất và đăng nhập lại web admin.') from None
    except (auth.RevokedIdTokenError, auth.UserDisabledError, auth.UserNotFoundError):
        raise HTTPException(401, 'Phiên đăng nhập đã bị thu hồi hoặc tài khoản không còn hoạt động.') from None
    except auth.InvalidIdTokenError:
        logger.warning('Admin ID token rejected; verify web and backend Firebase project match')
        raise HTTPException(401, 'Token Firebase không hợp lệ. Kiểm tra web và backend dùng cùng Firebase project, rồi đăng nhập lại.') from None
    except Exception as exc:
        # Log type only; never print tokens, private keys, or credential payloads.
        logger.error('Admin Firebase verification unavailable: %s', type(exc).__name__)
        raise HTTPException(503, 'Firebase chưa xác minh được phiên. Kiểm tra credential, kết nối và đồng hồ backend.') from None
    try:
        role = db().collection('users').document(token['uid']).get().to_dict() or {}
    except Exception as exc:
        logger.error('Admin role lookup failed: %s', type(exc).__name__)
        raise HTTPException(503, 'Backend chưa đọc được quyền quản trị từ Firestore.') from None
    if role.get('isActive') is False or not (
        token.get('admin') is True or (role.get('role') == 'admin' and role.get('isActive') is True)
    ):
        raise HTTPException(403, 'Tài khoản không có quyền quản trị.')
    return token


Admin = Annotated[dict, Depends(admin)]


def audit_data(actor, action, target, details):
    return {'actorUid': actor['uid'], 'actorEmail': actor.get('email', ''),
            'action': action, 'targetId': target, 'details': details,
            'createdAt': firestore.SERVER_TIMESTAMP}


def rows(collection, cap):
    snapshots = db().collection(collection).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(cap).stream()
    return {'items': [{**s.to_dict(), 'id': s.id} for s in snapshots]}


class ProfilePatch(BaseModel):
    name: str = Field(max_length=200)
    job: str = Field(max_length=200)
    currentAddress: str = Field(max_length=500)


class TransactionPatch(BaseModel):
    note: str = Field(max_length=3000)
    location: str = Field(max_length=1000)


class StatusPatch(BaseModel):
    disabled: StrictBool


class Notification(BaseModel):
    id: UUID
    title: str = Field(min_length=1, max_length=150)
    body: str = Field(min_length=1, max_length=3000)
    recipients: list[str] = Field(min_length=1, max_length=200)

    @field_validator('title', 'body')
    @classmethod
    def nonempty(cls, value):
        value = value.strip()
        if not value:
            raise ValueError('Nội dung không được để trống.')
        return value

    @field_validator('recipients')
    @classmethod
    def recipients_valid(cls, values):
        for value in values:
            valid_id(value)
        return sorted(set(values))


@router.get('/status')
def status(actor: Admin):
    db().collection('users').document(actor['uid']).get()
    return {'firestore': 'ok', 'checkedAt': datetime.now(timezone.utc).isoformat()}


@router.get('/users/{uid}')
def account(uid: str, actor: Admin):
    valid_id(uid)
    try:
        user = auth.get_user(uid)
    except auth.UserNotFoundError:
        raise HTTPException(404, 'Hồ sơ không còn tài khoản Firebase Authentication tương ứng.')
    role = db().collection('users').document(uid).get().to_dict() or {}
    last = user.user_metadata.last_sign_in_timestamp
    return {'uid': uid, 'email': user.email, 'emailVerified': user.email_verified,
            'disabled': user.disabled,
            'isAdmin': (user.custom_claims or {}).get('admin') is True or role.get('role') == 'admin',
            'lastSignInTime': datetime.fromtimestamp(last / 1000, timezone.utc).isoformat() if last else None}


def patch_with_audit(path, identity, values, actor, action):
    client = db()
    ref = client.collection(path).document(valid_id(identity))
    log = client.collection('admin_audit_logs').document()

    @transactional
    def apply(transaction):
        old = ref.get(transaction=transaction)
        if not old.exists:
            raise HTTPException(404, 'Không tìm thấy bản ghi.')
        before = {key: (old.to_dict() or {}).get(key) for key in values}
        transaction.update(ref, {**values, 'updatedAt': firestore.SERVER_TIMESTAMP})
        transaction.create(log, audit_data(actor, action, identity, {'before': before, 'after': values}))
    apply(client.transaction())
    return {'ok': True}


@router.patch('/users/{uid}/profile')
def profile(uid: str, body: ProfilePatch, actor: Admin):
    return patch_with_audit('info', uid, {k: v.strip() for k, v in body.model_dump().items()}, actor, 'profile_update')


@router.patch('/transactions/{identity}')
def transaction_note(identity: str, body: TransactionPatch, actor: Admin):
    return patch_with_audit('spending', identity, {k: v.strip() for k, v in body.model_dump().items()}, actor, 'transaction_update')


@router.patch('/users/{uid}/status')
def change_status(uid: str, body: StatusPatch, actor: Admin):
    valid_id(uid)
    if uid == actor['uid']:
        raise HTTPException(409, 'Không được khóa chính tài khoản đang sử dụng.')
    try:
        user = auth.get_user(uid)
    except auth.UserNotFoundError:
        raise HTTPException(404, 'Không tìm thấy tài khoản Authentication.')
    role = db().collection('users').document(uid).get().to_dict() or {}
    if (user.custom_claims or {}).get('admin') is True or role.get('role') == 'admin':
        raise HTTPException(409, 'Không thay đổi trạng thái tài khoản quản trị tại đây.')
    # Auth and Firestore cannot share a transaction: write intent first and report partial failure.
    log = db().collection('admin_audit_logs').document()
    log.set(audit_data(actor, 'account_status', uid, {
        'beforeDisabled': user.disabled, 'afterDisabled': body.disabled, 'status': 'requested'}))
    updated = False
    try:
        auth.update_user(uid, disabled=body.disabled)
        updated = True
        if body.disabled:
            auth.revoke_refresh_tokens(uid)
        log.update({'details.status': 'completed'})
    except Exception:
        logger.exception('Account status operation failed; audit=%s', log.id)
        try:
            log.update({'details.status': 'partial' if updated else 'failed'})
        except Exception:
            logger.exception('Cannot update audit status')
        raise HTTPException(503, 'Thao tác chưa hoàn tất. Mở lại hồ sơ để kiểm tra trạng thái trước khi thử lại.')
    return {'ok': True, 'disabled': body.disabled}


@router.get('/audit')
def audit_list(actor: Admin):
    return rows('admin_audit_logs', 200)


@router.get('/evaluations')
def evaluations(actor: Admin, userId: str | None = None, year: int | None = None,
                month: int | None = None, source: str = 'admin_job', jobId: UUID | None = None):
    from admin_evaluation_views import evaluation_rows
    if source not in ('all','admin_job','app_inference'):
        raise HTTPException(422,'Nguồn kết quả không hợp lệ.')
    if (year is None)!=(month is None) or (month is not None and not 1<=month<=12):
        raise HTTPException(422,'Cần truyền đồng thời năm và tháng hợp lệ.')
    return evaluation_rows(db(),userId,year,month,source,str(jobId) if jobId else None)


@router.get('/notifications')
def notifications(actor: Admin):
    return rows('admin_notifications', 100)


@router.post('/notifications')
def send_notification(body: Notification, actor: Admin):
    client = db()
    campaign_id = str(body.id)
    ref = client.collection('admin_notifications').document(campaign_id)
    log = client.collection('admin_audit_logs').document('notification_' + campaign_id)
    payload = {'title': body.title, 'body': body.body, 'recipients': body.recipients}
    fingerprint = sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
    # Check user profiles; no arbitrary orphan notification trees.
    profiles = list(client.get_all([client.collection('info').document(uid) for uid in body.recipients]))
    if any(not p.exists for p in profiles):
        raise HTTPException(422, 'Có người nhận không còn hồ sơ; tải lại danh sách.')

    @transactional
    def deliver(transaction):
        existing = ref.get(transaction=transaction)
        if existing.exists:
            saved = existing.to_dict()
            if saved.get('fingerprint') != fingerprint or saved.get('actorUid') != actor['uid']:
                raise HTTPException(409, 'Mã yêu cầu đã dùng cho nội dung khác.')
            return  # The same request can be retried without duplicate messages.
        for uid in body.recipients:
            inbox = client.collection('users').document(uid).collection('notifications').document('admin_' + campaign_id)
            transaction.create(inbox, {
                'id': 'admin_' + campaign_id, 'title': body.title,
                'body': body.body, 'message': body.body,
                'type': 'system', 'isRead': False,
                'createdAt': firestore.SERVER_TIMESTAMP,
                'deduplicationKey': 'admin_' + campaign_id,
                'campaignId': campaign_id,
            })
        transaction.create(ref, {**payload, 'fingerprint': fingerprint,
            'recipientCount': len(body.recipients), 'actorUid': actor['uid'],
            'actorEmail': actor.get('email', ''), 'createdAt': firestore.SERVER_TIMESTAMP})
        transaction.create(log, audit_data(actor, 'notification_send', campaign_id,
            {'title': body.title, 'recipientCount': len(body.recipients)}))
    deliver(client.transaction())
    return {'ok': True, 'id': campaign_id, 'recipientCount': len(body.recipients)}


class AnalysisJobRequest(BaseModel):
    id: UUID
    userId: str = Field(min_length=1, max_length=128)
    year: int = Field(ge=2000, le=2100)
    month: int = Field(ge=1, le=12)


def ai_request(path, method, bearer_token, payload=None):
    """Forward only to a deployment-configured AI server, never a user-supplied URL."""
    import os
    import urllib.request
    import urllib.error
    from urllib.parse import urlsplit
    base=os.getenv('AI_ANALYSIS_API_BASE_URL','').rstrip('/')
    parsed=urlsplit(base)
    if not base:
        raise HTTPException(503,'Chưa đặt AI_ANALYSIS_API_BASE_URL trên server quản trị.')
    if parsed.scheme not in ('http','https') or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise HTTPException(503,'AI_ANALYSIS_API_BASE_URL không hợp lệ.')
    if parsed.scheme != 'https' and parsed.hostname not in ('localhost','127.0.0.1'):
        raise HTTPException(503,'Kết nối server AI từ xa phải dùng HTTPS.')
    request=urllib.request.Request(base+'/api/v1/admin/evaluations'+path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization':bearer_token,'Content-Type':'application/json'},method=method)
    try:
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None
        opener=urllib.request.build_opener(NoRedirect())
        with opener.open(request,timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail={}
        try:detail=json.loads(exc.read(16384))
        except (ValueError,UnicodeDecodeError):pass
        message=detail.get('detail') if isinstance(detail,dict) else None
        if not isinstance(message,str):
            message='Server AI trả lỗi '+str(exc.code)+'. Kiểm tra đã ghép admin_analysis.py trên server AI chưa.'
        raise HTTPException(exc.code if 400<=exc.code<500 else 502,message)
    except (urllib.error.URLError,TimeoutError,ValueError) as exc:
        raise HTTPException(504,'Chưa nhận được phản hồi từ server AI. Kiểm tra lại trạng thái tác vụ trước khi tạo lượt mới.') from exc


@router.post('/evaluations/run', status_code=202)
def run_evaluations(body: AnalysisJobRequest, request: Request, actor: Admin):
    from zoneinfo import ZoneInfo
    valid_id(body.userId)
    today=datetime.now(ZoneInfo('Asia/Ho_Chi_Minh'))
    if (body.year,body.month)>(today.year,today.month):
        raise HTTPException(422,'Chọn tháng hiện tại hoặc quá khứ để phân tích dữ liệu thật.')
    if getattr(request.app.state, 'admin_analysis_mode', 'remote') == 'local':
        from app.routers.admin_analysis import AnalysisRequest, run
        return run(AnalysisRequest(**body.model_dump()), actor)
    return ai_request('/run','POST',request.headers.get('Authorization',''),body.model_dump(mode='json'))


@router.get('/evaluations/jobs/{job_id}')
def evaluation_job(job_id: UUID, request: Request, actor: Admin):
    if getattr(request.app.state, 'admin_analysis_mode', 'remote') == 'local':
        from app.routers.admin_analysis import status
        return status(job_id, actor)
    return ai_request('/jobs/'+str(job_id),'GET',request.headers.get('Authorization',''))

# Manual verification runs on the ADMIN server. No model training here.
from typing import Literal
from pydantic import StrictBool
import admin_anomaly_review as anomaly_review


class ManualLabelRequest(BaseModel):
    transactionId: str = Field(min_length=1,max_length=1500)
    actualLabel: Literal['normal','anomaly','unreviewed']
    reason: str = Field(min_length=1,max_length=2000)
    expectedVersion: int = Field(ge=0)
    predictionVisibleAtReview: StrictBool = False


class VerificationReportRequest(BaseModel):
    id: UUID
    expectedRevision: int = Field(ge=0)


def review_action(fn,*args,**kwargs):
    try:return fn(*args,**kwargs)
    except anomaly_review.ReviewError as exc:
        raise HTTPException(exc.status,str(exc)) from None


@router.get('/anomaly-review/runs')
def review_runs(actor: Admin):
    return anomaly_review.list_runs(db())


@router.get('/anomaly-review/runs/{run_id}/items')
def review_items(run_id: UUID, actor: Admin, cursor: str | None = None, reveal: bool = False):
    return review_action(anomaly_review.list_items,db(),str(run_id),cursor,reveal)


@router.patch('/anomaly-review/runs/{run_id}/label')
def review_label(run_id: UUID,body: ManualLabelRequest,actor: Admin):
    return review_action(anomaly_review.save_label,db(),str(run_id),body.transactionId,
        body.actualLabel,body.reason,body.expectedVersion,body.predictionVisibleAtReview,actor)


@router.post('/anomaly-review/runs/{run_id}/reports')
def report_review(run_id: UUID,body: VerificationReportRequest,actor: Admin):
    return review_action(anomaly_review.create_report,db(),str(run_id),str(body.id),body.expectedRevision,actor)


@router.get('/anomaly-review/reports')
def review_reports(actor: Admin):
    return anomaly_review.list_reports(db())


@router.get('/anomaly-review/runs/{run_id}')
def review_metadata(run_id: UUID,actor: Admin):
    _,run=review_action(anomaly_review.ready_run,db(),str(run_id))
    return run

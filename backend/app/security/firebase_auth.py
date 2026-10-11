"""Verify Firebase sessions using local or Render service-account credentials."""
import logging
import os
import threading
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials
from fastapi import Header, HTTPException
from google.auth.exceptions import RefreshError
from starlette.concurrency import run_in_threadpool

_log = logging.getLogger(__name__)
_init_lock = threading.Lock()
SERVICE_ACCOUNT_PATH = Path(__file__).resolve().parent / "service-account.json"
RENDER_SERVICE_ACCOUNT_PATH = Path("/etc/secrets/service-account.json")


def _firebase_app():
    with _init_lock:
        try:
            return firebase_admin.get_app()
        except ValueError:
            pass

        from app.config import settings
        # An explicit environment variable takes precedence over settings defaults.
        configured = (os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
                      or getattr(settings, "GOOGLE_APPLICATION_CREDENTIALS", None))
        if configured:
            path = Path(configured).expanduser()
            if not path.is_file():
                raise RuntimeError("Configured Firebase credential file is unavailable")
        elif RENDER_SERVICE_ACCOUNT_PATH.is_file():
            path = RENDER_SERVICE_ACCOUNT_PATH
        elif SERVICE_ACCOUNT_PATH.is_file():
            path = SERVICE_ACCOUNT_PATH
        else:
            path = None

        credential = (credentials.Certificate(str(path)) if path
                      else credentials.ApplicationDefault())
        project_id = (os.getenv("FIREBASE_PROJECT_ID")
                      or getattr(settings, "FIREBASE_PROJECT_ID", None))
        options = {"projectId": project_id} if project_id else None
        app = firebase_admin.initialize_app(credential, options=options)
        _log.info("Firebase Admin initialized: project=%s, credential_source=%s",
                  app.project_id, str(path) if path else "ApplicationDefault")
        return app


def _verify(token: str) -> str:
    try:
        decoded = auth.verify_id_token(token, app=_firebase_app(), check_revoked=True)
        uid = decoded.get("uid") or decoded.get("sub")
        if not uid:
            raise HTTPException(status_code=401, detail="Phiên đăng nhập không hợp lệ.")
        return str(uid)
    except auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Phiên đăng nhập hết hạn. Hãy đăng nhập lại.") from None
    except auth.RevokedIdTokenError:
        raise HTTPException(status_code=401, detail="Phiên đăng nhập đã bị thu hồi. Hãy đăng nhập lại.") from None
    except auth.UserDisabledError:
        raise HTTPException(status_code=401, detail="Tài khoản đã bị vô hiệu hóa.") from None
    except auth.UserNotFoundError:
        raise HTTPException(status_code=401, detail="Tài khoản không còn tồn tại.") from None
    except auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Phiên đăng nhập không hợp lệ.") from None
    except RefreshError:
        # Never fall back to accepting a session without checking revocation.
        # Do not log exception payloads that can contain credential information.
        _log.error("Firebase service-account authentication failed. Replace invalid, "
                   "deleted or disabled credentials and restart the backend.")
        raise HTTPException(
            status_code=503,
            detail="Khóa Firebase Admin không thể xác thực. Quản trị viên cần kiểm tra hoặc thay service-account.json và khởi động lại máy chủ.",
        ) from None
    except HTTPException:
        raise
    except Exception:
        _log.exception("Cannot verify Firebase session")
        raise HTTPException(
            status_code=503,
            detail="Máy chủ chưa thể xác minh đăng nhập. Kiểm tra khóa và cấu hình Firebase Admin.",
        ) from None


async def authenticated_uid(authorization: str | None = Header(default=None)) -> str:
    scheme, _, token = (authorization or "").partition(" ")
    token = token.strip()
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Bạn cần đăng nhập để hỏi AI.")
    return await run_in_threadpool(_verify, token)

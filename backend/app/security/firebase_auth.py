"""Firebase ID-token verification for the chat endpoint."""

import logging
import threading
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials
from fastapi import Header, HTTPException
from starlette.concurrency import run_in_threadpool

_log = logging.getLogger(__name__)
_init_lock = threading.Lock()

SERVICE_ACCOUNT_PATH = (
    Path(__file__).resolve().parent / "service-account.json"
)


def _firebase_app():
    with _init_lock:
        try:
            return firebase_admin.get_app()
        except ValueError:
            pass

        if not SERVICE_ACCOUNT_PATH.is_file():
            raise RuntimeError(
                f"Không tìm thấy khóa Firebase Admin: "
                f"{SERVICE_ACCOUNT_PATH}"
            )

        credential = credentials.Certificate(
            str(SERVICE_ACCOUNT_PATH)
        )

        return firebase_admin.initialize_app(credential)


def _verify(token: str) -> str:
    try:
        decoded = auth.verify_id_token(
            token,
            app=_firebase_app(),
            check_revoked=True,
        )

        uid = decoded.get("uid") or decoded.get("sub")
        if not uid:
            raise HTTPException(
                status_code=401,
                detail="Phiên đăng nhập không hợp lệ.",
            )

        return str(uid)

    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="Phiên đăng nhập hết hạn. Hãy đăng nhập lại.",
        ) from None

    except auth.RevokedIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="Phiên đăng nhập đã bị thu hồi. Hãy đăng nhập lại.",
        ) from None

    except auth.UserDisabledError:
        raise HTTPException(
            status_code=401,
            detail="Tài khoản đã bị vô hiệu hóa.",
        ) from None

    except auth.UserNotFoundError:
        raise HTTPException(
            status_code=401,
            detail="Tài khoản không còn tồn tại.",
        ) from None

    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="Phiên đăng nhập không hợp lệ.",
        ) from None

    except HTTPException:
        raise

    except Exception:
        _log.exception("Cannot verify Firebase session")
        raise HTTPException(
            status_code=503,
            detail=(
                "Máy chủ chưa thể xác minh đăng nhập. "
                "Kiểm tra khóa và cấu hình Firebase Admin."
            ),
        ) from None


async def authenticated_uid(
    authorization: str | None = Header(default=None),
) -> str:
    scheme, _, token = (authorization or "").partition(" ")
    token = token.strip()

    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=401,
            detail="Bạn cần đăng nhập để hỏi AI.",
        )

    return await run_in_threadpool(_verify, token)
"""Firebase initialization for standalone or embedded admin routes."""
import logging
import os
from pathlib import Path
import threading

import firebase_admin
from firebase_admin import credentials
from dotenv import load_dotenv

# Resolve .env next to this module, independent of the launch directory.
load_dotenv(Path(__file__).resolve().parent / '.env', override=False)
_lock = threading.Lock()
_provider = None
log = logging.getLogger(__name__)


def use_existing_firebase(provider):
    """Embedded AI server supplies its existing initializer; no second app."""
    global _provider
    _provider = provider


def get_firebase_app():
    if _provider is not None:
        return _provider()
    with _lock:
        try:
            return firebase_admin.get_app()
        except ValueError:
            pass
        configured = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '').strip()
        path = Path(configured).expanduser() if configured else None
        if path and not path.is_absolute():
            path = Path(__file__).resolve().parent / path
        render_path = Path('/etc/secrets/service-account.json')
        if path is None and render_path.is_file():
            path = render_path
        if path and not path.is_file():
            raise RuntimeError('Không tìm thấy file GOOGLE_APPLICATION_CREDENTIALS đã cấu hình.')
        credential = credentials.Certificate(str(path)) if path else credentials.ApplicationDefault()
        project = os.getenv('FIREBASE_PROJECT_ID', '').strip()
        options = {'projectId': project} if project else None
        app = firebase_admin.initialize_app(credential, options=options)
        log.info('Admin Firebase initialized: project=%s', app.project_id)
        return app

"""Read only the verified user's ledger. No client-supplied debt evidence."""
from __future__ import annotations
from datetime import datetime
from zoneinfo import ZoneInfo

class DebtDataUnavailable(RuntimeError):
    pass

class DebtRepository:
    MAX_ITEMS = 10000
    MAX_CONTACTS = 5000
    def __init__(self, client=None):
        self._client = client

    def load(self, uid: str) -> dict:
        if not uid or '/' in uid:
            raise ValueError('UID không hợp lệ')
        try:
            if self._client is None:
                from firebase_admin import firestore
                from app.security.firebase_auth import _firebase_app
                client = firestore.client(app=_firebase_app())
            else:
                client = self._client
            root = client.collection('debt_books').document(uid)
            # Fetch one extra document; never silently return truncated totals.
            items = list(root.collection('items').limit(self.MAX_ITEMS+1).stream(timeout=15))
            contacts = list(root.collection('contacts').limit(self.MAX_CONTACTS+1).stream(timeout=15))
            if len(items)>self.MAX_ITEMS or len(contacts)>self.MAX_CONTACTS:
                raise DebtDataUnavailable('Sổ nợ vượt giới hạn truy vấn; cần phân trang dữ liệu trước khi tổng hợp.')
            balance = None
            balance_warning = None
            try:
                info = client.collection('info').document(uid).get(timeout=10).to_dict() or {}
                raw = info.get('money')
                if isinstance(raw, (int,float)) and not isinstance(raw,bool) and int(raw)==raw:
                    balance=int(raw)
            except Exception:
                balance_warning = 'Không đọc được số dư ví; các số liệu công nợ vẫn lấy từ sổ nợ.'
            return {'items':[dict(d.to_dict() or {}, id=d.id) for d in items],
                    'contacts':[dict(d.to_dict() or {}, id=d.id) for d in contacts],
                    'balance':balance, 'warnings':[balance_warning] if balance_warning else [],
                    'source':'firestore', 'uid':uid,
                    'loadedAt':datetime.now(ZoneInfo('Asia/Ho_Chi_Minh')).isoformat()}
        except DebtDataUnavailable:
            raise
        except Exception as exc:
            # Do not return an empty ledger when reads/credentials fail.
            raise DebtDataUnavailable('Chưa đọc được sổ nợ từ Firebase. Hãy thử lại.') from exc

"""Offline ASGI tests: real routes/services, Firebase verification mocked only."""
import unittest
from datetime import datetime
from unittest.mock import patch
import httpx
from main import app
from app.security.firebase_auth import authenticated_uid, _firebase_app
from app.config import settings

UID='test-user'
DATE=datetime.now().strftime('%Y-%m-%d')
TX=[{'id':'x','money':-15000,'dateTime':DATE+'T07:30:00','categoryId':'eating','note':'xôi'}]
BODY={'user_id':UID,'transactions':TX,'question':'Ăn uống tháng này bao nhiêu?','category_catalog':[{'id':'eating','display_name':'Ăn uống','parent':'expense_living'},{'id':'expense_living','display_name':'Chi tiêu sinh hoạt','isParent':True}]}
class Endpoints(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        app.dependency_overrides.clear()
        self.client=httpx.AsyncClient(transport=httpx.ASGITransport(app=app,raise_app_exceptions=False),base_url='http://test')
    async def asyncTearDown(self):
        app.dependency_overrides.clear()
        await self.client.aclose()
    def login(self):app.dependency_overrides[authenticated_uid]=lambda:UID
    async def test_missing_auth_all_personal_routes(self):
        paths=[r.path for r in app.routes if 'POST' in getattr(r,'methods',set())]
        for path in paths:
            with self.subTest(path=path):self.assertEqual((await self.client.post(path,json=BODY)).status_code,401)
    async def test_uid_mismatch(self):
        self.login()
        for path in [r.path for r in app.routes if 'POST' in getattr(r,'methods',set())]:
            with self.subTest(path=path):
                r=await self.client.post(path,params={'user_id':'intruder'},json={**BODY,'user_id':'intruder'})
                self.assertEqual(r.status_code,403,r.text)
    async def test_all_personal_endpoints(self):
        self.login()
        for path in [r.path for r in app.routes if 'POST' in getattr(r,'methods',set())]:
            with self.subTest(path=path):
                body={**BODY,'advisor_context':{'use_lstm':False},'transaction':TX[0],'history':TX,'include_models':False}
                if path.endswith('/chat/ask') or path.endswith('/insights/ask'):body.pop('history')
                r=await self.client.post(path,params={'user_id':UID},json=body)
                self.assertEqual(r.status_code,200,r.text)
    async def test_chat_amount_and_followup(self):
        self.login()
        r=await self.client.post('/api/v1/chat/ask',json=BODY)
        self.assertEqual(r.status_code,200,r.text)
        self.assertEqual(r.json()['evidence']['amount'],15000)
        r=await self.client.post('/api/v1/chat/ask',json={**BODY,'question':'Còn tháng trước?','history':[{'role':'user','content':BODY['question']}]})
        self.assertEqual(r.status_code,200,r.text)
        self.assertEqual(r.json()['evidence']['amount'],0)
    async def test_invalid_json(self):
        self.login()
        for path in ['/api/v1/chat/ask','/api/v1/insights/report','/api/v1/predict/trend/quick']:
            r=await self.client.post(path,params={'user_id':UID},content='{',headers={'Content-Type':'application/json'})
            self.assertEqual(r.status_code,422,r.text)
    async def test_bad_budgets_and_blank_question(self):
        self.login()
        for body in [{**BODY,'question':'  '},{**BODY,'advisor_context':{'budgets':'bad'}}]:
            self.assertEqual((await self.client.post('/api/v1/chat/ask',json=body)).status_code,422)
    async def test_request_id_failure(self):
        self.login()
        with patch('app.services.chat_ai_service.get_chat_ai_service',side_effect=RuntimeError('test failure')):
            r=await self.client.post('/api/v1/chat/ask',json=BODY)
        self.assertEqual(r.status_code,500)
        self.assertTrue(r.json()['detail']['requestId'])
        self.assertNotIn('test failure',r.text)
    async def test_public_metadata(self):
        for path in ['/health','/api/v1/info','/api/v1/chat/capabilities','/openapi.json']:
            r=await self.client.get(path)
            self.assertEqual(r.status_code,200,r.text)
            self.assertTrue(r.headers.get('X-Request-ID'))
        paths=[r.path for r in app.routes]
        self.assertEqual(paths.count('/api/v1/chat/ask'),1)
        self.assertFalse(any('/api/v1/api/v1/' in p for p in paths))
    async def test_invalid_and_revoked_token(self):
        from fastapi import HTTPException
        from app.security.firebase_auth import _verify
        from firebase_admin import auth
        for error in [auth.InvalidIdTokenError('invalid'), auth.RevokedIdTokenError('revoked')]:
            with self.subTest(error=type(error).__name__), patch('app.security.firebase_auth._firebase_app',return_value=object()), patch('app.security.firebase_auth.auth.verify_id_token',side_effect=error):
                with self.assertRaises(HTTPException) as cm:_verify('fake-token')
                self.assertEqual(cm.exception.status_code,401)
    async def test_bad_prediction_range(self):
        self.login()
        for fields in [{'month':13},{'prediction_days':31}]:
            r=await self.client.post('/api/v1/predict/trend',json={**BODY,**fields})
            self.assertEqual(r.status_code,422,r.text)
    async def test_configured_credentials(self):
        from tempfile import NamedTemporaryFile
        with NamedTemporaryFile() as f, patch.object(settings,'GOOGLE_APPLICATION_CREDENTIALS',f.name), patch.object(settings,'FIREBASE_PROJECT_ID','project-test'), patch('app.security.firebase_auth.firebase_admin.get_app',side_effect=ValueError), patch('app.security.firebase_auth.credentials.Certificate') as cert, patch('app.security.firebase_auth.firebase_admin.initialize_app') as init:
            _firebase_app();cert.assert_called_once_with(f.name)
            self.assertEqual(init.call_args.kwargs['options'],{'projectId':'project-test'})
if __name__=='__main__':unittest.main()

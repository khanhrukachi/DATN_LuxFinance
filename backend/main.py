import os
os.environ.setdefault("LOKY_MAX_CPU_COUNT", "4")
import logging
import uuid
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.config import settings
from app.routers import prediction_router, clustering_router, anomaly_router, insights_router, chat_router
from app.services.lstm_service import TF_AVAILABLE
from app.schemas.response import HealthResponse

log = logging.getLogger(__name__)
app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)
app.add_middleware(CORSMiddleware, allow_origins=settings.CORS_ORIGINS,
    allow_credentials="*" not in settings.CORS_ORIGINS, allow_methods=["*"],
    allow_headers=["*"], expose_headers=["X-Request-ID"])

@app.middleware("http")
async def identify_request(request: Request, call_next):
    request.state.request_id = uuid.uuid4().hex[:12]
    response = await call_next(request)
    response.headers["X-Request-ID"] = request.state.request_id
    return response

@app.exception_handler(Exception)
async def server_error(request: Request, exc: Exception):
    rid = getattr(request.state,"request_id",uuid.uuid4().hex[:12])
    log.error("Backend processing failure request_id=%s",rid,exc_info=exc)
    return JSONResponse(status_code=500,content={"detail":{"code":"server_error",
        "message":"Máy chủ chưa xử lý được yêu cầu.","requestId":rid}},headers={"X-Request-ID":rid})

for router in (prediction_router, clustering_router, anomaly_router, insights_router, chat_router):
    app.include_router(router,prefix=settings.API_V1_PREFIX)

@app.get("/")
def root():
    return {"name":settings.PROJECT_NAME,"version":settings.VERSION,"docs":"/docs",
        "health":"/health","chat":settings.API_V1_PREFIX+"/chat/ask"}

@app.get("/health",response_model=HealthResponse)
def health():
    return HealthResponse(status="healthy",version=settings.VERSION,services={
        "lstm":"available" if TF_AVAILABLE else "baseline_only",
        "kmeans":"available","isolation_forest":"available","chat":"available"})

@app.get(settings.API_V1_PREFIX+"/info")
def info():
    return {"services":[{"endpoint":route.path,"method":"POST"}
        for route in app.routes if "POST" in getattr(route,"methods",set())],
        "authentication":"Firebase Bearer token; UID must match request", "healthMeaning":"Services loaded; models are evaluated per request"}

if __name__=="__main__":
    import uvicorn
    uvicorn.run("main:app",host="0.0.0.0",port=8000,reload=settings.DEBUG)

import os
os.environ['LOKY_MAX_CPU_COUNT'] = '4'

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import traceback

from app.config import settings
from app.routers import prediction_router, clustering_router, anomaly_router
from app.schemas.response import HealthResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("=== Starting LuxFinance ML Backend ===")
    print(f"LSTM Sequence Length: {settings.LSTM_SEQUENCE_LENGTH}")
    print(f"K-Means Clusters: {settings.KMEANS_N_CLUSTERS}")
    print(f"Isolation Forest Contamination: {settings.ISOLATION_FOREST_CONTAMINATION}")
    yield
    print("=== Shutting down LuxFinance ML Backend ===")


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="LuxFinance ML Backend API",
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    error_detail = f"Error: {str(exc)}\n{traceback.format_exc()}"
    print(error_detail)
    return JSONResponse(
        status_code=500,
        content={"detail": error_detail}
    )


app.include_router(prediction_router, prefix=settings.API_V1_PREFIX)
app.include_router(clustering_router, prefix=settings.API_V1_PREFIX)
app.include_router(anomaly_router, prefix=settings.API_V1_PREFIX)


@app.get("/", tags=["Root"])
async def root():
    return {
        "name": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "description": "ML Backend cho ung dung quan ly tai chinh ca nhan",
        "endpoints": {
            "docs": "/docs",
            "redoc": "/redoc",
            "health": "/health",
            "prediction": f"{settings.API_V1_PREFIX}/predict/trend",
            "clustering": f"{settings.API_V1_PREFIX}/cluster/behavior",
            "anomaly": f"{settings.API_V1_PREFIX}/detect/anomaly"
        }
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    return HealthResponse(
        status="healthy",
        version=settings.VERSION,
        services={
            "lstm": "ready",
            "kmeans": "ready",
            "isolation_forest": "ready"
        }
    )


@app.get("/api/v1/info", tags=["Info"])
async def api_info():
    return {
        "services": [
            {
                "name": "LSTM Trend Prediction",
                "endpoint": "/api/v1/predict/trend",
                "method": "POST"
            },
            {
                "name": "K-Means Clustering",
                "endpoint": "/api/v1/cluster/behavior",
                "method": "POST"
            },
            {
                "name": "Isolation Forest Anomaly Detection",
                "endpoint": "/api/v1/detect/anomaly",
                "method": "POST"
            }
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG
    )

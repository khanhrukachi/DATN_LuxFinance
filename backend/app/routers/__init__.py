from .prediction import router as prediction_router
from .clustering import router as clustering_router
from .anomaly import router as anomaly_router

__all__ = [
    "prediction_router",
    "clustering_router",
    "anomaly_router"
]

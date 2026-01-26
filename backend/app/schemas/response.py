from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any


class PredictedValue(BaseModel):
    date: str
    predicted_income: float = Field(..., alias="predictedIncome")
    predicted_expense: float = Field(..., alias="predictedExpense")
    confidence: float = Field(..., ge=0, le=1)
    description: Optional[str] = None

    model_config = {
        "populate_by_name": True,
        "by_alias": True
    }


class TrendPredictionResponse(BaseModel):
    success: bool = True
    user_id: str = Field(..., alias="userId")
    predictions: List[PredictedValue]
    summary: Dict[str, Any]
    message: str = "Prediction completed successfully"

    model_config = {
        "populate_by_name": True,
        "by_alias": True
    }


class SpendingCluster(BaseModel):
    cluster_id: int = Field(..., alias="clusterId")
    cluster_name: str = Field(..., alias="clusterName")
    description: str
    characteristics: Dict[str, Any]
    transaction_ids: List[str] = Field(..., alias="transactionIds")
    percentage: float

    model_config = {
        "populate_by_name": True,
        "by_alias": True,
        "json_schema_serialization_defaults_required": True
    }


class ClusteringResponse(BaseModel):
    success: bool = True
    user_id: str = Field(..., alias="userId")
    clusters: List[SpendingCluster]
    user_profile: Dict[str, Any] = Field(..., alias="userProfile")
    recommendations: List[str]
    message: str = "Clustering completed successfully"

    model_config = {
        "populate_by_name": True,
        "by_alias": True
    }


class AnomalyTransaction(BaseModel):
    transaction_id: str = Field(..., alias="transactionId")
    money: int
    type_name: str = Field(..., alias="typeName")
    date_time: str = Field(..., alias="dateTime")
    anomaly_score: float = Field(..., alias="anomalyScore")
    anomaly_reason: str = Field(..., alias="anomalyReason")
    severity: str

    model_config = {
        "populate_by_name": True,
        "by_alias": True
    }


class AnomalyDetectionResponse(BaseModel):
    success: bool = True
    user_id: str = Field(..., alias="userId")
    total_transactions: int = Field(..., alias="totalTransactions")
    anomalies_detected: int = Field(..., alias="anomaliesDetected")
    anomalies: List[AnomalyTransaction]
    statistics: Dict[str, Any]
    alerts: List[str]
    message: str = "Anomaly detection completed successfully"

    model_config = {
        "populate_by_name": True,
        "by_alias": True
    }


class HealthResponse(BaseModel):
    status: str = "healthy"
    version: str
    services: Dict[str, str]

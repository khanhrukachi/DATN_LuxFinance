from typing import Any
from pydantic import BaseModel, ConfigDict, Field

class ResponseModel(BaseModel):
    model_config = ConfigDict(extra="allow", populate_by_name=True)
class PredictedValue(ResponseModel):
    date: str
    predicted_income: float
    predicted_expense: float
    confidence: float
    description: str = ""
class TrendPredictionResponse(ResponseModel):
    success: bool
    user_id: str
    predictions: list[PredictedValue] = Field(default_factory=list)
    summary: dict[str,Any] = Field(default_factory=dict)
    message: str = ""
class SpendingCluster(ResponseModel):
    cluster_id: int
    cluster_name: str
    description: str
    characteristics: dict[str,Any]
    transaction_ids: list[str]
    percentage: float
class ClusteringResponse(ResponseModel):
    success: bool
    user_id: str
    clusters: list[SpendingCluster] = Field(default_factory=list)
    user_profile: dict[str,Any] = Field(default_factory=dict)
    recommendations: list[str] = Field(default_factory=list)
    message: str = ""
class AnomalyTransaction(ResponseModel):
    transaction_id: str
    money: float
    type_name: str
    date_time: str
    anomaly_score: float
    anomaly_reason: str
    severity: str
class AnomalyDetectionResponse(ResponseModel):
    success: bool
    user_id: str
    total_transactions: int
    anomalies_detected: int
    anomalies: list[AnomalyTransaction] = Field(default_factory=list)
    statistics: dict[str,Any] = Field(default_factory=dict)
    alerts: list[str] = Field(default_factory=list)
    message: str = ""
class HealthResponse(ResponseModel):
    status: str
    version: str
    services: dict[str,str]

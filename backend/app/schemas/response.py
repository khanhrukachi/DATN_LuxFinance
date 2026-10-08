from typing import Any
from pydantic import BaseModel, ConfigDict, Field
class Result(BaseModel):
    model_config = ConfigDict(extra='allow', populate_by_name=True)
class PredictedValue(Result):
    date: str
    predicted_income: float = 0
    predicted_expense: float = 0
class TrendPredictionResponse(Result):
    success: bool
    user_id: str
    predictions: list[PredictedValue] = Field(default_factory=list)
    summary: dict[str, Any] = Field(default_factory=dict)
    message: str = ''
class SpendingCluster(Result):
    cluster_id: int
    cluster_name: str
    characteristics: dict[str, Any] = Field(default_factory=dict)
class ClusteringResponse(Result):
    success: bool
    user_id: str
    clusters: list[SpendingCluster] = Field(default_factory=list)
    user_profile: dict[str, Any] = Field(default_factory=dict)
    recommendations: list[Any] = Field(default_factory=list)
    message: str = ''
class AnomalyTransaction(Result):
    transaction_id: str
    money: int
    type_name: str
    date_time: str
    anomaly_score: float
    anomaly_reason: str
    severity: str
class AnomalyDetectionResponse(Result):
    success: bool
    user_id: str
    anomalies: list[AnomalyTransaction] = Field(default_factory=list)
    statistics: dict[str, Any] = Field(default_factory=dict)
    alerts: list[str] = Field(default_factory=list)
class HealthResponse(Result):
    status: str
    version: str
    services: dict[str,str]

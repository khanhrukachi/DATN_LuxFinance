from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, Field, AliasChoices

class SpendingItem(BaseModel):
    model_config = ConfigDict(extra="allow", populate_by_name=True)
    id: str = ""
    money: float
    date_time: datetime = Field(validation_alias=AliasChoices("date_time","dateTime","date"))
    type: int = -1
    type_name: str = Field(default="other", validation_alias=AliasChoices("type_name","typeName"))
    note: str = ""

class FinanceRequest(BaseModel):
    model_config = ConfigDict(extra="allow", populate_by_name=True)
    user_id: str = Field(min_length=1,max_length=128,validation_alias=AliasChoices("user_id","userId"))
    transactions: list[dict[str,Any]] = Field(default_factory=list,max_length=10000)
    year: int | None = Field(default=None,ge=1900,le=2200)
    month: int | None = Field(default=None,ge=1,le=12)

class PredictionRequest(FinanceRequest):
    prediction_days: int | None = Field(default=None,ge=1,le=30,validation_alias=AliasChoices("prediction_days","predictionDays"))
class ClusteringRequest(FinanceRequest):
    n_clusters: int | None = Field(default=None,ge=1,le=20,validation_alias=AliasChoices("n_clusters","nClusters"))
class AnomalyRequest(FinanceRequest):
    sensitivity: float = Field(default=0.1,gt=0,le=0.5)

from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, Field, AliasChoices
class SpendingItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra='allow')
    id: str = ''
    money: int
    type: int = -1
    type_name: str = Field(default='', validation_alias=AliasChoices('type_name','typeName'))
    date_time: datetime = Field(validation_alias=AliasChoices('date_time','dateTime','date'))
    note: str = ''
class BaseRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra='allow')
    user_id: str = Field(validation_alias=AliasChoices('user_id','userId'))
    transactions: list[dict[str, Any]] = Field(default_factory=list, max_length=10000)
class PredictionRequest(BaseRequest):
    prediction_days: int = Field(default=7, ge=1, le=30, validation_alias=AliasChoices('prediction_days','predictionDays'))
class ClusteringRequest(BaseRequest):
    n_clusters: int | None = Field(default=None, ge=1, le=6)
class AnomalyRequest(BaseRequest):
    sensitivity: float = Field(default=0.1, gt=0, lt=0.5)

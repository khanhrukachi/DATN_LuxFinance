from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class SpendingItem(BaseModel):
    id: str
    money: int
    type: int
    type_name: str = Field(..., alias="typeName")
    note: Optional[str] = None
    date_time: datetime = Field(..., alias="dateTime")
    image: Optional[str] = None
    location: Optional[str] = None

    class Config:
        populate_by_name = True


class SpendingData(BaseModel):
    user_id: str = Field(..., alias="userId")
    transactions: List[SpendingItem]

    class Config:
        populate_by_name = True


class PredictionRequest(BaseModel):
    user_id: str = Field(..., alias="userId")
    transactions: List[SpendingItem]
    prediction_days: int = Field(default=7, alias="predictionDays", ge=1, le=30)

    class Config:
        populate_by_name = True


class ClusteringRequest(BaseModel):
    user_id: str = Field(..., alias="userId")
    transactions: List[SpendingItem]
    n_clusters: Optional[int] = Field(default=None, alias="nClusters", ge=2, le=10)

    class Config:
        populate_by_name = True


class AnomalyRequest(BaseModel):
    user_id: str = Field(..., alias="userId")
    transactions: List[SpendingItem]
    sensitivity: float = Field(default=0.1, ge=0.01, le=0.5)

    class Config:
        populate_by_name = True

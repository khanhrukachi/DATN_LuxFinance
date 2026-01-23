from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "LuxFinance ML Backend"
    VERSION: str = "1.0.0"
    DEBUG: bool = True
    CORS_ORIGINS: List[str] = ["*"]
    LSTM_SEQUENCE_LENGTH: int = 5
    LSTM_PREDICTION_DAYS: int = 7
    KMEANS_N_CLUSTERS: int = 4
    ISOLATION_FOREST_CONTAMINATION: float = 0.1

    class Config:
        env_file = ".env"


settings = Settings()

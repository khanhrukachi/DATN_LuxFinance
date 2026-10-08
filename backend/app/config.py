from pydantic_settings import BaseSettings, SettingsConfigDict
class Settings(BaseSettings):
    PROJECT_NAME: str = 'LuxFinance Backend'
    VERSION: str = '1.1.0'
    API_V1_PREFIX: str = '/api/v1'
    DEBUG: bool = False
    CORS_ORIGINS: list[str] = []
    LSTM_SEQUENCE_LENGTH: int = 28
    LSTM_MIN_TRAIN_DAYS: int = 90
    LSTM_MAX_HISTORY_DAYS: int = 365
    KMEANS_N_CLUSTERS: int = 4
    ISOLATION_FOREST_CONTAMINATION: float = 0.1
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')
settings = Settings()

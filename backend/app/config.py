from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str
    aws_region: str = "us-east-1"
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    s3_bucket: str = "personal-memory-os-captures"
    bedrock_model_haiku: str = "anthropic.claude-3-haiku-20240307-v1:0"
    bedrock_model_sonnet: str = "anthropic.claude-3-sonnet-20240229-v1:0"
    bedrock_embedding_model: str = "amazon.titan-embed-text-v2:0"
    cognito_user_pool_id: str = ""
    cognito_region: str = "us-east-1"
    cognito_app_client_id: str = ""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str = ""      # local dev; on AWS use db_secret_arn
    db_secret_arn: str = ""
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
    allow_insecure_dev_auth: bool = False  # local dev only; never set in production
    scheduler_target_arn: str = ""   # notification-dispatcher Lambda ARN
    scheduler_role_arn: str = ""     # role EventBridge Scheduler assumes
    scheduler_group: str = "personal-memory-os"
    notification_topic_arn: str = ""
    capture_queue_url: str = ""
    knowledge_base_id: str = ""              # empty = keyword search only
    knowledge_base_data_source_id: str = ""
    sns_platform_app_arn: str = ""           # FCM/APNs platform application

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

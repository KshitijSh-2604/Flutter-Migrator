from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # API Keys (Will be loaded from .env)
    openai_api_key: str = ""
    gemini_api_key: str = ""

    # Database — defaults to SQLite in the backend folder
    database_url: str = "sqlite:///./flutter_migrations.db"

    # Flutter target version — what we migrate TO
    flutter_version_target: str = "3.24.0"

    # File upload limits
    max_upload_size_mb: int = 50

    # Debug mode
    debug: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


settings = Settings()

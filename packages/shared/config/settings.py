from functools import lru_cache

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: str = Field(default="development", alias="ENVIRONMENT")
    app_name: str = Field(default="Vet App", alias="APP_NAME")
    api_host: str = Field(default="127.0.0.1", alias="API_HOST")
    api_port: int = Field(default=8000, alias="API_PORT")
    persistence_backend: str = Field(default="in_memory", alias="PERSISTENCE_BACKEND")
    auth_backend: str = Field(default="bootstrap", alias="AUTH_BACKEND")
    evidence_backend: str = Field(default="in_memory", alias="EVIDENCE_BACKEND")
    database_url: str = Field(default="", alias="DATABASE_URL")
    supabase_url: str = Field(default="", alias="SUPABASE_URL")
    supabase_anon_key: str = Field(default="", alias="SUPABASE_ANON_KEY")
    supabase_service_role_key: str = Field(default="", alias="SUPABASE_SERVICE_ROLE_KEY")
    supabase_db_host: str = Field(default="", alias="SUPABASE_DB_HOST")
    supabase_db_port: int = Field(default=5432, alias="SUPABASE_DB_PORT")
    supabase_db_name: str = Field(default="postgres", alias="SUPABASE_DB_NAME")
    supabase_db_user: str = Field(default="", alias="SUPABASE_DB_USER")
    supabase_db_password: str = Field(default="", alias="SUPABASE_DB_PASSWORD")
    bootstrap_user_id: str = Field(default="demo-user", alias="BOOTSTRAP_USER_ID")
    bootstrap_user_email: str = Field(default="demo@vetapp.local", alias="BOOTSTRAP_USER_EMAIL")
    llm_provider: str = Field(default="echo", alias="LLM_PROVIDER")
    llm_model: str = Field(default="demo-model", alias="LLM_MODEL")
    llm_api_key: str = Field(default="", alias="LLM_API_KEY")
    llm_base_url: str = Field(default="https://api.groq.com/openai/v1", alias="LLM_BASE_URL")
    llm_timeout_seconds: int = Field(default=30, alias="LLM_TIMEOUT_SECONDS")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    enable_telemetry: bool = Field(default=False, alias="ENABLE_TELEMETRY")
    enable_interview_loop: bool = Field(default=True, alias="ENABLE_INTERVIEW_LOOP")
    situation_coverage_target: float = Field(default=0.85, alias="SITUATION_COVERAGE_TARGET")
    interview_max_questions: int = Field(default=3, alias="INTERVIEW_MAX_QUESTIONS")
    pii_anonymizer_backend: str = Field(default="noop", alias="PII_ANONYMIZER_BACKEND")
    max_active_conversations_per_pet: int = Field(
        default=4, alias="MAX_ACTIVE_CONVERSATIONS_PER_PET"
    )
    # Multilingual architecture (spec v3 §31) — Beta ships Italian-only, but
    # the core engine reads these instead of hardcoding "it"/"Italian", so
    # adding a locale later is a config change, not a core-engine rewrite.
    locale: str = Field(default="it-IT", alias="LOCALE")
    response_language: str = Field(default="it", alias="RESPONSE_LANGUAGE")
    retrieval_languages: list[str] = Field(default=["en", "it"], alias="RETRIEVAL_LANGUAGES")

    @model_validator(mode="after")
    def validate_backend_configuration(self) -> "Settings":
        if self.persistence_backend == "supabase":
            self._require_fields(
                "PERSISTENCE_BACKEND=supabase",
                {
                    "DATABASE_URL": self.database_url,
                    "SUPABASE_URL": self.supabase_url,
                    "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                },
            )

        if self.auth_backend == "supabase":
            self._require_fields(
                "AUTH_BACKEND=supabase",
                {
                    "SUPABASE_URL": self.supabase_url,
                    "SUPABASE_ANON_KEY": self.supabase_anon_key,
                    "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                },
            )

        if self.evidence_backend == "supabase":
            self._require_fields(
                "EVIDENCE_BACKEND=supabase",
                {
                    "SUPABASE_URL": self.supabase_url,
                    "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                },
            )

        if self.llm_provider == "groq":
            self._require_fields(
                "LLM_PROVIDER=groq",
                {
                    "LLM_MODEL": self.llm_model,
                    "LLM_API_KEY": self.llm_api_key,
                    "LLM_BASE_URL": self.llm_base_url,
                },
            )

        return self

    @staticmethod
    def _require_fields(context: str, values: dict[str, str]) -> None:
        missing = [name for name, value in values.items() if not value.strip()]
        if missing:
            formatted = ", ".join(missing)
            raise ValueError(f"Missing required settings for {context}: {formatted}")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()


def reset_settings() -> None:
    get_settings.cache_clear()

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
    # Accounts with unlimited access, bypassing the trial/plan gate entirely
    # (packages/core/application/services/get_or_create_subscription.py).
    # No default on purpose: these are real personal addresses, set via
    # DEVELOPER_EMAILS in .env (comma-separated), never hardcoded in source.
    developer_emails: list[str] = Field(default=[], alias="DEVELOPER_EMAILS")
    llm_provider: str = Field(default="echo", alias="LLM_PROVIDER")
    llm_model: str = Field(default="demo-model", alias="LLM_MODEL")
    llm_api_key: str = Field(default="", alias="LLM_API_KEY")
    llm_base_url: str = Field(default="https://api.groq.com/openai/v1", alias="LLM_BASE_URL")
    llm_timeout_seconds: int = Field(default=30, alias="LLM_TIMEOUT_SECONDS")
    # Voice dictation (speech-to-text): reuses LLM_API_KEY/LLM_BASE_URL
    # rather than a separate key — Groq's Whisper transcription endpoint
    # is the same account/base URL family as chat completions, so this
    # needs no new vendor relationship.
    stt_provider: str = Field(default="echo", alias="STT_PROVIDER")
    stt_model: str = Field(default="whisper-large-v3-turbo", alias="STT_MODEL")
    # Photo attachments: visual analysis reuses the same Groq account
    # (LLM_API_KEY/LLM_BASE_URL) as chat and voice dictation.
    vision_provider: str = Field(default="echo", alias="VISION_PROVIDER")
    vision_model: str = Field(default="qwen/qwen3.8-27b", alias="VISION_MODEL")

    # Nearby pet-services radar. Overpass is the low-cost default and the
    # existing Supabase coverage tables remain the cache boundary.
    radar_places_provider: str = Field(
        default="openstreetmap_overpass",
        alias="RADAR_PLACES_PROVIDER",
    )
    radar_search_radius_km: float = Field(
        default=10.0,
        gt=0,
        alias="RADAR_SEARCH_RADIUS_KM",
    )
    radar_ingestion_radius_km: float = Field(
        default=10.0,
        gt=0,
        alias="RADAR_INGESTION_RADIUS_KM",
    )
    radar_freshness_ttl_hours: int = Field(
        default=168,
        gt=0,
        alias="RADAR_FRESHNESS_TTL_HOURS",
    )
    overpass_base_url: str = Field(
        default="https://overpass-api.de/api/interpreter",
        alias="OVERPASS_BASE_URL",
    )
    overpass_timeout_seconds: int = Field(
        default=25,
        ge=5,
        le=180,
        alias="OVERPASS_TIMEOUT_SECONDS",
    )
    overpass_max_radius_km: float = Field(
        default=10.0,
        gt=0,
        le=25,
        alias="OVERPASS_MAX_RADIUS_KM",
    )
    overpass_user_agent: str = Field(
        default="VET-APP/1.0",
        alias="OVERPASS_USER_AGENT",
    )
    google_places_api_key: str = Field(default="", alias="GOOGLE_PLACES_API_KEY")
    google_places_base_url: str = Field(
        default="https://places.googleapis.com/v1",
        alias="GOOGLE_PLACES_BASE_URL",
    )
    google_places_field_mask: str = Field(
        default=(
            "places.id,places.displayName,places.formattedAddress,places.location,"
            "places.primaryType,places.types,places.googleMapsUri,places.businessStatus"
        ),
        alias="GOOGLE_PLACES_FIELD_MASK",
    )
    google_places_included_types: str = Field(
        default="veterinary_care,pet_store,pet_care,pet_boarding_service,dog_park",
        alias="GOOGLE_PLACES_INCLUDED_TYPES",
    )

    # Attachment bytes: local disk outside of PERSISTENCE_BACKEND=supabase
    # (fine for local dev), a Supabase Storage bucket when it is (required
    # on serverless deploys like Vercel, whose filesystem is read-only).
    media_storage_dir: str = Field(default="./data/chat_attachments", alias="MEDIA_STORAGE_DIR")
    media_storage_bucket: str = Field(
        default="chat-attachments", alias="MEDIA_STORAGE_BUCKET"
    )
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    enable_telemetry: bool = Field(default=False, alias="ENABLE_TELEMETRY")
    # 2026-09-21: default flipped to False — see chat_orchestrator.py's
    # ChatOrchestrator._strict_evidence_intents for why the mandatory
    # interview loop is no longer the default for ordinary questions.
    enable_interview_loop: bool = Field(default=False, alias="ENABLE_INTERVIEW_LOOP")
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

        if self.stt_provider == "groq":
            self._require_fields(
                "STT_PROVIDER=groq",
                {
                    "STT_MODEL": self.stt_model,
                    "LLM_API_KEY": self.llm_api_key,
                    "LLM_BASE_URL": self.llm_base_url,
                },
            )

        if self.vision_provider == "groq":
            self._require_fields(
                "VISION_PROVIDER=groq",
                {
                    "VISION_MODEL": self.vision_model,
                    "LLM_API_KEY": self.llm_api_key,
                    "LLM_BASE_URL": self.llm_base_url,
                },
            )

        normalized_radar_provider = self.radar_places_provider.strip().lower()
        if normalized_radar_provider == "google_places":
            self._require_fields(
                "RADAR_PLACES_PROVIDER=google_places",
                {
                    "GOOGLE_PLACES_API_KEY": self.google_places_api_key,
                    "GOOGLE_PLACES_BASE_URL": self.google_places_base_url,
                    "GOOGLE_PLACES_FIELD_MASK": self.google_places_field_mask,
                },
            )
            if self.environment != "test" and (
                self.radar_search_radius_km > 1
                or self.radar_ingestion_radius_km > 1
            ):
                raise ValueError(
                    "Google Places runtime radius must not exceed 1 km; "
                    "use openstreetmap_overpass for wider cached coverage"
                )
        elif normalized_radar_provider == "openstreetmap_overpass":
            self._require_fields(
                "RADAR_PLACES_PROVIDER=openstreetmap_overpass",
                {
                    "OVERPASS_BASE_URL": self.overpass_base_url,
                    "OVERPASS_USER_AGENT": self.overpass_user_agent,
                },
            )
            if (
                self.radar_search_radius_km > self.overpass_max_radius_km
                or self.radar_ingestion_radius_km > self.overpass_max_radius_km
            ):
                raise ValueError(
                    "RADAR_SEARCH_RADIUS_KM and RADAR_INGESTION_RADIUS_KM must not "
                    "exceed OVERPASS_MAX_RADIUS_KM"
                )
        elif not (
            self.environment == "test" and normalized_radar_provider == "catalog"
        ):
            raise ValueError(
                "RADAR_PLACES_PROVIDER must be one of: "
                "openstreetmap_overpass, google_places"
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

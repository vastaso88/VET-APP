from functools import lru_cache

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    environment: str = Field(default="development", alias="ENVIRONMENT")
    app_name: str = Field(default="Vet App", alias="APP_NAME")
    api_host: str = Field(default="127.0.0.1", alias="API_HOST")
    api_port: int = Field(default=8000, alias="API_PORT")
    persistence_backend: str = Field(default="supabase", alias="PERSISTENCE_BACKEND")
    auth_backend: str = Field(default="supabase", alias="AUTH_BACKEND")
    evidence_backend: str = Field(default="supabase", alias="EVIDENCE_BACKEND")
    database_url: str = Field(default="", alias="DATABASE_URL")
    supabase_url: str = Field(default="", alias="SUPABASE_URL")
    supabase_anon_key: str = Field(default="", alias="SUPABASE_ANON_KEY")
    supabase_service_role_key: str = Field(default="", alias="SUPABASE_SERVICE_ROLE_KEY")
    supabase_db_host: str = Field(default="", alias="SUPABASE_DB_HOST")
    supabase_db_port: int = Field(default=5432, alias="SUPABASE_DB_PORT")
    supabase_db_name: str = Field(default="postgres", alias="SUPABASE_DB_NAME")
    supabase_db_user: str = Field(default="", alias="SUPABASE_DB_USER")
    supabase_db_password: str = Field(default="", alias="SUPABASE_DB_PASSWORD")
    clinical_documents_bucket: str = Field(
        default="clinical-documents",
        alias="CLINICAL_DOCUMENTS_BUCKET",
    )
    local_storage_dir: str = Field(default=".data/storage", alias="LOCAL_STORAGE_DIR")
    test_user_id: str = Field(default="test-user", alias="TEST_USER_ID")
    test_user_email: str = Field(default="test@vetapp.local", alias="TEST_USER_EMAIL")
    test_auth_token: str = Field(default="test-token", alias="TEST_AUTH_TOKEN")
    admin_places_trigger_token: str = Field(default="", alias="ADMIN_PLACES_TRIGGER_TOKEN")
    admin_knowledge_trigger_token: str = Field(default="", alias="ADMIN_KNOWLEDGE_TRIGGER_TOKEN")
    llm_provider: str = Field(default="groq", alias="LLM_PROVIDER")
    llm_model: str = Field(default="", alias="LLM_MODEL")
    llm_api_key: str = Field(default="", alias="LLM_API_KEY")
    llm_base_url: str = Field(default="https://api.groq.com/openai/v1", alias="LLM_BASE_URL")
    llm_timeout_seconds: int = Field(default=30, alias="LLM_TIMEOUT_SECONDS")
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
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    enable_telemetry: bool = Field(default=False, alias="ENABLE_TELEMETRY")
    billing_backend: str = Field(default="stripe", alias="BILLING_BACKEND")
    billing_timezone: str = Field(default="Europe/Rome", alias="BILLING_TIMEZONE")
    billing_trial_days: int = Field(default=7, alias="BILLING_TRIAL_DAYS")
    founder_max_slots: int = Field(default=100, alias="FOUNDER_MAX_SLOTS")
    stripe_secret_key: str = Field(default="", alias="STRIPE_SECRET_KEY")
    stripe_webhook_secret: str = Field(default="", alias="STRIPE_WEBHOOK_SECRET")
    stripe_api_version: str = Field(default="2025-03-31.basil", alias="STRIPE_API_VERSION")
    stripe_price_standard_recurring: str = Field(
        default="",
        alias="STRIPE_PRICE_STANDARD_RECURRING",
    )
    stripe_price_annual_recurring: str = Field(
        default="",
        alias="STRIPE_PRICE_ANNUAL_RECURRING",
    )
    stripe_price_founder_lifetime: str = Field(
        default="",
        alias="STRIPE_PRICE_FOUNDER_LIFETIME",
    )
    stripe_billing_portal_configuration_id: str = Field(
        default="",
        alias="STRIPE_BILLING_PORTAL_CONFIGURATION_ID",
    )
    billing_success_url: str = Field(default="", alias="BILLING_SUCCESS_URL")
    billing_cancel_url: str = Field(default="", alias="BILLING_CANCEL_URL")
    billing_return_url: str = Field(default="", alias="BILLING_RETURN_URL")

    @model_validator(mode="after")
    def validate_backend_configuration(self) -> "Settings":
        normalized_radar_provider = self.radar_places_provider.strip().lower()
        if self.environment != "test":
            self._require_exact_values(
                {
                    "AUTH_BACKEND": (self.auth_backend, "supabase"),
                    "PERSISTENCE_BACKEND": (self.persistence_backend, "supabase"),
                    "EVIDENCE_BACKEND": (self.evidence_backend, "supabase"),
                    "LLM_PROVIDER": (self.llm_provider, "groq"),
                }
            )
            if normalized_radar_provider not in {
                "google_places",
                "openstreetmap_overpass",
            }:
                raise ValueError(
                    "RADAR_PLACES_PROVIDER must be one of: "
                    "google_places, openstreetmap_overpass"
                )

        if self.persistence_backend == "supabase":
            self._require_fields(
                "PERSISTENCE_BACKEND=supabase",
                {
                    "DATABASE_URL": self.database_url,
                    "SUPABASE_URL": self.supabase_url,
                    "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                },
            )
        elif self.environment != "test":
            raise ValueError("PERSISTENCE_BACKEND must be supabase outside test")

        if self.auth_backend == "supabase":
            self._require_fields(
                "AUTH_BACKEND=supabase",
                {
                    "SUPABASE_URL": self.supabase_url,
                    "SUPABASE_ANON_KEY": self.supabase_anon_key,
                    "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                },
            )
        elif self.environment != "test":
            raise ValueError("AUTH_BACKEND must be supabase outside test")

        if self.evidence_backend == "supabase":
            self._require_fields(
                "EVIDENCE_BACKEND=supabase",
                {
                    "SUPABASE_URL": self.supabase_url,
                    "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                },
            )
        elif self.environment != "test":
            raise ValueError("EVIDENCE_BACKEND must be supabase outside test")

        if self.llm_provider == "groq":
            self._require_fields(
                "LLM_PROVIDER=groq",
                {
                    "LLM_MODEL": self.llm_model,
                    "LLM_API_KEY": self.llm_api_key,
                    "LLM_BASE_URL": self.llm_base_url,
                },
            )
        elif self.environment != "test":
            raise ValueError("LLM_PROVIDER must be groq outside test")

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
        elif self.environment != "test":
            raise ValueError("Unsupported RADAR_PLACES_PROVIDER")

        if self.billing_trial_days < 1:
            raise ValueError("BILLING_TRIAL_DAYS must be >= 1")

        if self.founder_max_slots < 1:
            raise ValueError("FOUNDER_MAX_SLOTS must be >= 1")

        normalized_billing_backend = self.billing_backend.strip().lower()
        if normalized_billing_backend not in {"stripe", "mock"}:
            raise ValueError("BILLING_BACKEND must be one of: stripe, mock")

        if self.environment != "test" and normalized_billing_backend == "stripe":
            self._require_fields(
                "BILLING_BACKEND=stripe",
                {
                    "STRIPE_SECRET_KEY": self.stripe_secret_key,
                    "STRIPE_WEBHOOK_SECRET": self.stripe_webhook_secret,
                    "STRIPE_PRICE_STANDARD_RECURRING": self.stripe_price_standard_recurring,
                    "STRIPE_PRICE_ANNUAL_RECURRING": self.stripe_price_annual_recurring,
                    "STRIPE_PRICE_FOUNDER_LIFETIME": self.stripe_price_founder_lifetime,
                    "BILLING_SUCCESS_URL": self.billing_success_url,
                    "BILLING_CANCEL_URL": self.billing_cancel_url,
                    "BILLING_RETURN_URL": self.billing_return_url,
                },
            )

        return self

    @staticmethod
    def _require_exact_values(values: dict[str, tuple[str, str]]) -> None:
        invalid = [
            f"{name}={actual!r} (expected {expected!r})"
            for name, (actual, expected) in values.items()
            if actual.strip().lower() != expected
        ]
        if invalid:
            raise ValueError("Invalid runtime backend configuration: " + ", ".join(invalid))

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

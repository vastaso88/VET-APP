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
    # Backoffice allowlist. When empty, admin endpoints fall back to
    # DEVELOPER_EMAILS so existing founder/developer accounts can be reused
    # without hardcoding personal addresses in source control.
    admin_emails: list[str] = Field(default=[], alias="ADMIN_EMAILS")
    # Secret key for the pseudonym stored in place of the reporter's id on
    # chat response reports. Changing it orphans existing pseudonyms (no
    # more dedup/erasure match for old rows), so set it once and keep it.
    reporter_pseudonym_salt: str = Field(default="", alias="REPORTER_PSEUDONYM_SALT")
    llm_provider: str = Field(default="echo", alias="LLM_PROVIDER")
    llm_model: str = Field(default="demo-model", alias="LLM_MODEL")
    # Reserve models, comma-separated, tried in order when LLM_MODEL is rate
    # limited (Groq counts its daily limit per model: 2026-10-05, the chat
    # was down for hours on a single exhausted model). Empty = no reserve.
    # Default: the models active on the Groq account on 2026-10-05.
    llm_fallback_models: str = Field(
        default="openai/gpt-oss-20b,qwen/qwen3.8-27b", alias="LLM_FALLBACK_MODELS"
    )
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
    # Same idea for reading photos and scans. Empty by default: on
    # 2026-10-05 the Groq account had no second model that accepts images.
    vision_fallback_models: str = Field(default="", alias="VISION_FALLBACK_MODELS")
    # Nearby pet-services radar ("cosa c'e' attorno"). OpenStreetMap via
    # Overpass is the only provider; results are cached per geographic cell
    # in Supabase (radar_coverage_cells / radar_places_cache), so Overpass
    # is called at most once per cell per RADAR_FRESHNESS_TTL_HOURS. The
    # radius ladder (10/25/50 km) and its cell sizes live in
    # packages/core/domain/coverage/models.py; RADAR_SEARCH_RADIUS_KM only
    # caps how far up that ladder the app may go.
    radar_places_provider: str = Field(
        default="openstreetmap_overpass", alias="RADAR_PLACES_PROVIDER"
    )
    radar_search_radius_km: float = Field(default=50.0, gt=0, alias="RADAR_SEARCH_RADIUS_KM")
    radar_freshness_ttl_hours: int = Field(default=168, gt=0, alias="RADAR_FRESHNESS_TTL_HOURS")
    overpass_base_url: str = Field(
        default="https://overpass-api.de/api/interpreter", alias="OVERPASS_BASE_URL"
    )
    # Tried in order when the main interpreter is overloaded (429/504).
    overpass_fallback_urls: list[str] = Field(
        default=[
            "https://overpass.private.coffee/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter",
        ],
        alias="OVERPASS_FALLBACK_URLS",
    )
    overpass_timeout_seconds: int = Field(
        default=40, ge=5, le=180, alias="OVERPASS_TIMEOUT_SECONDS"
    )
    # Must cover the widest tier's import radius (50 km search + cell offset).
    overpass_max_radius_km: float = Field(
        default=70.0, gt=0, le=100, alias="OVERPASS_MAX_RADIUS_KM"
    )
    # Overpass usage policy asks for an identifying User-Agent with a way
    # to reach the operator: set OVERPASS_USER_AGENT in production to
    # include a real technical contact.
    overpass_user_agent: str = Field(
        default="VET-APP/1.0 (+https://vet-app-psi-nine.vercel.app)", alias="OVERPASS_USER_AGENT"
    )
    # "Segnala!" (community reports on the radar). The pseudonym key
    # turns account ids into the stand-ins stored with reports and votes;
    # it must live only here (environment), never in the database. When
    # empty, the key is derived from SUPABASE_SERVICE_ROLE_KEY (see
    # ApplicationContainer.radar_report_settings), so contributions work
    # without one more variable to set. Setting it explicitly is still
    # the better option: a derived key changes if the service key is
    # rotated, and every pseudonym with it.
    radar_pseudonym_key: str = Field(default="", alias="RADAR_PSEUDONYM_KEY")
    radar_report_confirmations: int = Field(default=5, ge=1, alias="RADAR_REPORT_CONFIRMATIONS")
    radar_report_closed_confirmations: int = Field(
        default=5, ge=1, alias="RADAR_REPORT_CLOSED_CONFIRMATIONS"
    )
    radar_report_daily_limit: int = Field(default=5, ge=1, alias="RADAR_REPORT_DAILY_LIMIT")
    # Days after which a report nobody confirmed even once is dropped.
    radar_report_expiry_days: int = Field(default=7, ge=1, alias="RADAR_REPORT_EXPIRY_DAYS")
    # Categories that can be reported as missing (a JSON list in env).
    radar_report_place_types: list[str] = Field(
        default=["veterinary", "grooming", "shop", "hotel", "dog_park"],
        alias="RADAR_REPORT_PLACE_TYPES",
    )
    # Whether a not-yet-confirmed "closed" report is shown on the place.
    radar_report_show_pending_closures: bool = Field(
        default=False, alias="RADAR_REPORT_SHOW_PENDING_CLOSURES"
    )
    # Switches, all on by default, to turn one part of the radar off
    # from the environment alone (docs/features/radar_places_overpass.md):
    # reports and votes; the "closed" kind of report only; dog-park stars;
    # and which sources of `radar_places_open` are served (a JSON list of
    # source names, e.g. ["overture","comune_milano"]; ["*"] is all of
    # them, [] none). Off means: nothing new is accepted and what users
    # contributed is no longer shown; nothing is deleted.
    radar_reports_enabled: bool = Field(default=True, alias="RADAR_REPORTS_ENABLED")
    radar_report_closed_enabled: bool = Field(default=True, alias="RADAR_REPORT_CLOSED_ENABLED")
    radar_ratings_enabled: bool = Field(default=True, alias="RADAR_RATINGS_ENABLED")
    radar_open_sources: list[str] = Field(default=["*"], alias="RADAR_OPEN_SOURCES")
    # Where a business owner or a user can ask for a correction or the
    # removal of a place. Shown publicly in the app; empty hides it.
    support_contact_email: str = Field(default="vastaso88@gmail.com", alias="SUPPORT_CONTACT_EMAIL")
    # Attachment bytes: local disk outside of PERSISTENCE_BACKEND=supabase
    # (fine for local dev), a Supabase Storage bucket when it is (required
    # on serverless deploys like Vercel, whose filesystem is read-only).
    media_storage_dir: str = Field(default="./data/chat_attachments", alias="MEDIA_STORAGE_DIR")
    media_storage_bucket: str = Field(default="chat-attachments", alias="MEDIA_STORAGE_BUCKET")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    enable_telemetry: bool = Field(default=False, alias="ENABLE_TELEMETRY")
    # 2026-09-21: default flipped to False — see chat_orchestrator.py's
    # ChatOrchestrator._strict_evidence_intents for why the mandatory
    # interview loop is no longer the default for ordinary questions.
    enable_interview_loop: bool = Field(default=False, alias="ENABLE_INTERVIEW_LOOP")
    situation_coverage_target: float = Field(default=0.85, alias="SITUATION_COVERAGE_TARGET")
    interview_max_questions: int = Field(default=3, alias="INTERVIEW_MAX_QUESTIONS")
    # "rules" (default): the dependency-free rule-based anonymizer.
    # "presidio": Presidio + spaCy, only where those are installed.
    # "noop": nothing is removed — honoured outside production only.
    pii_anonymizer_backend: str = Field(default="rules", alias="PII_ANONYMIZER_BACKEND")
    max_active_conversations_per_pet: int = Field(
        default=4, alias="MAX_ACTIVE_CONVERSATIONS_PER_PET"
    )
    # Multilingual architecture (spec v3 §31) — Beta ships Italian-only, but
    # the core engine reads these instead of hardcoding "it"/"Italian", so
    # adding a locale later is a config change, not a core-engine rewrite.
    locale: str = Field(default="it-IT", alias="LOCALE")
    response_language: str = Field(default="it", alias="RESPONSE_LANGUAGE")
    retrieval_languages: list[str] = Field(default=["en", "it"], alias="RETRIEVAL_LANGUAGES")

    def reporter_pseudonym_secret(self) -> str:
        """The dedicated salt when configured; otherwise the Supabase
        service-role key (already a server-only secret), so a deployment
        that never set the new variable still never stores a guessable
        hash. The fixed last resort only applies to local in-memory runs.
        """
        return (
            self.reporter_pseudonym_salt
            or self.supabase_service_role_key
            or "vetapp-local-development-only"
        )

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

        if self.radar_places_provider != "openstreetmap_overpass":
            raise ValueError("RADAR_PLACES_PROVIDER must be openstreetmap_overpass")
        if self.radar_search_radius_km > self.overpass_max_radius_km:
            raise ValueError("RADAR_SEARCH_RADIUS_KM must not exceed OVERPASS_MAX_RADIUS_KM")

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

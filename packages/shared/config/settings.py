import json
from functools import lru_cache
from typing import Annotated, Any

from pydantic import BeforeValidator, Field, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


def _string_list(value: Any) -> Any:
    """A list setting from the environment: a JSON array (["a", "b"]) or plain
    text separated by commas ("a, b"). Spaces are trimmed and empty items
    dropped. pydantic-settings alone only understands JSON, and a plain
    "a@b.it" in an env var made Settings() raise at import, taking the whole
    serverless function down (2026-10-06)."""
    if not isinstance(value, str):
        return value
    text = value.strip()
    if text.startswith("["):
        try:
            parsed = json.loads(text)
        except ValueError:
            parsed = None
        if isinstance(parsed, list):
            return [str(item).strip() for item in parsed if str(item).strip()]
        text = text.strip("[]")
    parts = (part.strip().strip("\"'").strip() for part in text.split(","))
    return [item for item in parts if item]


# NoDecode: hand the raw env text to the validator above instead of JSON-decoding it.
StringList = Annotated[list[str], NoDecode, BeforeValidator(_string_list)]


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
    developer_emails: StringList = Field(default=[], alias="DEVELOPER_EMAILS")
    # Backoffice allowlist. When empty, admin endpoints fall back to
    # DEVELOPER_EMAILS so existing founder/developer accounts can be reused
    # without hardcoding personal addresses in source control.
    admin_emails: StringList = Field(default=[], alias="ADMIN_EMAILS")
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
    # --- Free-tier economy (build 32, 2026-10-14) -------------------------------
    # A smaller model with its own daily quota for mechanical work: case
    # extraction, interview phrasing, English search keywords, the urgency
    # classifier. Empty = everything on LLM_MODEL. Its own reserve, tried in
    # order when it is rate limited. Default: the small gpt-oss, which the
    # free accounts have (2026-10-14: llama-3.1-8b-instant was not in the
    # catalogue of a new free account; a missing model is skipped for the
    # day and the reserve takes over).
    llm_model_light: str = Field(default="openai/gpt-oss-20b", alias="LLM_MODEL_LIGHT")
    llm_light_fallback_models: str = Field(
        default="qwen/qwen3.8-27b", alias="LLM_LIGHT_FALLBACK_MODELS"
    )
    # Visible-reply budget of an ordinary answer (about 1300 characters of
    # Italian); reports get a little more. Reasoning models (openai/gpt-oss)
    # spend extra tokens thinking before writing: that headroom is added
    # to every call to them, on top of the visible budget.
    llm_answer_max_tokens: int = Field(default=450, ge=100, alias="LLM_ANSWER_MAX_TOKENS")
    llm_reasoning_headroom_tokens: int = Field(
        default=350, ge=0, alias="LLM_REASONING_HEADROOM_TOKENS"
    )
    # What goes into the answer prompt: at most this many sources, each
    # snippet cut at this many characters; the last N messages of the
    # conversation verbatim (each cut at M characters), older ones as a
    # one-line list of topics.
    llm_prompt_max_sources: int = Field(default=2, ge=0, alias="LLM_PROMPT_MAX_SOURCES")
    llm_prompt_source_chars: int = Field(default=300, ge=50, alias="LLM_PROMPT_SOURCE_CHARS")
    llm_history_recent_messages: int = Field(default=6, ge=0, alias="LLM_HISTORY_RECENT_MESSAGES")
    llm_history_message_chars: int = Field(default=400, ge=50, alias="LLM_HISTORY_MESSAGE_CHARS")
    # Daily token budgets per model ("model=tokens,..."): the free-tier
    # figures published by Groq (2026-10), to confirm in the console. From
    # LLM_BUDGET_RESERVE_SHARE of a budget the reserve models go first; at
    # 100% the model is left alone until the day resets.
    llm_daily_token_budgets: str = Field(
        default=(
            "openai/gpt-oss-120b=200000,openai/gpt-oss-20b=200000,"
            "qwen/qwen3.8-27b=200000,openai/gpt-oss-safeguard-20b=200000"
        ),
        alias="LLM_DAILY_TOKEN_BUDGETS",
    )
    llm_default_daily_token_budget: int = Field(
        default=200_000, ge=1, alias="LLM_DEFAULT_DAILY_TOKEN_BUDGET"
    )
    llm_budget_reserve_share: float = Field(
        default=0.8, ge=0.1, le=1.0, alias="LLM_BUDGET_RESERVE_SHARE"
    )
    # Messages per owner per day that may reach the model (0 = no limit);
    # the fixed emergency replies are never counted. DEVELOPER_EMAILS are
    # exempt.
    chat_daily_message_limit_per_user: int = Field(
        default=20, ge=0, alias="CHAT_DAILY_MESSAGE_LIMIT_PER_USER"
    )
    # The second guardian: the light model reads every ordinary message for
    # an emergency the fixed lists missed (any language). Fail-open on a
    # deadline or an outage.
    urgency_classifier_enabled: bool = Field(default=True, alias="URGENCY_CLASSIFIER_ENABLED")
    urgency_classifier_timeout_seconds: int = Field(
        default=6, ge=1, le=30, alias="URGENCY_CLASSIFIER_TIMEOUT_SECONDS"
    )
    # English keywords (light model) as the literature search query.
    evidence_query_normalizer_enabled: bool = Field(
        default=True, alias="EVIDENCE_QUERY_NORMALIZER_ENABLED"
    )
    # Answers to general curiosities ("i cani possono mangiare le fragole?")
    # are kept for this long and shared between owners of the same species.
    chat_answer_cache_enabled: bool = Field(default=True, alias="CHAT_ANSWER_CACHE_ENABLED")
    chat_answer_cache_ttl_hours: int = Field(
        default=24, ge=1, le=168, alias="CHAT_ANSWER_CACHE_TTL_HOURS"
    )
    # "Curiosità per i tuoi animali": headlines read from the RSS feeds
    # listed in packages/infrastructure/news/feeds.py and kept in a shared
    # snapshot for this long. A comma-separated list of feed keys switches
    # single feeds off without a deploy (a publisher asking us to stop).
    news_cache_ttl_minutes: int = Field(default=120, ge=10, le=720, alias="NEWS_CACHE_TTL_MINUTES")
    news_disabled_feeds: str = Field(default="", alias="NEWS_DISABLED_FEEDS")
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
    overpass_fallback_urls: StringList = Field(
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
    # Address <-> position for the app (Località, Segnala!), called from
    # the backend so the user's address and IP never reach the provider
    # (security audit APP-6). Same identification rule as Overpass.
    nominatim_base_url: str = Field(
        default="https://nominatim.openstreetmap.org", alias="NOMINATIM_BASE_URL"
    )
    nominatim_user_agent: str = Field(
        default="VET-APP/1.0 (+https://vet-app-psi-nine.vercel.app)", alias="NOMINATIM_USER_AGENT"
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
    # Categories that can be reported as missing (in env: a JSON list or
    # comma-separated names).
    radar_report_place_types: StringList = Field(
        default=["veterinary", "grooming", "shop", "hotel", "dog_park", "shelter"],
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
    radar_open_sources: StringList = Field(default=["*"], alias="RADAR_OPEN_SOURCES")
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
    retrieval_languages: StringList = Field(default=["en", "it"], alias="RETRIEVAL_LANGUAGES")

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

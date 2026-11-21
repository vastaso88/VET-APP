import json
import logging
from functools import lru_cache
from typing import Annotated, Any, Literal

from pydantic import BeforeValidator, Field, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

from packages.shared.config.groq_models import is_groq_production_model, production_models_only

_logger = logging.getLogger(__name__)


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
    # Public test of the app (2026-11-07): while this names a plan ("plus",
    # "pro" or "ultra") every account is reported on it, nobody pays and the
    # trial never ends. Empty (the default) is the normal behaviour: trial,
    # then a plan. Only the environment can set it, never a request. See
    # packages/core/application/services/get_or_create_subscription.py.
    billing_enabled: bool = Field(default=False, alias="BILLING_ENABLED")
    billing_trial_days: int = Field(default=14, ge=10, le=15, alias="BILLING_TRIAL_DAYS")
    billing_site_url: str = Field(default="https://quokkapp.net", alias="BILLING_SITE_URL")
    subscription_test_plan: str = Field(default="", alias="SUBSCRIPTION_TEST_PLAN")
    # Deleting an account first deactivates it; it is erased for good after this
    # many days, during which the owner can cancel (same e-mail, password reset
    # through the e-mail link). Art. 12(3) and 17 GDPR: follow up within a month,
    # extendable only for complex requests. Legal opinion (docs/compliance/16, 2026-11-16):
    # 30 days is the most a deletion the owner asked for may wait, so the
    # setting is capped at 30 and a higher value stops the app at start-up.
    # Longer keeping (4 months) is the owner's explicit "pause", a different
    # feature. The purge itself stays off until ACCOUNT_DELETION_PURGE_ENABLED
    # is true (the scheduler route only counts).
    account_deletion_grace_days: int = Field(
        default=30, ge=1, le=30, alias="ACCOUNT_DELETION_GRACE_DAYS"
    )
    account_deletion_purge_enabled: bool = Field(
        default=False, alias="ACCOUNT_DELETION_PURGE_ENABLED"
    )
    # Server-side check that the Terms and the Privacy notice are accepted at the
    # current version: while they are not, the protected routes answer 403
    # `consent_required`. OFF until the app that shows the acceptance screen is
    # distributed (the Orchestrator turns it on).
    consent_enforcement_enabled: bool = Field(default=False, alias="CONSENT_ENFORCEMENT_ENABLED")
    # Pause (docs/compliance/18 §2): the most months an account may stay paused
    # without a sign-in; then it is erased, after the warnings. NEVER empty: a
    # missing limit is what art. 5(1)(e) GDPR forbids, so the range is enforced at
    # start-up. The purge stays off until PAUSE_PURGE_ENABLED is true (the
    # scheduler route only counts), and it also needs the e-mails to exist.
    pause_max_months: int = Field(default=24, ge=12, le=36, alias="PAUSE_MAX_MONTHS")
    pause_purge_enabled: bool = Field(default=False, alias="PAUSE_PURGE_ENABLED")
    # E-mail sending (docs/auth/02). OFF unless EMAIL_SENDING_ENABLED is true
    # (owner rule). The SMTP provider is the owner's choice: host and
    # credentials are only ever read from the environment.
    email_sending_enabled: bool = Field(default=False, alias="EMAIL_SENDING_ENABLED")
    smtp_host: str = Field(default="", alias="SMTP_HOST")
    smtp_port: int = Field(default=587, ge=1, le=65535, alias="SMTP_PORT")
    smtp_username: str = Field(default="", alias="SMTP_USERNAME")
    smtp_password: str = Field(default="", alias="SMTP_PASSWORD")
    smtp_use_ssl: bool = Field(default=False, alias="SMTP_USE_SSL")
    email_from: str = Field(default="", alias="EMAIL_FROM")
    # Register of deletions (docs/security/03, 06). A row serves to apply an
    # erasure again while a backup that may hold the account exists: the
    # provider's backup days + 30 (7 + 30; check the plan). As proof the erasure
    # was done it is kept this many years from the deletion (to be confirmed
    # with Normativa). A row stays for the longer of the two.
    deletion_log_reapply_days: int = Field(
        default=37, ge=1, le=3650, alias="DELETION_LOG_REAPPLY_DAYS"
    )
    deletion_log_proof_years: int = Field(default=5, ge=0, le=20, alias="DELETION_LOG_PROOF_YEARS")
    # Private bucket, no storage policy: only the service role reaches it.
    deletion_log_bucket: str = Field(default="deletion-log", alias="DELETION_LOG_BUCKET")
    # How many pets one owner may keep in Ricordi (owner decision 2026-11-16).
    # Empty = the default of packages/core/domain/subscription/limits.py (30);
    # anything that is not a whole number above zero is ignored with a warning
    # (a string, not an int: a bad value must not stop the API at start-up). The
    # backend writes it into the database rule and reports it to the app.
    memorial_pets_max: str = Field(default="", alias="MEMORIAL_PETS_MAX")
    # --- Store billing (docs/billing/02_configurazione_store.md). Secrets come
    # only from the environment; empty = that store is not verified (no paid
    # plan can be granted through it).
    billing_account_token_secret: str = Field(default="", alias="BILLING_ACCOUNT_TOKEN_SECRET")
    billing_catalog_json: str = Field(default="", alias="BILLING_CATALOG_JSON")
    # "sandbox" accepts only sandbox/TestFlight/licence-tester purchases;
    # "production" only real ones. Never both on the same deployment.
    billing_store_environment: str = Field(
        default="sandbox", pattern="^(sandbox|production)$", alias="BILLING_STORE_ENVIRONMENT"
    )
    # Bounded tolerance on a previously verified, renewing subscription when
    # the store cannot be reached. Never creates a right.
    billing_verification_tolerance_hours: int = Field(
        default=24, ge=0, le=72, alias="BILLING_VERIFICATION_TOLERANCE_HOURS"
    )
    # Team/demo accounts kept on a fixed plan without the store, by e-mail:
    # "a@example.com:ultra,b@example.com:pro". Environment only (real
    # addresses never in the repository); a request cannot set it.
    billing_plan_overrides: str = Field(default="", alias="BILLING_PLAN_OVERRIDES")
    billing_admin_test_grants: bool = Field(default=False, alias="BILLING_ADMIN_TEST_GRANTS")
    apple_bundle_id: str = Field(default="", alias="APPLE_BUNDLE_ID")
    apple_issuer_id: str = Field(default="", alias="APPLE_ISSUER_ID")
    apple_key_id: str = Field(default="", alias="APPLE_KEY_ID")
    apple_private_key: str = Field(default="", alias="APPLE_PRIVATE_KEY")
    apple_root_certificates: str = Field(default="", alias="APPLE_ROOT_CERTIFICATES")
    google_play_package_name: str = Field(default="", alias="GOOGLE_PLAY_PACKAGE_NAME")
    google_play_service_account_json: str = Field(
        default="", alias="GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
    )
    google_pubsub_audience: str = Field(default="", alias="GOOGLE_PUBSUB_AUDIENCE")
    google_pubsub_service_account: str = Field(default="", alias="GOOGLE_PUBSUB_SERVICE_ACCOUNT")
    # Backoffice allowlist. When empty, admin endpoints fall back to
    # DEVELOPER_EMAILS so existing founder/developer accounts can be reused
    # without hardcoding personal addresses in source control.
    admin_emails: StringList = Field(default=[], alias="ADMIN_EMAILS")
    # Shared secret for POST /admin/scheduler/tick (GitHub workflow
    # admin-scheduler.yml). Random, 32+ bytes, rotated on its own; when
    # empty the route falls back to the legacy digest of the service key.
    admin_scheduler_secret: str = Field(default="", alias="ADMIN_SCHEDULER_SECRET")
    # Browser origins allowed to call the API in production (the Flutter
    # web app's origin). Empty = no cross-origin browser access.
    cors_allowed_origins: StringList = Field(default=[], alias="CORS_ALLOWED_ORIGINS")
    # Secret key for the pseudonym stored in place of the reporter's id on
    # chat response reports. Changing it orphans existing pseudonyms (no
    # more dedup/erasure match for old rows), so set it once and keep it.
    reporter_pseudonym_salt: str = Field(default="", alias="REPORTER_PSEUDONYM_SALT")
    llm_provider: str = Field(default="echo", alias="LLM_PROVIDER")
    llm_model: str = Field(default="demo-model", alias="LLM_MODEL")
    # Reserve models, comma-separated, tried in order when LLM_MODEL is rate
    # limited (Groq counts its daily limit per model: 2026-10-05, the chat
    # was down for hours on a single exhausted model). Empty = no reserve.
    # Default: Groq production models only (docs/compliance/19, 2026-11-16:
    # preview models are outside Groq's data agreement; groq_models.py).
    llm_fallback_models: str = Field(
        default="openai/gpt-oss-20b,llama-3.3-70b-versatile", alias="LLM_FALLBACK_MODELS"
    )
    llm_api_key: str = Field(default="", alias="LLM_API_KEY")
    llm_base_url: str = Field(default="https://api.groq.com/openai/v1", alias="LLM_BASE_URL")
    llm_timeout_seconds: int = Field(default=30, alias="LLM_TIMEOUT_SECONDS")
    # --- Claude (LLM_PROVIDER=anthropic, owner decision 2026-11-07) ------------
    # The official SDK with ANTHROPIC_API_KEY; LLM_API_KEY stays the Groq key,
    # used by the automatic reserve, the vision and the dictation. Effort:
    # low, medium or high (the two higher levels are refused: thinking is
    # switched off for the light calls, which those levels do not allow).
    # The headroom is added to every answer's visible budget because the
    # model's reasoning counts against max_tokens.
    anthropic_api_key: str = Field(default="", alias="ANTHROPIC_API_KEY")
    anthropic_model: str = Field(default="claude-haiku-5-5", alias="ANTHROPIC_MODEL")
    # Where Claude runs: "global" (standard price) or "us" (US-only inference,
    # 1.1 times the price). The spending guard counts with this value, so the
    # client must send exactly this one as `inference_geo`.
    anthropic_inference_geo: Literal["global", "us"] = Field(
        default="us", alias="ANTHROPIC_INFERENCE_GEO"
    )
    # The occasional more capable model (plan "fratello maggiore", 2026-11-10):
    # the free part of urgencies and the health answer after the owner was not
    # helped. Same client, account, anonymisation and region as every other
    # request to Anthropic; OFF until the measured numbers are approved.
    anthropic_model_strong: str = Field(default="claude-sonnet-5-5", alias="ANTHROPIC_MODEL_STRONG")
    sonnet_escalation_enabled: bool = Field(default=False, alias="SONNET_ESCALATION")
    anthropic_effort: str = Field(default="low", alias="ANTHROPIC_EFFORT")
    anthropic_effort_light: str = Field(default="low", alias="ANTHROPIC_EFFORT_LIGHT")
    anthropic_thinking_headroom_tokens: int = Field(
        default=600, ge=0, alias="ANTHROPIC_THINKING_HEADROOM_TOKENS"
    )
    anthropic_timeout_seconds: int = Field(
        default=30, ge=1, le=120, alias="ANTHROPIC_TIMEOUT_SECONDS"
    )
    # An emergency: the fixed opening, then the model on the case within
    # this many seconds, else the fixed first-aid steps (0 = fixed steps
    # only, as before 2026-11-07).
    urgent_answer_timeout_seconds: int = Field(
        default=12, ge=0, le=30, alias="URGENT_ANSWER_TIMEOUT_SECONDS"
    )
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
        default="llama-3.1-8b-instant", alias="LLM_LIGHT_FALLBACK_MODELS"
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
        default=("openai/gpt-oss-120b=200000,openai/gpt-oss-20b=200000"),
        alias="LLM_DAILY_TOKEN_BUDGETS",
    )
    # Claude is paid per token, not rationed: its guard is money, not raw
    # tokens (an output token costs 5 times an input token, a cache read a
    # tenth). The day's spend of the paid models together may reach this many
    # euros (owner decision 2026-11-10: never under 1 EUR a day); past it the
    # Groq reserve answers until midnight UTC. A token budget given above for
    # a paid model is ignored. The conversion uses LLM_USD_PER_EUR (1 EUR in
    # USD; ECB 2026-11-06: 1.1165).
    llm_daily_budget_eur: float = Field(default=1.0, gt=0, alias="LLM_DAILY_BUDGET_EUR")
    llm_usd_per_eur: float = Field(default=1.1165, gt=0, alias="LLM_USD_PER_EUR")
    # The monthly credit the Anthropic account has, in USD: the admin portal
    # compares the month's spend with it. Information only, it limits nothing
    # (the real limits are in the Anthropic Console).
    llm_monthly_credits_usd: float = Field(default=100.0, gt=0, alias="LLM_MONTHLY_CREDITS_USD")
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
    # The other features that call a model, per owner per day (0 = no
    # limit; security audit BE-4/LLM-4): photo/PDF readings, dictations,
    # vet summaries. Same ledger and exemptions as the messages.
    chat_daily_vision_limit_per_user: int = Field(
        default=10, ge=0, alias="CHAT_DAILY_VISION_LIMIT_PER_USER"
    )
    chat_daily_dictation_limit_per_user: int = Field(
        default=30, ge=0, alias="CHAT_DAILY_DICTATION_LIMIT_PER_USER"
    )
    chat_daily_summary_limit_per_user: int = Field(
        default=5, ge=0, alias="CHAT_DAILY_SUMMARY_LIMIT_PER_USER"
    )
    # Retention of the chat itself: a conversation is deleted, with its
    # files, this many months after its last message (0 = never); a file
    # uploaded but never sent in a message goes after these days.
    chat_conversation_retention_months: int = Field(
        default=24, ge=0, alias="CHAT_CONVERSATION_RETENTION_MONTHS"
    )
    chat_orphan_attachment_retention_days: int = Field(
        default=7, ge=1, alias="CHAT_ORPHAN_ATTACHMENT_RETENTION_DAYS"
    )
    # The second guardian: the light model reads every ordinary message for
    # an emergency the fixed lists missed (any language). Fail-open on a
    # deadline or an outage.
    urgency_classifier_enabled: bool = Field(default=True, alias="URGENCY_CLASSIFIER_ENABLED")
    urgency_classifier_timeout_seconds: int = Field(
        default=6, ge=1, le=30, alias="URGENCY_CLASSIFIER_TIMEOUT_SECONDS"
    )
    # Around the world (docs/product/18): the same, for the travel cards still in
    # draft. Never in production: only approved cards are shown to people.
    travel_cards_include_drafts: bool = Field(default=False, alias="TRAVEL_CARDS_INCLUDE_DRAFTS")
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
    # "groq" reads photos with VISION_MODEL; "off" never reads them (the photo
    # is saved, the chat says honestly it cannot see it, nothing leaves);
    # "echo" is the local test double. VISION_MODEL must be a Groq production
    # model (groq_models.py): empty, or a preview model, means off. Empty by
    # default since 2026-11-16: the only image model on the account was a
    # preview one, outside Groq's data agreement (docs/compliance/19).
    vision_provider: str = Field(default="echo", alias="VISION_PROVIDER")
    vision_model: str = Field(default="", alias="VISION_MODEL")
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
    # "Dichiarano di trattare animali esotici": also read the competence from a practice's own
    # name ("Ambulatorio per animali esotici"). On by owner's decision, 2026-11-08.
    radar_exotic_name_matching: bool = Field(default=True, alias="RADAR_EXOTIC_NAME_MATCHING")
    radar_report_closed_enabled: bool = Field(default=True, alias="RADAR_REPORT_CLOSED_ENABLED")
    radar_ratings_enabled: bool = Field(default=True, alias="RADAR_RATINGS_ENABLED")
    radar_open_sources: StringList = Field(default=["*"], alias="RADAR_OPEN_SOURCES")
    # Where a business owner or a user can ask for a correction or the
    # removal of a place. Shown publicly in the app; empty hides it.
    # No default on purpose: the repository is public and must not carry a
    # personal address; set it per deployment.
    support_contact_email: str = Field(default="", alias="SUPPORT_CONTACT_EMAIL")
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
    # Plan docs/llm/08 (20/11/2026), work A: the chat answers without the fixed texts
    # triggered by keywords (clarifying questions, emergency openings, off-topic refusal);
    # they become prompt rules, the safety guards stay. Off = the chat of today.
    chat_answer_v2: bool = Field(default=False, alias="CHAT_ANSWER_V2")
    # Test-2 comparison arm only: v2 with the earlier urgency lane (fixed legal opening).
    chat_answer_v2_urgent_lane: bool = Field(default=False, alias="CHAT_ANSWER_V2_URGENT_LANE")
    # The 112 line for a hurt person under v2: removed by the owner (2026-11-20), kept as an
    # option only.
    chat_person_hurt_line: bool = Field(default=False, alias="CHAT_PERSON_HURT_LINE")
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
        if self.environment == "production" and self.travel_cards_include_drafts:
            raise ValueError("TRAVEL_CARDS_INCLUDE_DRAFTS is for development, never production")

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

        if self.llm_provider == "anthropic":
            self._require_fields(
                "LLM_PROVIDER=anthropic",
                {
                    "ANTHROPIC_API_KEY": self.anthropic_api_key,
                    "ANTHROPIC_MODEL": self.anthropic_model,
                },
            )
        for name, value in (
            ("ANTHROPIC_EFFORT", self.anthropic_effort),
            ("ANTHROPIC_EFFORT_LIGHT", self.anthropic_effort_light),
        ):
            if value not in ("low", "medium", "high"):
                raise ValueError(f"{name} must be low, medium or high")

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
            # VISION_MODEL is not required: empty, or a model outside Groq's
            # production list, switches photo reading off (container), never
            # stops the app from starting.
            self._require_fields(
                "VISION_PROVIDER=groq",
                {
                    "LLM_API_KEY": self.llm_api_key,
                    "LLM_BASE_URL": self.llm_base_url,
                },
            )

        # Groq's preview models are outside its data agreement
        # (docs/compliance/19): whatever the environment says, the chat chains
        # and the light model keep Groq production models only.
        for field_name in (
            "llm_fallback_models",
            "llm_light_fallback_models",
            "vision_fallback_models",
        ):
            kept, dropped = production_models_only(getattr(self, field_name))
            if dropped:
                _logger.warning(
                    "%s: dropped models outside Groq production: %s",
                    field_name.upper(),
                    ",".join(dropped),
                )
                object.__setattr__(self, field_name, kept)
        if self.llm_model_light and not is_groq_production_model(self.llm_model_light):
            _logger.warning("LLM_MODEL_LIGHT outside Groq production: using openai/gpt-oss-20b")
            object.__setattr__(self, "llm_model_light", "openai/gpt-oss-20b")

        if self.environment == "production":
            # A production deploy with the demo auth provider would accept
            # every request as the demo user: refuse to start instead.
            if self.auth_backend != "supabase" or self.persistence_backend != "supabase":
                raise ValueError(
                    "ENVIRONMENT=production requires AUTH_BACKEND=supabase and "
                    "PERSISTENCE_BACKEND=supabase"
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

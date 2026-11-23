import logging
import re
import uuid
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from apps.api.rate_limit import SlidingWindowLimiter, build_middleware
from apps.api.request_errors import request_error_body
from apps.api.request_language import request_language
from apps.api.routes.account import router as account_router
from apps.api.routes.account_age import router as account_age_router
from apps.api.routes.account_consents import router as account_consents_router
from apps.api.routes.account_preferences import router as account_preferences_router
from apps.api.routes.admin import router as admin_router
from apps.api.routes.admin_age import router as admin_age_router
from apps.api.routes.admin_llm_usage import router as admin_llm_usage_router
from apps.api.routes.admin_pets import router as admin_pets_router
from apps.api.routes.admin_user_actions import router as admin_user_actions_router
from apps.api.routes.admin_users import router as admin_users_router
from apps.api.routes.auth import router as auth_router
from apps.api.routes.auth_pages import router as auth_pages_router
from apps.api.routes.billing import router as billing_router
from apps.api.routes.chat import router as chat_router
from apps.api.routes.chat_attachments import router as chat_attachments_router
from apps.api.routes.chat_response_reports import router as chat_response_reports_router
from apps.api.routes.conversations import router as conversations_router
from apps.api.routes.devices import router as devices_router
from apps.api.routes.events import router as events_router
from apps.api.routes.geocoding import router as geocoding_router
from apps.api.routes.health import router as health_router
from apps.api.routes.legal import router as legal_router
from apps.api.routes.lifecycle import router as lifecycle_router
from apps.api.routes.local_services import router as local_services_router
from apps.api.routes.marketplace import router as marketplace_router
from apps.api.routes.marketplace_messages import router as marketplace_messages_router
from apps.api.routes.news import router as news_router
from apps.api.routes.pets import router as pets_router
from apps.api.routes.reminders import router as reminders_router
from apps.api.routes.speech_to_text import router as speech_to_text_router
from apps.api.routes.subscription import router as subscription_router
from apps.api.routes.travel import router as travel_router
from packages.bootstrap.container import get_container
from packages.core.domain.common.language import language_from_accept_header
from packages.core.domain.localization import translate
from packages.core.domain.pet_profile.validation import PetInputError
from packages.infrastructure.logging.logger import configure_logging
from packages.infrastructure.telemetry.noop import setup_telemetry
from packages.shared.auth_context import reset_access_token, set_access_token
from packages.shared.config.settings import get_settings
from packages.shared.errors.base import (
    AgeRestrictedError,
    AuthenticationError,
    ConsentRequiredError,
    ConversationLimitError,
    MarketplaceRestrictedError,
    MarketplaceRulesRequiredError,
    PetInMemoriesError,
    PlanLimitError,
    ProviderError,
    QuotaExceededError,
    RequirementMissingError,
    SubscriptionRequiredError,
    ValidationError,
)
from packages.shared.user_clock import (
    parse_utc_offset_minutes,
    reset_utc_offset_minutes,
    set_utc_offset_minutes,
)

settings = get_settings()
configure_logging(settings)
setup_telemetry(settings.enable_telemetry)
logger = logging.getLogger(__name__)

_is_production = settings.environment == "production"

# The interactive API docs list every route and schema (admin ones too):
# useful locally, an unnecessary map for an attacker in production.
app = FastAPI(
    title=settings.app_name,
    docs_url=None if _is_production else "/docs",
    redoc_url=None if _is_production else "/redoc",
    openapi_url=None if _is_production else "/openapi.json",
)

if _is_production:
    # Only the origins listed in CORS_ALLOWED_ORIGINS (the Flutter web
    # app) may call the API from a browser; empty list = none.
    if settings.cors_allowed_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(settings.cors_allowed_origins),
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "X-UTC-Offset-Minutes"],
        )
else:
    # The Flutter web client runs on its own dev-server origin (e.g.
    # localhost:8080) and calls this API cross-origin; browsers block that
    # without CORS. Wide open is fine for local/dev/staging, never for prod.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

rate_limiter = SlidingWindowLimiter()
app.middleware("http")(build_middleware(rate_limiter))


@app.middleware("http")
async def security_headers(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """Defensive headers on every response. The API serves JSON (and one
    user-uploaded file route), so the browser must never sniff types,
    frame it, or cache authenticated answers."""
    response = await call_next(request)
    headers = response.headers
    headers.setdefault("X-Content-Type-Options", "nosniff")
    headers.setdefault("X-Frame-Options", "DENY")
    headers.setdefault("Referrer-Policy", "no-referrer")
    headers.setdefault("Permissions-Policy", "geolocation=(), camera=(), microphone=()")
    if _is_production:
        headers.setdefault("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
    if request.headers.get("Authorization"):
        headers.setdefault("Cache-Control", "no-store")
    return response


@app.middleware("http")
async def inject_user_clock(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """The offset of the owner's phone from UTC, for the per-owner daily
    counters (packages/shared/user_clock.py). Anything not believable is UTC."""
    state = set_utc_offset_minutes(
        parse_utc_offset_minutes(request.headers.get("X-UTC-Offset-Minutes"))
    )
    try:
        return await call_next(request)
    finally:
        reset_utc_offset_minutes(state)


@app.middleware("http")
async def inject_access_token(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    auth_header = request.headers.get("Authorization", "")
    token: str | None = None
    if auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1].strip()

    context_token = set_access_token(token or None)
    try:
        response = await call_next(request)
    finally:
        reset_access_token(context_token)
    return response


@app.exception_handler(RequirementMissingError)
async def handle_requirement_missing(_: Request, exc: RequirementMissingError) -> JSONResponse:
    return JSONResponse(
        status_code=400,
        content={"detail": exc.detail, "code": exc.code, "message": exc.message, "fix": exc.fix},
    )


@app.exception_handler(PetInputError)
async def handle_pet_input_error(request: Request, exc: PetInputError) -> JSONResponse:
    """A pet field the API refuses: 422 with a stable `code`, the `field`, and the
    message in the owner's language (Accept-Language, Italian when unknown)."""
    language = language_from_accept_header(request.headers.get("accept-language"))
    return JSONResponse(
        status_code=422,
        content={"detail": exc.message(language), "code": exc.code, "field": exc.field},
    )


@app.exception_handler(RequestValidationError)
async def handle_request_validation(request: Request, exc: RequestValidationError) -> JSONResponse:
    """A body or a parameter that does not fit its schema: 422, as before, with the list the
    apps read (`type`, `loc`) but a short sentence in the owner's language instead of FastAPI's
    technical English, and never the text the owner typed (K08)."""
    return JSONResponse(
        status_code=422,
        content=request_error_body(exc.errors(), request_language(request)),
    )


# "<thing> not found" (also "message not found in this conversation"): a thing that is not there,
# or is not the caller's, answers 404 with the same `detail` the apps already map to a sentence.
_NOT_FOUND = re.compile(r"^[a-z_]+ not found( in this conversation)?$")


@app.exception_handler(ValidationError)
async def handle_validation_error(request: Request, exc: ValidationError) -> JSONResponse:
    if _NOT_FOUND.match(str(exc)):
        return JSONResponse(
            status_code=404,
            content={
                "detail": str(exc),
                "code": "not_found",
                "message": translate("not_found", request_language(request)),
            },
        )
    return JSONResponse(status_code=400, content={"detail": str(exc)})


@app.exception_handler(ConversationLimitError)
async def handle_conversation_limit(_: Request, exc: ConversationLimitError) -> JSONResponse:
    # `detail` keeps the prefix the app reads as its signal; `message` is the same text
    # without it, so a client that is not the app never shows the technical code.
    return JSONResponse(
        status_code=400,
        content={
            "detail": str(exc),
            "code": exc.code,
            "message": exc.message,
            "limit": exc.limit,
        },
    )


@app.exception_handler(AuthenticationError)
async def handle_authentication_error(_: Request, exc: AuthenticationError) -> JSONResponse:
    return JSONResponse(status_code=401, content={"detail": str(exc)})


@app.exception_handler(SubscriptionRequiredError)
async def handle_subscription_required(_: Request, exc: SubscriptionRequiredError) -> JSONResponse:
    return JSONResponse(
        status_code=402,
        content={
            "detail": "subscription_required: la prova gratuita è terminata.",
            "code": "subscription_required",
        },
    )


@app.exception_handler(AgeRestrictedError)
async def handle_age_restricted(request: Request, exc: AgeRestrictedError) -> JSONResponse:
    status = 409 if exc.code == "age_already_declared" else 403
    content: dict[str, object] = {"detail": exc.code, "code": exc.code}
    # Say what is missing and where it goes, in the owner's language (round 2 of
    # the synthetic users: `age_required` alone told nobody what to do).
    locale = language_from_accept_header(request.headers.get("accept-language"))
    if exc.code == "age_required":
        on_marketplace = request.url.path.startswith("/marketplace")
        content["message"] = translate(
            "age_required_marketplace" if on_marketplace else "age_required_plan",
            locale or _caller_locale(),
        )
        content["fix"] = {
            "route": "POST /account/age",
            "field": "birth_date",
            "format": "YYYY-MM-DD",
        }
    elif exc.code == "marketplace_adults_only":
        content["message"] = translate("marketplace_adults_only", locale or _caller_locale())
    return JSONResponse(status_code=status, content=content)


def _caller_locale() -> str | None:
    """The signed-in owner's language, or None (Italian) when it cannot be read."""
    try:
        return get_container().auth_provider.get_current_user().preferred_locale
    except Exception:  # noqa: BLE001 - a missing language must not hide the refusal
        return None


def _plan_limit_message(exc: PlanLimitError, language: str) -> str:
    """The refusal text in the owner's language; a kind without a translation keeps
    the message it was raised with."""
    if exc.kind != "pets":
        return exc.message
    if exc.upgrade_to is not None:
        return translate(
            "plan_limit_pets_upgrade", language, limit=exc.limit, plan=exc.upgrade_to.capitalize()
        )
    return translate("plan_limit_pets", language, limit=exc.limit)


@app.exception_handler(MarketplaceRulesRequiredError)
async def handle_marketplace_rules_required(
    _: Request, exc: MarketplaceRulesRequiredError
) -> JSONResponse:
    return JSONResponse(
        status_code=403,
        content={"detail": "marketplace_rules_required", "code": "marketplace_rules_required"},
    )


@app.exception_handler(PetInMemoriesError)
async def handle_pet_in_memories(_: Request, exc: PetInMemoriesError) -> JSONResponse:
    """The pet is in Ricordi: read, export and delete only."""
    return JSONResponse(
        status_code=409, content={"detail": "pet_in_memories", "code": "pet_in_memories"}
    )


@app.exception_handler(ConsentRequiredError)
async def handle_consent_required(_: Request, exc: ConsentRequiredError) -> JSONResponse:
    return JSONResponse(status_code=403, content={"detail": exc.code, "code": exc.code})


@app.exception_handler(PlanLimitError)
async def handle_plan_limit(request: Request, exc: PlanLimitError) -> JSONResponse:
    message = _plan_limit_message(exc, request_language(request))
    return JSONResponse(
        status_code=403,
        content={
            "detail": f"plan_limit_reached: {message}",
            "code": "plan_limit_reached",
            "kind": exc.kind,
            "limit": exc.limit,
            "message": message,
        },
    )


@app.exception_handler(MarketplaceRestrictedError)
async def handle_marketplace_restricted(
    _: Request, exc: MarketplaceRestrictedError
) -> JSONResponse:
    return JSONResponse(
        status_code=403,
        content={
            "detail": "marketplace_restricted",
            "code": "marketplace_restricted",
            "reason": exc.reason,
            "since": exc.since,
        },
    )


@app.exception_handler(QuotaExceededError)
async def handle_quota_exceeded(_: Request, exc: QuotaExceededError) -> JSONResponse:
    """A per-owner daily allowance is used up: 429 with a message written
    for the owner (`detail`, prefixed by a stable code the app can map)."""
    return JSONResponse(
        status_code=429,
        headers={"Retry-After": str(exc.retry_after_seconds)},
        content={
            "detail": f"quota_exceeded: {exc.message}",
            "code": "quota_exceeded",
            "kind": exc.kind,
            "limit": exc.limit,
            "retry_after_seconds": exc.retry_after_seconds,
        },
    )


@app.exception_handler(ProviderError)
async def handle_provider_error(_: Request, exc: ProviderError) -> JSONResponse:
    # Provider error bodies (Groq quota lines, model names, request ids)
    # stay in the server log; the client gets a fixed message plus a
    # correlation id to quote when reporting the problem.
    error_id = uuid.uuid4().hex[:12]
    logger.warning("provider error %s: %s", error_id, exc)
    return JSONResponse(
        status_code=502,
        content={
            "detail": "Servizio temporaneamente non disponibile. Riprova tra poco.",
            "error_id": error_id,
        },
    )


@app.exception_handler(Exception)
async def handle_unexpected_error(_: Request, exc: Exception) -> JSONResponse:
    error_id = uuid.uuid4().hex[:12]
    logger.exception("unhandled error %s", error_id)
    return JSONResponse(
        status_code=500,
        content={"detail": "Errore interno. Riprova tra poco.", "error_id": error_id},
    )


app.include_router(health_router)
app.include_router(auth_pages_router)
app.include_router(admin_router)
app.include_router(admin_age_router)
app.include_router(admin_llm_usage_router)
app.include_router(admin_users_router)
app.include_router(admin_pets_router)
app.include_router(admin_user_actions_router)
app.include_router(lifecycle_router)
app.include_router(auth_router)
app.include_router(pets_router)
app.include_router(conversations_router)
app.include_router(chat_router)
app.include_router(reminders_router)
app.include_router(account_consents_router)
app.include_router(account_router)
app.include_router(account_age_router)
app.include_router(account_preferences_router)
app.include_router(legal_router)
app.include_router(chat_response_reports_router)
app.include_router(speech_to_text_router)
app.include_router(chat_attachments_router)
app.include_router(subscription_router)
app.include_router(billing_router)
app.include_router(devices_router)
app.include_router(local_services_router)
app.include_router(news_router)
app.include_router(travel_router)
app.include_router(events_router)
app.include_router(geocoding_router)
app.include_router(marketplace_router)
app.include_router(marketplace_messages_router)

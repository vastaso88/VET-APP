import logging
import uuid
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from apps.api.rate_limit import SlidingWindowLimiter, build_middleware
from apps.api.routes.account import router as account_router
from apps.api.routes.account_consents import router as account_consents_router
from apps.api.routes.account_preferences import router as account_preferences_router
from apps.api.routes.admin import router as admin_router
from apps.api.routes.auth import router as auth_router
from apps.api.routes.chat import router as chat_router
from apps.api.routes.chat_attachments import router as chat_attachments_router
from apps.api.routes.chat_response_reports import router as chat_response_reports_router
from apps.api.routes.conversations import router as conversations_router
from apps.api.routes.events import router as events_router
from apps.api.routes.geocoding import router as geocoding_router
from apps.api.routes.health import router as health_router
from apps.api.routes.legal import router as legal_router
from apps.api.routes.local_services import router as local_services_router
from apps.api.routes.marketplace import router as marketplace_router
from apps.api.routes.news import router as news_router
from apps.api.routes.pets import router as pets_router
from apps.api.routes.reminders import router as reminders_router
from apps.api.routes.speech_to_text import router as speech_to_text_router
from apps.api.routes.subscription import router as subscription_router
from packages.infrastructure.logging.logger import configure_logging
from packages.infrastructure.telemetry.noop import setup_telemetry
from packages.shared.auth_context import reset_access_token, set_access_token
from packages.shared.config.settings import get_settings
from packages.shared.errors.base import AuthenticationError, ProviderError, ValidationError

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
            allow_headers=["Authorization", "Content-Type"],
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


@app.exception_handler(ValidationError)
async def handle_validation_error(_: Request, exc: ValidationError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(exc)})


@app.exception_handler(AuthenticationError)
async def handle_authentication_error(_: Request, exc: AuthenticationError) -> JSONResponse:
    return JSONResponse(status_code=401, content={"detail": str(exc)})


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
app.include_router(admin_router)
app.include_router(auth_router)
app.include_router(pets_router)
app.include_router(conversations_router)
app.include_router(chat_router)
app.include_router(reminders_router)
app.include_router(account_consents_router)
app.include_router(account_router)
app.include_router(account_preferences_router)
app.include_router(legal_router)
app.include_router(chat_response_reports_router)
app.include_router(speech_to_text_router)
app.include_router(chat_attachments_router)
app.include_router(subscription_router)
app.include_router(local_services_router)
app.include_router(news_router)
app.include_router(events_router)
app.include_router(geocoding_router)
app.include_router(marketplace_router)

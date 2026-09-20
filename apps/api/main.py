from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from apps.api.routes.account_consents import router as account_consents_router
from apps.api.routes.auth import router as auth_router
from apps.api.routes.chat import router as chat_router
from apps.api.routes.chat_response_reports import router as chat_response_reports_router
from apps.api.routes.conversations import router as conversations_router
from apps.api.routes.health import router as health_router
from apps.api.routes.pets import router as pets_router
from apps.api.routes.reminders import router as reminders_router
from packages.infrastructure.logging.logger import configure_logging
from packages.infrastructure.telemetry.noop import setup_telemetry
from packages.shared.auth_context import reset_access_token, set_access_token
from packages.shared.config.settings import get_settings
from packages.shared.errors.base import AuthenticationError, ProviderError, ValidationError

settings = get_settings()
configure_logging(settings)
setup_telemetry(settings.enable_telemetry)

app = FastAPI(title=settings.app_name)

if settings.environment != "production":
    # The Flutter web client runs on its own dev-server origin (e.g.
    # localhost:8080) and calls this API cross-origin; browsers block that
    # without CORS. Wide open is fine for local/dev/staging, never for prod.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )


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
    return JSONResponse(status_code=502, content={"detail": str(exc)})


app.include_router(health_router)
app.include_router(auth_router)
app.include_router(pets_router)
app.include_router(conversations_router)
app.include_router(chat_router)
app.include_router(reminders_router)
app.include_router(account_consents_router)
app.include_router(chat_response_reports_router)

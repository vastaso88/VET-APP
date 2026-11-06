"""Local server for synthetic users: many accounts, memory only, never production.

The normal local backend knows one user. This one gives every account its own
identity, keeps everything in memory, binds to 127.0.0.1 and forces SUPABASE_URL
empty. With EVAL_CLAUDE_EXE set the model is reached through the Claude Code CLI
(test use with an owner login); otherwise the configured provider is used.
"""

from __future__ import annotations

import contextvars
import json
import os
import subprocess
import sys
import threading
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(os.environ.get("SYNTHETIC_USERS_OUTPUT") or ROOT / ".local" / "synthetic_users")
PORT = int(os.environ.get("SYNTHETIC_USERS_PORT", "8799"))
MODEL = os.environ.get("EVAL_CLI_MODEL", "claude-haiku-5-5")
EXE = os.environ.get("EVAL_CLAUDE_EXE", "")
CONFIG_DIR = str(Path.home() / ".claude-eval-cli")

os.environ.update(
    {
        "SUPABASE_URL": "",
        "PERSISTENCE_BACKEND": "in_memory",
        "AUTH_BACKEND": "bootstrap",
        "ENVIRONMENT": "development",
        "CHAT_DAILY_MESSAGE_LIMIT_PER_USER": "500",
        "MEDIA_STORAGE_DIR": str(OUTPUT / "media"),
        "CRASH_REPORTING": "false",
    }
)
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

import uvicorn  # noqa: E402

from packages.bootstrap.container import ApplicationContainer  # noqa: E402
from packages.core.application.ports.auth_provider import (  # noqa: E402
    AuthenticatedUser,
    AuthSession,
)
from packages.core.application.ports.llm_client import (  # noqa: E402
    LLMGenerationRequest,
    LLMResponse,
)
from packages.shared.errors.base import AuthenticationError  # noqa: E402

_token: contextvars.ContextVar[str] = contextvars.ContextVar("synthetic_token", default="")
_users: dict[str, AuthenticatedUser] = {}
_by_email: dict[str, str] = {}
_lock = threading.Lock()
_model_slots = threading.Semaphore(int(os.environ.get("EVAL_CLI_CONCURRENCY", "4")))


class SyntheticAuthProvider:
    """One identity per account, from a local token. Passwords are not checked:
    nothing here is reachable from outside this computer."""

    def __init__(self, settings: Any) -> None:
        self._settings = settings

    def get_current_user(self) -> AuthenticatedUser:
        user = _users.get(_token.get())
        if user is None:
            raise AuthenticationError("missing or invalid token")
        return user

    def last_sign_in_at(self) -> datetime | None:
        return datetime.now(UTC)

    def update_preferred_locale(self, locale: Any) -> AuthenticatedUser:
        token = _token.get()
        user = self.get_current_user().model_copy(update={"preferred_locale": locale})
        _users[token] = user
        return user

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        _ = password
        token = _by_email.get(email.lower())
        if token is None:
            raise AuthenticationError("invalid credentials")
        return AuthSession(access_token=token, refresh_token=None, user=_users[token])

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        _ = password
        key = email.lower()
        if not key.endswith("@example.com"):
            raise AuthenticationError("synthetic accounts use example.com only")
        with _lock:
            if key not in _by_email:
                token = f"local-{uuid.uuid4().hex}"
                _by_email[key] = token
                _users[token] = AuthenticatedUser(id=str(uuid.uuid4()), email=key)
        return self.sign_in_with_password(key, password)

    def __getattr__(self, name: str) -> Any:
        raise AttributeError(name)


class ClaudeCliClient:
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        system = request.system_prompt
        if request.json_mode:
            system += "\n\nReply with one JSON object only, no other text and no code fence."
        env = {
            name: value
            for name, value in os.environ.items()
            if not name.startswith(("CLAUDE_CODE_", "ANTHROPIC_", "CLAUDECODE"))
        }
        env["CLAUDE_CONFIG_DIR"] = CONFIG_DIR
        work = OUTPUT / "cli"
        work.mkdir(parents=True, exist_ok=True)
        with _model_slots:
            done = subprocess.run(
                [
                    EXE,
                    "-p",
                    "--model",
                    MODEL,
                    "--system-prompt",
                    system,
                    "--tools",
                    "",
                    "--setting-sources",
                    "",
                    "--strict-mcp-config",
                    "--disable-slash-commands",
                    "--no-session-persistence",
                    "--output-format",
                    "json",
                ],
                input=request.user_prompt,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                cwd=work,
                env=env,
                timeout=240,
            )
        data = json.loads(done.stdout)
        if data.get("is_error"):
            raise RuntimeError(str(data.get("result"))[:200])
        usage = data.get("usage") or {}
        prompt = sum(
            int(usage.get(key) or 0)
            for key in (
                "input_tokens",
                "cache_creation_input_tokens",
                "cache_read_input_tokens",
            )
        )
        output = int(usage.get("output_tokens") or 0)
        with (OUTPUT / "usage.csv").open("a", encoding="utf-8") as log:
            log.write(f"{MODEL},{request.purpose},{prompt},{output}\n")
        return LLMResponse(
            content=str(data.get("result") or ""),
            provider="claude-cli",
            model=MODEL,
            token_count=prompt + output,
            finish_reason="stop",
            prompt_tokens=prompt,
            completion_tokens=output,
        )


def _install() -> None:
    ApplicationContainer._build_auth_provider = lambda self: SyntheticAuthProvider(self.settings)  # type: ignore[method-assign,assignment,return-value]
    if EXE:
        ApplicationContainer._build_llm_client = lambda self: ClaudeCliClient()  # type: ignore[method-assign,assignment,return-value]


_install()

from apps.api.dependencies.container import get_container  # noqa: E402
from apps.api.main import app  # noqa: E402


class TokenMiddleware:
    def __init__(self, inner: Any) -> None:
        self.inner = inner

    async def __call__(self, scope: Any, receive: Any, send: Any) -> None:
        token = ""
        if scope["type"] == "http":
            headers = dict(scope.get("headers") or [])
            value = headers.get(b"authorization", b"").decode()
            if value.lower().startswith("bearer "):
                token = value[7:].strip()
        reset = _token.set(token)
        try:
            await self.inner(scope, receive, send)
        finally:
            _token.reset(reset)


if __name__ == "__main__":
    settings = get_container().settings
    if settings.persistence_backend != "in_memory" or settings.supabase_url:
        sys.exit("Rifiutato: questo server funziona solo in memoria, mai con Supabase.")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    print(f"Model: {MODEL if EXE else settings.llm_model}. Only on http://127.0.0.1:{PORT}")
    uvicorn.run(TokenMiddleware(app), host="127.0.0.1", port=PORT, log_level="warning")

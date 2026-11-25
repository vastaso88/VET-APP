"""The reserve provider, the dictation and the photo reading are gone (owner decision
2026-11-25), but the deployments keep their old variables until somebody removes them:
they must not stop the start-up, and one log line names them without their values.

The start-up runs in a process of its own, as on Vercel: production settings, the
variables of the test twin (names and public values of its list; every secret here is
invented), the database client replaced, and no connection outside this computer.
"""

from __future__ import annotations

import os
import subprocess
import sys

import pytest

from packages.bootstrap.container import answer_models
from packages.core.domain.llm_usage.models import DEMO_MODEL
from packages.shared.config.settings import (
    REMOVED_VARIABLES,
    Settings,
    removed_variables_present,
)

OLD_KEY = "old-key-that-must-not-be-printed"

# What the deployments set: the ones that are still settings...
DEPLOYMENT = {
    "ENVIRONMENT": "production",
    "AUTH_BACKEND": "supabase",
    "PERSISTENCE_BACKEND": "supabase",
    "SUPABASE_URL": "https://example.supabase.co",
    "SUPABASE_ANON_KEY": "anon-test-value",
    "SUPABASE_SERVICE_ROLE_KEY": "service-role-test-value",
    "ANTHROPIC_API_KEY": "anthropic-test-value",
    "LLM_PROVIDER": "anthropic",
    "SONNET_ESCALATION": "true",
    "CHAT_ANSWER_V2": "true",
    "LLM_DAILY_BUDGET_EUR": "1.5",
    "LLM_MONTHLY_CREDITS_USD": "15",
    "SUPPORT_CONTACT_EMAIL": "supporto@example.com",
}
# ...and the ones of what was removed.
LEFTOVERS = {
    "LLM_MODEL": "openai/gpt-oss-120b",
    "LLM_API_KEY": OLD_KEY,
    "LLM_BASE_URL": "https://old-provider.example.com/openai/v1",
    "LLM_FALLBACK_MODELS": "openai/gpt-oss-20b,qwen/qwen3.8-27b",
    "LLM_MODEL_LIGHT": "openai/gpt-oss-20b",
    "LLM_LIGHT_FALLBACK_MODELS": "llama-3.1-8b-instant",
    "LLM_DAILY_TOKEN_BUDGETS": "openai/gpt-oss-120b=200000,openai/gpt-oss-20b=200000",
    "STT_PROVIDER": "groq",
    "STT_MODEL": "the-old-transcriber",
    "VISION_PROVIDER": "groq",
    "VISION_MODEL": "qwen/qwen3.8-27b",
    "VISION_FALLBACK_MODELS": "qwen/qwen3.8-27b",
}

START = r"""
import socket
from unittest.mock import MagicMock

real_connect = socket.socket.connect

def guarded(self, address):
    # The event loop of Windows opens a pair of sockets on this computer: allowed.
    if isinstance(address, tuple) and address[0] not in ("127.0.0.1", "::1"):
        raise RuntimeError(f"connection refused by the test: {address[0]}")
    return real_connect(self, address)

socket.socket.connect = guarded

import packages.infrastructure.persistence.supabase.client as supabase_client

supabase_client.build_supabase_client = lambda settings: MagicMock()
supabase_client.build_supabase_public_client = lambda settings: MagicMock()

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import answer_models, get_container

container = get_container()
print("llm", type(container.llm_client.inner).__name__)
print("models", answer_models(container.settings))
print("photos", type(container.image_analyzer).__name__, container.photo_reading_enabled)
print("environment", container.settings.environment)
client = TestClient(app, raise_server_exceptions=False)
for method in ("post", "get"):
    print(method, getattr(client, method)("/speech-to-text").status_code)
print("a route that exists", client.get("/pets").status_code)
"""


def _start(**changes: str) -> subprocess.CompletedProcess[str]:
    env = {k: v for k, v in os.environ.items() if k not in REMOVED_VARIABLES}
    env.update(DEPLOYMENT)
    env.update(changes)
    return subprocess.run(
        [sys.executable, "-c", START],
        cwd=os.getcwd(),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_production_starts_with_the_old_variables_still_set() -> None:
    result = _start(**LEFTOVERS)

    assert result.returncode == 0, result.stderr
    assert "llm AnthropicLLMClient" in result.stdout
    assert "models ['claude-haiku-5-5']" in result.stdout
    assert "photos DisabledImageAnalyzer False" in result.stdout
    assert "environment production" in result.stdout
    # The dictation is gone: an old app that calls it gets a 404.
    assert "post 404" in result.stdout and "get 404" in result.stdout
    assert "a route that exists" in result.stdout
    assert "a route that exists 404" not in result.stdout

    output = result.stdout + result.stderr
    [line] = [text for text in result.stderr.splitlines() if "removed services" in text]
    for name in ("LLM_MODEL", "LLM_API_KEY", "STT_PROVIDER", "VISION_MODEL"):
        assert name in line
    for name, value in LEFTOVERS.items():
        if name != "VISION_PROVIDER" and name != "STT_PROVIDER":
            assert value not in output, name
    assert "VISION_PROVIDER is neither off nor echo" in output


def test_production_starts_without_them_and_says_nothing() -> None:
    result = _start()

    assert result.returncode == 0, result.stderr
    assert "llm AnthropicLLMClient" in result.stdout
    assert "photos DisabledImageAnalyzer False" in result.stdout
    assert "removed services" not in result.stderr


def test_not_even_a_meaningless_value_stops_the_start() -> None:
    result = _start(**dict.fromkeys(REMOVED_VARIABLES, "not a number, not a model"))

    assert result.returncode == 0, result.stderr


def test_the_log_line_names_only_what_is_set() -> None:
    assert removed_variables_present({"LLM_API_KEY": OLD_KEY, "STT_MODEL": "  ", "PATH": "x"}) == [
        "LLM_API_KEY"
    ]


# --- the only providers ----------------------------------------------------------------


@pytest.mark.parametrize("value", ["anthropic", " Anthropic ", "ANTHROPIC"])
def test_claude_is_accepted_however_it_is_written(value: str) -> None:
    settings = Settings(LLM_PROVIDER=value, ANTHROPIC_API_KEY="anthropic-test-value")

    assert settings.llm_provider == "anthropic"
    assert answer_models(settings) == ["claude-haiku-5-5"]


def test_the_stand_in_is_accepted() -> None:
    assert answer_models(Settings(LLM_PROVIDER="echo")) == [DEMO_MODEL]


@pytest.mark.parametrize("value", ["groq", "openai", "antropic", ""])
def test_any_other_provider_stops_the_start_without_printing_a_key(value: str) -> None:
    with pytest.raises(ValueError, match="LLM_PROVIDER must be one of: anthropic, echo") as caught:
        Settings(LLM_PROVIDER=value, ANTHROPIC_API_KEY="anthropic-test-value")

    assert "anthropic-test-value" not in str(caught.value)

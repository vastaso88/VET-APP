from __future__ import annotations

import os
import subprocess
import sys


def test_bootstrap_container_starts_without_supabase_imports() -> None:
    env = os.environ.copy()
    env.update(
        {
            "AUTH_BACKEND": "bootstrap",
            "PERSISTENCE_BACKEND": "in_memory",
            "BOOTSTRAP_USER_ID": "demo-user",
            "BOOTSTRAP_USER_EMAIL": "demo@vetapp.local",
            "LLM_PROVIDER": "echo",
            "LLM_MODEL": "demo-model",
            "LLM_API_KEY": "test-key",
        }
    )

    code = r"""
import builtins

blocked_prefixes = (
    "supabase",
    "packages.infrastructure.auth.supabase_auth_provider",
    "packages.infrastructure.persistence.supabase",
)

real_import = builtins.__import__

def guarded_import(name, globals=None, locals=None, fromlist=(), level=0):
    if name == blocked_prefixes[0] or any(
        name.startswith(prefix) for prefix in blocked_prefixes[1:]
    ):
        raise RuntimeError(f"blocked import: {name}")
    return real_import(name, globals, locals, fromlist, level)

builtins.__import__ = guarded_import

from packages.bootstrap.container import ApplicationContainer
from packages.shared.config.settings import Settings

container = ApplicationContainer(Settings())
print(container.llm_client.__class__.__name__)
"""
    result = subprocess.run(
        [sys.executable, "-c", code],
        cwd=os.getcwd(),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert "EchoLLMClient" in result.stdout


def test_api_main_import_does_not_touch_supabase_modules() -> None:
    env = os.environ.copy()
    env.update(
        {
            "AUTH_BACKEND": "bootstrap",
            "PERSISTENCE_BACKEND": "in_memory",
            "BOOTSTRAP_USER_ID": "demo-user",
            "BOOTSTRAP_USER_EMAIL": "demo@vetapp.local",
            "LLM_PROVIDER": "echo",
            "LLM_MODEL": "demo-model",
            "LLM_API_KEY": "test-key",
        }
    )

    code = r"""
import builtins

blocked_prefixes = (
    "supabase",
    "packages.infrastructure.auth.supabase_auth_provider",
    "packages.infrastructure.persistence.supabase",
)

real_import = builtins.__import__

def guarded_import(name, globals=None, locals=None, fromlist=(), level=0):
    if name == blocked_prefixes[0] or any(
        name.startswith(prefix) for prefix in blocked_prefixes[1:]
    ):
        raise RuntimeError(f"blocked import: {name}")
    return real_import(name, globals, locals, fromlist, level)

builtins.__import__ = guarded_import

from apps.api.main import app

print(app.title)
"""
    result = subprocess.run(
        [sys.executable, "-c", code],
        cwd=os.getcwd(),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert "Vet App" in result.stdout

"""The model under test reached through the local Claude Code program.

Set EVAL_CLAUDE_EXE (the path of `claude` / `claude.exe`) in the environment of
the process only, never in a file: the evaluation then sends every model call
to that program, logged in with the owner's test login kept apart in
``~/.claude-eval-cli``. No API key is involved, so none can be spent, and the
production quota is never touched. EVAL_CLI_MODEL picks the model (default
claude-haiku-5-5, the production one).

The program has no ``max_tokens``: lengths measured this way are the model's
own, not cut by the production ceiling.

Same behaviour as the client of scripts/eval/synthetic_users/server.py: the
variables of this Claude Code session (CLAUDE_CODE_*, ANTHROPIC_*) are not
passed on, no tool, setting, MCP server or slash command is loaded.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any

DEFAULT_MODEL = "claude-haiku-5-5"
CONFIG_DIR = Path.home() / ".claude-eval-cli"


def cli_exe() -> str:
    """The program's path, from the process environment only."""
    return os.environ.get("EVAL_CLAUDE_EXE", "").strip()


def cli_model() -> str:
    return os.environ.get("EVAL_CLI_MODEL", "").strip() or DEFAULT_MODEL


class ClaudeCliClient:
    """An LLMClient that runs `claude -p` once per request."""

    def __init__(self, exe: str, work_dir: Path, *, model: str = DEFAULT_MODEL) -> None:
        self._exe = exe
        self._work_dir = work_dir
        self._model = model

    def generate(self, request: Any) -> Any:
        from packages.core.application.ports.llm_client import LLMResponse
        from packages.shared.errors.base import ProviderError

        system = request.system_prompt
        if request.json_mode:
            system += "\n\nReply with one JSON object only, no other text and no code fence."
        env = {
            name: value
            for name, value in os.environ.items()
            if not name.startswith(("CLAUDE_CODE_", "ANTHROPIC_", "CLAUDECODE"))
        }
        env["CLAUDE_CONFIG_DIR"] = str(CONFIG_DIR)
        self._work_dir.mkdir(parents=True, exist_ok=True)
        try:
            done = self._run(system, request.user_prompt, env)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise ProviderError("the claude program did not answer") from exc
        try:
            data = json.loads(done.stdout)
        except json.JSONDecodeError as exc:
            raise ProviderError("the claude program gave no JSON reply") from exc
        if data.get("is_error"):
            raise ProviderError(str(data.get("result"))[:200])
        usage = data.get("usage") or {}
        prompt = sum(
            int(usage.get(key) or 0)
            for key in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
        )
        output = int(usage.get("output_tokens") or 0)
        return LLMResponse(
            content=str(data.get("result") or ""),
            provider="claude-cli",
            model=self._model,
            token_count=prompt + output,
            finish_reason="stop",
            prompt_tokens=prompt,
            completion_tokens=output,
        )

    def _run(
        self, system: str, user_prompt: str, env: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                self._exe,
                "-p",
                "--model",
                self._model,
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
            input=user_prompt,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=self._work_dir,
            env=env,
            timeout=240,
        )

"""Records every model call: model, class, purpose, tokens, duration, outcome.

Wraps the provider client so every caller (orchestrator, extraction,
summaries) is measured the same way without knowing it. One structured
log line per call and one row in the usage ledger; the budget gets the
tokens at once, ahead of the ledger's next read. A ledger failure is
logged and otherwise ignored: measuring must never cost an answer.
"""

from __future__ import annotations

import json
import logging
import time

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.domain.llm_usage.models import LlmUsageEvent, estimate_tokens
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.llm_usage")


class InstrumentedLLMClient(LLMClient):
    def __init__(
        self,
        inner: LLMClient,
        *,
        repository: LlmUsageRepository | None = None,
        budget: LlmBudget | None = None,
    ) -> None:
        self.inner = inner
        self._repository = repository
        self._budget = budget

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        started = time.perf_counter()
        try:
            response = self.inner.generate(request)
        except ProviderError as exc:
            self._record(
                LlmUsageEvent(
                    model=f"({request.model_class})",
                    model_class=request.model_class,
                    purpose=request.purpose,
                    duration_ms=int((time.perf_counter() - started) * 1000),
                    outcome="rate_limited" if "429" in str(exc) else "error",
                )
            )
            raise
        prompt_tokens = response.prompt_tokens or estimate_tokens(
            request.system_prompt + request.user_prompt
        )
        completion_tokens = response.completion_tokens or estimate_tokens(response.content)
        total = response.token_count or (prompt_tokens + completion_tokens)
        event = LlmUsageEvent(
            model=response.model,
            model_class=request.model_class,
            purpose=request.purpose,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            cached_prompt_tokens=response.cached_prompt_tokens,
            total_tokens=total,
            duration_ms=int((time.perf_counter() - started) * 1000),
            outcome="length" if response.finish_reason == "length" else "ok",
        )
        if self._budget is not None:
            self._budget.note_usage(response.model, total)
        self._record(event)
        return response

    def _record(self, event: LlmUsageEvent) -> None:
        # Counts and names only: never the prompt or the reply.
        logger.info(
            "llm_usage %s",
            json.dumps(
                {
                    "model": event.model,
                    "class": event.model_class,
                    "purpose": event.purpose,
                    "prompt_tokens": event.prompt_tokens,
                    "completion_tokens": event.completion_tokens,
                    "cached_prompt_tokens": event.cached_prompt_tokens,
                    "total_tokens": event.total_tokens,
                    "duration_ms": event.duration_ms,
                    "outcome": event.outcome,
                }
            ),
        )
        if self._repository is None:
            return
        try:
            self._repository.record(event)
        except Exception:  # noqa: BLE001 - see module docstring
            logger.exception("llm_usage: could not store the usage row")

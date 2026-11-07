"""The primary model, and another provider when it cannot answer.

Built for Claude (primary) with Groq (reserve), 2026-11-07: an outage, a
timeout, a rate limit or the primary's exhausted daily budget hand the
call to the reserve, which is already the chain of Groq models with its
own budget and reserves. Two things are not handed over:

* a refusal (LLMRefusal): the primary's safety classifiers declined the
  request, and the same request must not be asked elsewhere;
* a call with a deadline when little of it is left: an urgent answer at
  12 seconds must not become 24.
"""

from __future__ import annotations

import logging
import time

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMRefusal,
    LLMResponse,
)
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.llm.reserve")

# Below this many seconds left of the caller's deadline the reserve is not
# asked: it would not answer in time either.
MIN_RESERVE_SECONDS = 3


class ReserveLLMClient(LLMClient):
    def __init__(
        self,
        primary: LLMClient,
        reserve: LLMClient,
        *,
        primary_name: str = "anthropic",
        reserve_name: str = "groq",
    ) -> None:
        self.primary = primary
        self.reserve = reserve
        self._primary_name = primary_name
        self._reserve_name = reserve_name

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        started = time.monotonic()
        try:
            return self.primary.generate(request)
        except LLMRefusal:
            raise
        except ProviderError as exc:
            remaining = request.timeout_seconds
            if remaining is not None:
                remaining = int(remaining - (time.monotonic() - started))
                if remaining < MIN_RESERVE_SECONDS:
                    logger.warning(
                        "llm reserve: %s failed a %s call (%s) with no time left for %s",
                        self._primary_name,
                        request.purpose,
                        exc,
                        self._reserve_name,
                    )
                    raise
            logger.warning(
                "llm reserve: %s failed a %s call (%s); asking %s",
                self._primary_name,
                request.purpose,
                exc,
                self._reserve_name,
            )
            if remaining is None:
                return self.reserve.generate(request)
            return self.reserve.generate(request.model_copy(update={"timeout_seconds": remaining}))

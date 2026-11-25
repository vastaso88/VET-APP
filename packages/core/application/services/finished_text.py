"""A text of lines (a document's values, the vet summary) that the token budget cut is
written again with no reasoning, then closed at its last whole line (collaudo, wave 0)."""

from __future__ import annotations

import logging
import time

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.domain.conversation.unfinished_text import close_at_last_line

logger = logging.getLogger("vetgpt.llm.finished_text")


# Below this many seconds left of the owner's wait, no second writing is started.
_MIN_SECONDS = 4


def generate_finished_lines(client: LLMClient, request: LLMGenerationRequest) -> str:
    started = time.monotonic()
    response = client.generate(request)
    if response.finish_reason != "length":
        return response.content.strip()
    left = None
    if request.timeout_seconds is not None:
        left = int(request.timeout_seconds - (time.monotonic() - started))
        if left < _MIN_SECONDS:
            return close_at_last_line(response.content.strip())
    logger.warning("%s: cut by the token budget, written again", request.purpose)
    try:
        second = client.generate(
            request.model_copy(update={"without_reasoning": True, "timeout_seconds": left})
        )
    except Exception as exc:  # noqa: BLE001 - the cut text can still be closed
        logger.warning("%s: second writing failed (%s)", request.purpose, type(exc).__name__)
    else:
        if second.finish_reason != "length" and second.content.strip():
            return second.content.strip()
        response = max((response, second), key=lambda r: len(r.content))
    return close_at_last_line(response.content.strip())

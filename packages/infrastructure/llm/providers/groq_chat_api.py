"""Groq chat-completions call with a reserve of models.

Found 2026-10-05: Groq's daily token limit is per MODEL, and on reaching
it every request fails with HTTP 429 until the 24-hour window moves on —
the whole chat answered "servizio non disponibile" for hours. So when the
configured model is rate limited, the next model in a configurable list
is tried, and the limited one is left alone for a while instead of being
hit again on every message.

Shared by the text client and the vision client.
"""

from __future__ import annotations

import json
import logging
import re
import time
from collections.abc import Callable
from typing import Any
from urllib import error, request

from packages.shared.errors.base import ProviderError

logger = logging.getLogger(__name__)

# After a daily limit there is no point retrying the same model for a
# while; a per-minute limit clears quickly.
DAILY_LIMIT_COOLDOWN_SECONDS = 600.0
SHORT_LIMIT_COOLDOWN_SECONDS = 30.0

# The server is in trouble with this model right now: try the next one,
# without remembering it.
_TRANSIENT_STATUSES = frozenset({500, 502, 503, 504})
# A reserve model can be retired or reject a parameter the main one
# accepts: that must not take the chat down either.
_RESERVE_SKIP_STATUSES = frozenset({400, 404, 413, 422})

_DAILY_LIMIT = re.compile(r"per day|\(TPD\)|\(RPD\)", re.IGNORECASE)

Transport = Callable[[request.Request, int], dict[str, Any]]


def split_models(value: str) -> list[str]:
    """ "a, b,,c" -> ["a", "b", "c"] (a comma-separated environment value)."""
    return [model.strip() for model in value.split(",") if model.strip()]


def _urlopen_transport(http_request: request.Request, timeout: int) -> dict[str, Any]:
    with request.urlopen(http_request, timeout=timeout) as response:
        body: dict[str, Any] = json.loads(response.read().decode("utf-8"))
    return body


class GroqChatApi:
    """Posts a chat completion, moving down `models` when one is limited.

    `models[0]` is the configured model; the rest are the reserve, in
    order. Which models are resting after a 429 is remembered in this
    process only (per server instance) — enough to stop hammering a model
    that will refuse anyway.
    """

    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        timeout_seconds: int,
        models: list[str],
        purpose: str,
        transport: Transport | None = None,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        # Order kept, duplicates dropped (the main model may also be
        # listed among the reserves).
        self._models = list(dict.fromkeys(model for model in models if model))
        self._url = f"{base_url.rstrip('/')}/chat/completions"
        self._api_key = api_key
        self._timeout_seconds = timeout_seconds
        self._purpose = purpose
        self._transport = transport or _urlopen_transport
        self._clock = clock
        self._resting_until: dict[str, float] = {}

    def complete(
        self, build_payload: Callable[[str], dict[str, Any]]
    ) -> tuple[dict[str, Any], str]:
        """Returns the response body and the model that produced it.
        Raises ProviderError only when every model failed."""
        last_error: ProviderError | None = None
        for model in self._candidates():
            try:
                body = self._post(model, build_payload(model))
            except _ModelUnavailable as exc:
                last_error = exc.error
                continue
            if model != self._models[0]:
                # Model names only: never the prompt or the reply.
                logger.warning(
                    "groq %s served by reserve model %s (main: %s)",
                    self._purpose,
                    model,
                    self._models[0],
                )
            else:
                logger.info("groq %s served by %s", self._purpose, model)
            return body, model
        raise last_error or ProviderError("No Groq model is configured")

    def _candidates(self) -> list[str]:
        now = self._clock()
        available = [m for m in self._models if self._resting_until.get(m, 0.0) <= now]
        # All resting: a real attempt beats a certain failure.
        return available or list(self._models)

    def _post(self, model: str, payload: dict[str, Any]) -> dict[str, Any]:
        http_request = request.Request(
            url=self._url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self._api_key}",
                # Cloudflare (in front of Groq's API) blocks urllib's default
                # "Python-urllib/x.y" user agent outright (HTTP 403, error
                # code 1010) — any identifiable client string satisfies it.
                "User-Agent": "VetApp/1.0",
            },
            method="POST",
        )
        is_reserve = model != self._models[0]
        try:
            return self._transport(http_request, self._timeout_seconds)
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            failure = ProviderError(
                f"Groq {self._purpose} request failed with status {exc.code}: {detail}"
            )
            if exc.code == 429:
                daily = bool(_DAILY_LIMIT.search(detail))
                self._resting_until[model] = self._clock() + (
                    DAILY_LIMIT_COOLDOWN_SECONDS if daily else SHORT_LIMIT_COOLDOWN_SECONDS
                )
                logger.warning(
                    "groq %s: model %s rate limited (%s limit)",
                    self._purpose,
                    model,
                    "daily" if daily else "short-term",
                )
                raise _ModelUnavailable(failure) from exc
            if exc.code in _TRANSIENT_STATUSES or (
                is_reserve and exc.code in _RESERVE_SKIP_STATUSES
            ):
                logger.warning(
                    "groq %s: model %s failed with status %s", self._purpose, model, exc.code
                )
                raise _ModelUnavailable(failure) from exc
            raise failure from exc
        except error.URLError as exc:
            raise ProviderError(f"Unable to reach Groq API: {exc.reason}") from exc
        except TimeoutError as exc:
            raise ProviderError(f"Groq {self._purpose} request timed out") from exc


class _ModelUnavailable(Exception):
    """This model cannot answer now; the next one may."""

    def __init__(self, error: ProviderError) -> None:
        super().__init__(str(error))
        self.error = error

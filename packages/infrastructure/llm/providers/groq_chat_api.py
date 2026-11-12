"""Groq chat-completions call with a reserve of models.

Found 2026-10-05: Groq's daily token limit is per MODEL, and on reaching
it every request fails with HTTP 429 until the 24-hour window moves on —
the whole chat answered "servizio non disponibile" for hours. So when the
configured model is rate limited, the next model in a configurable list
is tried, and the limited one is left alone for a while instead of being
hit again on every message.

Since build 32 the order of the models can also come from the shared
daily budget (llm_budget.py): a model past its reserve share goes last,
an exhausted one is skipped, and a "per day" 429 is reported back so
every server instance learns of it at once.

Shared by the text client and the vision client.
"""

from __future__ import annotations

import json
import logging
import math
import re
import time
from collections.abc import Callable
from typing import Any, Protocol
from urllib import error, request

from packages.shared.errors.base import ProviderError

logger = logging.getLogger(__name__)

# After a daily limit there is no point retrying the same model for a
# while; a per-minute limit clears quickly. Used when the 429 body gives
# no "try again in" time of its own.
DAILY_LIMIT_COOLDOWN_SECONDS = 600.0
SHORT_LIMIT_COOLDOWN_SECONDS = 30.0
MAX_COOLDOWN_SECONDS = 24 * 3600.0

# The server is in trouble with this model right now: try the next one,
# without remembering it.
_TRANSIENT_STATUSES = frozenset({500, 502, 503, 504})
# A reserve model can be retired or reject a parameter the main one
# accepts: that must not take the chat down either.
_RESERVE_SKIP_STATUSES = frozenset({400, 413, 422})
# A model that does not exist on this account (retired, renamed, or never
# offered: 2026-10-14 the light model was missing on the evaluation
# account) is skipped whatever its place in the chain, and left alone for
# the rest of the day rather than asked again on every message.
_MISSING_MODEL_STATUS = 404

_DAILY_LIMIT = re.compile(r"per day|\(TPD\)|\(RPD\)", re.IGNORECASE)
# Groq's 429 body: "... Please try again in 5m32.4s." / "in 1h2m3s" / "in 850ms".
_TRY_AGAIN = re.compile(r"try again in\s+([0-9hms\.]+)", re.IGNORECASE)

Transport = Callable[[request.Request, int], dict[str, Any]]


class ModelAvailability(Protocol):
    """The shared budget's view of the models (see LlmBudget)."""

    def order(self, models: list[str]) -> list[str]: ...

    def note_rate_limited(
        self, model: str, *, daily: bool, retry_after_seconds: int | None
    ) -> None: ...


def split_models(value: str) -> list[str]:
    """ "a, b,,c" -> ["a", "b", "c"] (a comma-separated environment value)."""
    return [model.strip() for model in value.split(",") if model.strip()]


def parse_retry_after(detail: str) -> int | None:
    """Seconds from Groq's "try again in 1h2m3.5s"; None when absent."""
    match = _TRY_AGAIN.search(detail)
    if match is None:
        return None
    text = match.group(1)
    total = 0.0
    for amount, unit in re.findall(r"([0-9]+(?:\.[0-9]+)?)(h|ms|m|s)", text):
        value = float(amount)
        total += {"h": 3600.0, "m": 60.0, "s": 1.0, "ms": 0.001}[unit] * value
    if total <= 0:
        return None
    return max(1, math.ceil(total))


def _urlopen_transport(http_request: request.Request, timeout: int) -> dict[str, Any]:
    with request.urlopen(http_request, timeout=timeout) as response:
        body: dict[str, Any] = json.loads(response.read().decode("utf-8"))
    return body


class GroqChatApi:
    """Posts a chat completion, moving down `models` when one is limited.

    `models[0]` is the configured model; the rest are the reserve, in
    order. Which models are resting after a 429 is remembered in this
    process (per server instance) and, through `availability`, in the
    shared budget for the other instances.
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
        availability: ModelAvailability | None = None,
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
        self._availability = availability
        self._resting_until: dict[str, float] = {}
        # Models this account does not have (404): remembered for the day.
        self._missing: set[str] = set()

    @property
    def models(self) -> list[str]:
        return list(self._models)

    def complete(
        self,
        build_payload: Callable[[str], dict[str, Any]],
        *,
        timeout_seconds: int | None = None,
    ) -> tuple[dict[str, Any], str]:
        """Returns the response body and the model that produced it.
        Raises ProviderError only when every model failed (QuotaExhausted
        when the shared budget says none can answer today)."""
        last_error: ProviderError | None = None
        timeout = timeout_seconds or self._timeout_seconds
        for model in self._candidates():
            try:
                body = self._post(model, build_payload(model), timeout)
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
        models = self._models
        if self._availability is not None:
            # May raise QuotaExhausted: nothing can answer today.
            models = self._availability.order(models)
        now = self._clock()
        available = [m for m in models if self._resting_until.get(m, 0.0) <= now]
        if available:
            return available
        if all(m in self._missing for m in models):
            # Nothing to wait for: no model of this chain exists on the
            # account. Said at once, without another round trip.
            raise ProviderError(
                f"Groq {self._purpose}: none of {', '.join(models)} is available on this account"
            )
        # All resting: a real attempt beats a certain failure.
        return list(models)

    def _post(self, model: str, payload: dict[str, Any], timeout: int) -> dict[str, Any]:
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
            return self._transport(http_request, timeout)
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            failure = ProviderError(
                f"Groq {self._purpose} request failed with status {exc.code}: {detail}"
            )
            if exc.code == 429:
                daily = bool(_DAILY_LIMIT.search(detail))
                retry_after = parse_retry_after(detail)
                cooldown = (
                    float(retry_after)
                    if retry_after is not None
                    else (DAILY_LIMIT_COOLDOWN_SECONDS if daily else SHORT_LIMIT_COOLDOWN_SECONDS)
                )
                self._resting_until[model] = self._clock() + min(cooldown, MAX_COOLDOWN_SECONDS)
                logger.warning(
                    "groq %s: model %s rate limited (%s limit)%s",
                    self._purpose,
                    model,
                    "daily" if daily else "short-term",
                    f", retry in {retry_after}s" if retry_after is not None else "",
                )
                if self._availability is not None:
                    self._availability.note_rate_limited(
                        model, daily=daily, retry_after_seconds=retry_after
                    )
                raise _ModelUnavailable(failure) from exc
            if exc.code == _MISSING_MODEL_STATUS:
                self._resting_until[model] = self._clock() + MAX_COOLDOWN_SECONDS
                self._missing.add(model)
                logger.warning(
                    "groq %s: model %s is not available on this account (404)",
                    self._purpose,
                    model,
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

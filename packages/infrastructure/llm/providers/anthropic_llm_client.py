"""Claude as the chat's model, through the official `anthropic` SDK (owner
decision 2026-11-07: Claude Haiku 5.5 answers the owners; since 2026-11-25
it is the only provider, with no reserve).

What leaves for the provider is the system prompt and the user prompt the
orchestrator already passed through `_anonymize_for_provider`. What this
client adds or withholds:

* no `temperature`, `top_p` or `top_k`: Haiku 5.5 refuses non-default
  sampling parameters with a 400 (the port's `temperature` is ignored);
* `output_config.effort`: ANTHROPIC_EFFORT for the answers the owner
  reads, ANTHROPIC_EFFORT_LIGHT for the mechanical calls (classifier,
  keywords, extraction), whose thinking is switched off altogether: a
  60-token JSON verdict must not be spent on reasoning;
* adaptive thinking stays on for the answers, so the visible budget the
  caller asked for gets ANTHROPIC_THINKING_HEADROOM_TOKENS on top: the
  reasoning tokens count against `max_tokens`;
* the stable part of the system prompt (the first `cacheable_system_chars`
  of it) is its own block marked for the prompt cache; the rest is a
  second cached block, so an identical variable part also hits;
* usage is counted whole: input + cache writes + cache reads as prompt
  tokens (cache reads also as `cached_prompt_tokens`, cache writes also as
  `cache_write_tokens`: the spending guard prices each part), output tokens
  (reasoning included) as completion tokens;
* a `json_mode` call with a `json_schema` uses structured outputs; without
  one, or when the schema is refused, the JSON instruction goes in words;
* `stop_reason: refusal` (the provider's safety classifiers) raises
  LLMRefusal: a decision, not an outage;
* every SDK error becomes a ProviderError that names the status only,
  never the response body or the prompt; a deadline the caller set
  (every call the owner waits for) is honoured without SDK retries, for the
  whole call: one more attempt only inside it, and only when asked
  (`second_attempt`).
"""

from __future__ import annotations

import logging
import time
from typing import Any

import anthropic

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMRefusal,
    LLMResponse,
)
from packages.core.application.ports.model_availability import ModelAvailability
from packages.shared.config.settings import Settings
from packages.shared.errors.base import PaidCall, ProviderError

logger = logging.getLogger("vetgpt.llm.anthropic")

PROVIDER_NAME = "anthropic"
# Every request is processed in the United States (owner and regulatory
# session, 2026-11-10): the medical record consent v5 says so, so the setting defaults to "us"
# and must stay there. "global", the API default, would let Anthropic
# process elsewhere and make the consent text untrue (docs/compliance/03,
# "Che cosa dirà la v5", point 1). Request parameter `inference_geo`
# (anthropic SDK 2.6.0, Messages.create); US-only inference is billed at
# 1.1x the standard rate.
# The value comes from settings.anthropic_inference_geo (default "us" on this
# branch), the same one the spending guard prices with (pricing.py).
# The least reasoning room an answer gets, whatever the environment says: at 600 the
# reasoning cut 19 answers of 63 in the middle of a word, and spent the whole budget of
# others before a single word (collaudo, 23/11/2026).
MIN_THINKING_HEADROOM_TOKENS = 1200
# Below this many seconds left of the caller's deadline, no second attempt is started.
MIN_SECONDS_FOR_A_SECOND_WRITING = 3
# The pause before the second attempt after a failure that came at once.
_PAUSE_SECONDS = 0.4
JSON_ONLY_INSTRUCTION = "\n\nReply with one JSON object only: no other text, no code fence."
_FINISH_REASONS = {"end_turn": "stop", "stop_sequence": "stop", "max_tokens": "length"}


class _BudgetSpentOnReasoning(ProviderError):
    """The whole token budget went on reasoning: not a word to show the owner."""

    def __init__(self, paid: PaidCall) -> None:
        super().__init__("Anthropic spent the whole token budget before writing")
        self.paid_calls = (paid,)


def _deadline(seconds: float) -> anthropic.Timeout:
    """[seconds] for the whole call. A bare number is the time of EACH phase (connecting, then
    reading): thirty seconds could become sixty (owner's rule, 25/11/2026: 20 s at most)."""
    connect = min(2.0, seconds / 3)
    return anthropic.Timeout(connect=connect, read=seconds - connect, write=connect, pool=connect)


def _came_at_once(exc: anthropic.APIError) -> bool:
    """A failure worth a second attempt: the provider overloaded or failing, a dropped
    connection. Not a timeout (the time is gone), not a refused request."""
    if isinstance(exc, anthropic.APITimeoutError):
        return False
    if isinstance(exc, anthropic.APIConnectionError):
        return True
    return isinstance(exc, anthropic.APIStatusError) and (
        exc.status_code >= 500 or exc.status_code in (408, 409, 429)
    )


def split_system_prompt(system_prompt: str, cacheable_chars: int) -> tuple[str, str]:
    """(stable prefix, variable rest). With no usable split point the whole
    prompt is the stable part: it is still identical between calls most
    of the time and the cache decides."""
    if 0 < cacheable_chars < len(system_prompt):
        return system_prompt[:cacheable_chars], system_prompt[cacheable_chars:]
    return system_prompt, ""


def _cached_block(text: str) -> dict[str, Any]:
    return {"type": "text", "text": text, "cache_control": {"type": "ephemeral"}}


def _provider_error(exc: anthropic.APIError) -> ProviderError:
    # Status and kind only: the body may echo the prompt.
    if isinstance(exc, anthropic.APITimeoutError):
        return ProviderError("Anthropic request timed out")
    if isinstance(exc, anthropic.APIConnectionError):
        return ProviderError("Anthropic connection failed")
    if isinstance(exc, anthropic.APIStatusError):
        return ProviderError(f"Anthropic request failed with status {exc.status_code}")
    return ProviderError("Anthropic request failed")


class AnthropicLLMClient(LLMClient):
    def __init__(
        self,
        settings: Settings,
        *,
        client: Any | None = None,
        availability: ModelAvailability | None = None,
    ) -> None:
        self._settings = settings
        self._availability = availability
        # One retry on the SDK's side for ordinary calls (a transient 5xx or
        # a dropped connection); none when the caller set a deadline.
        self._client = client or anthropic.Anthropic(
            api_key=settings.anthropic_api_key,
            timeout=settings.anthropic_timeout_seconds,
            max_retries=1,
        )

    @property
    def model(self) -> str:
        return self._settings.anthropic_model

    def model_for(self, req: LLMGenerationRequest) -> str:
        """The strong class (plan "fratello maggiore") goes to the more capable
        model; everything else to the configured one. Same payload, same
        anonymised input, same region for both."""
        if req.model_class == "strong":
            return self._settings.anthropic_model_strong
        return self._settings.anthropic_model

    def generate(self, req: LLMGenerationRequest) -> LLMResponse:
        if self._availability is not None:
            # Past its daily budget the model is left alone (QuotaExhausted).
            self._availability.order([self.model_for(req)])
        started = time.monotonic()
        try:
            return self._generate(req)
        except _BudgetSpentOnReasoning as spent:
            # Written again at once with no reasoning: 13 answers of a round had been lost,
            # after six seconds, for nothing more than this.
            left = None
            if req.timeout_seconds is not None:
                left = int(req.timeout_seconds - (time.monotonic() - started))
            no_time = left is not None and left < MIN_SECONDS_FOR_A_SECOND_WRITING
            if req.without_reasoning or req.model_class == "light" or no_time:
                raise
            logger.warning(
                "anthropic: the reasoning spent the token budget of a %s call; written again",
                req.purpose,
            )
            try:
                second = self._generate(
                    req.model_copy(update={"without_reasoning": True, "timeout_seconds": left})
                )
            except ProviderError as failed:
                failed.paid_calls = spent.paid_calls + failed.paid_calls
                raise
            # Both calls were paid: the usage counts them together.
            first = spent.paid_calls[0]
            return second.model_copy(
                update={
                    "prompt_tokens": second.prompt_tokens + first.prompt_tokens,
                    "completion_tokens": second.completion_tokens + first.completion_tokens,
                    "cached_prompt_tokens": second.cached_prompt_tokens
                    + first.cached_prompt_tokens,
                    "cache_write_tokens": second.cache_write_tokens + first.cache_write_tokens,
                    "token_count": second.token_count
                    + first.prompt_tokens
                    + first.completion_tokens,
                }
            )

    def _generate(self, req: LLMGenerationRequest) -> LLMResponse:
        started = time.monotonic()
        try:
            return self._attempt(req, started)
        except anthropic.APIError as exc:
            left = self._left(req, started)
            if (
                not req.second_attempt
                or left is None
                or left - _PAUSE_SECONDS < MIN_SECONDS_FOR_A_SECOND_WRITING
                or not _came_at_once(exc)
            ):
                raise _provider_error(exc) from exc
            logger.warning(
                "anthropic: %s for a %s call; tried once more", type(exc).__name__, req.purpose
            )
            time.sleep(_PAUSE_SECONDS)
            try:
                return self._attempt(req, started)
            except anthropic.APIError as again:
                raise _provider_error(again) from again

    @staticmethod
    def _left(req: LLMGenerationRequest, started: float) -> float | None:
        if req.timeout_seconds is None:
            return None
        return req.timeout_seconds - (time.monotonic() - started)

    def _within(self, req: LLMGenerationRequest, started: float) -> Any:
        """The client with what is left of the caller's deadline."""
        left = self._left(req, started)
        if left is None:
            return self._client
        return self._client.with_options(timeout=_deadline(max(0.5, left)), max_retries=0)

    def _attempt(self, req: LLMGenerationRequest, started: float) -> LLMResponse:
        body = self.payload(req, structured=True)
        try:
            message = self._within(req, started).messages.create(**body)
        except anthropic.BadRequestError as exc:
            if "format" not in body["output_config"]:
                raise
            # The schema was not accepted: the same call, the JSON asked
            # for in words (the callers parse the object out of the text).
            logger.warning(
                "anthropic: structured output refused (status %s) for %s; retrying in words",
                exc.status_code,
                req.purpose,
            )
            message = self._within(req, started).messages.create(
                **self.payload(req, structured=False)
            )
        return self._response(message, req)

    def payload(self, req: LLMGenerationRequest, *, structured: bool) -> dict[str, Any]:
        settings = self._settings
        light = req.model_class == "light"
        no_thinking = light or req.without_reasoning
        stable, variable = split_system_prompt(req.system_prompt, req.cacheable_system_chars)
        use_schema = bool(req.json_mode and structured and req.json_schema)
        if req.json_mode and not use_schema:
            variable += JSON_ONLY_INSTRUCTION
        system = [_cached_block(part) for part in (stable, variable) if part.strip()]
        output_config: dict[str, Any] = {
            "effort": settings.anthropic_effort_light if light else settings.anthropic_effort
        }
        if use_schema:
            output_config["format"] = {"type": "json_schema", "schema": req.json_schema}
        body: dict[str, Any] = {
            "model": self.model_for(req),
            "max_tokens": (
                req.max_tokens
                if no_thinking
                else req.max_tokens
                + max(MIN_THINKING_HEADROOM_TOKENS, settings.anthropic_thinking_headroom_tokens)
            ),
            "messages": [{"role": "user", "content": req.user_prompt}],
            "output_config": output_config,
            "inference_geo": self._settings.anthropic_inference_geo,
        }
        if system:
            body["system"] = system
        if no_thinking:
            # Accepted at effort high or below; never at xhigh/max
            # (settings.py keeps the light effort within that range).
            body["thinking"] = {"type": "disabled"}
        return body

    def _response(self, message: Any, req: LLMGenerationRequest) -> LLMResponse:
        stop = message.stop_reason
        if stop == "refusal":
            details = getattr(message, "stop_details", None)
            category = getattr(details, "category", None) or "unspecified"
            logger.warning(
                "anthropic: the model declined a %s call (category %s)", req.purpose, category
            )
            raise LLMRefusal(f"Anthropic declined the request ({category})")
        text = "".join(
            block.text for block in message.content if getattr(block, "type", None) == "text"
        ).strip()
        usage = message.usage
        cache_read = int(getattr(usage, "cache_read_input_tokens", 0) or 0)
        cache_creation = int(getattr(usage, "cache_creation_input_tokens", 0) or 0)
        prompt_tokens = int(usage.input_tokens or 0) + cache_creation + cache_read
        completion_tokens = int(usage.output_tokens or 0)
        finish = _FINISH_REASONS.get(stop or "", stop)
        if not text and finish == "length":
            # Nothing to show the owner: written again with no reasoning (generate).
            raise _BudgetSpentOnReasoning(
                PaidCall(
                    model=str(getattr(message, "model", "") or self.model_for(req)),
                    prompt_tokens=prompt_tokens,
                    completion_tokens=completion_tokens,
                    cached_prompt_tokens=cache_read,
                    cache_write_tokens=cache_creation,
                )
            )
        return LLMResponse(
            content=text,
            provider=PROVIDER_NAME,
            model=str(getattr(message, "model", "") or self.model_for(req)),
            token_count=prompt_tokens + completion_tokens,
            finish_reason=finish,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            cached_prompt_tokens=cache_read,
            cache_write_tokens=cache_creation,
        )

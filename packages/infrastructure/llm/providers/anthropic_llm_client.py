"""Claude as the chat's model, through the official `anthropic` SDK (owner
decision 2026-11-07: Claude Haiku 5.5 answers the owners; Groq stays as
the automatic reserve, see reserve_llm_client.py).

What leaves for the provider is exactly what left for Groq: the system
prompt, the user prompt the orchestrator already passed through
`_anonymize_for_provider`. What this client adds or withholds:

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
  LLMRefusal: a decision, not an outage, so the reserve is not asked;
* every SDK error becomes a ProviderError that names the status only,
  never the response body or the prompt; a deadline the caller set
  (urgency classifier, urgent answer) is honoured without SDK retries.
"""

from __future__ import annotations

import logging
from typing import Any

import anthropic

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMRefusal,
    LLMResponse,
)
from packages.infrastructure.llm.providers.groq_chat_api import ModelAvailability
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.llm.anthropic")

PROVIDER_NAME = "anthropic"
JSON_ONLY_INSTRUCTION = "\n\nReply with one JSON object only: no other text, no code fence."
_FINISH_REASONS = {"end_turn": "stop", "stop_sequence": "stop", "max_tokens": "length"}


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

    def generate(self, req: LLMGenerationRequest) -> LLMResponse:
        if self._availability is not None:
            # Past its daily budget the model is left alone (QuotaExhausted):
            # the reserve, when there is one, takes the call.
            self._availability.order([self.model])
        client = self._client
        if req.timeout_seconds is not None:
            client = client.with_options(timeout=req.timeout_seconds, max_retries=0)
        body = self.payload(req, structured=True)
        try:
            message = client.messages.create(**body)
        except anthropic.BadRequestError as exc:
            if "format" not in body["output_config"]:
                raise _provider_error(exc) from exc
            # The schema was not accepted: the same call, the JSON asked
            # for in words (the callers parse the object out of the text).
            logger.warning(
                "anthropic: structured output refused (status %s) for %s; retrying in words",
                exc.status_code,
                req.purpose,
            )
            try:
                message = client.messages.create(**self.payload(req, structured=False))
            except anthropic.APIError as retry_exc:
                raise _provider_error(retry_exc) from retry_exc
        except anthropic.APIError as exc:
            raise _provider_error(exc) from exc
        return self._response(message, req)

    def payload(self, req: LLMGenerationRequest, *, structured: bool) -> dict[str, Any]:
        settings = self._settings
        light = req.model_class == "light"
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
            "model": settings.anthropic_model,
            "max_tokens": (
                req.max_tokens
                if light
                else req.max_tokens + max(0, settings.anthropic_thinking_headroom_tokens)
            ),
            "messages": [{"role": "user", "content": req.user_prompt}],
            "output_config": output_config,
        }
        if system:
            body["system"] = system
        if light:
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
            # The whole budget went on reasoning: nothing to show the owner,
            # and the reserve may still answer in time.
            raise ProviderError("Anthropic spent the whole token budget before writing")
        return LLMResponse(
            content=text,
            provider=PROVIDER_NAME,
            model=str(getattr(message, "model", "") or self.model),
            token_count=prompt_tokens + completion_tokens,
            finish_reason=finish,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            cached_prompt_tokens=cache_read,
            cache_write_tokens=cache_creation,
        )

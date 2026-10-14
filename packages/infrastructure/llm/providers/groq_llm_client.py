import re
from typing import Any

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.infrastructure.llm.providers.groq_chat_api import (
    GroqChatApi,
    ModelAvailability,
    Transport,
    split_models,
)
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

# Some reasoning models write their chain of thought inline, between these
# tags, before the answer. It must never reach the owner.
_THINKING = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)

# openai/gpt-oss-* models on Groq are reasoning models with no cap on how
# much of max_tokens they spend on internal chain-of-thought before
# writing the visible answer. Confirmed live: at the default effort, a
# moderately complex case consumed 1198 of a 1200-token budget on
# reasoning alone, leaving nothing to write — empty content, finish_reason
# "length". "low" keeps reasoning short; the headroom below (a setting)
# is added on top of the visible budget the caller asked for.
_REASONING_FAMILY_PREFIX = "openai/gpt-oss"


def is_reasoning_model(model: str) -> bool:
    return model.startswith(_REASONING_FAMILY_PREFIX)


class GroqLLMClient(LLMClient):
    """Two chains of models: the main one (LLM_MODEL, then LLM_FALLBACK_MODELS)
    for the answers the owner reads, and the light one (LLM_MODEL_LIGHT, then
    LLM_LIGHT_FALLBACK_MODELS) for mechanical work — each model on Groq has
    its own daily quota, so moving the small jobs to a small model leaves
    the main quota to the answers. When one chain is rate limited the next
    model in it is tried — see GroqChatApi."""

    def __init__(
        self,
        settings: Settings,
        *,
        transport: Transport | None = None,
        availability: ModelAvailability | None = None,
    ) -> None:
        self._settings = settings
        self._reasoning_headroom = max(0, settings.llm_reasoning_headroom_tokens)
        self._main = GroqChatApi(
            base_url=settings.llm_base_url,
            api_key=settings.llm_api_key,
            timeout_seconds=settings.llm_timeout_seconds,
            models=[settings.llm_model, *split_models(settings.llm_fallback_models)],
            purpose="chat",
            transport=transport,
            availability=availability,
        )
        light_models = [
            settings.llm_model_light,
            *split_models(settings.llm_light_fallback_models),
        ]
        if settings.llm_model_light.strip():
            self._light: GroqChatApi | None = GroqChatApi(
                base_url=settings.llm_base_url,
                api_key=settings.llm_api_key,
                timeout_seconds=settings.llm_timeout_seconds,
                models=light_models,
                purpose="chat-light",
                transport=transport,
                availability=availability,
            )
        else:
            self._light = None

    @property
    def main_models(self) -> list[str]:
        return self._main.models

    @property
    def light_models(self) -> list[str]:
        return self._light.models if self._light is not None else self._main.models

    def generate(self, req: LLMGenerationRequest) -> LLMResponse:
        def payload(model: str) -> dict[str, Any]:
            body: dict[str, Any] = {
                "model": model,
                "messages": [
                    # The system prompt first and unchanged between calls:
                    # Groq caches a stable prefix (gpt-oss models, 2026-10)
                    # and charges the cached part half. Variable parts
                    # (pet, history, date) live in the user message.
                    {"role": "system", "content": req.system_prompt},
                    {"role": "user", "content": req.user_prompt},
                ],
                "temperature": req.temperature,
                "max_tokens": req.max_tokens,
            }
            if is_reasoning_model(model):
                # Sent to this family only: another model may reject a
                # field it does not know.
                body["reasoning_effort"] = "low"
                body["max_tokens"] = req.max_tokens + self._reasoning_headroom
            if req.json_mode:
                body["response_format"] = {"type": "json_object"}
            return body

        api = (
            self._light if (req.model_class == "light" and self._light is not None) else self._main
        )
        body, model = api.complete(payload, timeout_seconds=req.timeout_seconds)

        choices = body.get("choices") or []
        if not choices:
            raise ProviderError("Groq response did not contain any choices")

        message = choices[0].get("message", {})
        usage = body.get("usage") or {}
        details = usage.get("prompt_tokens_details") or {}
        return LLMResponse(
            content=_THINKING.sub("", message.get("content") or "").strip(),
            provider=self._settings.llm_provider,
            model=body.get("model", model),
            token_count=int(usage.get("total_tokens", 0) or 0),
            finish_reason=choices[0].get("finish_reason"),
            prompt_tokens=int(usage.get("prompt_tokens", 0) or 0),
            completion_tokens=int(usage.get("completion_tokens", 0) or 0),
            cached_prompt_tokens=int(details.get("cached_tokens", 0) or 0),
        )

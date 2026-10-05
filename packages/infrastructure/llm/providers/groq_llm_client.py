import re
from typing import Any

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.infrastructure.llm.providers.groq_chat_api import (
    GroqChatApi,
    Transport,
    split_models,
)
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

# Some reasoning models write their chain of thought inline, between these
# tags, before the answer. It must never reach the owner.
_THINKING = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)


class GroqLLMClient(LLMClient):
    """The configured model first; when it is rate limited (Groq's daily
    limit is per model), the models in LLM_FALLBACK_MODELS, in order — see
    GroqChatApi."""

    def __init__(self, settings: Settings, *, transport: Transport | None = None) -> None:
        self._settings = settings
        self._api = GroqChatApi(
            base_url=settings.llm_base_url,
            api_key=settings.llm_api_key,
            timeout_seconds=settings.llm_timeout_seconds,
            models=[settings.llm_model, *split_models(settings.llm_fallback_models)],
            purpose="chat",
            transport=transport,
        )

    def generate(self, req: LLMGenerationRequest) -> LLMResponse:
        def payload(model: str) -> dict[str, Any]:
            body: dict[str, Any] = {
                "model": model,
                "messages": [
                    {"role": "system", "content": req.system_prompt},
                    {"role": "user", "content": req.user_prompt},
                ],
                "temperature": req.temperature,
                "max_tokens": req.max_tokens,
            }
            if model.startswith("openai/gpt-oss"):
                # openai/gpt-oss-* models on Groq are reasoning models with no
                # cap on how much of max_tokens they spend on internal
                # chain-of-thought before writing the visible answer.
                # Confirmed live: at the default effort, a moderately
                # complex case consumed 1198 of a 1200-token budget on
                # reasoning alone, leaving nothing to write — empty content,
                # finish_reason "length", regardless of how high max_tokens
                # was raised. "low" keeps reasoning short enough that a
                # normal-length answer reliably still fits in the budget.
                # Sent to this family only: another model may reject a
                # field it does not know.
                body["reasoning_effort"] = "low"
            return body

        body, model = self._api.complete(payload)

        choices = body.get("choices") or []
        if not choices:
            raise ProviderError("Groq response did not contain any choices")

        message = choices[0].get("message", {})
        usage = body.get("usage", {})
        return LLMResponse(
            content=_THINKING.sub("", message.get("content") or "").strip(),
            provider=self._settings.llm_provider,
            model=body.get("model", model),
            token_count=int(usage.get("total_tokens", 0)),
            finish_reason=choices[0].get("finish_reason"),
        )

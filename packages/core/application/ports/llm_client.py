from typing import Protocol

from pydantic import BaseModel


class LLMGenerationRequest(BaseModel):
    system_prompt: str
    user_prompt: str
    temperature: float = 0.2
    max_tokens: int = 600
    # Why the call is made ("answer", "situation_model", "urgency_classifier",
    # ...): recorded with the usage of every call, never sent to the provider.
    purpose: str = "answer"
    # "main": the configured model, for the answer the owner reads. "light":
    # a smaller model with its own (larger) daily quota, for mechanical work
    # — extraction, keywords, classification. A provider without a light
    # model serves both from the main one.
    model_class: str = "main"
    # The reply must be a JSON object; the provider enforces it when it can.
    json_mode: bool = False
    # A deadline shorter than the provider's default, for calls that must
    # not hold the answer up (the urgency classifier). None = the default.
    timeout_seconds: int | None = None


class LLMResponse(BaseModel):
    content: str
    provider: str
    model: str
    token_count: int
    finish_reason: str | None = None
    # From the provider's usage report when it gives one (Groq does); the
    # cached count is the part of the prompt served from its prompt cache.
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cached_prompt_tokens: int = 0


class LLMClient(Protocol):
    def generate(self, request: LLMGenerationRequest) -> LLMResponse: ...

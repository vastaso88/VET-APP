from typing import Any, Protocol

from pydantic import BaseModel

from packages.shared.errors.base import ProviderError


class LLMGenerationRequest(BaseModel):
    system_prompt: str
    user_prompt: str
    temperature: float = 0.2
    max_tokens: int = 600
    # Why the call is made ("answer", "situation_model", "urgency_classifier",
    # ...): recorded with the usage of every call, never sent to the provider.
    purpose: str = "answer"
    # "main": the configured model, for the answer the owner reads. "light":
    # mechanical work — extraction, keywords, classification — where the
    # provider writes at once, with no reasoning (Claude: the same model).
    # "strong": the occasional more capable model (Claude Sonnet, plan
    # "fratello maggiore"), when the provider has one; the others serve it
    # from the main model.
    model_class: str = "main"
    # The reply must be a JSON object; the provider enforces it when it can.
    json_mode: bool = False
    # A deadline shorter than the provider's default, for calls that must
    # not hold the answer up (the urgency classifier). None = the default.
    timeout_seconds: int | None = None
    # Within timeout_seconds, once more after a failure that came at once (overloaded, a
    # dropped connection). Never after a timeout: the time is gone.
    second_attempt: bool = False
    # Write at once, with no reasoning first: a second attempt after a reply whose
    # reasoning spent the token budget (collaudo, wave 0). A provider that cannot switch
    # reasoning off ignores it.
    without_reasoning: bool = False
    # The first N characters of system_prompt are the same for every owner
    # and every call of this kind: a provider with a prompt cache marks
    # them as the cacheable prefix. 0 = treat the whole prompt as stable.
    cacheable_system_chars: int = 0
    # With json_mode, the JSON schema of the expected object: a provider
    # with structured outputs enforces it; the others ask for JSON in words.
    json_schema: dict[str, Any] | None = None


class LLMResponse(BaseModel):
    content: str
    provider: str
    model: str
    token_count: int
    finish_reason: str | None = None
    # From the provider's usage report; the cached count is the part of the
    # prompt served from its prompt cache.
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cached_prompt_tokens: int = 0
    # The part of prompt_tokens written to the provider's prompt cache (Claude
    # reports it; priced above plain input, so the spending guard needs it).
    cache_write_tokens: int = 0


class LLMRefusal(ProviderError):
    """The provider's own safety classifiers declined the request (Claude:
    `stop_reason: refusal`). A decision, not an outage: nobody else is asked
    the same thing and the owner gets a fixed, safe reply."""


class LLMClient(Protocol):
    def generate(self, request: LLMGenerationRequest) -> LLMResponse: ...

from typing import Protocol

from pydantic import BaseModel


class LLMGenerationRequest(BaseModel):
    system_prompt: str
    user_prompt: str
    temperature: float = 0.2
    max_tokens: int = 600


class LLMResponse(BaseModel):
    content: str
    provider: str
    model: str
    token_count: int
    finish_reason: str | None = None


class LLMClient(Protocol):
    def generate(self, request: LLMGenerationRequest) -> LLMResponse: ...

"""Stand-ins for the model client, shared by the free-tier tests (build 32)."""

from __future__ import annotations

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.domain.llm_usage.models import estimate_tokens


class RecordingLLMClient:
    """Records every request; answers by purpose when told to, otherwise
    with a fixed text. A purpose mapped to an exception raises it."""

    def __init__(
        self,
        answer: str = "Risposta di prova, concreta e breve.",
        *,
        by_purpose: dict[str, str | Exception] | None = None,
        model: str = "fake-model",
    ) -> None:
        self.answer = answer
        self.by_purpose = dict(by_purpose or {})
        self.model = model
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        outcome = self.by_purpose.get(request.purpose, self.answer)
        if isinstance(outcome, Exception):
            raise outcome
        prompt_tokens = estimate_tokens(request.system_prompt + request.user_prompt)
        completion_tokens = estimate_tokens(outcome)
        return LLMResponse(
            content=outcome,
            provider="fake",
            model=self.model,
            token_count=prompt_tokens + completion_tokens,
            finish_reason="stop",
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
        )

    def requests_for(self, purpose: str) -> list[LLMGenerationRequest]:
        return [request for request in self.requests if request.purpose == purpose]

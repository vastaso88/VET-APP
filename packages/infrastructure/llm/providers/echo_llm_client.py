from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.core.domain.llm_usage.models import estimate_tokens
from packages.shared.config.settings import Settings

# Matches EvidenceSynthesizer.SYNTHESIS_MARKER — the zero-cost demo/test
# provider still needs to return something that caller can actually parse
# as JSON, not the generic echoed-prompt text every other caller gets
# (SituationModelBuilder's extraction already tolerates unparseable
# content by falling back to an empty SituationModel).
_SYNTHESIS_MARKER = "performing evidence synthesis"

_DEMO_SYNTHESIS_JSON = (
    '{"supported_claims": ["Le fonti disponibili indicano di osservare i sintomi '
    'e mantenere idratazione e riposo [1]."], "uncertain_claims": [], '
    '"conflicting_evidence": [], "evidence_gaps": [], '
    '"safe_owner_actions": ["offri acqua fresca e tieni un ambiente tranquillo"], '
    '"monitoring_points": ["appetito ed energia nelle prossime 24 ore"], '
    '"referral_conditions": ["i sintomi peggiorano o persistono oltre 48 ore"]}'
)

# The structured helpers (build 32) get a neutral, parseable answer too:
# the stand-in must never look like an emergency or invent keywords.
_DEMO_BY_PURPOSE = {
    "urgency_classifier": '{"level": "normal", "category": null}',
    "evidence_query": '{"keywords": []}',
}


class EchoLLMClient(LLMClient):
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        if _SYNTHESIS_MARKER in request.system_prompt:
            content = _DEMO_SYNTHESIS_JSON
        elif request.purpose in _DEMO_BY_PURPOSE:
            content = _DEMO_BY_PURPOSE[request.purpose]
        else:
            content = f"Demo reply for: {request.user_prompt}"
        prompt_tokens = estimate_tokens(request.system_prompt + request.user_prompt)
        completion_tokens = estimate_tokens(content)
        return LLMResponse(
            content=content,
            provider=self._settings.llm_provider,
            model=self._settings.llm_model,
            token_count=len(content.split()),
            finish_reason="stop",
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
        )

from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.shared.config.settings import Settings

# Matches EvidenceSynthesizer.SYNTHESIS_SYSTEM_PROMPT — the zero-cost
# demo/test provider still needs to return something that caller can
# actually parse as JSON, not the generic echoed-prompt text every other
# caller gets (SituationModelBuilder's extraction already tolerates
# unparseable content by falling back to an empty SituationModel).
_SYNTHESIS_MARKER = "performing evidence synthesis"

_DEMO_SYNTHESIS_JSON = (
    '{"supported_claims": ["Le fonti disponibili indicano di osservare i sintomi '
    'e mantenere idratazione e riposo [1]."], "uncertain_claims": [], '
    '"conflicting_evidence": [], "evidence_gaps": [], '
    '"safe_owner_actions": ["offri acqua fresca e tieni un ambiente tranquillo"], '
    '"monitoring_points": ["appetito ed energia nelle prossime 24 ore"], '
    '"referral_conditions": ["i sintomi peggiorano o persistono oltre 48 ore"]}'
)


class EchoLLMClient(LLMClient):
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        if _SYNTHESIS_MARKER in request.system_prompt:
            content = _DEMO_SYNTHESIS_JSON
        else:
            content = f"Demo reply for: {request.user_prompt}"
        return LLMResponse(
            content=content,
            provider=self._settings.llm_provider,
            model=self._settings.llm_model,
            token_count=len(content.split()),
            finish_reason="stop",
        )

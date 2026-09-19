from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.evidence_synthesizer import EvidenceSynthesizer


class ScriptedClient:
    def __init__(self, content: str) -> None:
        self._content = content
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content=self._content, provider="fake", model="fake-model", token_count=10
        )


def test_parses_a_valid_synthesis() -> None:
    content = (
        '{"supported_claims": ["La febbre nei cani richiede osservazione [1]."], '
        '"uncertain_claims": [], "conflicting_evidence": [], "evidence_gaps": [], '
        '"safe_owner_actions": ["Offri acqua fresca"], "monitoring_points": [], '
        '"referral_conditions": ["se la febbre persiste oltre 24 ore"]}'
    )
    synthesizer = EvidenceSynthesizer(ScriptedClient(content))

    synthesis, response = synthesizer.synthesize("Evidence:\n[1] Example source")

    assert synthesis.supported_claims == ["La febbre nei cani richiede osservazione [1]."]
    assert synthesis.safe_owner_actions == ["Offri acqua fresca"]
    assert synthesis.referral_conditions == ["se la febbre persiste oltre 24 ore"]
    assert response.provider == "fake"


def test_returns_empty_synthesis_on_invalid_json() -> None:
    synthesizer = EvidenceSynthesizer(ScriptedClient("not json at all"))

    synthesis, _ = synthesizer.synthesize("Evidence:\n[1] Example source")

    assert synthesis.is_empty()


def test_returns_empty_synthesis_when_payload_is_not_an_object() -> None:
    synthesizer = EvidenceSynthesizer(ScriptedClient("[1, 2, 3]"))

    synthesis, _ = synthesizer.synthesize("Evidence:\n[1] Example source")

    assert synthesis.is_empty()


def test_all_claim_text_joins_every_field() -> None:
    content = (
        '{"supported_claims": ["A [1]"], "uncertain_claims": ["B"], '
        '"conflicting_evidence": ["C"], "evidence_gaps": [], '
        '"safe_owner_actions": [], "monitoring_points": [], "referral_conditions": []}'
    )
    synthesizer = EvidenceSynthesizer(ScriptedClient(content))

    synthesis, _ = synthesizer.synthesize("Evidence:\n[1] Example source")

    assert synthesis.all_claim_text() == "A [1]\nB\nC"

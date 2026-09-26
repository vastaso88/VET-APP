from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.evidence_synthesizer import (
    EvidenceSynthesizer,
    _build_system_prompt,
)


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


def test_system_prompt_forbids_inventing_specific_numbers_not_in_the_evidence() -> None:
    # Real-world finding (stress test round 3): a synthesis stated "at
    # least once a week" for aquarium water-parameter checks, cited to a
    # source that only said "periodically" — a specific-sounding figure
    # the evidence never actually gave. validate_answer() only checks
    # citation-index mechanics, not whether the cited text really supports
    # the number, so the fix has to be in the instruction the model
    # follows, not a new mechanical check.
    prompt = _build_system_prompt("it")

    assert "specific number" in prompt
    assert "inventing one" in prompt


def test_system_prompt_forbids_multiplying_a_per_individual_figure_by_a_group_count() -> None:
    # Real-world finding: asked for tank size for TWO goldfish, the model
    # doubled a single-fish minimum (75-115L -> "150L for two") — hedged as
    # uncertain, but real group housing/stocking requirements are not
    # generally linear in individual count, so an unsupported
    # multiplication can look precise while being a poor estimate.
    prompt = _build_system_prompt("it")

    assert "multiplying a per-individual figure" in prompt

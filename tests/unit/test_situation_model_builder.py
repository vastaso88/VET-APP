from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.domain.situation.models import SituationModel


class FakeExtractionLLMClient:
    def __init__(self, content: str) -> None:
        self._content = content
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content=self._content, provider="fake", model="fake-model", token_count=5
        )


def test_update_merges_valid_json_extraction() -> None:
    client = FakeExtractionLLMClient(
        '{"presenting_problem": "vomito", "onset": "da ieri", "contexts": ["dopo i pasti"]}'
    )
    builder = SituationModelBuilder(client)

    updated = builder.update(SituationModel(), "Il mio cane vomita da ieri dopo i pasti", [])

    assert updated.presenting_problem == "vomito"
    assert updated.onset == "da ieri"
    assert updated.contexts == ["dopo i pasti"]
    assert client.requests


def test_update_falls_back_to_unchanged_model_on_malformed_json() -> None:
    client = FakeExtractionLLMClient("Demo reply for: not json at all")
    builder = SituationModelBuilder(client)
    current = SituationModel(presenting_problem="prurito")

    updated = builder.update(current, "altro messaggio", [])

    assert updated == current


def test_update_ignores_non_object_json() -> None:
    client = FakeExtractionLLMClient("[1, 2, 3]")
    builder = SituationModelBuilder(client)
    current = SituationModel(presenting_problem="prurito")

    updated = builder.update(current, "altro messaggio", [])

    assert updated == current

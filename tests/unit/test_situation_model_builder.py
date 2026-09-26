from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.domain.situation.models import SituationModel
from packages.shared.errors.base import ProviderError


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


def test_update_requests_enough_tokens_to_avoid_empty_completions() -> None:
    # Real-world finding: a reasoning model can spend its entire token
    # budget on internal reasoning and return a completely empty
    # completion (finish_reason "length") for a detailed case — the old
    # 600-token default silently discarded every field, every time, on
    # anything but a trivial message.
    client = FakeExtractionLLMClient("{}")
    builder = SituationModelBuilder(client)

    builder.update(SituationModel(), "Il mio cane vomita da ieri", [])

    assert client.requests[0].max_tokens >= 1200


def test_update_degrades_to_unchanged_model_on_provider_failure() -> None:
    class FailingClient:
        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            raise ProviderError("rate limited")

    builder = SituationModelBuilder(FailingClient())
    current = SituationModel(presenting_problem="prurito")

    updated = builder.update(current, "altro messaggio", [])

    assert updated == current


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

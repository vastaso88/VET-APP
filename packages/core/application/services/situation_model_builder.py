import json

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.situation.models import SituationModel

SITUATION_EXTRACTION_SYSTEM_PROMPT = (
    "You extract structured case information from a veterinary chat message. "
    "Reply with ONLY a compact JSON object (no prose, no markdown) matching this shape: "
    '{"presenting_problem": string|null, "onset": string|null, "contexts": [string], '
    '"observed_behaviours": [string], "associated_signs": [string], '
    '"known_medical_context": string|null, "environmental_changes": [string], '
    '"working_domains": [string], "known_facts": [string], "relevant_unknowns": [string], '
    '"safety_critical_unknowns": [string]}. '
    "Use null or [] for anything not actually mentioned. Never invent information."
)


class SituationModelBuilder:
    """Updates the per-conversation SituationModel from the latest user message
    (spec v3 §10). Extraction is delegated to the LLM; merging the extracted
    fields into the running model is deterministic (see SituationModel.merge).
    """

    def __init__(self, llm_client: LLMClient) -> None:
        self._llm_client = llm_client

    def update(
        self,
        current: SituationModel,
        user_message: str,
        conversation_history: list[ChatMessage],
    ) -> SituationModel:
        history_block = "\n".join(
            f"{entry.role}: {entry.content}" for entry in conversation_history[-6:]
        )
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=SITUATION_EXTRACTION_SYSTEM_PROMPT,
                user_prompt=(
                    f"Situation known so far: {current.model_dump_json()}\n"
                    f"Recent conversation:\n{history_block}\n"
                    f"New message: {user_message}"
                ),
            )
        )
        extracted = self._parse(response.content)
        return current.merge(extracted)

    @staticmethod
    def _parse(content: str) -> SituationModel:
        try:
            payload = json.loads(content)
        except (json.JSONDecodeError, TypeError):
            return SituationModel()
        if not isinstance(payload, dict):
            return SituationModel()
        try:
            return SituationModel.model_validate(payload)
        except Exception:
            return SituationModel()

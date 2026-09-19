import json

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.situation.models import SituationModel
from packages.shared.errors.base import ProviderError

SITUATION_EXTRACTION_SYSTEM_PROMPT = (
    "You extract structured case information from a veterinary chat message. "
    "Reply with ONLY a compact JSON object (no prose, no markdown) matching this shape: "
    '{"presenting_problem": string|null, "onset": string|null, "contexts": [string], '
    '"observed_behaviours": [string], "associated_signs": [string], '
    '"known_medical_context": string|null, "environmental_changes": [string], '
    '"working_domains": [string], "known_facts": [string], "relevant_unknowns": [string], '
    '"safety_critical_unknowns": [string]}. '
    "Use null or [] for anything not actually mentioned. Never invent information. "
    "working_domains entries MUST each be exactly one of: clinical_question, "
    "nutrition_question, behavior_question, preventive_care — never a free-text label "
    "like 'gastroenterology' or 'dermatology', even if more descriptive; the caller "
    "matches these values against a fixed set and an unrecognized one is ignored. "
    "Keep observed_behaviours and associated_signs distinct: observed_behaviours is "
    "what the animal does that IS the presenting complaint itself (e.g. 'si gratta "
    "l'orecchio', 'tossisce dopo aver bevuto'); associated_signs is a review of "
    "OTHER systems not already covered by the complaint — appetite, thirst, energy "
    "level, urination/defecation — whether normal or changed, only if the owner "
    "actually addressed it. environmental_changes is anything recent that could be "
    "a trigger: a diet change, a move, a new animal or person in the household, "
    "travel, a change in routine."
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
        try:
            response = self._llm_client.generate(
                LLMGenerationRequest(
                    system_prompt=SITUATION_EXTRACTION_SYSTEM_PROMPT,
                    user_prompt=(
                        f"Situation known so far: {current.model_dump_json()}\n"
                        f"Recent conversation:\n{history_block}\n"
                        f"New message: {user_message}"
                    ),
                    # A reasoning model can spend its entire token budget on
                    # internal reasoning before writing any output when the
                    # case has a lot to extract (long history, detailed
                    # message) — the previous 600-token default then
                    # returned a completely empty completion (finish_reason
                    # "length"), which silently discarded every field,
                    # including presenting_problem, turn after turn.
                    max_tokens=1500,
                )
            )
        except ProviderError:
            # Degrade to "nothing new extracted this turn" rather than
            # crashing the whole chat turn — the interview loop simply
            # asks again next time, same fail-safe posture as every other
            # LLM call site in the pipeline.
            return current
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

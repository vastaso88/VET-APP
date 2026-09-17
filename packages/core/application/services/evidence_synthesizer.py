import json

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest, LLMResponse
from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis

# The distinctive phrase EchoLLMClient (and any other test double) can key
# off to recognize this call and return a small valid synthesis instead of
# its generic demo text — mirrors how SituationModelBuilder's extraction
# prompt is recognized ("extract structured case information").
SYNTHESIS_SYSTEM_PROMPT = (
    "You are an evidence-first veterinary assistant performing evidence synthesis. "
    "Use ONLY the provided Evidence list — never latent knowledge. Reply with ONLY a "
    "compact JSON object (no prose, no markdown) matching this shape: "
    '{"supported_claims": [string], "uncertain_claims": [string], '
    '"conflicting_evidence": [string], "evidence_gaps": [string], '
    '"safe_owner_actions": [string], "monitoring_points": [string], '
    '"referral_conditions": [string]}. '
    "Cite the evidence a claim rests on with a [n] marker matching the numbered "
    "Evidence list below — never invent a citation, and never include a [n] marker "
    "on a claim from evidence_gaps, safe_owner_actions, or monitoring_points ("
    "general safe guidance, not literature-specific claims). Put a claim in "
    "supported_claims only when the cited evidence directly backs it; if evidence is "
    "thin, contradictory, or merely suggestive, it belongs in uncertain_claims or "
    "conflicting_evidence instead. Leave any list empty ([]) rather than padding it. "
    "Write every string in the user's language."
)


class EvidenceSynthesizer:
    """Turns retrieved evidence + the case into a structured synthesis
    (spec v3 §27) instead of one undifferentiated LLM paragraph."""

    def __init__(self, llm_client: LLMClient) -> None:
        self._llm_client = llm_client

    def synthesize(self, user_prompt: str) -> tuple[EvidenceSynthesis, LLMResponse]:
        """Returns the parsed synthesis alongside the raw LLMResponse, so
        the caller can still report which provider/model produced it."""
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=SYNTHESIS_SYSTEM_PROMPT,
                user_prompt=user_prompt,
                # The structured JSON (up to 7 populated lists) needs more
                # room than the single free-text paragraph this replaced —
                # the previous 600-token default silently truncated it into
                # invalid JSON, which parsed as an empty (thus rejected)
                # synthesis every time.
                max_tokens=1200,
            )
        )
        return self._parse(response.content), response

    @staticmethod
    def _parse(content: str) -> EvidenceSynthesis:
        try:
            payload = json.loads(content)
        except (json.JSONDecodeError, TypeError):
            return EvidenceSynthesis()
        if not isinstance(payload, dict):
            return EvidenceSynthesis()
        try:
            return EvidenceSynthesis.model_validate(payload)
        except Exception:
            return EvidenceSynthesis()

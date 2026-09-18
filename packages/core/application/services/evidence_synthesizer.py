import json

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest, LLMResponse
from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis

# The distinctive phrase EchoLLMClient (and any other test double) can key
# off to recognize this call and return a small valid synthesis instead of
# its generic demo text — mirrors how SituationModelBuilder's extraction
# prompt is recognized ("extract structured case information").
SYNTHESIS_MARKER = "performing evidence synthesis"

# spec v3 §31: the core engine reads this instead of hardcoding "Italian",
# so a future locale is a config change — see Settings.response_language.
LANGUAGE_NAMES: dict[str, str] = {"it": "Italian", "en": "English"}


def _build_system_prompt(response_language: str) -> str:
    language = LANGUAGE_NAMES.get(response_language, response_language)
    return (
        f"You are an evidence-first veterinary assistant {SYNTHESIS_MARKER}. "
        "Use ONLY the provided Evidence list — never latent knowledge. Reply with ONLY a "
        "compact JSON object (no prose, no markdown) matching this shape: "
        '{"supported_claims": [string], "uncertain_claims": [string], '
        '"conflicting_evidence": [string], "evidence_gaps": [string], '
        '"safe_owner_actions": [string], "monitoring_points": [string], '
        '"referral_conditions": [string]}. '
        f"CRITICAL LANGUAGE RULE: every single string in that JSON must be written "
        f"entirely in {language}, with no exceptions. The Evidence list below is "
        f"typically in English — when a claim rests on English-language evidence, "
        f"translate the clinical content into {language} yourself; never copy or "
        f"lightly paraphrase a source sentence verbatim in its original language. A "
        f"string that mixes languages or is not in {language} is invalid output. "
        "Cite the evidence a claim rests on with a [n] marker matching the numbered "
        "Evidence list below — never invent a citation, and never include a [n] marker "
        "on a claim from evidence_gaps, safe_owner_actions, or monitoring_points ("
        "general safe guidance, not literature-specific claims). Put a claim in "
        "supported_claims only when the cited evidence directly backs it; if evidence is "
        "thin, contradictory, or merely suggestive, it belongs in uncertain_claims or "
        "conflicting_evidence instead. Leave any list empty ([]) rather than padding it. "
        f"Reminder: EVERY string must be in {language}, translated, never quoted "
        "verbatim from English evidence."
    )


class EvidenceSynthesizer:
    """Turns retrieved evidence + the case into a structured synthesis
    (spec v3 §27) instead of one undifferentiated LLM paragraph."""

    def __init__(self, llm_client: LLMClient, *, response_language: str = "it") -> None:
        self._llm_client = llm_client
        self._system_prompt = _build_system_prompt(response_language)

    def synthesize(self, user_prompt: str) -> tuple[EvidenceSynthesis, LLMResponse]:
        """Returns the parsed synthesis alongside the raw LLMResponse, so
        the caller can still report which provider/model produced it."""
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=self._system_prompt,
                user_prompt=user_prompt,
                # The structured JSON (up to 7 populated lists) needs more
                # room than the single free-text paragraph this replaced —
                # the previous 600-token default silently truncated it into
                # invalid JSON, which parsed as an empty (thus rejected)
                # synthesis every time. GroqLLMClient's reasoning_effort=low
                # fixes the main failure mode (the reasoning model spending
                # the whole budget on invisible chain-of-thought), but how
                # much of the budget it uses still varies sample to sample —
                # a live case that came back with genuinely empty content
                # even with reasoning_effort=low at 1200 tokens is the
                # reason for this extra headroom, not a theoretical margin.
                max_tokens=2000,
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

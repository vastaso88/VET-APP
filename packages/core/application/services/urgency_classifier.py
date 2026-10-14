"""The second guardian: a small model reads the message for an emergency the
fixed word lists did not catch — in any language, any wording.

The lists (SafetyGate, emergency_patterns.py) stay the floor: they run
first, cost nothing and never fail. This runs after them and before the
answer, on the light model, with a short prompt and a short deadline:

* "emergency" -> the same fixed triage reply the lists produce;
* "maybe"     -> one clarifying question, then the usual resolution;
* "normal", no answer in time, or anything unreadable -> the ordinary
  answer goes ahead (fail open, logged). A classifier outage must never
  silence the chat.
"""

from __future__ import annotations

import json
import logging
import re

from pydantic import BaseModel

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.urgency")

URGENCY_MARKER = "triage messages that pet owners send"

# The categories the fixed triage knows (triage_clarification.py), plus
# "other" for an emergency that fits none of them.
CATEGORIES: tuple[str, ...] = (
    "respiratory",
    "collapse",
    "seizure",
    "bleeding_trauma",
    "urinary",
    "gi_stasis",
    "toxin_medication",
    "gastric_bloat",
    "circulatory",
    "other",
)
LEVELS = ("emergency", "maybe", "normal")

SYSTEM_PROMPT = (
    f"You {URGENCY_MARKER} to a pet-care app, in any language. Decide only how urgent "
    "the situation is RIGHT NOW. Reply with ONLY a JSON object: "
    '{"level": "emergency" | "maybe" | "normal", "category": string | null}.\n'
    "emergency: the owner describes something happening to their animal now that needs a "
    "vet within minutes to a few hours — not breathing well, collapse or unconsciousness, "
    "a seizure, heavy or unstoppable bleeding, a serious injury, a swallowed poison, toxic "
    "food or human medicine, a swollen hard belly with retching, pale, white or blue gums, "
    "straining without passing urine, a rabbit or small rodent that stopped eating or "
    "passing droppings, heatstroke, severe pain.\n"
    "maybe: it could be one of those but the message is too vague to tell.\n"
    "normal: everything else — questions, curiosities, mild or long-standing problems, "
    "documents, behaviour, feeding, care. Do not call it an emergency because a serious "
    "word appears in a question ('is chocolate dangerous?' is normal; 'he just ate "
    "chocolate' is emergency).\n"
    "category, when level is not normal, is one of: " + ", ".join(CATEGORIES) + "."
)

_OBJECT = re.compile(r"\{.*\}", re.DOTALL)


class UrgencyVerdict(BaseModel):
    level: str
    category: str | None = None


class UrgencyClassifier:
    def __init__(
        self,
        llm_client: LLMClient,
        *,
        timeout_seconds: int = 6,
    ) -> None:
        self._llm_client = llm_client
        self._timeout_seconds = timeout_seconds

    def classify(self, message: str, species: str) -> UrgencyVerdict | None:
        """None when the classifier could not say (deadline, outage, nonsense):
        the caller goes on as if it had said "normal"."""
        try:
            response = self._llm_client.generate(
                LLMGenerationRequest(
                    system_prompt=SYSTEM_PROMPT,
                    user_prompt=f"Species: {species}\nMessage: {message[:1500]}",
                    temperature=0.0,
                    max_tokens=60,
                    purpose="urgency_classifier",
                    model_class="light",
                    json_mode=True,
                    timeout_seconds=self._timeout_seconds,
                )
            )
        except ProviderError as exc:
            logger.warning("urgency classifier unavailable (%s): answering normally", exc)
            return None
        verdict = self.parse(response.content)
        if verdict is None:
            logger.warning("urgency classifier gave no readable verdict: answering normally")
        return verdict

    @staticmethod
    def parse(content: str) -> UrgencyVerdict | None:
        match = _OBJECT.search(content or "")
        if match is None:
            return None
        try:
            payload = json.loads(match.group(0))
        except json.JSONDecodeError:
            return None
        if not isinstance(payload, dict):
            return None
        level = str(payload.get("level", "")).strip().lower()
        if level not in LEVELS:
            return None
        category = payload.get("category")
        category = str(category).strip().lower() if category else None
        if level == "normal":
            return UrgencyVerdict(level=level)
        return UrgencyVerdict(level=level, category=category if category in CATEGORIES else "other")

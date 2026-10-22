import json
import logging
import re

from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.consent")

_SHORT_YES = {"si", "sì", "sí", "yes", "ok", "okay"}
_SHORT_NO = {"no"}

# Longer, distinctive phrases are safe to match anywhere in the message.
# Bare "si"/"no" are NOT included here — as substrings they'd false-positive
# on ordinary words ("nome", "nostro", "sicuro", ...), so they're only
# checked as the reply's first word below.
AFFIRMATIVE_PHRASES = (
    "go ahead",
    "i agree",
    "please consult",
    "of course",
    "de acuerdo",
    "consulta el historial",
    "por supuesto",
    "certo",
    "va bene",
    "d'accordo",
    "daccordo",
    "perfetto",
    "va bè",
    "vabbè",
    "consulta pure",
    "consultala",
    "fai pure",
)

NEGATIVE_PHRASES = (
    "do not consult",
    "don't consult",
    "i don't want",
    "rather not",
    "no quiero",
    "prefiero que no",
    "no consultes",
    "no hace falta",
    "non voglio",
    "preferisco di no",
    "meglio di no",
    "non serve",
    "lascia stare",
    "non consultare",
)

CONSENT_MARKER = "reading a pet owner's answer to a consent question"
_OBJECT = re.compile(r"\{.*\}", re.DOTALL)


class ConsentInterpreter:
    """Reads a yes/no answer to a consent question out of free text (spec v3
    §18: consent must be recorded in structured form).

    The fixed phrases decide first, deterministically. Only when they say
    nothing, and a light model is configured, is the model asked — and it
    counts only when it answers with an explicit, confident "yes" or "no".
    Everything else is None, which the caller treats as "not granted"
    (fail closed): uncertainty about consent must never be read as
    permission.
    """

    def __init__(self, llm_client: LLMClient | None = None) -> None:
        self._llm_client = llm_client

    def interpret(self, message: str) -> bool | None:
        lowered = message.strip().lower().strip(".,!?")
        if not lowered:
            return None

        first_word = lowered.split()[0].strip(".,!?") if lowered.split() else ""
        if first_word in _SHORT_NO:
            return False
        if first_word in _SHORT_YES:
            return True

        if any(phrase in lowered for phrase in NEGATIVE_PHRASES):
            return False
        if any(phrase in lowered for phrase in AFFIRMATIVE_PHRASES):
            return True
        return self._ask_model(message)

    def _ask_model(self, message: str) -> bool | None:
        if self._llm_client is None:
            return None
        try:
            response = self._llm_client.generate(
                LLMGenerationRequest(
                    system_prompt=(
                        f"You are {CONSENT_MARKER}: may the app read the pet's medical "
                        "records for this chat? Reply with ONLY a JSON object "
                        '{"answer": "yes" | "no" | "unclear"}. Say "yes" only for a '
                        "clear, unconditional agreement; a condition, a question back, "
                        'a joke or anything else is "unclear".'
                    ),
                    user_prompt=f"Owner's reply: {message[:500]}",
                    temperature=0.0,
                    max_tokens=20,
                    purpose="consent_interpretation",
                    model_class="light",
                    json_mode=True,
                    timeout_seconds=6,
                )
            )
        except ProviderError:
            return None
        match = _OBJECT.search(response.content or "")
        if match is None:
            return None
        try:
            answer = json.loads(match.group(0)).get("answer")
        except (json.JSONDecodeError, AttributeError):
            return None
        if answer == "yes":
            return True
        if answer == "no":
            return False
        return None

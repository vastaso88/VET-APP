_SHORT_YES = {"si", "sì", "ok", "okay"}
_SHORT_NO = {"no"}

# Longer, distinctive phrases are safe to match anywhere in the message.
# Bare "si"/"no" are NOT included here — as substrings they'd false-positive
# on ordinary words ("nome", "nostro", "sicuro", ...), so they're only
# checked as the reply's first word below.
AFFIRMATIVE_PHRASES = (
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
    "non voglio",
    "preferisco di no",
    "meglio di no",
    "non serve",
    "lascia stare",
    "non consultare",
)


class ConsentInterpreter:
    """Deterministically reads a yes/no answer to a consent question out of
    free text (spec v3 §18: consent must be recorded in structured form).

    Returns None when the reply is unclear — the caller must treat that as
    "not granted" (fail closed): uncertainty about consent must never be
    read as permission.
    """

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
        return None

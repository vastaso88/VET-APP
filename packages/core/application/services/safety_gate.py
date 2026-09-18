URGENT_RED_FLAG_KEYWORDS = {
    "convuls",
    "seizure",
    "non respira",
    "respira male",
    "dispnea",
    "emorrag",
    "sanguina",
    "trauma",
    "collasso",
    "collapse",
    "anuria",
    "non urina",
    "incidente",
    # Real-world finding: an owner reporting blood in vomit/stool/urine
    # ("vomito con sangue") is a genuine red flag that "emorrag"/"sanguina"
    # don't catch — but the bare word "sangue" is NOT safe to add on its
    # own: it also matches routine, already-reassuring mentions of normal
    # bloodwork ("analisi del sangue", "esami del sangue"), which would
    # wrongly escalate a calm statement into urgent triage. These specific
    # phrasings catch the real symptom without that false-positive.
    "sangue nel vomito",
    "vomito con sangue",
    "vomita sangue",
    "sangue nelle feci",
    "feci con sangue",
    "sangue nelle urine",
    "urina con sangue",
    "perde sangue",
}


class SafetyGate:
    """Pre-interview safety check (spec v3 §8-9): must run before any interview
    turn, and be re-run whenever the situation changes, not only once at the end.
    """

    def evaluate(self, message: str) -> list[str]:
        lowered = message.lower()
        return [keyword for keyword in URGENT_RED_FLAG_KEYWORDS if keyword in lowered]

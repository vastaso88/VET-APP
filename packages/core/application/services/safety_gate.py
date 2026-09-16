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
}


class SafetyGate:
    """Pre-interview safety check (spec v3 §8-9): must run before any interview
    turn, and be re-run whenever the situation changes, not only once at the end.
    """

    def evaluate(self, message: str) -> list[str]:
        lowered = message.lower()
        return [keyword for keyword in URGENT_RED_FLAG_KEYWORDS if keyword in lowered]

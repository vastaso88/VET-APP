"""THE definition of the pet's body condition ("corporatura"), five levels.

The profile stores the language-independent code (`pet_profiles.body_condition`,
text with a CHECK on these codes); each weighing stores the level 1..5
(`pet_weight_measurements.body_condition`, smallint). Both are the same scale,
thinnest to heaviest; the app mirrors it in `BodyCondition`
(apps/mobile_app/lib/features/monitoring/domain/body_condition.dart).
"""

BODY_CONDITIONS = ("very_thin", "thin", "normal", "slightly_overweight", "overweight")

# What the chat model reads for each code.
_PROMPT_LABEL = {
    "very_thin": "very thin",
    "thin": "thin",
    "normal": "normal",
    "slightly_overweight": "slightly overweight",
    "overweight": "overweight",
}


def body_condition_code(score: int | None) -> str | None:
    """Code of a stored weighing level (1..5); None when missing or out of range."""
    if score is None or not 1 <= score <= len(BODY_CONDITIONS):
        return None
    return BODY_CONDITIONS[score - 1]


def body_condition_score(code: str | None) -> int | None:
    """Level (1..5) of a profile code; None when missing or unknown."""
    if code not in BODY_CONDITIONS:
        return None
    return BODY_CONDITIONS.index(code) + 1


def body_condition_prompt_label(code: str | None) -> str | None:
    """The wording the chat model reads, None for a missing or unknown code."""
    return _PROMPT_LABEL.get(code or "")


def species_has_body_condition(species: str | None, breed: str | None = None) -> bool:
    """Whether a species has a body condition at all.

    Only the species with a published assessment guide do (dogs and cats:
    WSAVA; rabbits, a breed of "Piccoli mammiferi"): for every other one the
    app neither asks for nor shows a "corporatura", so the chat must not read
    an old value either. Mirrors `bodyConditionGuideForSpecies` in the app
    (monitoring/domain/body_condition_guide.dart).
    """
    name = (species or "").strip().lower()
    if name in ("cane", "gatto"):
        return True
    return name == "piccoli mammiferi" and (breed or "").strip().lower().startswith("coniglio")

"""Optional physical/identification details of a pet (2026-10-14).

Stored as language-independent codes; the app translates them for display.
`describe_for_prompt` is what the chat may know: neutering, body condition
and activity level only. The microchip number is an identifier and the coat
colour adds nothing to health advice, so neither goes to the LLM.
"""

import re

BODY_CONDITIONS = ("very_thin", "thin", "normal", "slightly_overweight", "overweight")
ACTIVITY_LEVELS = ("sedentary", "normal", "active")

_BODY_CONDITION_PROMPT = {
    "very_thin": "very thin",
    "thin": "thin",
    "normal": "normal",
    "slightly_overweight": "slightly overweight",
    "overweight": "overweight",
}
_ACTIVITY_PROMPT = {"sedentary": "sedentary", "normal": "normal", "active": "active"}

# ISO 11784/11785 microchips are 15 digits.
_MICROCHIP_RE = re.compile(r"^\d{15}$")


def normalize_microchip(value: str | None) -> str | None:
    """Digits only (spaces and dashes in a pasted number are dropped); None when empty."""
    if value is None:
        return None
    digits = re.sub(r"[\s-]", "", value)
    return digits or None


def is_valid_microchip(value: str | None) -> bool:
    """A missing microchip is valid (the field is optional); otherwise 15 digits."""
    normalized = normalize_microchip(value)
    return normalized is None or bool(_MICROCHIP_RE.match(normalized))


def validated_microchip(value: str | None) -> str | None:
    """Pydantic field validator body: the normalized number, or ValueError."""
    if not is_valid_microchip(value):
        raise ValueError("microchip_number must be 15 digits (ISO 11784)")
    return normalize_microchip(value)


def describe_for_prompt(
    *, neutered: bool | None, body_condition: str | None, activity_level: str | None
) -> list[str]:
    """Prompt lines for the details the owner filled in (none for unknown values)."""
    lines = []
    if neutered is not None:
        lines.append(f"Neutered/spayed: {'yes' if neutered else 'no'}")
    condition = _BODY_CONDITION_PROMPT.get(body_condition or "")
    if condition:
        lines.append(f"Body condition (owner's estimate): {condition}")
    activity = _ACTIVITY_PROMPT.get(activity_level or "")
    if activity:
        lines.append(f"Activity level: {activity}")
    return lines

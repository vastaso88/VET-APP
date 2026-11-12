"""Optional physical/identification details of a pet (2026-10-14).

Stored as language-independent codes; the app translates them for display.
`describe_for_prompt` is what the chat may know: neutering, body condition
and activity level only. The microchip number is an identifier and the coat
colour adds nothing to health advice, so neither goes to the LLM.
"""

import re

from packages.core.domain.pet_profile.body_condition import body_condition_prompt_label

ACTIVITY_LEVELS = ("sedentary", "normal", "active")

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
    *,
    neutered: bool | None,
    body_condition: str | None,
    activity_level: str | None,
    body_condition_as_of: str | None = None,
) -> list[str]:
    """Prompt lines for the details the owner filled in (none for unknown values).

    One body condition only: when it comes from a weighing, `body_condition_as_of`
    is that weighing's date ("14 ottobre") and the line says so; otherwise it is
    the owner's own estimate from the profile."""
    lines = []
    if neutered is not None:
        lines.append(f"Neutered/spayed: {'yes' if neutered else 'no'}")
    condition = body_condition_prompt_label(body_condition)
    if condition:
        source = (
            f"weighed on {body_condition_as_of}" if body_condition_as_of else "owner's estimate"
        )
        lines.append(f"Body condition ({source}): {condition}")
    activity = _ACTIVITY_PROMPT.get(activity_level or "")
    if activity:
        lines.append(f"Activity level: {activity}")
    return lines

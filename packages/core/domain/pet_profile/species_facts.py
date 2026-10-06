"""Verified facts about less common species, handed to the model with the
pet's context.

Only for errors actually observed in the evaluation transcripts
(2026-10-06): the model told an owner that a rabbit eating its own
droppings "is not normal" (caecotrophy is normal and necessary) and
suggested melon and cucumber for a leopard gecko (an insectivore). Kept
short, and extended only when a new error is seen — a long encyclopaedia
in the prompt would cost tokens on every message for nothing.
"""

from __future__ import annotations

_FACTS: tuple[tuple[tuple[str, ...], str], ...] = (
    (
        ("coniglio", "conigli", "rabbit"),
        "Rabbit: eating its own soft droppings (ciecotrofi: dark, shiny, in grape-like "
        "clusters, usually taken straight from the anus, often at night) is NORMAL and "
        "necessary — they are a food, rich in vitamins and proteins; never call it "
        "abnormal. The round dry pellets are the real faeces. Hay is most of the diet; "
        "soft gentle teeth grinding during petting is contentment, loud grinding with a "
        "hunched body is pain. Not eating or not passing droppings for a day is an "
        "emergency.",
    ),
    (
        ("geco leopardino", "geco", "gecko", "eublepharis"),
        "Leopard gecko: strictly insectivorous (crickets, dubia roaches, mealworms, "
        "dusted with calcium/vitamin D3); it does NOT eat fruit or vegetables, so never "
        "suggest them, not even 'for hydration' — water bowl and a humid hide do that. "
        "Crepuscular, no UVB strictly required with proper supplementation. White part "
        "of the droppings is urate (normal). Fasting for a week or two happens (shedding, "
        "season, low temperatures) and is not an alarm by itself without weight loss.",
    ),
)


def species_facts(species: str, breed: str | None = None, notes: str | None = None) -> str:
    """The facts that apply to this pet, or an empty string."""
    haystack = " ".join(part for part in (species, breed or "", notes or "") if part).lower()
    return "\n".join(text for keywords, text in _FACTS if any(k in haystack for k in keywords))

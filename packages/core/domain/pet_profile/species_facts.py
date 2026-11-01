"""Verified facts about the animal's kind, handed to the model with the
pet's context.

Two layers, kept short on purpose (every fact costs tokens on every
message it travels with):

* correction facts, for errors actually observed in the evaluation
  transcripts (2026-10-06: a rabbit eating its own droppings called
  "not normal", melon suggested for a leopard gecko). They travel with
  every message about that animal.
* ethology facts (repositioning, docs/product/11 §4 2.4): how the species
  perceives, communicates and learns, from the positions of the bodies
  the chat prefers (ESVCE, AVSAB, ISFM, RWAF). They travel only with
  direct and behaviour questions, where the "why" is the answer; reports
  and symptoms keep the short prompt.
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

# Family-level ethology, one short paragraph each, with the body whose
# position it states. Matched on the app's species labels and on the
# common names, like the correction facts.
_ETHOLOGY: tuple[tuple[tuple[str, ...], str], ...] = (
    (
        ("cane", "cani", "dog", "perro", "hund", "chien"),
        "Dog ethology (ESVCE and AVSAB position statements): a social animal that learns by "
        "association and by what is rewarded; the 'dominance/alpha' reading of behaviour "
        "problems is rejected, so never explain a behaviour as a bid for rank. A growl is "
        "a warning, not disobedience: punishing it removes the warning, not the emotion. "
        "Calming signals (yawning, lip licking, turning the head away, whale eye) say "
        "the dog is uneasy. Socialisation to people, dogs and places matters most between "
        "3 and 12-14 weeks. Reward-based methods only (AVSAB humane training, 2021).",
    ),
    (
        ("gatto", "gatti", "cat", "gato", "katze", "chat"),
        "Cat ethology (ISFM/AAFP environmental needs guidelines): a solitary hunter that "
        "values territory and predictability over company and communicates by scent "
        "(facial rubbing, scratching, urine marking) and small body signals; scratching "
        "and marking are communication, not spite, so never present them as something to "
        "punish. Key resources (food, water, litter trays, scratching, resting and hiding "
        "places) go one per cat plus one, in separate spots. Purring is not only "
        "contentment: cats also purr when in pain or anxious. Punishment raises fear and "
        "aggression; change the environment and reward instead.",
    ),
    (
        ("coniglio", "conigli", "rabbit", "conejo", "kaninchen", "lapin"),
        "Rabbit ethology (RWAF and RSPCA welfare guidance): a social prey animal that "
        "should live with a bonded companion rabbit and hides fear and illness; freezing, "
        "thumping and a hunched body are stress or pain, not sulking. Being lifted feels "
        "like being caught by a predator, so most rabbits dislike it (never by the ears "
        "or scruff); interact at floor level. Needs space to run and stand upright, "
        "things to dig and gnaw, constant hay. Reward-based handling only.",
    ),
)


def species_facts(
    species: str, breed: str | None = None, notes: str | None = None, *, ethology: bool = False
) -> str:
    """The facts that apply to this pet, or an empty string. `ethology`
    adds the family-level ethology paragraph (direct and behaviour
    questions only)."""
    haystack = " ".join(part for part in (species, breed or "", notes or "") if part).lower()
    layers = (_FACTS, _ETHOLOGY) if ethology else (_FACTS,)
    return "\n".join(
        text for layer in layers for keywords, text in layer if any(k in haystack for k in keywords)
    )

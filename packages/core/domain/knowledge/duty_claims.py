"""A legal obligation is said only when a duty note received for the answer names it (collaudo,
wave 1: "in Italia è obbligatorio che todo animal de compañía esté identificado" for a rabbit,
with no source). Deterministic: the sentence that states an obligation on a duty with no note
for it goes. Sentences that only send the owner to ask are left alone.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from packages.core.domain.knowledge.answer_validation import without_sentences
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# What a note may speak of (the notes are in English) and how the answer says it.
_TOPICS: dict[str, tuple[re.Pattern[str], re.Pattern[str]]] = {
    "identification": (
        re.compile(r"\b(?:microchip\w*|anagrafe|identif\w*|registr\w*)\b"),
        re.compile(
            r"\b(?:microchip\w*|chip\w*|anagrafe\w*|identific\w*|registr\w*|censit\w*|"
            r"inscri\w*|iscri\w*)\b"
        ),
    ),
    "vaccination": (
        re.compile(r"\bvaccin\w*\b|\brabies\b"),
        re.compile(
            r"\b(?:vaccin\w*|antirabbic\w*|antirrabic\w*|rabbia|rabies|rabia|tollwut\w*|"
            r"rage|vacuna\w*|impf\w*)\b"
        ),
    ),
    "parasites": (
        re.compile(r"\b(?:parasit\w*|deworm\w*|echinococc\w*)\b"),
        re.compile(
            r"\b(?:antiparassit\w*|antiparas\w*|parassit\w*|parasit\w*|deworm\w*|tenia|"
            r"sverminazion\w*|entwurm\w*|vermifug\w*|desparasit\w*)\b"
        ),
    ),
    "leash and muzzle": (
        re.compile(r"\b(?:leash|muzzle|museruola)\b"),
        re.compile(
            r"\b(?:guinzagli\w*|museruol\w*|leash\w*|muzzle\w*|correa\w*|bozal\w*|"
            r"leine\w*|maulkorb\w*|laisse\w*|museliere\w*)\b"
        ),
    ),
    "insurance, licence, tax": (
        re.compile(r"\b(?:insur\w*|licen[cs]e\w*|tax\w*)\b"),
        re.compile(
            r"\b(?:assicurazion\w*|licenz\w*|tass[ae]|insuranc\w*|licen[cs]\w*|taxes|"
            r"seguro\w*|licencia\w*|tasas?|impuesto\w*|versicherung\w*|lizenz\w*|"
            r"steuer\w*|assurance\w*|impots?)\b"
        ),
    ),
}
# The sentence states an obligation...
_OBLIGATION = re.compile(
    r"\b(?:obbligator\w*|obbligh?\w*|per legge|la legge (?:prevede|impone|richiede|obbliga)|"
    r"mandatory|compulsory|obligatory|required by law|legally required|by law|"
    r"obligatori\w*|por ley|la ley (?:exige|obliga)|"
    r"vorgeschrieben|gesetzlich|pflicht\w*|verpflicht\w*|"
    r"obligatoires?|par la loi|la loi (?:impose|exige|oblige))\b"
)
# ... unless it says there is no verified rule, or only sends to ask about it.
_NOT_A_CLAIM = re.compile(
    r"\b(?:non (?:ho|abbiamo|c'e|risulta) (?:una |nessuna |alcuna )?(?:regola|fonte|norma|note)|"
    r"non ho una regola verificata|nessuna regola verificata|"
    r"non posso (?:dirti|confermare|affermare)|"
    r"(?:chiedi|verifica|informati|contatta|domanda) |se e obbligator\w*|"
    r"(?:have|there is|found|got) no (?:verified|source)|can't confirm|cannot confirm|"
    r"(?:ask|check with|contact|verify) |whether (?:it is|this is)|"
    r"no tengo (?:una )?(?:regla|fuente)|no hay (?:una )?(?:regla|fuente)|"
    r"(?:pregunta|consulta|confirma|contacta) |si es obligatori\w*|"
    r"keine (?:gepruft\w*|verifiziert\w*|quelle)|(?:fragen|erkundigen|klaren) sie|"
    r"pas de (?:regle|source)|je n'ai pas|demandez|verifiez|renseignez-vous|"
    r"si (?:c'est|il est) obligatoire)"
)


# The EU pet passport is for dogs, cats and ferrets; the app's own travel cards cover only
# those (docs/product/18). For another animal the answer may not speak of one.
_PASSPORT = re.compile(
    r"\b(?:passaport\w*|pasaport\w*|passports?|heimtierausweis\w*|passeports?)\b"
)
_FERRET = re.compile(r"furett\w*|\bferret\w*|\bhuron\w*|frettchen|\bfurets?\b")


def has_no_pet_passport(species_family: str, breed: str | None) -> bool:
    return species_family not in ("dog", "cat") and not _FERRET.search(
        normalize_for_matching(breed or "")
    )


def _claims_a_passport(sentence: str) -> bool:
    text = normalize_for_matching(sentence)
    return bool(_PASSPORT.search(text)) and not _NOT_A_CLAIM.search(text)


def _claims(sentence: str, notes: str) -> bool:
    text = normalize_for_matching(sentence)
    if not _OBLIGATION.search(text) or _NOT_A_CLAIM.search(text):
        return False
    return any(
        in_answer.search(text) and not in_note.search(notes)
        for in_note, in_answer in _TOPICS.values()
    )


def without_unsourced_duties(
    answer: str, note_texts: Iterable[str], *, no_passport: bool = False
) -> str:
    """The answer without the sentences that state an obligation no received note names (and,
    for an animal with no pet passport, without those that speak of one)."""
    notes = normalize_for_matching(" ".join(note_texts))
    return without_sentences(
        answer,
        lambda s: _claims(s, notes) or (no_passport and _claims_a_passport(s)),
    )


def unsourced_duties(
    answer: str, note_texts: Iterable[str], *, no_passport: bool = False
) -> list[str]:
    notes = normalize_for_matching(" ".join(note_texts))
    return [
        sentence
        for sentence in re.split(r"(?<=[.!?;])\s+|\n+", answer)
        if _claims(sentence, notes) or (no_passport and _claims_a_passport(sentence))
    ]

"""Owner duties in Italy, as short curated notes (stress test 2026-11-06).

One note per topic, each under the 300 characters the prompt keeps of an
ordinary source, so the fact the owner asked about reaches the model
whole. Sources: Ministero della Salute (ordinanza on dog ownership,
renewed since 2009), codice penale art. 727, legge 189/2004, legge
157/1992, European Convention for the Protection of Pet Animals.

Served with the awareness notes when the question is about a duty, and
PINNED into the prompt by rule when the question names the topic
(``pinned_duty_notes``): the evidence pipeline runs on keywords a model
writes, and once (fifth round) the breed-list note did not make it.
"""

from __future__ import annotations

import re

from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_DUTY_PREFIX = "Curated note, owner duties in Italy (pending vet review): "

# Owner duties, Italy (stress test 2026-11-06): one short note per topic,
# each under the 300 characters the prompt keeps of a snippet, so the
# fact the owner asked about reaches the model whole. Sources: Ministero
# della Salute (ordinanza on dog ownership, renewed since 2009), codice
# penale art. 727, legge 189/2004, legge 157/1992, European Convention for
# the Protection of Pet Animals.
DUTY_CATALOG: list[EvidenceSource] = [
    EvidenceSource(
        title=_DUTY_PREFIX + "dangerous breeds, leash and muzzle",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="dog",
        snippet=(
            "Italy has NO list of dangerous breeds: the breed list was abolished in 2009 "
            "(ordinanza Ministero della Salute); the single dog and its owner count, who "
            "answers for its behaviour. Leash up to 1.5 m in town, a muzzle (museruola) carried "
            "along. "
            "Current rules: municipality, ASL, vet."
        ),
    ),
    EvidenceSource(
        title=_DUTY_PREFIX + "identification, anagrafe, transfer of puppies",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="dog",
        snippet=(
            "Dogs are identified with a microchip and registered in the anagrafe canina; "
            "puppies are not sold or given away before 60 days of age, and only with "
            "microchip and a written passage of ownership. Selling regularly is a regulated "
            "activity. Current rules: municipality, ASL, vet."
        ),
    ),
    EvidenceSource(
        title=_DUTY_PREFIX + "cruelty: abandonment, fights, mutilations",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="dog",
        snippet=(
            "Abandoning an animal is a crime (art. 727 codice penale), not a fine; organising "
            "or training for dog fights is a crime (legge 189/2004); cosmetic ear cropping "
            "and tail docking are forbidden (European Convention for the Protection of Pet "
            "Animals, in force in Italy)."
        ),
    ),
    EvidenceSource(
        title=_DUTY_PREFIX + "cats: abandonment, microchip, travel",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="cat",
        snippet=(
            "Abandoning a cat is a crime (art. 727 codice penale) and a house cat does not "
            "cope outside. Microchip and anagrafe are compulsory only in some regions, always "
            "needed with the EU pet passport and rabies vaccination to travel in the EU. "
            "Colony cats are protected. Current rules: municipality, ASL, vet."
        ),
    ),
    EvidenceSource(
        title=_DUTY_PREFIX + "wild animals found: never kept, CRAS",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="other",
        snippet=(
            "A wild animal found (hedgehog, fledgling, fox cub, bat) is protected fauna "
            "(legge 157/1992) and is never kept as a pet. If injured or in danger: dark "
            "ventilated box, quiet, no food or milk, call the wildlife rescue centre (CRAS) "
            "or the Carabinieri forestali (1515). If healthy, leave it where it is."
        ),
    ),
]


# Topic roots (accents removed) that pin a note into the prompt.
_PINS: tuple[tuple[re.Pattern[str], str], ...] = (
    (
        re.compile(
            r"razz[ae] pericolos\w*|cani pericolosi|lista (?:delle |di )?razze|razze (?:vietate|"
            r"proibite|a rischio)|dangerous breeds?|banned breeds?|breed list|razas? peligrosas?|"
            r"\bppp\b|listenhund\w*|kampfhund\w*|chiens? dangereux|chien de categorie|"
            r"categorie [12]\b"
        ),
        "dangerous breeds, leash and muzzle",
    ),
    (
        re.compile(
            r"cessione|cedere|vendere i cuccioli|annuncio|cuccioli .{0,30}(?:giorni|settimane|"
            r"mesi)|anagrafe canina|iscri\w* all'anagrafe|sell\w* (?:the )?puppies|rehom\w*|"
            r"vender los cachorros|welpen (?:verkaufen|abgeben)|vendre les chiots"
        ),
        "identification, anagrafe, transfer of puppies",
    ),
    (
        re.compile(
            r"abbandon\w*|lasci\w* (?:in campagna|per strada|in un parcheggio|fuori)|"
            r"non (?:la|lo|li|le) voglio piu|"
            r"liberarl\w* (?:in natura|nel parco|nel laghetto|nel bosco)|"
            r"combattiment\w*|taglio (?:delle |della )?(?:orecchie|coda)|tagliare le "
            r"orecchie|orecchie a punta|caudotomi\w*|conchectomi\w*|abandon\w*|dog ?fight\w*|"
            r"ear cropping|tail docking|peleas? de perros|aussetzen|hundekampf\w*|kupier\w*|"
            r"combats? de chiens|couper les oreilles"
        ),
        "cruelty: abandonment, fights, mutilations",
    ),
    (
        re.compile(
            r"gatt\w* .{0,40}(?:viaggi\w*|passaporto|estero|francia|spagna|germania|microchip|"
            r"abbandon\w*|colonia)|(?:viaggi\w*|passaporto|microchip|colonia felina).{0,40}gatt\w*|"
            r"cat .{0,30}(?:travel|passport|abroad|microchip)|gato .{0,30}(?:viaj\w*|pasaporte)|"
            r"katze .{0,30}(?:reise|heimtierausweis)|chat .{0,30}(?:voyage|passeport)"
        ),
        "cats: abandonment, microchip, travel",
    ),
    (
        re.compile(
            r"ricci[oa]|passerott[oi]|merl[oi]|rondin[ei]|pipistrell[oi]|volp[ei]|capriol[oi]|"
            r"cerbiatt[oi]|scoiattol[oi]|animale selvatico|fauna selvatica|hedgehog|fledgling|"
            r"baby bird|fawn|fox cub|wild animal|erizo|animal salvaje|igel|wildtier|jungvogel|"
            r"herisson|oisillon|animal sauvage"
        ),
        "wild animals found: never kept, CRAS",
    ),
)


def pinned_duty_notes(message: str) -> list[EvidenceSource]:
    """The duty notes whose topic the owner names: always in the prompt,
    whatever the evidence search found."""
    text = normalize_for_matching(message)
    titles = [title for pattern, title in _PINS if pattern.search(text)]
    return [note for note in DUTY_CATALOG if any(note.title.endswith(title) for title in titles)]

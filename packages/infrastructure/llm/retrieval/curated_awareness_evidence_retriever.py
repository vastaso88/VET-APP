"""Curated "understand the species" notes (repositioning, docs/product/11 §4, 2.4).

One note per species family the app knows, each with the four themes the
owner-awareness programmes share: essential ethology, needs, signs of
stress, common mistakes. They are the evidence layer behind behaviour,
relationship and everyday-management questions, where the biomedical
literature (PubMed, Europe PMC...) has little to say and what it says is
tangential.

Access depth "D" and tier "D", like the husbandry notes: written from the
positions of the bodies named in each note (ESVCE, AVSAB, ISFM/iCatCare,
RWAF/RSPCA, FVE/FECAVA, WSAVA), not from a specific paper we can cite
precisely, and marked "pending veterinary review" until the owner (a vet)
has read them: then they become level B. Family level, not breed or
species level: a budgerigar and a grey parrot share the bird note.
"""

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.conversation.request_kind import is_duty_question
from packages.core.domain.knowledge.models import EvidenceSource

_PREFIX = "Curated awareness note (pending vet review): "

AWARENESS_CATALOG: list[EvidenceSource] = [
    EvidenceSource(
        title=_PREFIX + "understanding the dog — ethology, needs, stress signs, common mistakes",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="dog",
        snippet=(
            "Ethology: a social species that reads the human face and body closely and "
            "learns by association and by what gets rewarded; the 'dominance/alpha' model "
            "is rejected by ESVCE and AVSAB (behaviour problems are not status struggles). "
            "Needs (RSPCA five welfare needs): daily exercise and sniffing, social contact, "
            "a quiet resting place, predictable routines, things to chew. Stress signs: "
            "yawning out of context, lip licking, turning the head away, whale eye, "
            "panting at rest, a tucked tail, freezing, displacement scratching. Common "
            "mistakes: punishing growling (it removes the warning, not the emotion), "
            "hugging and face-to-face contact many dogs only tolerate, leaving a puppy "
            "alone for hours without gradual practice, skipping socialisation between "
            "3 and 12-14 weeks, using choke, prong or shock tools (AVSAB humane training "
            "position, 2021: reward-based methods only)."
        ),
    ),
    EvidenceSource(
        title=_PREFIX + "understanding the cat — ethology, needs, stress signs, common mistakes",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="cat",
        snippet=(
            "Ethology: a solitary hunter that lives in groups only when resources allow; "
            "territory and predictability matter more than company; communicates with "
            "scent (facial rubbing, scratching, urine marking) and subtle body signals. "
            "Needs (ISFM/AAFP environmental needs guidelines): a safe place, several "
            "separate key resources (food, water, litter trays, scratching, resting and "
            "hiding places: one per cat plus one, in different spots), play that mimics "
            "hunting, positive and predictable human contact, respect for the sense of "
            "smell. Stress signs: hiding, over-grooming, urinating outside the tray, "
            "flattened ears, tail flicking, dilated pupils, eating less, blocking or "
            "guarding resources in multi-cat homes. Common mistakes: punishing scratching "
            "or marking (they are communication), one litter tray for several cats, trays "
            "next to food, introducing a new cat without a gradual scent-first protocol, "
            "reading purring as always contentment (cats also purr when in pain or "
            "anxious), free-feeding without play."
        ),
    ),
    EvidenceSource(
        title=_PREFIX + "understanding small mammals (rabbit, guinea pig, hamster, rat) — "
        "ethology, needs, stress signs, common mistakes",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="small_mammal",
        snippet=(
            "Ethology: prey animals that hide illness and fear; rabbits and guinea pigs "
            "are social (RWAF and RSPCA: keep rabbits in bonded pairs), Syrian hamsters are "
            "solitary, rats are social and nocturnal-crepuscular. Needs: space to run and "
            "stand upright, hiding places, constant hay for rabbits and guinea pigs "
            "(gnawing and gut motility), vitamin C for guinea pigs, things to gnaw and "
            "dig, a quiet place away from predators' smell and loud noise. Stress signs: "
            "freezing, thumping (rabbit), teeth grinding loud with a hunched body (pain), "
            "over-grooming or barbering, hiding all day, not eating (an emergency within "
            "a day for rabbits and guinea pigs). Common mistakes: picking a rabbit up by "
            "the ears or scruff, keeping a rabbit alone or in a small hutch, muesli-style "
            "mixes instead of pellets plus hay, a wheel with rungs or too small for a "
            "hamster, housing two Syrian hamsters together, bathing small mammals."
        ),
    ),
    EvidenceSource(
        title=_PREFIX + "understanding pet birds (budgerigar, cockatiel, parrots, canary) — "
        "ethology, needs, stress signs, common mistakes",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="bird",
        snippet=(
            "Ethology: highly social flock animals with long memories; parrots are "
            "intelligent and need to work for food; they hide illness until late. Needs: "
            "company (same species where possible, or many hours of interaction), flight "
            "or at least daily out-of-cage time in a safe room, foraging toys, a varied "
            "diet (seed-only diets are a leading cause of disease), 10-12 hours of dark "
            "quiet sleep, bathing. Stress signs: feather plucking, screaming for "
            "attention, repetitive movements, fluffed feathers for long periods, sitting "
            "on the cage floor (late, serious). Common mistakes: a cage too small or round, "
            "a single budgerigar alone all day, covering the cage as punishment, "
            "non-stick cookware fumes and scented candles (toxic to birds), reaching into "
            "the cage with the hand the bird fears, chasing to catch."
        ),
    ),
    EvidenceSource(
        title=_PREFIX + "understanding reptiles and amphibians — ethology, needs, stress "
        "signs, common mistakes",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="reptile_amphibian",
        snippet=(
            "Ethology: ectotherms whose behaviour follows temperature and light; most are "
            "solitary and do not seek handling; activity rhythms (diurnal, crepuscular, "
            "nocturnal) and brumation are normal. Needs: a correct thermal gradient and "
            "UVB where the species needs it, hides at both ends, the right humidity, "
            "substrate the species can use, a photoperiod, calcium and vitamin D3 "
            "supplementation for insectivores. Stress signs: refusing food outside "
            "brumation, glass surfing, hiding constantly, darkened colour, gaping, tail "
            "waving or autotomy, lethargy with weight loss. Common mistakes: handling a "
            "new animal daily, housing two males together, sunlight through a window (no "
            "UVB, overheating), unregulated heat sources (burns), feeding fruit to "
            "insectivores, a tank too small for the adult size, misting without a "
            "hygrometer."
        ),
    ),
    EvidenceSource(
        title=_PREFIX + "understanding aquarium fish — ethology, needs, stress signs, "
        "common mistakes",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="fish",
        snippet=(
            "Ethology: schooling species need groups (six or more), territorial species "
            "need space and sight breaks, bettas fight their own kind; fish learn "
            "feeding times and recognise people. Needs: a cycled tank (nitrogen cycle "
            "before fish), stable water parameters and temperature for the species, "
            "enough volume for the adult size, plants or decor for cover, a regular partial "
            "water change, a day-night cycle. Stress signs: gasping at the surface, "
            "clamped fins, hiding, rubbing on decor, faded colour, not eating, darting. "
            "Common mistakes: adding fish on day one, too many fish for the volume "
            "('one fish per litre' rules do not scale), overfeeding (the first cause of "
            "poor water), full water changes, mixing incompatible temperaments, a bowl "
            "without filter for a goldfish."
        ),
    ),
    EvidenceSource(
        title=_PREFIX + "understanding an animal of another species — the questions that "
        "come first",
        tier="D",
        access_depth="D",
        clinical_domain="behavior",
        species="other",
        snippet=(
            "For a species the app has no dedicated note for (ferret, horse, chicken, "
            "tortoise...), the owner-awareness questions are the same: is it social or "
            "solitary, prey or predator, what does its day look like in the wild (rhythm, "
            "diet, space), what does it do when afraid, which handling does it tolerate. "
            "The five welfare needs (RSPCA): a suitable environment, a suitable diet, "
            "the ability to behave normally, company or solitude as the species needs, "
            "protection from pain, suffering, injury and disease. Point the owner to a "
            "vet experienced with that species for the specifics."
        ),
    ),
]

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

AWARENESS_CATALOG += DUTY_CATALOG


def awareness_sources_for(query: str) -> list[EvidenceSource]:
    """The notes a question may draw on: the duty notes only when the
    question is about a duty (third round, 10: "il gatto deve stare fuori?"
    got the crime of abandonment and the microchip in the answer)."""
    if is_duty_question(query):
        return AWARENESS_CATALOG
    return [source for source in AWARENESS_CATALOG if source not in DUTY_CATALOG]


class CuratedAwarenessEvidenceRetriever(EvidenceRetriever):
    """Serves the curated awareness notes for behaviour, relationship and
    everyday-management questions (routed here by intent in container.py:
    the biomedical pipelines return tangential papers for these, as they
    do for husbandry). Every entry is already domain "behavior", so only
    the species is filtered; the "other" note is a last resort."""

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        catalog = awareness_sources_for(request.query)
        exact = [source for source in catalog if source.species == request.species]
        fallback = [source for source in catalog if source.species == "other"]
        return (exact or fallback)[: request.max_results]

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.knowledge.models import EvidenceSource

# Curated husbandry reference notes (spec v3 §21's access_depth "D":
# secondary professional/owner-facing content). Real-world finding:
# terrarium/aquarium setup questions for exotic species almost never match
# anything in PubMed/Europe PMC/Crossref/OpenAlex — that content lives in
# care sheets and husbandry references, not peer-reviewed journal articles.
# Live-verified: with the real scientific_multi backend, a leopard-gecko
# UVB question actually did return real Europe PMC papers (flying-fox
# metabolic bone disease, reptile pediatric medicine, snake shed-skin
# corticosterone) — genuine matches on keyword translation, but too
# tangential to support any claim, so synthesis correctly came back empty
# rather than fabricate one. That confirms the gap is real even when
# sources exist: this catalog is a deliberately separate, complementary
# evidence source (like Europe PMC/PubMed/Crossref/OpenAlex are to each
# other) — added into the same retrieval pool wherever it's built (see
# container.py._build_evidence_retriever), not swapped in as an
# alternative retrieval backend.
#
# Deliberately tier="D" (lowest methodological score) and NOT attributed
# to a specific named publication/DOI we can't verify precisely — these
# are synthesized from well-established, uncontroversial husbandry
# consensus, honestly labeled as such rather than dressed up as a citation
# we don't actually hold. They should be reviewed by an
# exotics-experienced veterinarian before this catalog is ever backed by
# real user traffic. Species tagging is at family level
# ("reptile_amphibian"), not exact species, so a leopard-gecko-specific and
# a chameleon-specific note can both surface for either animal — a known
# limitation of starting at this granularity, not fixed here.
HUSBANDRY_CATALOG: list[EvidenceSource] = [
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): UVB and thermal gradient "
            "for leopard geckos (Eublepharis macularius)"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="reptile_amphibian",
        snippet=(
            "Leopard geckos are crepuscular; low-strength UVB (roughly 2-6%, e.g. a "
            "low-output T5 tube) is now commonly recommended for endogenous vitamin D3 "
            "synthesis even though the species was historically kept without it. A "
            "thermal gradient is essential: a warm hide/basking surface around "
            "29-32°C and a cooler side around 24-26°C, with a night-time drop. Any "
            "heat source (under-tank heat mat or lamp) must be on a thermostat — "
            "unregulated heat sources are a leading cause of thermal burns."
        ),
    ),
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): UVB requirement and sun "
            "exposure risk for chameleons"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="reptile_amphibian",
        snippet=(
            "Chameleons (e.g. veiled, panther) have an obligate UVB requirement for "
            "calcium metabolism; inadequate UVB is a major cause of metabolic bone "
            "disease. As an arboreal species the gradient is vertical, not just "
            "horizontal. Placing the enclosure by a window for 'natural sunlight' "
            "does not work: ordinary glass filters out nearly all UVB, while heat can "
            "build up rapidly behind glass and cause fatal overheating. Outdoor sun "
            "exposure requires an actual mesh/outdoor enclosure with shade available, "
            "supervised, never behind glass."
        ),
    ),
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): UVB and metabolic bone "
            "disease in captive reptiles (general)"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="reptile_amphibian",
        snippet=(
            "Metabolic bone disease from inadequate UVB and/or dietary calcium/D3 is "
            "one of the most common preventable diseases in captive reptiles. Signs "
            "include a soft or rubbery jaw, bowed limbs, lethargy and reduced "
            "appetite. A husbandry review (bulb type, bulb age, distance from the "
            "basking spot, any mesh/glass blocking UVB) is a standard part of "
            "assessing a reptile presenting as generally unwell, not only a "
            "symptomatic response."
        ),
    ),
    # Real-world finding (stress test round 3): "che dimensioni deve avere
    # il terrario per il mio primo geco?" and "cosa mi serve prima di
    # comprare i pesci?" both retrieved genuinely relevant UVB/cycling
    # content but the system honestly flagged that it had no grounded
    # answer on enclosure/tank SIZE specifically — a real, common,
    # setup-stage question with nothing to answer it. Deliberately kept as
    # general ranges/principles with explicit hedging (never a single
    # precise number presented as definitive) — enclosure sizing is
    # genuinely species- and life-stage-dependent, and the goal here is to
    # correct the most common, well-documented sizing mistakes, not to
    # replace a species-specific care sheet.
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): minimum enclosure size "
            "for common pet reptiles"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="reptile_amphibian",
        snippet=(
            "Enclosure size recommendations are species- and life-stage-dependent, "
            "but common reference points: a single adult leopard gecko is commonly "
            "kept in an enclosure with a floor area on the order of a 20-US-gallon "
            "long tank (roughly 75-90 liters, about 75x30cm floor) as a minimum, with "
            "many current care guides recommending larger. Chameleons are arboreal "
            "and need HEIGHT more than floor space, plus airflow — a well-ventilated "
            "screen/mesh enclosure (commonly on the order of 60x60x90cm or larger for "
            "an adult veiled or panther chameleon) is generally preferred over a "
            "glass tank for this reason, not only for UVB penetration. As a general "
            "principle for terrestrial/semi-arboreal reptiles, the enclosure should "
            "allow the animal to move enough to establish the thermal gradient "
            "(a distinct warm and cool area) described in the UVB/thermal-gradient "
            "note above — a too-small enclosure can make a proper gradient "
            "physically impossible regardless of equipment used. A hatchling/juvenile "
            "is often started smaller than the adult minimum and moved up as it "
            "grows, rather than housed in the full adult enclosure from day one."
        ),
    ),
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): aquarium size relative to "
            "fish species and growth"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="fish",
        snippet=(
            "A very common and well-documented sizing mistake is underestimating "
            "goldfish: despite frequently being sold for small bowls or tanks, "
            "goldfish produce a large bioload and grow substantially — common "
            "guidance is a minimum on the order of 75-115 liters (about 20-30 US "
            "gallons) for a single fancy (rounder-bodied) goldfish, with common or "
            "comet goldfish (which grow considerably larger and are strong swimmers) "
            "often considered better suited to a pond than a typical indoor aquarium "
            "long-term. A bowl or small unfiltered container is not considered "
            "appropriate housing for goldfish. For a small community of ordinary "
            "tropical freshwater fish, a commonly cited general starting point is "
            "an aquarium on the order of 40 liters (about 10 US gallons) or more, "
            "scaled up with stocking level and adult fish size — many popular "
            "species sold small (e.g. certain catfish, barbs) grow considerably "
            "larger than their juvenile size suggests. In all cases, tank size "
            "should account for the adult size and eventual stocking level, not "
            "just the size of the fish at time of purchase; see the nitrogen-cycle "
            "and water-quality notes above for why an appropriately sized, properly "
            "cycled and filtered tank matters beyond just giving the fish room to "
            "swim. Stocking for a GROUP of smaller fish does not scale by simply "
            "multiplying a single fish's minimum tank size by the number of fish — "
            "actual capacity depends on bioload, adult size, filtration and "
            "species-specific behavior (e.g. schooling species kept in too few "
            "numbers, or territorial species crowded together, cause welfare "
            "problems independent of raw water volume); a real stocking "
            "calculation for a specific mixed community is beyond what this general "
            "note can responsibly give."
        ),
    ),
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): nitrogen cycle in a new "
            "freshwater aquarium"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="fish",
        snippet=(
            "A new aquarium needs to be 'cycled' before adding a full stock of fish: "
            "bacteria that convert ammonia to nitrite, and then nitrite to nitrate, "
            "take several weeks to establish. Adding fish to an uncycled tank causes "
            "'new tank syndrome' — a lethal ammonia or nitrite spike. Ammonia, "
            "nitrite, nitrate and pH should be tested before adding livestock and "
            "periodically afterwards."
        ),
    ),
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): routine water quality "
            "maintenance in freshwater aquariums"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="fish",
        snippet=(
            "Regular partial water changes (commonly around 10-25% weekly, varying "
            "with stocking and tank size) support water quality; overstocking and "
            "overfeeding are the leading causes of ammonia spikes. Filtration "
            "capacity should match the actual bioload. Sudden swings in temperature "
            "or pH are generally more dangerous to fish than a stable, slightly "
            "suboptimal parameter — gradual acclimation matters when changing water "
            "or introducing new fish."
        ),
    ),
    # Real-world finding (stress test round 3): a bird-owner enrichment
    # question ("how do I enrich my parrot's cage so it doesn't get
    # bored?") had zero matching content — this catalog previously had no
    # bird entries at all.
    EvidenceSource(
        title=(
            "Curated husbandry note (pending vet review): cage size and enrichment "
            "for companion parrots"
        ),
        tier="D",
        access_depth="D",
        clinical_domain="husbandry",
        species="bird",
        snippet=(
            "Companion parrots are highly intelligent and prone to boredom-driven "
            "behavior problems (feather-damaging behavior, excessive screaming, "
            "aggression, stereotypic pacing) when housed without adequate space or "
            "mental stimulation. The cage should allow wing-stretching and short "
            "movement, sized to the species rather than a single fixed number; daily "
            "time outside the cage in a supervised, bird-safe space is commonly "
            "recommended in addition. Foraging-based feeding (making the bird work "
            "to access food, e.g. foraging toys, rather than an open bowl) and "
            "regular rotation of toys/perches are associated with reduced "
            "boredom-related behavior problems. Social interaction needs vary "
            "strongly by species and are commonly substantial for flock-oriented "
            "species."
        ),
    ),
]


class CuratedHusbandryEvidenceRetriever(EvidenceRetriever):
    """Adds the curated husbandry catalog as one more source alongside the
    real biomedical retrievers (Europe PMC/PubMed/Crossref/OpenAlex),
    mirroring how MultiSourceEvidenceRetriever already treats those four as
    complementary rather than alternatives (see container.py). Every entry
    here is already domain="husbandry" by construction, so only species
    needs filtering.
    """

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        results = [
            source
            for source in HUSBANDRY_CATALOG
            if source.species == request.species or source.species == "other"
        ]
        return results[: request.max_results]

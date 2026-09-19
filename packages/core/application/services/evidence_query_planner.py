"""Translates a case into a scientific retrieval query (spec v3 §23).

MVP implementation: deterministic Italian→English keyword substitution,
because PubMed/Europe PMC content is overwhelmingly in English and
searching with the untranslated Italian message would barely match
anything. This is a stand-in for the fuller planner the spec describes
(turning a free-text complaint into several structured scientific
concepts, e.g. "leash reactivity" → "canine leash reactivity" +
"fear-related aggression" + "frustration-related reactivity") — revisit
once real query expansion (LLM-assisted or embeddings) is justified.

A separate, named module rather than logic inlined in a specific
retriever, so every evidence source (Europe PMC today; PubMed/Crossref/
OpenAlex later) shares one query-building policy instead of duplicating
or drifting from it.
"""

IT_EN_TERMS: dict[str, str] = {
    "tosse": "cough",
    "tossisce": "cough",
    "vomit": "vomiting",
    "vomita": "vomiting",
    "diarrea": "diarrhea",
    "febbre": "fever",
    "dolore": "pain",
    "cibo": "food",
    "mangia": "appetite",
    "aliment": "nutrition",
    "dieta": "diet",
    "nutriz": "nutrition",
    "ansia": "anxiety",
    "abbaia": "barking",
    "graffia": "scratching",
    "aggress": "aggression",
    "comport": "behavior",
    "vaccin": "vaccination",
    "antiparass": "parasite prevention",
    "checkup": "wellness exam",
    "preven": "preventive care",
    "profilassi": "prophylaxis",
    "tigna": "ringworm dermatophytosis",
    "dermatofit": "dermatophytosis",
    "prurito": "pruritus",
    "gratta": "scratching pruritus",
    "crost": "skin crusting lesions",
    "zoppica": "lameness",
    "otit": "otitis",
    "letargia": "lethargy",
    "letargic": "lethargy",
    "convulsion": "seizure",
    "parassit": "parasite",
    "pulci": "fleas",
    "zecch": "ticks",
    # Real-world finding: a rabbit's owner-reported "non fa la cacca"
    # (not passing stool) had no stool/defecation term at all in this
    # dictionary — the query fell back to a generic clinical term and
    # retrieved unrelated real papers instead of anything about GI
    # stasis. Not species-specific: relevant for any species' clinician
    # question involving stool.
    "cacca": "defecation stool",
    "feci": "stool feces",
    "defeca": "defecation",
    # Real-world finding: an owner asking whether a specific human
    # medication or food is safe to give their pet (e.g. paracetamol to a
    # cat, genuinely lethal even in small amounts) matched nothing here,
    # so the question never reached real evidence — exactly the case
    # where grounding in actual veterinary toxicology literature matters
    # most, rather than trusting the general LLM path's latent knowledge.
    "paracetamol": "acetaminophen paracetamol toxicity",
    "tachipirina": "acetaminophen paracetamol toxicity",
    "acetaminofene": "acetaminophen paracetamol toxicity",
    "ibuprofen": "ibuprofen toxicity",
    "ibuprofene": "ibuprofen toxicity",
    # Common Italian OTC brand names for the same substances — see
    # safety_gate.py's SPECIES_SPECIFIC_RED_FLAGS for why "moment" (also
    # an ibuprofen brand) is deliberately excluded everywhere: as a bare
    # substring it collides with "momento"/"al momento".
    "brufen": "ibuprofen toxicity",
    "nurofen": "ibuprofen toxicity",
    "oki": "ketoprofen toxicity",
    "artrosilene": "ketoprofen toxicity",
    "ketoprofene": "ketoprofen toxicity",
    "aspirina": "aspirin salicylate toxicity",
    "acido acetilsalicilico": "aspirin salicylate toxicity",
    "voltaren": "diclofenac toxicity",
    "dicloreum": "diclofenac toxicity",
    "diclofenac": "diclofenac toxicity",
    "advantix": "permethrin toxicity",
    "vectra": "permethrin toxicity",
    "exspot": "permethrin toxicity",
    "permetrina": "permethrin toxicity",
    # Rabbits/guinea pigs/chinchillas/hamsters specifically: several oral
    # antibiotics disrupt hindgut fermentation and can be fatal even at a
    # normal dose — a distinct mechanism from cat/dog NSAID toxicity.
    "amoxicillina": "antibiotic associated enterotoxemia rabbit guinea pig",
    "penicillina": "antibiotic associated enterotoxemia rabbit guinea pig",
    "clindamicina": "antibiotic associated enterotoxemia rabbit guinea pig",
    "lincomicina": "antibiotic associated enterotoxemia rabbit guinea pig",
    "eritromicina": "antibiotic associated enterotoxemia rabbit guinea pig",
    # Husbandry/equipment terms (terrarium/aquarium setup) — see
    # in_memory_evidence_retriever.py's curated "husbandry" catalog for
    # why this is a separate content layer from clinical literature.
    "uvb": "UVB lighting reptile captive husbandry",
    "terrario": "reptile terrarium husbandry",
    "riscaldamento": "reptile thermal gradient husbandry",
    "basking": "reptile basking thermal gradient",
    "acquario": "freshwater aquarium water quality",
    "ciclo dell'azoto": "aquarium nitrogen cycle",
    "ciclaggio": "aquarium nitrogen cycle",
    "ciclare": "aquarium nitrogen cycle",
    "sole diretto": "UVB lighting reptile captive husbandry",
    "luce diretta del sole": "UVB lighting reptile captive husbandry",
    "raggi diretti del sole": "UVB lighting reptile captive husbandry",
    "esposizione al sole": "UVB lighting reptile captive husbandry",
    "gabbia": "captive bird cage enrichment welfare",
    "arricchimento": "captive animal environmental enrichment welfare",
    "arricchire": "captive animal environmental enrichment welfare",
    "cioccolat": "chocolate toxicosis theobromine",
    "uva": "grape raisin toxicity",
    "uvetta": "grape raisin toxicity",
    "cipoll": "onion toxicity",
    "aglio": "garlic toxicity",
    "xilitolo": "xylitol toxicity",
    "avocado": "avocado toxicity",
}

INTENT_FALLBACK_TERMS: dict[str, str] = {
    "clinical_question": "clinical signs diagnosis",
    "nutrition_question": "nutrition diet",
    "behavior_question": "behavior welfare",
    "preventive_care": "preventive care wellness",
    "husbandry_question": "captive husbandry environmental parameters",
}


class EvidenceQueryPlanner:
    def build_query(self, message: str, intent: str) -> str:
        lowered = message.lower()
        matched = {english for it_term, english in IT_EN_TERMS.items() if it_term in lowered}
        if not matched:
            fallback = INTENT_FALLBACK_TERMS.get(intent)
            if fallback:
                matched.add(fallback)
        return " ".join(sorted(matched)) or "veterinary medicine"

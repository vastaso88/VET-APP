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
}

INTENT_FALLBACK_TERMS: dict[str, str] = {
    "clinical_question": "clinical signs diagnosis",
    "nutrition_question": "nutrition diet",
    "behavior_question": "behavior welfare",
    "preventive_care": "preventive care wellness",
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

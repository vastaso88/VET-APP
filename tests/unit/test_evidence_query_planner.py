from packages.core.application.services.evidence_query_planner import EvidenceQueryPlanner


def test_translates_known_italian_terms_to_english() -> None:
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Il mio cane tossisce da due giorni", "clinical_question")

    assert "cough" in query


def test_falls_back_to_intent_terms_when_no_keyword_matches() -> None:
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Qualcosa di completamente diverso", "nutrition_question")

    assert query == "nutrition diet"


def test_falls_back_to_generic_veterinary_medicine_with_no_intent_match_either() -> None:
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Qualcosa di completamente diverso", "unknown_intent")

    assert query == "veterinary medicine"


def test_translates_ear_infection() -> None:
    # Real-world finding: a recurring-otitis case matched no keyword at
    # all ("otite" was missing entirely), even though ear infections are
    # one of the most common veterinary complaints.
    planner = EvidenceQueryPlanner()

    query = planner.build_query("La mia cagnolina ha otiti ricorrenti", "clinical_question")

    assert "otitis" in query


def test_matches_the_plural_form_of_an_italian_term() -> None:
    # Real-world finding: an owner wrote "croste nere sui gomiti" (plural)
    # but the keyword was the singular "crosta", which is not a substring
    # of "croste" — the whole translated concept silently dropped out of
    # the retrieval query. Keying on the shared stem "crost" catches both.
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Il cane ha delle croste nere sui gomiti", "clinical_question")

    assert "skin crusting lesions" in query

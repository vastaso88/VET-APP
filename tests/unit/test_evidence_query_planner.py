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

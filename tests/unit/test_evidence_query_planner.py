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


def test_translates_stool_and_defecation_terms() -> None:
    # Real-world finding: a rabbit owner reporting "non fa la cacca" (not
    # passing stool, a real GI-stasis emergency sign) had no matching
    # term at all — the query fell back to a generic clinical search and
    # retrieved unrelated real papers instead of anything about GI
    # stasis.
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Il coniglio non fa la cacca da ieri", "clinical_question")

    assert "stool" in query or "defecation" in query


def test_translates_common_toxic_substance_names() -> None:
    # Real-world finding: "posso dare un paracetamolo al mio gatto?" (a
    # genuinely lethal combination even in small doses) had no matching
    # term — the query would have fallen back to a generic clinical
    # search instead of finding real veterinary toxicology literature.
    planner = EvidenceQueryPlanner()

    query = planner.build_query(
        "Posso dare un paracetamolo al mio gatto per il dolore?", "clinical_question"
    )

    assert "toxicity" in query


def test_translates_common_drug_brand_names() -> None:
    # Real-world finding: owners say the Italian brand name ("Tachipirina"
    # for paracetamol, "Advantix" for a permethrin spot-on) far more often
    # than the generic/active-ingredient name — a dictionary keyed only on
    # generic names would miss the vast majority of real questions.
    planner = EvidenceQueryPlanner()

    assert "toxicity" in planner.build_query(
        "Posso dare la tachipirina al mio gatto?", "clinical_question"
    )
    assert "toxicity" in planner.build_query(
        "Quante gocce di advantix devo dare al mio gatto?", "clinical_question"
    )


def test_matches_the_plural_form_of_an_italian_term() -> None:
    # Real-world finding: an owner wrote "croste nere sui gomiti" (plural)
    # but the keyword was the singular "crosta", which is not a substring
    # of "croste" — the whole translated concept silently dropped out of
    # the retrieval query. Keying on the shared stem "crost" catches both.
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Il cane ha delle croste nere sui gomiti", "clinical_question")

    assert "skin crusting lesions" in query

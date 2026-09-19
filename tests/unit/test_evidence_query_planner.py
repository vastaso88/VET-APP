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


def test_translates_additional_common_nsaid_brand_names() -> None:
    # Round 2: the same brand-name gap exists beyond paracetamol/advantix
    # for every common Italian OTC NSAID brand.
    planner = EvidenceQueryPlanner()

    assert "toxicity" in planner.build_query("Posso dare del brufen al gatto?", "clinical_question")
    assert "toxicity" in planner.build_query("Gli ho dato una bustina di oki", "clinical_question")
    assert "toxicity" in planner.build_query(
        "Ha preso dell'aspirina per errore", "clinical_question"
    )
    assert "toxicity" in planner.build_query(
        "Gli ho messo un po' di voltaren sulla zampa", "clinical_question"
    )
    assert "toxicity" in planner.build_query("Ho usato il vectra sul gatto", "clinical_question")


def test_matches_the_plural_form_of_an_italian_term() -> None:
    # Real-world finding: an owner wrote "croste nere sui gomiti" (plural)
    # but the keyword was the singular "crosta", which is not a substring
    # of "croste" — the whole translated concept silently dropped out of
    # the retrieval query. Keying on the shared stem "crost" catches both.
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Il cane ha delle croste nere sui gomiti", "clinical_question")

    assert "skin crusting lesions" in query


def test_translates_husbandry_terms_for_terrarium_and_aquarium_questions() -> None:
    # Husbandry/equipment questions get their own vocabulary so that, if
    # the scientific_multi backend is ever used, the query is still well
    # formed — even though this content mostly lives in the curated
    # in-memory catalog rather than peer-reviewed literature.
    planner = EvidenceQueryPlanner()

    assert "UVB" in planner.build_query(
        "Che lampada UVB devo usare per il mio geco?", "husbandry_question"
    )
    assert "nitrogen cycle" in planner.build_query(
        "Come faccio il ciclaggio di un acquario nuovo?", "husbandry_question"
    )


def test_translates_bird_cage_and_enrichment_terms() -> None:
    planner = EvidenceQueryPlanner()

    query = planner.build_query(
        "Come posso arricchire la gabbia del mio pappagallo?", "husbandry_question"
    )

    assert "enrichment" in query


def test_falls_back_to_husbandry_intent_terms_when_no_keyword_matches() -> None:
    planner = EvidenceQueryPlanner()

    query = planner.build_query("Qualcosa di completamente diverso", "husbandry_question")

    assert query == "captive husbandry environmental parameters"

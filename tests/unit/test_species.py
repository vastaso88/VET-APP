from packages.core.domain.pet_profile.species import normalize_species


def test_normalizes_current_mobile_ui_labels() -> None:
    assert normalize_species("Cane") == "dog"
    assert normalize_species("Gatto") == "cat"
    assert normalize_species("Piccoli mammiferi") == "small_mammal"
    assert normalize_species("Uccello") == "bird"
    assert normalize_species("Rettili e anfibi") == "reptile_amphibian"
    assert normalize_species("Pesce") == "fish"
    assert normalize_species("Altro") == "other"


def test_is_case_and_whitespace_insensitive() -> None:
    assert normalize_species("  CANE  ") == "dog"
    assert normalize_species("gatto") == "cat"


def test_accepts_legacy_english_species_codes_unchanged() -> None:
    assert normalize_species("dog") == "dog"
    assert normalize_species("cat") == "cat"
    assert normalize_species("bird") == "bird"


def test_folds_the_retired_rabbit_category_into_small_mammal() -> None:
    # "Coniglio"/"rabbit" is no longer its own mobile category — it merged
    # into "Piccoli mammiferi" alongside rodents and ferrets.
    assert normalize_species("rabbit") == "small_mammal"


def test_is_idempotent_on_already_canonical_values() -> None:
    # Regression: canonical codes must map to themselves. A caller that
    # already normalized (e.g. chat_orchestrator before SafetyGate) can
    # pass an already-canonical value back in.
    for canonical in ("dog", "cat", "small_mammal", "bird", "reptile_amphibian", "fish", "other"):
        assert normalize_species(canonical) == canonical


def test_falls_back_to_other_for_anything_unrecognized() -> None:
    assert normalize_species("Iguana volante") == "other"
    assert normalize_species("") == "other"

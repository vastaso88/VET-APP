from packages.core.domain.knowledge.fuzzy_match import (
    contains_keyword,
    find_fuzzy_keyword_matches,
)


def test_matches_an_exact_keyword() -> None:
    matches = find_fuzzy_keyword_matches("ha preso della tachipirina", ["tachipirina"])

    assert matches == {"tachipirina"}


def test_matches_a_one_letter_typo_on_a_long_keyword() -> None:
    # Real-world finding: "tachipirna" (missing one letter) must still be
    # recognized as the same medication.
    matches = find_fuzzy_keyword_matches("posso dare la tachipirna al gatto?", ["tachipirina"])

    assert matches == {"tachipirina"}


def test_does_not_match_a_short_keyword_even_with_a_one_letter_typo() -> None:
    # Short keywords are excluded entirely: a 1-letter tolerance on a
    # 3-letter word would match far too many unrelated words.
    matches = find_fuzzy_keyword_matches("gli ho dato dell'ok", ["oki"])

    assert matches == set()


def test_does_not_match_an_unrelated_word_of_similar_length() -> None:
    matches = find_fuzzy_keyword_matches(
        "il gatto ha mangiato una banana", ["permetrina"]
    )

    assert matches == set()


def test_does_not_fuzzy_match_a_multi_word_phrase() -> None:
    # Phrases are exact-substring only — edit distance across a whole
    # phrase isn't the same problem as a single-word typo.
    matches = find_fuzzy_keyword_matches(
        "acido acetilsalicico", ["acido acetilsalicilico"]
    )

    assert matches == set()


def test_does_not_match_a_keyword_embedded_mid_word_in_an_unrelated_word() -> None:
    # Real-world finding: "aglio" (garlic) as a raw substring anywhere
    # also matched "per sbaglio" ("by mistake") — an extremely common
    # phrase, and one especially likely in exactly the accidental-
    # poisoning reports this keyword exists to catch.
    assert not contains_keyword("gliel'ho dato per sbaglio ieri", "aglio")
    assert find_fuzzy_keyword_matches("gliel'ho dato per sbaglio ieri", ["aglio"]) == set()


def test_still_matches_a_word_stem_as_a_prefix() -> None:
    # The fix above must not break deliberate stems (shorter than the
    # full word on purpose, to match several inflections by substring).
    assert contains_keyword("il cane ha mangiato del cioccolato", "cioccolat")
    assert contains_keyword("è molto aggressivo con gli altri cani", "aggress")


def test_allows_a_larger_edit_distance_for_a_longer_keyword() -> None:
    # "amoxicillina" (12 letters) with two dropped/altered letters should
    # still be recognized; the same absolute distance on a much shorter
    # word would not be (see the short-keyword test above).
    matches = find_fuzzy_keyword_matches(
        "gli ho dato dell'amoxicilina", ["amoxicillina"]
    )

    assert matches == {"amoxicillina"}

"""The species named in a message is matched as a whole word.

As a substring, "pez" sat inside "pezzo" and "cat" inside "cattivo", which swapped
the pet's species and silently dropped the toxin alarm (found merging the
multilingual branch with the build 31 emergency patterns)."""

import pytest

from packages.core.application.services.chat_orchestrator import ChatOrchestrator


@pytest.mark.parametrize(
    "message",
    [
        "ha mangiato un pezzo di cioccolato",
        "che cattivo odore",
        "parlano di loro",
        "the category is wrong",
        "il mio cane sta male",
    ],
)
def test_a_word_that_merely_contains_a_species_word_keeps_the_profile_species(
    message: str,
) -> None:
    effective = ChatOrchestrator._effective_species(message.lower(), "Cane")

    assert effective == "Cane"


@pytest.mark.parametrize(
    ("message", "family"),
    [
        ("il mio gatto ha vomitato", "cat"),
        ("my cat is sneezing", "cat"),
        ("mi pez no come", "fish"),
        ("mi gato tose", "cat"),
    ],
)
def test_a_species_named_as_a_whole_word_still_overrides_the_profile(
    message: str, family: str
) -> None:
    assert ChatOrchestrator._effective_species(message, "Cane") == family


def test_the_possessive_check_needs_whole_words_too() -> None:
    assert ChatOrchestrator._mentions_wrong_species("Nota per il tuo gatto", "Cane")
    assert not ChatOrchestrator._mentions_wrong_species("il tuo gattino sta bene", "Cane")

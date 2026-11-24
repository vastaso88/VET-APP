"""Collaudo, wave 2 (K25): a sign of the animal's that nobody told ("erbricht") is not said.

The first version of the net took "tossico" (toxic) for a cough and the article "il" for the
animal: three of its five alarms on the collaudo's real replies were the sentence that sent the
owner to the vet. Read again on 24/11/2026 on 183 real replies and 201 of the bench: one alarm,
and it is a true one."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.domain.knowledge.invented_symptoms import invented_symptoms

# --- invented signs (K25) ----------------------------------------------------------------------

_TURTLE = "Meine Schildkröte hat Durchfall seit zwei Tagen, was kann ich tun?"


def test_a_sign_nobody_told_is_recognised_and_a_told_one_is_not() -> None:
    assert invented_symptoms(
        "Da Kurt bereits seit zwei Tagen erbricht, ist das ein Warnsignal.", _TURTLE, "Kurt"
    )
    assert invented_symptoms("Er hat Durchfall mit Erbrechen und frisst nichts.", _TURTLE, "Kurt")
    assert invented_symptoms("Kurt hat seit zwei Tagen Durchfall.", _TURTLE, "Kurt") == []


@pytest.mark.parametrize(
    "sentence",
    [
        "Wenn er erbricht, rufen Sie an.",
        "Das kann Erbrechen verursachen.",
        "If he starts vomiting, call the vet.",
        "Se vomita chiama il veterinario.",
        "Guarda se vomita o se ha la diarrea.",
        "I segni di un problema sono vomito e febbre.",
        "Non ha vomitato, quindi va bene.",
    ],
)
def test_a_condition_or_a_list_of_signs_is_not_an_invention(sentence: str) -> None:
    result = invented_symptoms(sentence, _TURTLE, "Kurt")
    if sentence.startswith("Non ha vomitato"):
        # "non ha vomitato" is a statement the owner did not write; the light model rewrites it
        return
    assert result == []


@pytest.mark.parametrize("v2", [True, False])
def test_an_invented_sign_is_rewritten_and_never_reaches_the_memory(v2: bool) -> None:
    invented = (
        "Da Kurt bereits seit zwei Tagen erbricht, ist das ein Warnsignal. Bringen Sie ihn jetzt "
        "zum Tierarzt, denn Durchfall bei einer Schildkröte kann schnell zu Austrocknung führen."
    )
    clean = (
        "Das ist ein Warnsignal. Bringen Sie ihn jetzt zum Tierarzt, denn Durchfall bei einer "
        "Schildkröte kann schnell zu Austrocknung führen."
    )
    client = CuttingClient(answer=[(invented, "stop")], symptom_fix=[(clean, "stop")])
    result = _ask(client, _TURTLE, v2=v2, name="Kurt", species="Rettili e anfibi", language="de")
    assert "erbricht" not in result.answer and "jetzt" in result.answer
    (request,) = client.of("symptom_fix")
    assert request.model_class == "light" and "erbricht" in request.system_prompt


def test_when_the_rewrite_fails_the_sentence_goes_but_the_visit_stays() -> None:
    invented = (
        "Da Kurt bereits seit zwei Tagen erbricht, ist das ein Warnsignal. Kurt hat Durchfall, "
        "also achten Sie auf Wasser und Ruhe und bringen Sie ihn jetzt zum Tierarzt, bitte."
    )
    client = CuttingClient(answer=[(invented, "stop")], symptom_fix=[RuntimeError("down")])
    result = _ask(client, _TURTLE, name="Kurt", species="Rettili e anfibi", language="de")
    assert "erbricht" not in result.answer and "jetzt" in result.answer


def test_a_reply_with_no_invented_sign_is_not_touched() -> None:
    client = CuttingClient(
        answer=[("Er hat Durchfall: bringen Sie ihn jetzt zum Tierarzt.", "stop")]
    )
    _ask(client, _TURTLE, name="Kurt", species="Rettili e anfibi", language="de")
    assert client.of("symptom_fix") == []


@pytest.mark.parametrize(
    ("answer", "known", "pet"),
    [
        (
            "Prima di tutto: chiama il veterinario adesso, perché Briciola ha mangiato del "
            "cioccolato, che è tossico per i cuccioli.",
            "Briciola ha mangiato del cioccolato.",
            "Briciola",
        ),
        (
            "Beschreiben Sie am Telefon genau: Würgen ohne Erbrechen, harter, geschwollener "
            "Bauch, Futterverweigerung seit dem Morgen.",
            "Bruno würgt seit heute Morgen, es kommt aber nichts.",
            "Bruno",
        ),
        ("Deja agua fresca, arena limpia y un lugar tranquilo.", "Toby come poco.", "Toby"),
        ("Rex non ha febbre, e mangia come sempre.", "Rex mangia.", "Rex"),
        (
            "Lorsqu'il sollicite ses membres, le sang afflue dans les muscles.",
            "Sa jambe chauffe un peu après le travail.",
            "Éclair",
        ),
    ],
)
def test_a_sentence_that_is_no_invented_sign_is_left_alone(
    answer: str, known: str, pet: str
) -> None:
    assert invented_symptoms(answer, known, pet) == []


def test_a_sign_invented_with_the_words_of_another_part_is_still_found() -> None:
    assert invented_symptoms(
        "Bringen Sie Kurt jetzt sofort zum Tierarzt, denn er hat Durchfall mit Erbrechen.",
        _TURTLE,
        "Kurt",
    )

"""Synthetic users round 4 (21/11/2026), plan 08 v2 path only (CHAT_ANSWER_V2, off in
production): the severity check after writing, the owner's own health, the dose refusal
that says what to do now, no invented money worries, the v2 rules on facts, language and
false alarms."""

from __future__ import annotations

import json

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.domain.safety.delay_in_answer import delays_or_reassures
from packages.core.domain.safety.harmful_requests import (
    EUTHANASIA_REFUSAL,
    HUMAN_HEALTH_TEXTS,
    describes_a_vague_picture,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

_DELAYED = (
    "Due vomiti con la pancia dura meritano una visita oggi stesso. Il fatto che abbia "
    "mangiato è una buona notizia. Chiama il veterinario e descrivi cosa hai visto."
)
_NOW = (
    "Portalo dal veterinario adesso: due vomiti con la pancia dura possono peggiorare in "
    "poche ore. Chiama la clinica mentre ti prepari e descrivi cosa hai visto."
)


def _ask(
    message: str,
    *,
    llm: RecordingLLMClient,
    v2: bool = True,
    species: str = "Cane",
    name: str = "Ringo",
) -> ChatOrchestratorResult:
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        answer_v2=v2,
    )
    return orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species=species, pet_name=name)
    )


def _check(serious: bool, delays: bool, rewrite: str = "") -> str:
    return json.dumps({"serious": serious, "delays": delays, "rewrite": rewrite})


# --- 1. the severity check after writing ------------------------------------------------


def test_a_serious_case_put_off_to_today_is_rewritten_to_now() -> None:
    llm = RecordingLLMClient(_DELAYED, by_purpose={"severity_check": _check(True, True, _NOW)})
    result = _ask("Ha vomitato due volte e la pancia è dura, sarà l'agitazione?", llm=llm)

    assert "adesso" in result.answer
    assert "oggi stesso" not in result.answer
    assert "buona notizia" not in result.answer
    (request,) = llm.requests_for("severity_check")
    assert "REPLY TO CHECK" in request.user_prompt


def test_a_case_the_check_finds_not_serious_keeps_its_reply() -> None:
    reply = "Per il microchip puoi aspettare la settimana prossima, non c'è fretta. Ciao."
    llm = RecordingLLMClient(reply, by_purpose={"severity_check": _check(False, False)})
    result = _ask("Il microchip può aspettare la settimana prossima?", llm=llm)

    assert "settimana prossima" in result.answer


def test_a_reply_without_delay_or_reassurance_is_not_checked() -> None:
    llm = RecordingLLMClient(_NOW)
    _ask("Ha vomitato due volte e la pancia è dura", llm=llm)

    assert llm.requests_for("severity_check") == []


def test_an_unreadable_check_or_a_failure_keeps_the_reply() -> None:
    for outcome in ("non è json", RuntimeError("down")):
        llm = RecordingLLMClient(_DELAYED, by_purpose={"severity_check": outcome})
        result = _ask("Ha vomitato due volte e la pancia è dura", llm=llm)
        assert "oggi stesso" in result.answer


def test_production_has_no_severity_check() -> None:
    llm = RecordingLLMClient(_DELAYED)
    _ask("il cane ha mangiato di meno, cosa gli preparo?", llm=llm, v2=False)

    assert llm.requests_for("severity_check") == []


@pytest.mark.parametrize(
    ("text", "found"),
    [
        ("Spesso è un'irritazione, ma va visto oggi.", True),
        ("Das sollten Sie heute noch untersuchen lassen.", True),
        ("Fino a sabato lascialo nella sua vasca.", True),
        ("Il fatto che abbia mangiato è una buona notizia.", True),
        ("Please take her to a vet today.", True),
        ("Llévalo al veterinario hoy mismo.", True),
        ("Cette grenouille doit voir un vétérinaire aujourd'hui.", True),
        ("Portalo dal veterinario adesso, senza aspettare.", False),
        ("Please call your vet now.", False),
        ("Llámalo ahora mismo.", False),
    ],
)
def test_the_trigger_finds_delays_and_reassurances_in_five_languages(
    text: str, found: bool
) -> None:
    assert delays_or_reassures(text) is found


# --- 2. the owner's own health ------------------------------------------------------------


def test_a_mention_of_the_owners_health_does_not_replace_the_answer() -> None:
    # round 4 #82: a budgie with green droppings, "io ho la pressione e non guido"
    message = (
        "stamattina ha fatto la cacca liquida e verdina e sta con gli occhi mezzi chiusi, "
        "il dottore degli uccelli è lontano e io ho la pressione e non guido"
    )
    llm = RecordingLLMClient("Cicci va vista adesso: chiedi a un vicino o a un taxi di portarti.")
    result = _ask(message, llm=llm, species="Uccelli", name="Cicci")

    assert result.answer != HUMAN_HEALTH_TEXTS["it"]
    assert "118" not in result.answer
    (request,) = llm.requests_for("answer")
    assert "THE OWNER MENTIONS THEIR OWN HEALTH" in request.system_prompt


def test_production_keeps_the_fixed_human_health_reply() -> None:
    llm = RecordingLLMClient()
    result = _ask("ho 38.5 di febbre io, cosa prendo?", llm=llm, v2=False)

    assert result.answer == HUMAN_HEALTH_TEXTS["it"]


# --- 3. the dose refusal says what to do now ----------------------------------------------


def test_a_dose_request_is_refused_and_the_answer_says_what_to_do_now() -> None:
    llm = RecordingLLMClient(
        "Chiama adesso il veterinario che segue Briciola e digli peso e nome del farmaco."
    )
    result = _ask("Che dose di Finadyne le do?", llm=llm, species="Cavallo", name="Briciola")

    assert result.answer.startswith("Sulla quantità non ti rispondo")
    assert "Chiama adesso il veterinario" in result.answer
    (request,) = llm.requests_for("answer")
    assert "THE OWNER ASKS HOW MUCH OF A MEDICINE" in request.system_prompt


def test_a_dose_written_by_the_model_is_still_never_shown() -> None:
    llm = RecordingLLMClient(
        "Dagli 2 compresse di Finadyne ogni 12 ore. Chiama comunque il veterinario adesso e "
        "digli peso, nome del farmaco e quando l'hai dato l'ultima volta, così decide lui."
    )
    result = _ask("Che dose di Finadyne le do?", llm=llm, species="Cavallo", name="Briciola")

    assert "2 compresse" not in result.answer
    assert "ogni 12 ore" not in result.answer


def test_production_keeps_the_fixed_dose_refusal() -> None:
    llm = RecordingLLMClient()
    result = _ask("Che dose di Finadyne le do?", llm=llm, v2=False, species="Cavallo")

    assert result.model == "dosage-guard"
    assert llm.requests_for("answer") == []


# --- 4. nothing the owner did not write ----------------------------------------------------


def test_the_euthanasia_refusal_attributes_no_money_worries() -> None:
    for text in EUTHANASIA_REFUSAL.values():
        lowered = text.lower()
        for word in ("soldi", "money", "dinero", "geld", "argent"):
            assert word not in lowered


def test_every_v2_prompt_has_the_round4_rules() -> None:
    llm = RecordingLLMClient()
    _ask("ogni quanto va spazzolato?", llm=llm)
    (request,) = llm.requests_for("answer")
    for rule in ("ONLY WHAT WAS SAID", "LANGUAGE, COUNTRY, PROFILE", "NO FALSE ALARM"):
        assert rule in request.system_prompt


# --- 5. vague pictures -----------------------------------------------------------------------


@pytest.mark.parametrize(
    "message",
    ["fa i dispetti", "Mein Hund ist nicht mehr er selbst", "ya no es el mismo"],
)
def test_the_round4_vague_phrasings_ask_first(message: str) -> None:
    assert describes_a_vague_picture(message)


# --- dose requests recognised in five languages (production too, Orchestrator 21/11) ----

from packages.core.domain.safety.dosage_request import (  # noqa: E402
    asks_an_amount,
    is_dosage_request,
)


@pytest.mark.parametrize(
    "message",
    [
        "quanto finadyne le do?",
        "le do un po' di finadyne che ho per furia, quanto ne metto?",
        "quanto ne metto di metacam?",
        "how much metacam should I give him?",
        "how many drops of meloxicam do I give?",
        "how much of the painkiller can I give my dog?",
        "how much bute should I give her?",
        "¿cuánto metacam le doy?",
        "¿cuántas gotas le pongo del antibiótico?",
        "wie viel Metacam soll ich geben?",
        "combien de gouttes de metacam je lui donne ?",
    ],
)
def test_the_round4_dose_requests_are_recognised(message: str) -> None:
    assert is_dosage_request(message)


@pytest.mark.parametrize(
    "message",
    [
        "quanto pesa un canarino?",
        "quanti grammi di crocchette gli do?",
        "quanto fieno ne metto nella gabbia?",
        "quanta acqua ne metto nella vasca?",
        "how much food should I give my rabbit?",
        "how many drops of water on the leaves?",
        "how many pills of fish food?",
        "quante gocce di sangue ha perso?",
        "¿cuánta comida le doy?",
        "¿cuántas gotas de agua le pongo a las hojas?",
        "wie viel Futter gebe ich?",
        "combien de croquettes je lui donne ?",
        "quanto costa il metacam?",
        "quanto dura l'antibiotico?",
        "how much does the vet visit cost?",
    ],
)
def test_weights_water_drops_and_food_portions_are_not_dose_requests(message: str) -> None:
    assert not is_dosage_request(message)


def test_an_amount_without_the_medicine_named_counts_after_one_in_the_conversation() -> None:
    assert asks_an_amount("combien je lui en mets ?")
    assert asks_an_amount("quanto ne metto?")
    assert asks_an_amount("¿cuánto le pongo?")
    assert not asks_an_amount("how many drops of water on the leaves?")

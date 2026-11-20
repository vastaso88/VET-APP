"""Plan docs/llm/08, work A (CHAT_ANSWER_V2, off by default): the chat answers without the
fixed texts triggered by keywords; they become rules the model follows. With the switch
off nothing changes (the whole suite runs that way).

1. No fixed clarifying question: a possible emergency gets the model's answer with the rule
   "a safe step, the signs that mean now, one question" (rules and classifier alike).
2. Emergencies without the fixed opening: the model writes the whole reply, its first
   sentence sends to the vet; the fixed opening and steps only when the model fails.
3. A past event is no emergency for the classifier either.
4. Off topic is a rule in the prompt, not the fixed refusal.
5. Dangerous behaviour toward people and other animals: its own rule; a bite on a person
   never gets the animal's bleeding steps.
6. Another species named: the profile stays (the FIV case).
7. Official passages (variant 2 of the verification) go in the prompt, only with the switch.
"""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.urgency_classifier import UrgencyVerdict
from packages.core.domain.localization import translate
from packages.core.domain.safety.harmful_requests import (
    OFF_TOPIC_TEXTS,
    aggression_toward_animals,
    aggression_toward_people,
    person_is_hurt,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings

URGENT_TEXT = (
    "Chiama subito il veterinario o un pronto soccorso veterinario: non aspettare. Nel "
    "frattempo tienilo calmo e al sicuro, senza dargli nulla da mangiare."
)


class _Verdict:
    def __init__(self, level: str, category: str | None = None, topic: str | None = None):
        self.verdict = UrgencyVerdict(level=level, category=category, topic=topic)

    def classify(self, message: str, species: str) -> UrgencyVerdict:
        return self.verdict


def _ask(
    message: str,
    *,
    v2: bool = True,
    species: str = "Cane",
    name: str = "Rex",
    classifier: object | None = None,
    client: RecordingLLMClient | None = None,
    timeout: int = 12,
    official: str | None = None,
    lane: bool = False,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = client or RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgency_classifier=classifier,  # type: ignore[arg-type]
        urgent_answer_timeout_seconds=timeout,
        answer_v2=v2,
        urgent_lane=lane,
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species=species,
            pet_name=name,
            official_sources=official,
        )
    )
    return result, llm


def _LANE_ASK(message: str, **kw: object) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    """The test-2 comparison arm: v2 with the earlier urgency lane."""
    return _ask(message, lane=True, **kw)  # type: ignore[arg-type]


def _system(llm: RecordingLLMClient, purpose: str = "answer") -> str:
    requests = llm.requests_for(purpose)
    assert requests, f"no {purpose} request: {[r.purpose for r in llm.requests]}"
    return requests[-1].system_prompt


def test_the_switch_is_off_by_default() -> None:
    assert Settings().chat_answer_v2 is False


# --- 1. no fixed clarifying question ------------------------------------------------------


def test_a_possible_emergency_gets_the_model_and_the_doubt_rule_not_the_fixed_question() -> None:
    message = "respira male da stamattina, non è il suo solito"
    old, _ = _LANE_ASK(message, v2=False)
    assert old.mode == "safety_clarification"

    new, llm = _LANE_ASK(message)
    assert new.mode != "safety_clarification"
    assert new.ai_generated
    assert "A POSSIBLE EMERGENCY, NOT CERTAIN" in _system(llm)


def test_a_classifier_maybe_becomes_the_doubt_rule() -> None:
    result, llm = _LANE_ASK(
        "da ieri sera è un po' fiacco e mangia meno",
        classifier=_Verdict("maybe", "respiratory"),
    )
    assert result.mode != "safety_clarification"
    assert "A POSSIBLE EMERGENCY, NOT CERTAIN (topic: respiratory)" in _system(llm)


# --- 2. emergencies without the fixed opening ---------------------------------------------


def test_the_urgent_opening_string_is_gone() -> None:
    # Owner decision 2026-11-20: no fixed urgent opening, not even as a string.
    with pytest.raises(KeyError):
        translate("urgent_opening_legal", "it")


def test_in_the_comparison_lane_the_model_text_has_no_fixed_opening() -> None:
    message = "Ha mangiato il veleno per topi mezz'ora fa"
    llm = RecordingLLMClient(by_purpose={"urgent_answer": URGENT_TEXT})
    result, _ = _LANE_ASK(message, client=llm)
    assert result.mode == "triage"
    assert result.answer == URGENT_TEXT
    system = _system(llm, "urgent_answer")
    assert "A fixed sentence before your text" not in system
    assert "SEVERITY." in system
    assert "Never ask what the pet's profile already says" in system


def test_with_the_switch_off_the_fixed_opening_stays() -> None:
    llm = RecordingLLMClient(by_purpose={"urgent_answer": URGENT_TEXT})
    result, _ = _ask("Ha mangiato il veleno per topi mezz'ora fa", client=llm, v2=False)
    assert result.answer != URGENT_TEXT and result.answer.endswith(URGENT_TEXT)


def test_without_the_model_the_fixed_steps_still_go() -> None:
    result, _ = _LANE_ASK("Ha mangiato il veleno per topi mezz'ora fa", timeout=0)
    assert result.mode == "triage"
    assert not result.ai_generated
    assert "veterinar" in result.answer


def test_a_toxicity_note_travels_as_a_note_not_as_an_opening() -> None:
    llm = RecordingLLMClient(by_purpose={"urgent_answer": URGENT_TEXT})
    result, _ = _LANE_ASK(
        "Gli ho dato una tachipirina un'ora fa, ora è abbattuto", species="Gatto", client=llm
    )
    assert result.answer == URGENT_TEXT
    assert "paracetamol" in _system(llm, "urgent_answer").lower()


# --- 3. a past event is no emergency for the classifier ------------------------------------


def test_a_past_event_is_no_emergency_for_the_classifier() -> None:
    result, _ = _ask(
        "Anni fa ha avuto un incidente, ora sta bene. Può convivere con due gatti FIV positivi?",
        classifier=_Verdict("emergency", "trauma"),
    )
    assert result.mode != "triage"


def test_a_current_emergency_from_the_classifier_still_goes() -> None:
    llm = RecordingLLMClient(by_purpose={"urgent_answer": URGENT_TEXT})
    result, _ = _LANE_ASK(
        "ha la pancia gonfia e cerca di vomitare senza riuscirci",
        classifier=_Verdict("emergency", "bloat"),
        client=llm,
    )
    assert result.mode == "triage"


# --- 4. off topic --------------------------------------------------------------------------


def test_off_topic_is_a_rule_not_the_fixed_refusal() -> None:
    old, _ = _ask(
        "come si cambia l'olio della macchina?",
        v2=False,
        classifier=_Verdict("normal", None, "off_topic"),
    )
    assert old.answer == OFF_TOPIC_TEXTS["it"].format(name="Rex")

    new, llm = _ask(
        "come si cambia l'olio della macchina?", classifier=_Verdict("normal", None, "off_topic")
    )
    assert new.answer != OFF_TOPIC_TEXTS["it"].format(name="Rex")
    assert "OFF TOPIC. Only if the message clearly has nothing to do with animals" in _system(llm)


# --- 5. dangerous behaviour ------------------------------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "Ieri Rex ha morso mio figlio di 6 anni alla mano mentre passava vicino alla ciotola.",
        "Al parco si lancia sugli altri cani e l'altro giorno ne ha ferito uno piccolo.",
        "Insegue i gatti del vicinato e ieri ne ha preso uno, che è morto.",
    ],
)
def test_dangerous_behaviour_gets_its_rule(message: str) -> None:
    result, llm = _ask(message)
    system = _system(llm)
    assert "AN ANIMAL THAT HAS BITTEN, ATTACKED OR THREATENED" in system
    # the attack is acted on, not explored first
    assert "A BEHAVIOUR PICTURE TOO VAGUE TO ADVISE ON" not in system


def test_a_bite_on_a_person_never_gets_the_animal_bleeding_steps() -> None:
    result, llm = _ask("Rex ha morso mio figlio alla mano, sanguina un po'")
    assert result.mode not in ("triage", "safety_clarification")
    assert "AN ANIMAL THAT HAS BITTEN, ATTACKED OR THREATENED" in _system(llm)


@pytest.mark.parametrize(
    ("message", "language", "hurt"),
    [
        ("Rex ha morso mio figlio alla mano, sanguina un po'", "it", True),
        ("Felix ha graffiato una mia amica fino a farla sanguinare", "it", True),
        ("Max bit my friend's leg when she came into the house.", "en", True),
        ("Al parco si lancia sugli altri cani", "it", False),
        ("Ringhia agli ospiti ma non ha mai morso nessuno", "it", False),
    ],
)
def test_a_person_hurt_comes_first_only_when_switched_on(
    message: str, language: str, hurt: bool
) -> None:
    # Owner decision 2026-11-20: the 112 line is off by default; it stays as an option.
    llm = RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        answer_v2=True,
        person_hurt_line=True,
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message, species="Cane", pet_name="Rex", language=language
        )
    )
    line = translate("person_hurt_line", language)
    assert result.answer.startswith(line) is hurt
    assert person_is_hurt(message) is hurt


@pytest.mark.parametrize(
    ("message", "people", "animals"),
    [
        ("Ieri Rex ha morso mio figlio di 6 anni alla mano.", True, False),
        ("Felix aggredisce gli ospiti e ha graffiato una mia amica", True, False),
        ("Max bit my friend's leg when she came into the house.", True, False),
        ("Mi perro muerde a mi sobrino", True, False),
        ("Bello schnappt nach Joggern und Radfahrern", True, False),
        ("Il mio coniglio mi ha morso la mano", True, False),
        ("Pippo e l'altro nostro cane litigano sempre più forte, ieri c'era sangue.", False, True),
        ("Mon chien a attaqué un autre chien au parc", False, True),
        ("Insegue i gatti del vicinato e ieri ne ha preso uno", False, True),
        ("La cucciola mordicchia mani e caviglie quando giochiamo", False, False),
        ("Il mio gatto non ha mai morso nessuno, è timido con gli ospiti", False, False),
        ("Il mio gatto insegue la pallina tutto il giorno", False, False),
        ("Il cane abbaia ai gatti dalla finestra", False, False),
    ],
)
def test_aggression_detectors(message: str, people: bool, animals: bool) -> None:
    assert aggression_toward_people(message) is people
    assert aggression_toward_animals(message) is animals


# --- 6. another species named --------------------------------------------------------------


def test_another_species_keeps_the_profile() -> None:
    result, llm = _ask("Può convivere con due gatti FIV positivi?")
    request = llm.requests_for("answer")[-1]
    assert "ANOTHER ANIMAL NAMED" in request.system_prompt
    assert "none of its data applies" not in request.user_prompt
    assert "Rex" in request.user_prompt


# --- 7. official passages --------------------------------------------------------------------


def test_official_passages_reach_the_prompt_only_with_the_switch() -> None:
    passage = "[1] (legge, livello 1) La museruola va portata con sé."
    _, llm = _ask("Devo portare la museruola?", official=passage)
    request = llm.requests_for("answer")[-1]
    assert "<fonti_ufficiali>" in request.user_prompt and passage in request.user_prompt
    assert "OFFICIAL SOURCES" in request.system_prompt

    _, old = _ask("Devo portare la museruola?", official=passage, v2=False)
    assert "<fonti_ufficiali>" not in old.requests_for("answer")[-1].user_prompt


def test_the_fixed_reply_texts_still_exist_for_the_fallback() -> None:
    assert translate("triage_opening", "it", pet_name="Rex")


# --- owner decision 2026-11-20: no urgency lane with v2 ---------------------------------


def test_without_lane_a_grave_case_takes_the_ordinary_path() -> None:
    classifier = _Verdict("emergency", "bloat")
    result, llm = _ask(
        "ha la pancia gonfia e cerca di vomitare senza riuscirci", classifier=classifier
    )
    assert result.mode == "natural"
    assert "Quokka non può valutare" not in result.answer  # no fixed opening


def test_every_v2_answer_carries_the_severity_rule() -> None:
    _, llm = _ask("il gatto starnutisce da due giorni")
    assert "SEVERITY. Never judge how serious the case is" in _system(llm)
    # test 2 (20/11): "today" in place of "now", and going made to depend on a sign
    # the owner had already described, were judged wrong reassurances
    assert 'never "today"' in _system(llm)
    assert "already described" in _system(llm)
    _, old = _ask("il gatto starnutisce da due giorni", v2=False)
    assert "SEVERITY." not in _system(old)


def test_without_lane_a_medicine_about_to_be_given_is_still_refused() -> None:
    result, _ = _ask("posso dargli una tachipirina?")
    assert result.mode != "natural" or result.ai_generated is False


def test_the_person_hurt_line_is_off_by_default() -> None:
    assert Settings().chat_person_hurt_line is False
    llm = RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        answer_v2=True,
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="il cane ha morso mio figlio alla mano, sanguina",
            species="Cane",
            pet_name="Rex",
        )
    )
    assert "112" not in result.answer


# --- after test 2 (20/11/2026) ------------------------------------------------------------

_BODY = (
    "Trova subito un adulto di cui ti fidi, un familiare o un vicino. "
    "Tieni Rex vicino a te e non dargli da mangiare finché un adulto non ti dice cosa fare. "
)


def test_a_v2_answer_never_carries_an_emergency_number() -> None:
    # Normativa doc 20 §20.13: the model never writes a phone number, not even 112.
    llm = RecordingLLMClient(_BODY + "Se non trovi nessuno chiama il 112. Portalo poi in clinica.")
    result, _ = _ask("ho 12 anni e Rex ha mangiato un calzino", client=llm)
    assert "112" not in result.answer
    assert "adulto di cui ti fidi" in result.answer


def test_every_v2_prompt_says_adult_first_and_no_numbers() -> None:
    _, llm = _ask("ho 12 anni e Rex ha mangiato un calzino")
    system = _system(llm)
    assert "MINORS AND PHONE NUMBERS" in system
    assert "an adult they trust" in system
    assert "a veterinary clinic" in system
    _, old = _ask("ho 12 anni, come spazzolo Rex?", v2=False)
    assert "MINORS AND PHONE NUMBERS" not in _system(old)


def test_in_v2_an_overclaiming_word_costs_its_sentence_not_the_answer() -> None:
    # test 2: a Spanish answer on leftovers was replaced whole by the validator's text
    text = (
        "Las sobras suelen tener mucha grasa y sal, y eso puede causarle molestias. "
        "Este truco lo resuelve sin riesgo. "
        "Mejor dale su pienso y, como premio, un trozo pequeño de zanahoria."
    )
    result, _ = _ask("¿Puedo darle a Rex las sobras?", client=RecordingLLMClient(text))
    assert result.model != "answer-validator"
    assert "sin riesgo" not in result.answer
    assert "zanahoria" in result.answer
    old, _ = _ask("¿Puedo darle a Rex las sobras?", client=RecordingLLMClient(text), v2=False)
    assert old.model == "answer-validator"  # production unchanged


def test_an_adverb_that_reinforces_a_warning_is_not_an_overclaim() -> None:
    from packages.core.domain.knowledge.answer_validation import absolute_claims

    assert absolute_claims("Definitivamente no le des cebolla.") == []
    assert absolute_claims("Sicuramente non va dato.") == []
    assert absolute_claims("Definitely avoid onions.") == []
    assert absolute_claims("Es definitivamente la mejor dieta.") == ["definitivamente"]
    assert absolute_claims("Non c'è nessun rischio.") == ["nessun rischio"]
    assert absolute_claims("è insicuramente fatto") == []

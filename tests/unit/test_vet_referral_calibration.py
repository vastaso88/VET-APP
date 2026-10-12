"""Build 29: the vet is recommended when it is really needed — clearly, once,
with the reason and when — and not as a ritual closing on mild questions.
Deterministic: fake model, no provider calls."""

import pytest
from test_chat_orchestrator import ScriptedContentLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.evidence_synthesizer import _build_system_prompt
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.domain.conversation.referral_style import strip_ritual_referral
from packages.core.domain.conversation.request_kind import RequestKind
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

ADVICE = (
    "Masticare è normale a quattro mesi: i denti stanno cambiando. Dagli un osso di gomma "
    "e tieni le scarpe in alto."
)


# --- the instructions -------------------------------------------------------------


@pytest.mark.parametrize(
    ("kind", "may_ask"),
    [
        (RequestKind.DIRECT, False),
        (RequestKind.SYMPTOM, True),
        (RequestKind.SYMPTOM, False),
        (RequestKind.REPORT, False),
    ],
)
def test_no_instruction_asks_for_a_vet_timing_in_every_answer(
    kind: RequestKind, may_ask: bool
) -> None:
    prompt = build_system_prompt(kind, may_ask=may_ask, has_reference_material=False)

    # The old wording that made every symptom answer end with a visit.
    assert "how soon the vet should see it" not in prompt
    assert "how soon the vet should see the animal" not in prompt
    assert "routine ('parlane al prossimo controllo')" not in prompt
    # The rule that replaces it is always there.
    assert "WHEN TO SEND THE OWNER TO THE VET" in prompt
    assert "Recommend a visit ONLY when" in prompt


def test_the_rule_keeps_the_real_reasons_for_a_visit() -> None:
    prompt = build_system_prompt(RequestKind.SYMPTOM, may_ask=False, has_reference_material=False)

    for reason in (
        "difficulty breathing",
        "a seizure",
        "suspected poisoning",
        "blood in vomit, stools or urine",
        "more than 24 hours for not eating",
        "a dose",
        "a very young animal",
        "exotic species",
    ):
        assert reason in prompt, reason
    # Said once, with a reason and a time.
    assert "say it ONCE and clearly, with the reason and when" in prompt
    assert "'oggi stesso'" in prompt


def test_the_rule_forbids_ritual_closings_and_disclaimers() -> None:
    prompt = build_system_prompt(RequestKind.DIRECT, may_ask=False, has_reference_material=False)

    assert "do NOT recommend a visit" in prompt
    assert "at most ONE short conditional sentence" in prompt
    for ritual in ("'consulta il veterinario'", "'per sicurezza'", "'in caso di dubbio'"):
        assert ritual in prompt  # listed as what never to end with
    assert "never add a disclaimer that you are not a vet" in prompt


def test_a_report_with_normal_values_is_not_a_reason_to_ask_the_vet() -> None:
    prompt = build_system_prompt(RequestKind.REPORT, may_ask=False, has_reference_material=False)

    assert "5. only if something is outside the range" in prompt


def test_the_evidence_path_asks_for_referral_conditions_only_when_real() -> None:
    prompt = _build_system_prompt("it")

    assert "never a generic 'if in doubt'" in prompt


# --- the deterministic net ------------------------------------------------------------


@pytest.mark.parametrize(
    "closing",
    [
        "In caso di dubbi, consulta il veterinario.",
        "Per sicurezza, parlane comunque con il veterinario.",
        "Se hai domande, non esitare a chiedere al tuo veterinario.",
        "È sempre meglio sentire il veterinario per una valutazione personalizzata.",
        "Ricorda che questo non sostituisce una visita veterinaria.",
    ],
)
def test_a_ritual_closing_is_removed(closing: str) -> None:
    assert strip_ritual_referral(f"{ADVICE} {closing}") == ADVICE


def test_several_ritual_closings_in_a_row_are_all_removed() -> None:
    text = (
        f"{ADVICE}\n\nPer sicurezza parlane al veterinario. In caso di dubbi, "
        "consulta il veterinario."
    )

    assert strip_ritual_referral(text) == ADVICE


@pytest.mark.parametrize(
    "closing",
    [
        # A threshold: concrete, kept.
        "Se fra 2-3 giorni si gratta ancora, allora fallo vedere dal veterinario.",
        # A warning sign: kept even with a hedge word around it.
        "Per sicurezza, se vomita sangue portalo oggi stesso dal veterinario.",
        "Se smette di mangiare, per sicurezza chiama il veterinario.",
        # A real recommendation with a time, no hedge.
        "Portalo dal veterinario entro 24-48 ore.",
        # Not a referral at all.
        "Per sicurezza, tieni le scarpe in un armadio.",
    ],
)
def test_a_concrete_or_non_referral_sentence_is_kept(closing: str) -> None:
    text = f"{ADVICE} {closing}"

    assert strip_ritual_referral(text) == text


def test_a_hedge_in_the_middle_of_the_answer_is_not_touched() -> None:
    text = f"In caso di dubbi, chiedi al veterinario.\n\n{ADVICE}"

    assert strip_ritual_referral(text) == text


def test_an_answer_made_only_of_a_ritual_sentence_is_left_alone() -> None:
    text = "In caso di dubbi, consulta il veterinario."

    assert strip_ritual_referral(text) == text


# --- end to end with a fake model ----------------------------------------------------


def _answer(message: str, model_reply: str, species: str = "Cane") -> str:
    client = ScriptedContentLLMClient(model_reply)
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    return orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species=species, pet_name="Birba")
    ).answer


def test_a_mild_question_loses_the_ritual_closing() -> None:
    answer = _answer(
        "perché mastica le scarpe quando usciamo?",
        f"{ADVICE} In caso di dubbi, consulta il veterinario.",
    )

    assert answer == ADVICE


def test_a_mild_question_keeps_a_conditional_sentence_with_a_threshold() -> None:
    reply = f"{ADVICE} Se fra una settimana rosicchia ancora tutto, sentiamo un educatore."

    assert _answer("perché mastica le scarpe?", reply) == reply


def test_greetings_get_no_referral_instruction() -> None:
    client = ScriptedContentLLMClient("Prego, a presto!")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    orchestrator.answer(ChatOrchestratorInput(user_message="grazie!", species="Cane", pet_name="X"))

    prompt = client.requests[-1].system_prompt
    assert "encourage professional care" not in prompt
    assert "Do not mention the vet" in prompt


@pytest.mark.parametrize(
    ("message", "species"),
    [
        ("ha mangiato mezza tavoletta di cioccolato fondente", "Cane"),
        ("respira a bocca aperta e fa molta fatica a respirare", "Gatto"),
        ("ha le convulsioni e non si sveglia", "Cane"),
    ],
)
def test_red_flags_still_escalate_to_the_vet_without_the_model(message: str, species: str) -> None:
    client = ScriptedContentLLMClient("non dovrebbe essere chiamato")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species=species, pet_name="Birba")
    )

    assert result.mode == "triage"
    assert "veterinari" in result.answer
    assert client.requests == []


def test_a_red_flag_follow_up_keeps_its_safety_wording() -> None:
    # The rule-based reply after a reassuring answer to the safety question:
    # its "contact the vet if it does not improve" is deliberate and untouched.
    orchestrator = ChatOrchestrator(
        ScriptedContentLLMClient("x"), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="ha appena corso tanto al parco e fa caldo, ora si sta calmando",
            species="Cane",
            pet_name="Birba",
            awaiting_safety_clarification=True,
            safety_clarification_category="respiratory",
        )
    )

    assert result.mode == "safety_clarification_resolved"
    assert "contatta subito il veterinario" in result.answer

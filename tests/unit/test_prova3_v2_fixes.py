"""Prova 3 (22/11/2026), v2 path only (CHAT_ANSWER_V2, off in production): going now made to
depend on a sign is a delay, and first aid carries no explanation a source does not give."""

from __future__ import annotations

import json

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.natural_answer_prompt import SEVERITY_CHECK_PROMPT
from packages.core.domain.safety.delay_in_answer import (
    delays_or_reassures,
    makes_going_conditional,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

# the reply of prova 3 (V2+B) on "Si è sdraiato a 35 gradi e ansima forte"
_HEAT_IF_WORSE = (
    "Chiama il veterinario adesso, mentre lo rinfreschi.\n\n1. Portalo all'ombra.\n"
    "2. Bagnagli pancia e zampe con acqua fresca.\n\n"
    "Se barcolla, si accascia o le gengive diventano scure, portalo subito in clinica."
)
_HEAT_NOW = (
    "Portalo dal veterinario adesso: con 35 gradi e il fiatone forte può essere un colpo di "
    "calore. Mentre ti prepari, mettilo all'ombra e bagnalo con acqua fresca."
)


@pytest.mark.parametrize(
    "text",
    [
        _HEAT_IF_WORSE,
        "Antes de nada: si Canela ha comido hojas y sigue vomitando, llévala ahora mismo.",
        "If she keeps vomiting, take her to the vet right away.",
        "Wenn er taumelt, bringen Sie ihn sofort in die Klinik.",
        "S'il titube, emmenez-le tout de suite chez le vétérinaire.",
        "Portalo in clinica solo se peggiora.",
        "Take him in only if he gets worse.",
    ],
)
def test_going_now_on_a_condition_starts_the_check(text: str) -> None:
    assert makes_going_conditional(text)
    assert delays_or_reassures(text)


@pytest.mark.parametrize(
    "text",
    [
        _HEAT_NOW,
        "Please call your vet now and tell them what you saw.",
        "Llévala al veterinario ahora mismo: el lirio es muy tóxico para los gatos.",
        "Ogni quanto va spazzolato? Due o tre volte a settimana basta.",
    ],
)
def test_going_now_with_no_condition_does_not(text: str) -> None:
    assert not makes_going_conditional(text)


def test_the_check_treats_a_condition_on_going_as_a_delay() -> None:
    assert "going now made to depend on a sign" in SEVERITY_CHECK_PROMPT
    assert "with no condition" in SEVERITY_CHECK_PROMPT


def test_a_serious_case_sent_only_if_worse_is_rewritten_to_now() -> None:
    check = json.dumps({"serious": True, "delays": True, "rewrite": _HEAT_NOW})
    llm = RecordingLLMClient(_HEAT_IF_WORSE, by_purpose={"severity_check": check})
    orchestrator = ChatOrchestrator(
        llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=True
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Si è sdraiato a 35 gradi e ansima forte. Lo bagno con acqua fredda?",
            species="Cane",
            pet_name="Zefiro",
        )
    )

    assert llm.requests_for("severity_check")
    assert "solo" not in result.answer and "Se barcolla" not in result.answer
    assert result.answer.startswith("Portalo dal veterinario adesso")


def test_every_v2_prompt_has_first_aid_without_own_explanations() -> None:
    llm = RecordingLLMClient("Mettilo all'ombra e chiama il veterinario adesso.")
    orchestrator = ChatOrchestrator(
        llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=True
    )
    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="ansima forte al sole", species="Cane", pet_name="Zefiro"
        )
    )
    for request in llm.requests_for("answer"):
        assert "FIRST AID AS GIVEN" in request.system_prompt
        assert "never say that cold water is dangerous" in request.system_prompt


def test_production_prompt_is_unchanged() -> None:
    llm = RecordingLLMClient("Mettilo all'ombra e chiama il veterinario adesso.")
    orchestrator = ChatOrchestrator(
        llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=False
    )
    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="ogni quanto lo spazzolo?", species="Cane", pet_name="Zefiro"
        )
    )
    for request in llm.requests_for("answer"):
        assert "FIRST AID AS GIVEN" not in request.system_prompt

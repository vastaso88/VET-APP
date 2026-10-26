"""Security audit LLM-5: a dose the model wrote on its own never reaches the
owner; the fixed dosage text takes its place, in every language."""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.knowledge.dose_in_answer import find_dosage
from packages.core.domain.localization import translate
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

DOSES = {
    "it": [
        "Puoi dargli 10 mg/kg di metacam una volta al giorno.",
        "Dagli mezza compressa di tachipirina ogni 8 ore e vedrai che sta meglio.",
        "Per il dolore vanno bene 2 gocce di novalgina tre volte al giorno.",
    ],
    "en": [
        "Give 5 mg of meloxicam twice a day with food.",
        "You can give one tablet of carprofen every 12 hours.",
        "A common dose is 0.1 mg/kg of meloxicam.",
    ],
    "es": [
        "Dale 20 mg de ibuprofeno cada 8 horas.",
        "Puedes darle media pastilla de paracetamol dos veces al día.",
        "La dosis habitual es 2 mg/kg de carprofeno.",
    ],
    "de": [
        "Geben Sie 1 Tablette Metacam alle 12 Stunden.",
        "Sie können ihm 50 mg Carprofen zweimal täglich geben.",
        "Üblich sind 0,2 mg/kg Meloxicam.",
    ],
    "fr": [
        "Donnez-lui 2 gouttes de Doliprane trois fois par jour.",
        "Vous pouvez lui donner un demi-comprimé d'aspirine toutes les 8 heures.",
        "La dose habituelle est de 4 mg/kg de carprofène.",
    ],
}
HARMLESS = [
    "La creatinina è 2,4 mg/dl, appena sopra il massimo di 1,8 mg/dl.",
    "Pesa 20 kg, un buon peso per la sua taglia.",
    "Offrigli 200 ml di acqua fresca più volte al giorno.",
    "Il Metacam è un antinfiammatorio che il veterinario prescrive per il dolore.",
    "Dagli 120 g di crocchette due volte al giorno.",
    "His glucose was 110 mg/dl, within the normal range.",
    "Das Zahnfleisch ist rosa und er wiegt 12 kg.",
    "Le vétérinaire décidera du traitement ; en attendant, de l'eau fraîche.",
    "Un cucciolo mangia tre volte al giorno fino ai sei mesi.",
]


@pytest.mark.parametrize(
    "answer",
    [pytest.param(a, id=f"{lang}: {a[:40]}") for lang, items in DOSES.items() for a in items],
)
def test_a_dose_in_the_reply_is_found(answer: str) -> None:
    assert find_dosage(answer) is not None, answer


@pytest.mark.parametrize("answer", HARMLESS)
def test_values_weights_food_and_drug_names_alone_are_not_doses(answer: str) -> None:
    assert find_dosage(answer) is None, answer


def test_a_dose_quoted_from_the_owners_document_is_the_vets_not_the_models() -> None:
    reply = "Il veterinario ha prescritto 1 compressa al giorno di Metacam per 5 giorni."
    record = "Terapia: Metacam 1 compressa al giorno per 5 giorni"

    assert find_dosage(reply) is not None
    assert find_dosage(reply, allowed_text=record) is None


@pytest.mark.parametrize("language", ["it", "en", "es", "de", "fr"])
def test_the_orchestrator_replaces_the_reply_with_the_fixed_dosage_text(language: str) -> None:
    client = RecordingLLMClient(DOSES[language][0])
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="zoppica un po' dopo la passeggiata, cosa posso fare?",
            species="Cane",
            pet_name="Rex",
            language=language,
        )
    )

    assert result.answer == translate("dosage_answer", language)
    assert result.model == "answer-validator"
    assert result.ai_generated is False
    assert translate("dosage_rewritten_limit", language) in result.limitations
    assert len(client.requests_for("answer")) == 1


def test_a_clean_reply_goes_through_unchanged() -> None:
    client = RecordingLLMClient("Tienilo a riposo un paio di giorni e passeggiate brevi.")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="zoppica un po' dopo la passeggiata, cosa posso fare?",
            species="Cane",
            pet_name="Rex",
        )
    )

    assert result.model != "answer-validator"
    assert "riposo" in result.answer

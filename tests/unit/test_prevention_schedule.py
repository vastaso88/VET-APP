"""Prevention schedule questions (repositioning, docs/product/11 §4 2.3).

"Ogni quanto il vermifugo?" is not a dose request: it gets the prevention
principles and "product and frequency decided by the vet". A dose
(mg/kg, tablets, ml, "quanto ne do") is still refused before the model.
"""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.knowledge.dose_in_answer import find_dosage
from packages.core.domain.safety.dosage_request import (
    is_dosage_request,
    is_prevention_schedule_question,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

SCHEDULE: tuple[tuple[str, str], ...] = (
    ("it", "ogni quanto va fatto il vermifugo?"),
    ("it", "Ogni quanto devo dare l'antiparassitario al gatto?"),
    ("it", "quante volte all'anno si fa l'antipulci?"),
    ("it", "con che frequenza vanno fatti i richiami dei vaccini?"),
    ("it", "a che età si fa la prima sverminazione a un cucciolo?"),
    ("it", "quando va fatto il vaccino al coniglio?"),
    ("en", "How often should I deworm my dog?"),
    ("en", "how often does a cat need flea treatment?"),
    ("en", "when should a puppy get its first vaccination?"),
    ("es", "¿Cada cuánto hay que desparasitar a un perro?"),
    ("es", "¿Con qué frecuencia se vacuna a un gato?"),
    ("de", "Wie oft muss ich meinen Hund entwurmen?"),
    ("de", "Wann sollte ein Welpe geimpft werden?"),
    ("fr", "Tous les combien faut-il vermifuger un chat ?"),
    ("fr", "À quelle fréquence faire l'antiparasitaire ?"),
)

DOSES: tuple[tuple[str, str], ...] = (
    ("it", "quante compresse di vermifugo gli do? pesa 12 kg"),
    ("it", "quanti ml di antiparassitario per un gatto di 4 kg?"),
    ("it", "quanto ne do di vermifugo?"),
    ("it", "mg/kg del vermifugo per un cane?"),
    ("en", "how many tablets of wormer for a 12 kg dog?"),
    ("en", "how much flea treatment do I give a kitten?"),
    ("es", "¿cuántos comprimidos de desparasitante le doy?"),
    ("de", "wie viel Wurmkur gebe ich einem 5 kg Hund?"),
    ("fr", "combien de comprimés de vermifuge pour un chat de 4 kg ?"),
)


@pytest.mark.parametrize(("language", "message"), SCHEDULE)
def test_how_often_a_preventive_is_done_is_not_a_dose_request(language: str, message: str) -> None:
    assert is_prevention_schedule_question(message), (language, message)
    assert not is_dosage_request(message), (language, message)


@pytest.mark.parametrize(("language", "message"), DOSES)
def test_an_amount_of_a_preventive_is_still_a_dose_request(language: str, message: str) -> None:
    assert not is_prevention_schedule_question(message), (language, message)
    assert is_dosage_request(message), (language, message)


def test_the_schedule_question_reaches_the_model_with_the_prevention_note() -> None:
    client = RecordingLLMClient()
    result = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message="ogni quanto va fatto il vermifugo?", species="Cane", pet_name="Birba"
        )
    )

    assert result.mode != "dosage_refusal", result.mode
    assert client.requests
    system_prompt = client.requests[-1].system_prompt
    assert "PREVENTION SCHEDULE" in system_prompt
    assert "decided by the vet" in system_prompt


def test_the_dose_of_a_preventive_is_still_refused_before_the_model() -> None:
    client = RecordingLLMClient()
    ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message="quante compresse di vermifugo gli do? pesa 12 kg",
            species="Cane",
            pet_name="Birba",
        )
    )

    assert client.requests == []


def test_the_answer_validator_lets_a_prevention_principle_through_but_not_an_amount() -> None:
    principle = (
        "Il vermifugo protegge dai parassiti intestinali; la frequenza dipende da età, "
        "stile di vita e zona, e la decide il veterinario insieme al prodotto."
    )
    amount = "Di solito si dà 1 compressa di vermifugo ogni 10 kg di peso."

    assert find_dosage(principle) is None
    assert find_dosage(amount) is not None

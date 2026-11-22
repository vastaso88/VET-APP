"""QK-19: the chat answer path, recorded as it is, before and after the natural-answer
preparation is moved out of ChatOrchestrator._generate_natural_answer.

Every scenario drives the PUBLIC ``ChatOrchestrator.answer`` with a scripted fake model (no
inference, no network) and an anonymizer that records the texts it is given. What is pinned,
per scenario and per step, with the v2 flag off and on:

* the model requests, in order: purpose, model class, token ceiling, cacheable prefix length
  and a SHA-256 of the full system and user prompts (plus a readable head), so a prompt that
  changes by one character shows up;
* the whole result (answer, mode, state, flags, sources, provider, model, ...);
* the texts handed to the anonymizer, in order (nothing personal may reach a provider that
  did not pass through it).

The golden file ``golden/natural_answer_characterization.json`` was produced from the
orchestrator BEFORE the extraction. It pins prompt text on purpose: when a prompt is edited
for a real reason, regenerate it and read the diff::

    QK19_REGENERATE_GOLDEN=1 uv run pytest tests/unit/test_natural_answer_characterization.py

The golden is read with ``json.load`` (never as raw text: the repository checks out with CRLF).
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.llm_budget import QuotaExhausted
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
    InMemoryClinicalEventRepository,
)
from packages.shared.errors.base import ProviderError

GOLDEN = Path(__file__).parent / "golden" / "natural_answer_characterization.json"
FIXED_NOW = datetime(2026, 11, 20, 9, 0, tzinfo=UTC)
TODAY = date(2026, 11, 22)
DEFAULT_ANSWER = "Risposta di prova, concreta e breve."
LONG_ANSWER = " ".join(["Una frase lunga che spiega con calma ogni singolo aspetto."] * 40)
QUESTIONS_ONLY = "Da quando succede? Mangia normalmente? Ha altri sintomi?"


class _ScriptedModel:
    """Answers by purpose from a script: a list is used in order, the last item repeating."""

    def __init__(self, script: dict[str, list[str | Exception]]) -> None:
        self._script = {purpose: list(items) for purpose, items in script.items()}
        self._used: dict[str, int] = {}
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        items = self._script.get(request.purpose) or [DEFAULT_ANSWER]
        index = min(self._used.get(request.purpose, 0), len(items) - 1)
        self._used[request.purpose] = self._used.get(request.purpose, 0) + 1
        outcome = items[index]
        if isinstance(outcome, Exception):
            raise outcome
        return LLMResponse(
            content=outcome,
            provider="fake",
            model="fake-model",
            token_count=len(request.system_prompt + request.user_prompt + outcome) // 4,
            finish_reason="stop",
        )


class _RecordingAnonymizer:
    """Records every text, redacts two synthetic names with a placeholder."""

    def __init__(self) -> None:
        self.texts: list[str] = []

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        self.texts.append(request.text)
        text = request.text
        count = 0
        for name in ("Mario Rossi", "Argo"):
            if name in text:
                text = text.replace(name, "<NOME>")
                count += 1
        return PiiAnonymizationResult(anonymized_text=text, redaction_count=count)


@dataclass
class Scenario:
    message: str
    species: str = "dog"
    pet_name: str = "Rex"
    script: dict[str, list[str | Exception]] = field(default_factory=dict)
    extra: dict[str, Any] = field(default_factory=dict)  # ChatOrchestratorInput fields
    options: dict[str, Any] = field(default_factory=dict)  # ChatOrchestrator kwargs
    steps: list[dict[str, Any]] = field(default_factory=list)  # more turns, same orchestrator
    cache: bool = False
    records: bool = False  # a clinical record for pet-1 and the retriever for it
    v2_only: bool = False


def _history(*pairs: tuple[str, str]) -> list[ChatMessage]:
    return [ChatMessage(role=role, content=text, created_at=FIXED_NOW) for role, text in pairs]


SEVERE = json.dumps(
    {"serious": True, "delays": True, "rewrite": "Vai dal veterinario adesso, senza aspettare."}
)
REPORT_TEXT = "Esami del sangue del 12 novembre: creatinina 1,9 mg/dl, urea 80 mg/dl."

SCENARIOS: dict[str, Scenario] = {
    # --- ordinary answers --------------------------------------------------------------
    "care_question": Scenario("Ogni quanto devo cambiare la lettiera?", species="cat"),
    "long_history": Scenario(
        "e poi cosa faccio?",
        extra={
            "conversation_history": _history(
                ("user", "il mio cane mastica le scarpe"),
                ("assistant", "Succede spesso ai cuccioli: serve un'alternativa."),
            )
        },
    ),
    "english_reply": Scenario("How often should I brush my dog?", extra={"language": "en"}),
    "prevention_schedule": Scenario("Ogni quanto devo fare l'antiparassitario al cane?"),
    "plant_diet": Scenario("Posso dare solo verdure al mio gatto?", species="cat"),
    "future_animal": Scenario("Vorrei prendere un cane: quale razza è tranquilla?"),
    "owner_health_v2": Scenario("Mi fa male lo stomaco da ieri", v2_only=True),
    # --- the answer written by the model is reshaped -----------------------------------
    "shortened_when_long": Scenario(
        "Come si addestra un cucciolo?",
        script={"answer": [LONG_ANSWER], "shorten": ["Premia i comportamenti giusti, con calma."]},
    ),
    "shorten_fails_keeps_long": Scenario(
        "Come si addestra un cucciolo?",
        script={"answer": [LONG_ANSWER], "shorten": [ProviderError("down")]},
    ),
    "question_only_is_retried": Scenario(
        "Dimmi cosa fare, senza farmi altre domande, il cane scava in giardino.",
        script={"answer": [QUESTIONS_ONLY], "answer_retry": ["Dagli uno spazio dove scavare."]},
    ),
    "ritual_referral_stripped": Scenario(
        "Il gatto fa le fusa quando dorme?",
        species="cat",
        script={
            "answer": [
                "Le fusa sono un segno di benessere nella maggior parte dei casi. "
                "Per qualsiasi dubbio consulta il veterinario."
            ]
        },
    ),
    "bare_yes_no_replaced": Scenario(
        "Argo ha il cancro? Rispondi solo sì o no.", script={"answer": ["NO"]}
    ),
    "price_invented_dropped": Scenario(
        "Cosa serve per il cane di mia sorella?",
        script={"answer": ["Una visita costa circa 60 euro, poi si vede."]},
    ),
    "dose_in_answer_refused": Scenario(
        "Cosa posso dare al cane per il dolore?",
        script={"answer": ["Puoi dargli 10 mg/kg di paracetamolo ogni otto ore."]},
    ),
    "dose_part_question": Scenario("Il CBD funziona per l'artrosi? Quante gocce?"),
    "phone_number_cut_v2": Scenario(
        "Cosa faccio se il cane ha caldo?",
        script={"answer": ["Mettilo all'ombra e dagli acqua. Se peggiora chiama il 112 subito."]},
    ),
    "wrong_species_mention": Scenario(
        "Ogni quanto vanno puliti i denti?",
        species="cat",
        script={"answer": ["Il tuo cane dovrebbe lavarsi i denti ogni giorno con calma."]},
    ),
    "validator_blocks_absolute_claim": Scenario(
        "Questo integratore funziona?",
        script={"answer": ["Funziona sempre, è garantito al 100% e senza alcun rischio."]},
    ),
    "severity_check_rewrites_v2": Scenario(
        "Da ieri zoppica, cosa faccio?",
        v2_only=True,
        script={
            "answer": ["Domani mattina porta il cane dal veterinario, nel frattempo osservalo."],
            "severity_check": [SEVERE],
        },
    ),
    "open_case_elsewhere_v2": Scenario(
        "Che pettorina mi consigli?",
        v2_only=True,
        extra={
            "recent_other_chats": _history(
                ("user", "ieri sera ha mangiato un giglio"), ("assistant", "Vai dal vet adesso.")
            )
        },
        script={"severity_check": ['{"serious": false, "delays": false, "rewrite": ""}']},
    ),
    # --- errors and fallbacks ----------------------------------------------------------
    "provider_error": Scenario(
        "Come si lava un gatto?", species="cat", script={"answer": [ProviderError("boom")]}
    ),
    "quota_exhausted": Scenario(
        "Come si lava un gatto?",
        species="cat",
        script={"answer": [QuotaExhausted(retry_after_seconds=60)]},
    ),
    # --- behaviour and the questions asked first ---------------------------------------
    "behaviour_anamnesis": Scenario("Il mio cane ringhia ogni tanto."),
    "behaviour_warning_signal": Scenario("Il cane ringhia quando mi avvicino alla ciotola."),
    "dangerous_behaviour_v2": Scenario("Il mio cane ha morso un bambino ieri.", v2_only=True),
    "vague_picture": Scenario("È strano, non so spiegarlo."),
    "stop_asking": Scenario(
        "Basta domande, il gatto vomita ogni tanto, dimmi cosa pensi.", species="cat"
    ),
    # --- the owner's own case, the second try ------------------------------------------
    "not_helped_escalates": Scenario(
        "Non hai capito, il mio gatto continua a vomitare.",
        species="cat",
        extra={"escalate_health": True},
        options={"strong_model": "fake-strong"},
    ),
    "not_helped_without_strong_model": Scenario(
        "Non hai capito, il mio gatto continua a vomitare.",
        species="cat",
        extra={"escalate_health": True},
    ),
    # --- another animal, attachments, reminders ----------------------------------------
    "other_animal": Scenario("Il mio gatto vomita da due giorni.", species="dog"),
    "photo_context": Scenario(
        "Cosa ne pensi?",
        extra={"photo_context": "Foto di una zampa gonfia con una piccola ferita rossa."},
    ),
    "attachment_unreadable": Scenario("Guarda il referto.", extra={"attachment_unreadable": True}),
    "photo_reading_off": Scenario("Cosa vedi nella foto?", extra={"photo_reading_off": True}),
    "photo_mentioned_not_attached": Scenario("Ti allego la foto della zampa."),
    "reminders_context": Scenario(
        "Posso fargli il bagno?",
        extra={"reminders_context": "Antibiotico ogni 12 ore fino al 25 novembre."},
    ),
    "owner_name_redacted": Scenario("Sono Mario Rossi, il cane tossisce di notte."),
    "official_sources_v2": Scenario(
        "Devo mettere la museruola al cane?",
        v2_only=True,
        extra={
            "official_sources": "Art. 1 dell'ordinanza: obbligo di guinzaglio in luogo pubblico."
        },
    ),
    # --- consents and the record -------------------------------------------------------
    "record_consent_given": Scenario(
        "Il cane tossisce, cosa può essere?",
        records=True,
        extra={"pet_id": "pet-1", "medical_record_consent": True},
    ),
    "record_consent_refused": Scenario(
        "Il cane tossisce, cosa può essere?",
        records=True,
        extra={"pet_id": "pet-1", "medical_record_consent": False},
    ),
    "record_consent_unknown": Scenario(
        "Il cane tossisce, cosa può essere?", records=True, extra={"pet_id": "pet-1"}
    ),
    # --- sources -----------------------------------------------------------------------
    "foreign_country_duty": Scenario("Devo microchippare il cane per legge nel Regno Unito?"),
    "pinned_duty_note": Scenario("Devo registrare il mio cane all'anagrafe canina?"),
    # --- cache -------------------------------------------------------------------------
    "cache_miss_then_hit": Scenario(
        "Quanto vive un criceto?", species="hamster", cache=True, steps=[{}, {}]
    ),
    "cache_not_for_a_personal_case": Scenario(
        "Il mio cane può mangiare le fragole?", cache=True, steps=[{}, {}]
    ),
    "cache_not_for_a_name": Scenario(
        "Sono Mario Rossi: i cani possono mangiare le fragole?", cache=True, steps=[{}, {}]
    ),
    "cache_not_after_replacement": Scenario(
        "Argo ha il cancro? Rispondi solo sì o no.",
        cache=True,
        script={"answer": ["NO"]},
        steps=[{}, {}],
    ),
    # --- urgency (the natural path is not reached: fixed texts and rules) -------------
    "urgent_collapse": Scenario("Il mio cane è collassato e non risponde."),
    "urgent_toxin": Scenario("Il gatto ha mangiato del cioccolato, cosa faccio?", species="cat"),
    "urgent_breathing": Scenario("Il mio gatto respira male da stamattina.", species="cat"),
    "urgent_follow_up": Scenario(
        "e adesso?",
        extra={
            "conversation_history": _history(
                ("user", "il cane è collassato"),
                ("assistant", "È un'emergenza: portalo subito in clinica."),
            )
        },
    ),
    "self_harm": Scenario("Non voglio più vivere dopo la morte del mio cane."),
    "minor_account": Scenario(
        "Il mio cane è morto, non ce la faccio più.", extra={"owner_is_minor": True}
    ),
}


def _orchestrator(
    scenario: Scenario, v2: bool, model: _ScriptedModel, anonymizer: _RecordingAnonymizer
) -> ChatOrchestrator:
    options: dict[str, Any] = {"answer_v2": v2}
    if scenario.cache:
        options["answer_cache"] = InMemoryAnswerCacheRepository()
    if scenario.records:
        repository = InMemoryClinicalEventRepository(
            seed=[ClinicalEvent(pet_id="pet-1", title="Richiamo vaccinale", subtitle="completo")]
        )
        options["medical_record_context_retriever"] = MedicalRecordContextRetriever(repository)
    options.update(scenario.options)
    return ChatOrchestrator(model, InMemoryEvidenceRetriever(), anonymizer, **options)  # type: ignore[arg-type]


def _request_record(request: LLMGenerationRequest) -> dict[str, Any]:
    return {
        "purpose": request.purpose,
        "model_class": request.model_class,
        "max_tokens": request.max_tokens,
        "temperature": request.temperature,
        "json_mode": request.json_mode,
        "cacheable_system_chars": request.cacheable_system_chars,
        "system_sha": hashlib.sha256(request.system_prompt.encode()).hexdigest(),
        "user_sha": hashlib.sha256(request.user_prompt.encode()).hexdigest(),
        "system_len": len(request.system_prompt),
        "user_len": len(request.user_prompt),
        "user_head": request.user_prompt[:160],
    }


def run_scenario(name: str, v2: bool) -> list[dict[str, Any]]:
    """The recorded steps of one scenario (one entry per turn)."""
    scenario = SCENARIOS[name]
    model = _ScriptedModel(scenario.script)
    anonymizer = _RecordingAnonymizer()
    orchestrator = _orchestrator(scenario, v2, model, anonymizer)
    recorded: list[dict[str, Any]] = []
    for step in scenario.steps or [{}]:
        model.requests.clear()
        anonymizer.texts.clear()
        values: dict[str, Any] = {
            "user_message": scenario.message,
            "species": scenario.species,
            "pet_name": scenario.pet_name,
            "today": TODAY,
            **scenario.extra,
            **step,
        }
        result = orchestrator.answer(ChatOrchestratorInput(**values))
        recorded.append(
            {
                "requests": [_request_record(r) for r in model.requests],
                "result": result.model_dump(mode="json"),
                "anonymized": list(anonymizer.texts),
            }
        )
    return recorded


def _cases() -> list[tuple[str, bool]]:
    cases = []
    for name, scenario in SCENARIOS.items():
        for v2 in (False, True):
            if scenario.v2_only and not v2:
                continue
            cases.append((name, v2))
    return cases


def _key(name: str, v2: bool) -> str:
    return f"{name}|{'v2' if v2 else 'v1'}"


def _load_golden() -> dict[str, Any]:
    with GOLDEN.open(encoding="utf-8") as handle:
        loaded: dict[str, Any] = json.load(handle)
    return loaded


def test_regenerate_golden_when_asked() -> None:
    if os.environ.get("QK19_REGENERATE_GOLDEN") != "1":
        pytest.skip("set QK19_REGENERATE_GOLDEN=1 to rewrite the golden file")
    golden = {_key(name, v2): run_scenario(name, v2) for name, v2 in _cases()}
    GOLDEN.parent.mkdir(parents=True, exist_ok=True)
    with GOLDEN.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(golden, handle, ensure_ascii=False, indent=1, sort_keys=True)
        handle.write("\n")


@pytest.mark.skipif(
    os.environ.get("QK19_REGENERATE_GOLDEN") == "1", reason="the golden is being rewritten"
)
@pytest.mark.parametrize(("name", "v2"), _cases(), ids=[_key(n, v) for n, v in _cases()])
def test_the_answer_path_is_unchanged(name: str, v2: bool) -> None:
    golden = _load_golden()
    expected = golden[_key(name, v2)]

    assert run_scenario(name, v2) == expected, (
        f"{_key(name, v2)} differs from the recorded behaviour. If a prompt or a rule was "
        "changed ON PURPOSE, regenerate: QK19_REGENERATE_GOLDEN=1 pytest "
        "tests/unit/test_natural_answer_characterization.py and read the diff."
    )


def test_every_scenario_has_a_recording() -> None:
    assert set(_load_golden()) == {_key(name, v2) for name, v2 in _cases()}


def test_the_recorded_paths_cover_what_the_extraction_touches() -> None:
    """A guard on the harness itself: the scenarios do reach the natural path with the calls
    the extraction must keep (otherwise the golden would be pinning something else)."""
    golden = _load_golden()

    def purposes(name: str, v2: bool, step: int = 0) -> list[str]:
        return [r["purpose"] for r in golden[_key(name, v2)][step]["requests"]]

    assert purposes("care_question", False) == ["answer"]
    assert purposes("shortened_when_long", False) == ["answer", "shorten"]
    assert purposes("question_only_is_retried", False) == ["answer", "answer_retry"]
    assert purposes("severity_check_rewrites_v2", True)[0] == "answer"
    assert "severity_check" in purposes("severity_check_rewrites_v2", True)
    assert purposes("cache_miss_then_hit", False, 0) == ["answer"]
    assert purposes("cache_miss_then_hit", False, 1) == []  # the hit: no model call at all
    assert purposes("provider_error", False) == ["answer"]
    strong = [r["model_class"] for r in golden[_key("not_helped_escalates", False)][0]["requests"]]
    assert "strong" in strong
    assert re.fullmatch(
        r"[0-9a-f]{64}", golden[_key("care_question", False)][0]["requests"][0]["system_sha"]
    )

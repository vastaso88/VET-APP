"""The synthetic users' report of 2026-11-07 (10 owners, Haiku 5.5): fixed
behaviour at the orchestrator and chat-service level."""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient
from test_chat_orchestrator import ScriptedContentLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.urgency_classifier import (
    UrgencyClassifier,
    UrgencyVerdict,
)
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.knowledge.dose_in_answer import find_dosage
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.safety.clarification_fit import (
    clarifying_question_fits,
    denies_the_emergency,
    describes_a_grave_picture,
    injury_is_on_a_person,
    is_a_past_event,
)
from packages.core.domain.safety.harmful_requests import is_minor_writing
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ValidationError


class _Classifier(UrgencyClassifier):
    def __init__(self, level: str, category: str | None = None) -> None:  # noqa: D107
        self.level, self.category, self.calls = level, category, 0

    def classify(self, message: str, species: str) -> UrgencyVerdict | None:
        self.calls += 1
        return UrgencyVerdict(level=self.level, category=self.category)


def _ask(
    message: str,
    *,
    species: str = "Cane",
    name: str = "Toby",
    sex: str | None = None,
    client: RecordingLLMClient | ScriptedContentLLMClient | None = None,
    language: str = "it",
    history: tuple[tuple[str, str], ...] = (),
    awaiting: str | None = None,
    orchestrator: ChatOrchestrator | None = None,
    user_daily_limit: int | None = None,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient | ScriptedContentLLMClient]:
    llm = client or RecordingLLMClient()
    orchestrator = orchestrator or ChatOrchestrator(
        llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species=species,
            pet_name=name,
            sex=sex,
            language=language,
            owner_id="owner-1",
            conversation_history=[ChatMessage(role=r, content=c) for r, c in history],
            awaiting_safety_clarification=awaiting is not None,
            safety_clarification_category=awaiting,
            user_daily_limit=user_daily_limit,
        )
    )
    return result, llm


# --- P1. an emergency never stops at the daily limit ------------------------------


def _exhausted_budget(owner_id: str = "owner-1") -> LlmBudget:
    budget = LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={"main": 10_000_000},
        default_budget=10_000_000,
        user_daily_limit=1,
    )
    budget.admit(owner_id=owner_id, models=["main"], exempt=False, user_daily_limit=1)
    return budget


def test_the_fixed_lists_catch_the_blocked_cases_before_any_limit() -> None:
    for message, species in (
        (
            "Assunta adesso non riesce a fare pipi e sta ferma nella lettiera e piange, il "
            "pancino e duro",
            "Gatto",
        ),
        (
            "Pixel sta in piedi sulla lettiera e urina a gocce, fa forza e miagola, da stamattina",
            "Gatto",
        ),
        (
            "Nebbia ha appena mangiato un pezzo di gomma e ora vomita e sbava, ha la pancia dura",
            "Altro",
        ),
    ):
        orchestrator = ChatOrchestrator(
            RecordingLLMClient(),
            InMemoryEvidenceRetriever(),
            NoopPiiAnonymizer(),
            usage_budget=_exhausted_budget(),
            answer_models=["main"],
        )
        result, _ = _ask(message, species=species, orchestrator=orchestrator, user_daily_limit=1)
        assert result.mode in ("triage", "safety_clarification"), (message, result.answer[:80])


def test_the_classifier_runs_before_the_limit_and_an_emergency_goes_on() -> None:
    classifier = _Classifier("emergency", "other")
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        usage_budget=_exhausted_budget(),
        answer_models=["main"],
        urgency_classifier=classifier,
    )
    result, _ = _ask(
        "da stamattina è strano, sta accucciato e geme ogni tanto",
        orchestrator=orchestrator,
        user_daily_limit=1,
    )

    assert classifier.calls == 1
    assert result.mode == "triage"


def test_the_limit_message_puts_safety_first_in_the_owners_language() -> None:
    for language, fragment in (
        ("it", "un caso grave non aspetta"),
        ("en", "a serious case does not wait"),
        ("de", "Ein ernster Fall wartet nicht"),
    ):
        orchestrator = ChatOrchestrator(
            RecordingLLMClient(),
            InMemoryEvidenceRetriever(),
            NoopPiiAnonymizer(),
            usage_budget=_exhausted_budget(),
            answer_models=["main"],
        )
        result, _ = _ask(
            "quante volte al giorno deve mangiare?",
            orchestrator=orchestrator,
            language=language,
            user_daily_limit=1,
        )
        assert result.mode == "user_limit_reached"
        assert result.answer.startswith(("Se Toby", "If Toby", "Wenn es Toby"))
        assert fragment in result.answer
        assert "tutti i " not in result.answer and " messaggi " not in result.answer
        assert "plan_limit" not in result.answer and not result.answer.startswith("Per oggi")


# --- P5. the per-pet chat limit and empty conversations -------------------------------


def _service(limit_per_pet: int = 1, budget: LlmBudget | None = None) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        usage_budget=budget,
        answer_models=["main"],
    )
    return SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pets,
        max_active_conversations_per_pet=limit_per_pet,
    )


def test_an_emergency_goes_on_in_the_most_recent_chat_when_the_pet_limit_is_reached() -> None:
    service = _service(limit_per_pet=1)
    first = service.execute(
        SendChatMessageInput(
            owner_id="owner-a", pet_id="pet-a", user_message="quanto deve dormire?"
        )
    )
    with pytest.raises(ValidationError, match="conversation_limit_reached: Hai già 1 chat"):
        service.execute(
            SendChatMessageInput(
                owner_id="owner-a", pet_id="pet-a", user_message="e quanto mangia?"
            )
        )

    urgent = service.execute(
        SendChatMessageInput(
            owner_id="owner-a", pet_id="pet-a", user_message="ha mangiato il veleno per topi"
        )
    )

    assert urgent.mode == "triage"
    assert urgent.conversation.id == first.conversation.id


def test_a_message_the_daily_limit_stops_does_not_create_a_chat() -> None:
    service = _service(limit_per_pet=3, budget=_exhausted_budget("owner-a"))

    output = service.execute(
        SendChatMessageInput(
            owner_id="owner-a", pet_id="pet-a", user_message="quanto deve dormire?"
        )
    )

    assert output.mode == "user_limit_reached"
    assert service._repository.list_by_pet("pet-a") == []  # noqa: SLF001


# --- P6. the substance of the last message ---------------------------------------------------


def test_a_substance_the_owner_rules_out_is_not_the_one_asked_about() -> None:
    result, client = _ask(
        "No aspetta, io parlavo del Rimadyl per la zampa, non dell'aglio. Posso dargli mezza "
        "pastiglia sì o no? Dimmelo chiaro.",
        name="Lampo",
    )

    assert client.requests == []
    assert "aglio" not in result.answer.lower() and "globuli rossi" not in result.answer
    assert result.model == "dosage-guard"


def test_antibiotic_drops_for_another_animal_do_not_get_the_paracetamol_text() -> None:
    result, client = _ask(
        "The vet gave antibiotic drops for the water. Can I just put the drops in Poppy's water "
        "as well to be safe?",
        species="Uccello",
        name="Poppy",
        language="en",
        history=(
            ("user", "Pip was given paracetamol once, was that bad?"),
            ("assistant", "(earlier answer)"),
        ),
    )

    assert "Paracetamol" not in result.answer
    assert client.requests, "a real question for the model"


def test_a_refused_generic_amount_in_the_models_answer_is_not_a_dose() -> None:
    assert find_dosage("No, nemmeno una goccia di grappa: è alcol.") is None
    assert find_dosage("Dagli 2 gocce di metacam al giorno.") is not None


# --- P3, P4. action first, questions that fit, past events ------------------------------------


def test_a_grave_picture_gets_the_action_before_any_question() -> None:
    assert describes_a_grave_picture("il ratto ha la bocca aperta e blu")
    assert describes_a_grave_picture("è caduta da un metro, è a terra e non si muove")

    result, _ = _ask(
        "URGENTE: Kernel è appena caduta dalla mia mano da 1 metro, è a terra, respira con la "
        "bocca aperta e non si muove.",
        species="Piccoli mammiferi",
        name="Kernel",
        sex="Femmina",
    )

    assert result.mode == "triage"
    assert "fresco" not in result.answer and "colpo di calore" not in result.answer


def test_a_question_that_contradicts_the_message_is_not_asked() -> None:
    assert not clarifying_question_fits("urinary", "beve tanto e fa pipì dappertutto")
    assert not clarifying_question_fits("respiratory", "Totò tossisce di notte")
    assert clarifying_question_fits("respiratory", "respira male da stamattina")

    result, client = _ask(
        "Stella ultimamente beve tanto e fa pipì dappertutto, ha 9 anni. Che ne pensi?",
        name="Stella",
        sex="Femmina",
    )

    assert result.mode not in ("safety_clarification", "triage")
    assert client.requests


def test_a_past_accident_is_not_a_current_emergency() -> None:
    assert is_a_past_event("parlavo dell'incidente di anni fa, nessun sangue")
    assert not is_a_past_event("è caduto adesso e sanguina")

    result, client = _ask(
        "ha avuto un incidente anni fa con emorragia, ora sta bene. ho fatto male a tenerlo "
        "con i gatti FIV?",
        species="Gatto",
        name="Tripode",
    )

    assert result.mode not in ("safety_clarification", "triage")
    assert client.requests


def test_a_reply_that_denies_the_emergency_closes_the_question() -> None:
    assert denies_the_emergency("No, nessun sangue, parlavo dell'incidente di anni fa.")
    assert denies_the_emergency("No, il graffio è piccolo e non sanguina.")

    result, client = _ask(
        "No, il graffio è piccolo e non sanguina. Dimmi solo come separarli senza farmi mordere.",
        name="Brina",
        awaiting="bleeding_trauma",
    )

    assert result.mode != "triage"
    assert result.awaiting_safety_clarification is False
    assert client.requests


def test_a_greeting_after_an_emergency_does_not_reopen_it() -> None:
    result, client = _ask("ciao", awaiting="respiratory")

    assert result.mode == "general" and client.requests == []
    assert "Toby" in result.answer and "valutazione veterinaria" not in result.answer


def test_a_wound_on_the_child_is_a_doctors_matter() -> None:
    assert injury_is_on_a_person("il graffio è sul bambino!")

    result, client = _ask(
        "il graffio è sul bambino!", species="Gatto", name="Merlino", awaiting="bleeding_trauma"
    )

    assert client.requests == []
    assert result.model == "person-injury"
    assert "medico" in result.answer and "acqua corrente e sapone" in result.answer


# --- 5. a child writing about the animal's emergency --------------------------------------------


def test_a_child_who_names_their_age_is_recognised_in_an_emergency() -> None:
    message = (
        "scrive Luca 12 anni: papà non c'è. Rocky ha mangiato un calzino intero e vomita. "
        "che faccio?"
    )
    assert is_minor_writing(message)
    assert is_minor_writing("ho dodici anni e il cane sta male")
    assert not is_minor_writing("Rocky ha 12 anni e vomita")

    result, _ = _ask(message, name="Rocky")

    assert result.mode == "triage"
    assert result.answer.startswith("Prima di tutto: chiama subito un adulto")


# --- P7. the last reply travels whole -------------------------------------------


def test_the_last_reply_in_the_history_is_not_cut_at_400_characters() -> None:
    long_reply = "La ruota giusta per un degu è piena, senza raggi. " * 20
    _, client = _ask(
        "non vedo per intero la tua risposta sulla ruota, me la ripeti?",
        species="Piccoli mammiferi",
        name="Kernel",
        history=(("user", "che ruota compro?"), ("assistant", long_reply)),
    )

    prompt = client.requests[-1].user_prompt
    assert long_reply[:900] in prompt
    assert "never tell the owner that a message is cut" in client.requests[-1].system_prompt


def test_the_prompt_forbids_talking_about_the_reference_material() -> None:
    from packages.core.application.services.natural_answer_prompt import build_system_prompt
    from packages.core.domain.conversation.request_kind import RequestKind

    prompt = build_system_prompt(RequestKind.DIRECT, may_ask=False, has_reference_material=True)

    assert "Never mention the material itself" in prompt
    assert "il materiale che hai allegato" in prompt

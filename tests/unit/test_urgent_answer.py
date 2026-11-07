"""An emergency with the model (owner decision 2026-11-07): the fixed
opening says to act now, the model answers on the case with the fixed
first aid as binding notes, and the fixed steps return whenever the model
cannot be trusted or reached. What stays fixed stays fixed."""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.ports.llm_client import LLMRefusal
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.natural_answer_prompt import (
    build_emergency_prompt,
    stable_prefix,
)
from packages.core.application.services.urgency_classifier import (
    UrgencyClassifier,
    UrgencyVerdict,
)
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.localization import translate
from packages.core.domain.safety.harmful_requests import ADULT_FIRST, MINOR_HURT_TEXTS
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryLlmUsageRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError

EMERGENCY = "Toby ha appena mangiato il topicida e adesso trema e sbava"
MODEL_TEXT = (
    "Parti adesso verso il pronto soccorso veterinario e avvisali per telefono che arrivi: "
    "porta con te la confezione del topicida. Non dargli niente da bere né da mangiare e non "
    "provare a farlo vomitare. I veleni per topi bloccano la coagulazione o il sistema "
    "nervoso e il tempo conta."
)
FIXED_STEP = "contatta subito il tuo veterinario"
OPENING = translate("triage_toxin_opening", "it", pet_name="Toby")


class _Classifier(UrgencyClassifier):
    def __init__(self, level: str, category: str | None = None) -> None:  # noqa: D107
        self.level, self.category = level, category

    def classify(self, message: str, species: str) -> UrgencyVerdict | None:
        return UrgencyVerdict(level=self.level, category=self.category)


def _orchestrator(
    client: RecordingLLMClient,
    *,
    timeout: int = 12,
    budget: LlmBudget | None = None,
    classifier: UrgencyClassifier | None = None,
) -> ChatOrchestrator:
    return ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgent_answer_timeout_seconds=timeout,
        usage_budget=budget,
        answer_models=["main"],
        urgency_classifier=classifier,
    )


def _ask(
    message: str,
    *,
    client: RecordingLLMClient | None = None,
    orchestrator: ChatOrchestrator | None = None,
    history: tuple[tuple[str, str], ...] = (),
    awaiting: str | None = None,
    user_daily_limit: int | None = None,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = client or RecordingLLMClient(by_purpose={"urgent_answer": MODEL_TEXT})
    orchestrator = orchestrator or _orchestrator(llm)
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species="Cane",
            pet_name="Toby",
            owner_id="owner-1",
            conversation_history=[ChatMessage(role=r, content=c) for r, c in history],
            awaiting_safety_clarification=awaiting is not None,
            safety_clarification_category=awaiting,
            user_daily_limit=user_daily_limit,
        )
    )
    return result, llm


def _budget(*, user_daily_limit: int = 0, model_budget: int = 10_000_000) -> LlmBudget:
    return LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={"main": model_budget},
        default_budget=model_budget,
        user_daily_limit=user_daily_limit,
    )


# --- the model answers after the fixed opening ----------------------------------------


def test_the_fixed_opening_then_the_model_on_the_case() -> None:
    result, llm = _ask(EMERGENCY)

    assert result.answer.startswith(OPENING)
    assert MODEL_TEXT in result.answer
    assert FIXED_STEP not in result.answer
    assert result.mode == "triage"
    assert result.ai_generated is True
    assert result.provider == "fake"
    assert result.safety_flags
    (request,) = llm.requests_for("urgent_answer")
    assert request.timeout_seconds == 12
    assert request.max_tokens == 320
    assert "FIRST AID FOR THIS CASE" in request.system_prompt
    assert FIXED_STEP in request.system_prompt
    assert "AN EMERGENCY" in request.system_prompt
    assert EMERGENCY in request.user_prompt
    assert request.system_prompt.startswith(stable_prefix(None))
    assert request.cacheable_system_chars == len(stable_prefix(None))


def test_the_emergency_prompt_stays_short() -> None:
    prompt = build_emergency_prompt(
        first_aid=translate("triage_steps", "it", pet_name="Toby"), language="de"
    )

    assert len(prompt) <= 9700
    assert "Sie" in prompt


# --- the fixed steps whenever the model cannot be trusted or reached -------------------


def test_the_fixed_steps_when_the_model_fails() -> None:
    result, _ = _ask(
        EMERGENCY,
        client=RecordingLLMClient(by_purpose={"urgent_answer": ProviderError("timed out")}),
    )

    assert result.answer.startswith(OPENING)
    assert FIXED_STEP in result.answer
    assert result.ai_generated is False
    assert result.model == "safety-triage-guard"


def test_the_fixed_steps_when_the_model_declines() -> None:
    result, _ = _ask(
        EMERGENCY, client=RecordingLLMClient(by_purpose={"urgent_answer": LLMRefusal("bio")})
    )

    assert FIXED_STEP in result.answer and MODEL_TEXT not in result.answer


def test_the_fixed_steps_when_the_model_writes_a_dose() -> None:
    result, _ = _ask(
        EMERGENCY,
        client=RecordingLLMClient(
            by_purpose={"urgent_answer": MODEL_TEXT + " Dagli vitamina K 5 mg/kg al giorno."}
        ),
    )

    assert FIXED_STEP in result.answer and "mg/kg" not in result.answer


def test_the_fixed_steps_when_the_model_only_asks() -> None:
    result, _ = _ask(
        EMERGENCY,
        client=RecordingLLMClient(by_purpose={"urgent_answer": "Quanto ne ha mangiato? Quando?"}),
    )

    assert FIXED_STEP in result.answer


def test_the_fixed_steps_when_the_model_speaks_of_another_animal() -> None:
    result, _ = _ask(
        EMERGENCY,
        client=RecordingLLMClient(
            by_purpose={"urgent_answer": "Porta subito il tuo gatto dal veterinario. " * 4}
        ),
    )

    assert FIXED_STEP in result.answer


def test_with_the_deadline_at_zero_the_reply_stays_fixed_and_the_model_is_not_called() -> None:
    llm = RecordingLLMClient(by_purpose={"urgent_answer": MODEL_TEXT})

    result, _ = _ask(EMERGENCY, orchestrator=_orchestrator(llm, timeout=0))

    assert FIXED_STEP in result.answer
    assert llm.requests == []


# --- limits -------------------------------------------------------------------------------


def test_an_emergency_past_the_owner_limit_still_gets_the_model() -> None:
    budget = _budget(user_daily_limit=1)
    budget.admit(owner_id="owner-1", models=["main"], user_daily_limit=1)
    llm = RecordingLLMClient(by_purpose={"urgent_answer": MODEL_TEXT})

    result, _ = _ask(EMERGENCY, orchestrator=_orchestrator(llm, budget=budget), user_daily_limit=1)

    assert MODEL_TEXT in result.answer
    assert len(llm.requests_for("urgent_answer")) == 1


def test_an_emergency_with_every_model_exhausted_gets_the_fixed_steps() -> None:
    budget = _budget(model_budget=1000)
    budget.note_usage("main", 1000)
    llm = RecordingLLMClient(by_purpose={"urgent_answer": MODEL_TEXT})

    result, _ = _ask(EMERGENCY, orchestrator=_orchestrator(llm, budget=budget))

    assert result.answer.startswith(OPENING)
    assert FIXED_STEP in result.answer
    assert llm.requests == []


# --- what stays fixed and outside the model -------------------------------------------------


def test_a_hurt_child_keeps_the_fixed_reply_without_a_model_call() -> None:
    result, llm = _ask("ho 9 anni, il cane mi ha morso la mano e esce sangue")

    assert result.answer == MINOR_HURT_TEXTS["it"].format(name="Toby")
    assert llm.requests == []


def test_a_child_writing_about_an_emergency_hears_call_an_adult_first() -> None:
    result, llm = _ask("ho 10 anni, Toby ha mangiato il topicida e trema")

    assert result.answer.startswith(ADULT_FIRST["it"])
    assert OPENING in result.answer
    assert MODEL_TEXT in result.answer
    assert len(llm.requests_for("urgent_answer")) == 1


def test_dose_euthanasia_and_identity_stay_fixed_without_a_model_call() -> None:
    for message in (
        "quanto paracetamolo posso dare a Toby per il dolore?",
        "voglio addormentarlo a casa, che dose di sonnifero serve?",
        "ma tu sei un veterinario vero?",
    ):
        _, llm = _ask(message)

        assert llm.requests_for("urgent_answer") == [], message


# --- the other ways into an emergency -----------------------------------------------------


def test_the_reply_that_confirms_a_clarifying_question_goes_to_the_model() -> None:
    result, llm = _ask(
        "sì, sangue a fiotti che non si ferma da dieci minuti", awaiting="bleeding_trauma"
    )

    assert result.mode == "triage"
    assert MODEL_TEXT in result.answer
    assert len(llm.requests_for("urgent_answer")) == 1


def test_the_classifier_emergency_goes_to_the_model_too() -> None:
    llm = RecordingLLMClient(by_purpose={"urgent_answer": MODEL_TEXT})
    orchestrator = _orchestrator(
        llm, budget=_budget(user_daily_limit=5), classifier=_Classifier("emergency", "collapse")
    )

    result, _ = _ask("Toby oggi è proprio strano, non so cosa abbia", orchestrator=orchestrator)

    assert result.mode == "triage"
    assert MODEL_TEXT in result.answer
    assert len(llm.requests_for("urgent_answer")) == 1


def test_the_message_after_an_emergency_reply_gets_the_follow_up_note() -> None:
    previous = OPENING + translate("triage_steps", "it", pet_name="Toby")

    _, llm = _ask(
        "siamo in macchina, quanto ci mette a fare effetto il veleno?",
        history=(("user", EMERGENCY), ("assistant", previous)),
    )

    (request,) = llm.requests_for("answer")
    assert "AFTER AN EMERGENCY REPLY" in request.system_prompt


def test_an_ordinary_question_carries_no_emergency_note() -> None:
    _, llm = _ask("ogni quanto devo spazzolare Toby?")

    (request,) = llm.requests_for("answer")
    assert "AFTER AN EMERGENCY REPLY" not in request.system_prompt
    assert "AN EMERGENCY" not in request.system_prompt

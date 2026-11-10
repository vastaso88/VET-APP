"""Plan "fratello maggiore" (owner decision 2026-11-10): Claude Sonnet writes a
few answers a day when Haiku's did not help; the messages that continue a
topic are not new questions; at the limit the chat says when the count starts
again and which plan goes beyond it (no paid credits)."""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from llm_fakes import RecordingLLMClient

from apps.api.main import app
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import (
    FOLLOWUP_KIND,
    FOLLOWUPS_PER_QUESTION,
    SONNET_KIND,
    LlmBudget,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.subscription.limits import (
    LIMITS_BY_PLAN,
    NO_ACCESS_LIMITS,
    TRIAL_LIMITS,
    PlanLimits,
    effective_limits,
)
from packages.core.domain.subscription.models import Subscription
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.user_clock import reset_utc_offset_minutes, set_utc_offset_minutes

HAIKU = "claude-haiku-5-5"
SONNET = "claude-sonnet-5-5"
GROQ = "openai/gpt-oss-120b"
NOON = datetime(2026, 11, 10, 12, 0, tzinfo=UTC)


class _Clock:
    def __init__(self, now: datetime) -> None:
        self.now = now

    def __call__(self) -> datetime:
        return self.now


def _budget(
    repository: InMemoryLlmUsageRepository | None = None,
    *,
    clock: _Clock | None = None,
    cap: float | None = 1.0,
    user_daily_limit: int = 0,
    reserve_share: float = 0.8,
) -> LlmBudget:
    return LlmBudget(
        repository or InMemoryLlmUsageRepository(),
        budgets={GROQ: 1000},
        default_budget=1000,
        reserve_share=reserve_share,
        user_daily_limit=user_daily_limit,
        clock=clock or _Clock(NOON),
        refresh_seconds=3600.0,
        daily_budget_eur=cap,
        usd_per_eur=1.0,
    )


@pytest.fixture
def offset() -> Iterator[None]:
    """Each test starts on the UTC clock and leaves it there."""
    token = set_utc_offset_minutes(0)
    yield
    reset_utc_offset_minutes(token)


# --- the allowance per plan -----------------------------------------------------------------


def test_sonnet_answers_per_day_are_one_two_three() -> None:
    assert LIMITS_BY_PLAN["plus"].daily_sonnet_answers == 1
    assert LIMITS_BY_PLAN["pro"].daily_sonnet_answers == 2
    assert LIMITS_BY_PLAN["ultra"].daily_sonnet_answers == 3


def test_the_trial_and_the_public_test_have_the_allowance_of_pro() -> None:
    pro = LIMITS_BY_PLAN["pro"]

    assert TRIAL_LIMITS.daily_sonnet_answers == pro.daily_sonnet_answers == 2
    in_trial = Subscription(owner_id="anna")
    assert effective_limits(in_trial, is_developer=False) == TRIAL_LIMITS


def test_without_access_there_is_no_sonnet_and_a_developer_has_no_limit() -> None:
    expired = Subscription(owner_id="anna", trial_ends_at=NOON - timedelta(days=3))

    assert NO_ACCESS_LIMITS.daily_sonnet_answers == 0
    assert effective_limits(expired, is_developer=False) == NO_ACCESS_LIMITS
    assert effective_limits(expired, is_developer=True) is None


def test_the_status_tells_the_app_the_allowance_of_every_plan(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")

    body = TestClient(app).get("/subscription/status").json()

    assert body["limits"]["daily_sonnet_answers"] == 2  # a new account is on the trial
    assert body["limits"]["source"] == "trial"
    assert {
        plan: limits["daily_sonnet_answers"] for plan, limits in body["plan_limits"].items()
    } == {"plus": 1, "pro": 2, "ultra": 3}


@pytest.mark.parametrize(
    ("limits", "upgrade"),
    [
        (LIMITS_BY_PLAN["plus"], "pro"),
        (LIMITS_BY_PLAN["pro"], "ultra"),
        (LIMITS_BY_PLAN["ultra"], None),
        (TRIAL_LIMITS, None),
        (NO_ACCESS_LIMITS, None),
    ],
    ids=["plus", "pro", "ultra", "trial", "no access"],
)
def test_the_plan_above_is_pro_then_ultra_and_nothing_for_ultra_or_the_trial(
    limits: PlanLimits, upgrade: str | None
) -> None:
    assert limits.upgrade_to == upgrade


# --- who may have Sonnet today ------------------------------------------------------------------


def test_an_owner_gets_exactly_the_plans_allowance_of_sonnet_answers(offset: None) -> None:
    budget = _budget()
    limit = LIMITS_BY_PLAN["pro"].daily_sonnet_answers

    allowed = [budget.admit_sonnet(owner_id="anna", limit=limit) for _ in range(limit)]
    refused = budget.admit_sonnet(owner_id="anna", limit=limit)

    assert allowed == [None] * limit
    assert refused is not None
    assert refused.reason == "sonnet_limit" and refused.daily_limit == limit


def test_the_allowance_is_per_owner(offset: None) -> None:
    budget = _budget()
    budget.admit_sonnet(owner_id="anna", limit=1)

    assert budget.admit_sonnet(owner_id="anna", limit=1) is not None
    assert budget.admit_sonnet(owner_id="bruno", limit=1) is None


def test_the_count_starts_again_at_the_owners_own_midnight() -> None:
    clock = _Clock(datetime(2026, 11, 10, 22, 30, tzinfo=UTC))
    budget = _budget(clock=clock)
    token = set_utc_offset_minutes(60)  # 23:30 where the owner is
    try:
        assert budget.admit_sonnet(owner_id="anna", limit=1) is None
        assert budget.admit_sonnet(owner_id="anna", limit=1) is not None
        clock.now = datetime(2026, 11, 10, 22, 59, tzinfo=UTC)  # 23:59 locally
        assert budget.admit_sonnet(owner_id="anna", limit=1) is not None
        clock.now = datetime(2026, 11, 10, 23, 1, tzinfo=UTC)  # 00:01 on the next day
        assert budget.admit_sonnet(owner_id="anna", limit=1) is None
    finally:
        reset_utc_offset_minutes(token)


def test_the_refusal_says_when_the_count_restarts_but_is_not_shown_to_the_owner(
    offset: None,
) -> None:
    budget = _budget()
    budget.admit_sonnet(owner_id="anna", limit=1)

    denial = budget.admit_sonnet(owner_id="anna", limit=1)

    assert denial is not None
    assert denial.retry_after_seconds == 12 * 3600  # from noon to the next midnight


def test_a_developer_account_has_no_sonnet_limit(offset: None) -> None:
    budget = _budget()

    assert all(budget.admit_sonnet(owner_id="dev", limit=None) is None for _ in range(10))
    assert all(budget.admit_sonnet(owner_id="dev", limit=1, exempt=True) is None for _ in range(10))


def test_an_owner_whose_plan_allows_none_never_gets_sonnet(offset: None) -> None:
    budget = _budget()

    denial = budget.admit_sonnet(owner_id="anna", limit=0)

    assert denial is not None and denial.reason == "sonnet_limit"


def test_if_the_ledger_cannot_count_the_answer_is_haikus(offset: None) -> None:
    """An expensive model is never left unmetered by an outage, or by the SQL
    not being run yet: it fails closed, unlike the questions."""

    class _Down(InMemoryLlmUsageRepository):
        def add_user_usage(self, owner_id: str, day: date, kind: str) -> int:
            raise RuntimeError("unknown usage kind: sonnet")

    budget = _budget(_Down())

    denial = budget.admit_sonnet(owner_id="anna", limit=3)

    assert denial is not None and denial.reason == "sonnet_ledger"


# --- Sonnet and the euro cap ---------------------------------------------------------------------


def test_the_euro_cap_counts_a_sonnet_answer_at_its_own_price(offset: None) -> None:
    sonnet = _budget()
    haiku = _budget()
    # The same 100,000 tokens written by each model.
    sonnet.note_usage(SONNET, 100_000, prompt_tokens=0, completion_tokens=100_000)
    haiku.note_usage(HAIKU, 100_000, prompt_tokens=0, completion_tokens=100_000)

    assert sonnet.spent_today_eur() == pytest.approx(1.0)  # 100,000 x $10 per million
    assert haiku.spent_today_eur() == pytest.approx(0.05)  # 100,000 x $0.50 per million
    assert sonnet.state(SONNET) == "exhausted"
    assert haiku.state(HAIKU) == "ok"


def test_haiku_and_sonnet_spend_from_the_same_cap(offset: None) -> None:
    budget = _budget(cap=0.01)
    budget.note_usage(HAIKU, 12_000, prompt_tokens=0, completion_tokens=12_000)  # $0.006
    budget.note_usage(SONNET, 300, prompt_tokens=0, completion_tokens=300)  # $0.003

    assert budget.spent_today_eur() == pytest.approx(0.009)
    assert budget.state(HAIKU) == budget.state(SONNET) == "reserve"


def test_past_the_reserve_share_sonnet_goes_first_and_the_allowance_is_kept(offset: None) -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository, cap=0.01)
    budget.note_usage(HAIKU, 17_000, prompt_tokens=0, completion_tokens=17_000)  # 85% of the cap

    denial = budget.admit_sonnet(owner_id="anna", limit=2, model=SONNET)

    assert denial is not None and denial.reason == "sonnet_budget"
    # Nothing was spent: the first real count is the first.
    assert repository.add_user_usage("anna", NOON.date(), SONNET_KIND) == 1


def test_with_room_under_the_cap_sonnet_is_allowed_and_counted(offset: None) -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository, cap=1.0)

    assert budget.admit_sonnet(owner_id="anna", limit=2, model=SONNET) is None

    assert repository.add_user_usage("anna", NOON.date(), SONNET_KIND) == 2


# --- the messages that continue a topic -----------------------------------------------------------


class _Spy(InMemoryLlmUsageRepository):
    def __init__(self) -> None:
        super().__init__()
        self.question_counts = 0
        self.kinds: list[str] = []

    def add_user_message(self, owner_id: str, day: date) -> int:
        self.question_counts += 1
        return super().add_user_message(owner_id, day)

    def add_user_usage(self, owner_id: str, day: date, kind: str) -> int:
        self.kinds.append(kind)
        return super().add_user_usage(owner_id, day, kind)


def test_a_continuation_is_not_a_question_of_the_plan(offset: None) -> None:
    repository = _Spy()
    budget = _budget(repository)

    assert (
        budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False)
        is None
    )

    assert repository.question_counts == 0
    assert repository.kinds == [FOLLOWUP_KIND]


def test_the_message_that_opens_a_topic_still_counts_as_before(offset: None) -> None:
    repository = _Spy()
    budget = _budget(repository)

    assert budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2) is None
    assert budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2) is None
    refused = budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2)

    assert refused is not None and refused.reason == "user_limit"
    assert FOLLOWUP_KIND not in repository.kinds


def test_a_case_under_way_is_never_cut_off_by_the_questions_being_used_up(offset: None) -> None:
    budget = _budget()
    for _ in range(2):
        budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2)
    assert budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2) is not None

    follow_up = budget.admit(
        owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False
    )

    assert follow_up is None


def test_continuations_have_a_ceiling_of_three_times_the_questions(offset: None) -> None:
    budget = _budget()
    ceiling = 2 * FOLLOWUPS_PER_QUESTION

    inside = [
        budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False)
        for _ in range(ceiling)
    ]
    over = budget.admit(
        owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False
    )

    assert FOLLOWUPS_PER_QUESTION == 3
    assert inside == [None] * ceiling
    assert over is not None
    # Told the same way as the questions: "you used the day's questions".
    assert over.reason == "user_limit" and over.daily_limit == 2


def test_continuations_are_counted_per_owner_and_never_for_a_developer(offset: None) -> None:
    budget = _budget()
    for _ in range(6):
        budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False)

    assert (
        budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False)
        is not None
    )
    assert (
        budget.admit(owner_id="bruno", models=[HAIKU], user_daily_limit=2, counts_as_question=False)
        is None
    )
    assert all(
        budget.admit(
            owner_id="dev",
            models=[HAIKU],
            exempt=True,
            user_daily_limit=2,
            counts_as_question=False,
        )
        is None
        for _ in range(20)
    )


def test_an_owner_without_access_has_no_continuations_either(offset: None) -> None:
    budget = _budget()

    denial = budget.admit(
        owner_id="anna", models=[HAIKU], user_daily_limit=0, counts_as_question=False
    )

    assert denial is not None and denial.reason == "user_limit"


def test_a_continuation_does_not_get_past_the_models_quota(offset: None) -> None:
    budget = _budget(cap=0.001)
    budget.note_usage(HAIKU, 100_000, prompt_tokens=0, completion_tokens=100_000)

    denial = budget.admit(
        owner_id="anna", models=[HAIKU], user_daily_limit=5, counts_as_question=False
    )

    assert denial is not None and denial.reason == "models_exhausted"


def test_a_ledger_outage_does_not_cut_a_case_under_way(offset: None) -> None:
    class _Down(InMemoryLlmUsageRepository):
        def add_user_usage(self, owner_id: str, day: date, kind: str) -> int:
            raise RuntimeError("ledger down")

    budget = _budget(_Down())

    assert (
        budget.admit(owner_id="anna", models=[HAIKU], user_daily_limit=2, counts_as_question=False)
        is None
    )


# --- at the limit: when it restarts, and the plan above ----------------------


def _ask_at_the_limit(language: str, upgrade_plan: str | None) -> ChatOrchestratorResult:
    budget = _budget(user_daily_limit=1)
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        usage_budget=budget,
        answer_models=[GROQ],
    )

    def ask(text: str) -> ChatOrchestratorResult:
        return orchestrator.answer(
            ChatOrchestratorInput(
                user_message=text,
                species="Cane",
                pet_name="Rex",
                owner_id="anna",
                language=language,
                user_daily_limit=1,
                upgrade_plan=upgrade_plan,
            )
        )

    ask("quante volte al giorno deve mangiare?")
    return ask("e quanta acqua deve bere?")


@pytest.mark.parametrize(
    ("language", "section"),
    [
        ("it", "Impostazioni → Abbonamento e pagamenti"),
        ("en", "Settings → Subscription and payments"),
        ("es", "Ajustes → Suscripción y pagos"),
        ("de", "Einstellungen → Abo und Zahlungen"),
        ("fr", "Paramètres → Abonnement et paiements"),
    ],
)
def test_at_the_limit_the_message_says_when_it_restarts_and_names_the_plan_above(
    language: str, section: str, offset: None
) -> None:
    result = _ask_at_the_limit(language, "pro")

    assert result.mode == "user_limit_reached"
    assert "Pro" in result.answer and section in result.answer
    assert "12" in result.answer  # the wait until the owner's midnight, as before
    assert result.ai_generated is False


def test_the_message_says_the_plan_above_only_when_there_is_one(offset: None) -> None:
    without = _ask_at_the_limit("it", None)
    with_ultra = _ask_at_the_limit("it", "ultra")

    assert "piano" in without.answer and "Impostazioni" not in without.answer
    assert "piano Ultra" in with_ultra.answer
    assert without.answer in with_ultra.answer  # the same message, one sentence longer


def test_nothing_in_the_message_offers_paid_credits(offset: None) -> None:
    answer = _ask_at_the_limit("it", "pro").answer.lower()

    for word in ("credit", "acquista", "compra", "ricarica", "€"):
        assert word not in answer


# --- the plan reaches the chat -----------------------------------------------


class _Capture(ChatOrchestrator):
    inputs: list[ChatOrchestratorInput]

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        self.inputs.append(data)
        return super().answer(data)


def _service(limits: PlanLimits | None) -> tuple[SendChatMessageService, _Capture]:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    orchestrator = _Capture(RecordingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    orchestrator.inputs = []
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pets,
        owner_limits=lambda _owner, _email: limits,
    )
    return service, orchestrator


@pytest.mark.parametrize(
    ("limits", "sonnet", "upgrade"),
    [
        (LIMITS_BY_PLAN["plus"], 1, "pro"),
        (LIMITS_BY_PLAN["pro"], 2, "ultra"),
        (LIMITS_BY_PLAN["ultra"], 3, None),
        (TRIAL_LIMITS, 2, None),
        (None, None, None),
    ],
    ids=["plus", "pro", "ultra", "trial", "developer"],
)
def test_the_chat_receives_the_sonnet_allowance_and_the_plan_above(
    limits: PlanLimits | None, sonnet: int | None, upgrade: str | None
) -> None:
    service, orchestrator = _service(limits)

    service.execute(
        SendChatMessageInput(owner_id="owner-a", pet_id="pet-a", user_message="Quante crocchette?")
    )

    sent = orchestrator.inputs[0]
    assert sent.sonnet_daily_limit == sonnet
    assert sent.upgrade_plan == upgrade

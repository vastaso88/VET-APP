"""Plans, limits and the access gate (trial 14 days, no free plan): what each
plan allows, what an expired owner can no longer do, and that the limits are
counted per owner (a second owner never uses up the first one's room)."""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest

from apps.api import main as api_main
from apps.api.dependencies import subscription as gate
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.subscription.limits import (
    LIMITS_BY_PLAN,
    NO_ACCESS_LIMITS,
    TRIAL_LIMITS,
    PlanLimits,
    effective_limits,
)
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
    InMemoryPetProfileRepository,
    InMemorySubscriptionRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import (
    PlanLimitError,
    SubscriptionRequiredError,
    ValidationError,
)

_DEVELOPERS = frozenset({"dev@example.com"})
_NOON = datetime(2026, 11, 10, 12, 0, tzinfo=UTC)
_MAIN = "main-model"


def _subscription(**kwargs: object) -> Subscription:
    return Subscription(owner_id="owner-a", **kwargs)  # type: ignore[arg-type]


# --- the table --------------------------------------------------------------


def test_every_limit_grows_from_plus_to_ultra() -> None:
    plus, pro, ultra = (LIMITS_BY_PLAN[p] for p in ("plus", "pro", "ultra"))

    assert plus.max_pets < pro.max_pets < ultra.max_pets
    assert plus.max_chats_per_pet < pro.max_chats_per_pet < ultra.max_chats_per_pet
    assert plus.daily_questions < pro.daily_questions < ultra.daily_questions
    assert plus.max_devices <= pro.max_devices <= ultra.max_devices


def test_there_is_no_free_plan() -> None:
    assert SubscriptionPlan.ALL == {"plus", "pro", "ultra"}


def test_a_plan_saved_before_the_change_reads_as_no_plan() -> None:
    # "free" rows exist in databases from before the paywall: reading them
    # must not fail (the app fails open on an error) and they count as trial
    # or expired, never as a paid plan.
    assert _subscription(plan="free").plan is None
    assert _subscription(plan="gold").plan is None
    assert _subscription(plan="pro").plan == "pro"


# --- effective limits -------------------------------------------------------


def test_effective_limits_by_state() -> None:
    in_trial = _subscription()
    expired = _subscription(trial_ends_at=utc_now() - timedelta(days=1))
    paid_after_trial = _subscription(trial_ends_at=utc_now() - timedelta(days=1), plan="plus")

    assert effective_limits(in_trial, is_developer=False) == TRIAL_LIMITS == LIMITS_BY_PLAN["pro"]
    assert effective_limits(expired, is_developer=False) == NO_ACCESS_LIMITS
    assert effective_limits(paid_after_trial, is_developer=False) == LIMITS_BY_PLAN["plus"]
    assert effective_limits(expired, is_developer=True) is None


def test_an_expired_owner_is_allowed_nothing() -> None:
    assert NO_ACCESS_LIMITS.max_pets == 0
    assert NO_ACCESS_LIMITS.max_chats_per_pet == 0
    assert NO_ACCESS_LIMITS.daily_questions == 0


def test_status_carries_the_limits_and_the_catalogue() -> None:
    repository = InMemorySubscriptionRepository()
    service = GetOrCreateSubscriptionService(repository, _DEVELOPERS)

    result = service.execute(GetOrCreateSubscriptionInput(owner_id="u", email="u@example.com"))

    assert result.limits == TRIAL_LIMITS
    assert result.plan_limits == LIMITS_BY_PLAN
    dumped = result.model_dump()
    assert dumped["plan_limits"]["ultra"]["daily_questions"] == 30


# --- pets -------------------------------------------------------------------


def _create_pet(service: CreatePetProfileService, owner: str, name: str = "Milo") -> None:
    service.execute(CreatePetProfileInput(owner_id=owner, name=name, species="Cane"))


def test_a_plan_caps_the_number_of_pets() -> None:
    pets = InMemoryPetProfileRepository()
    plus = LIMITS_BY_PLAN["plus"]
    service = CreatePetProfileService(pets, owner_limits=lambda _owner, _email: plus)

    for index in range(plus.max_pets):
        _create_pet(service, "owner-a", f"Pet {index}")

    with pytest.raises(PlanLimitError) as error:
        _create_pet(service, "owner-a", "One too many")
    assert error.value.kind == "pets"
    assert error.value.limit == plus.max_pets
    assert len(pets.list_by_owner("owner-a")) == plus.max_pets


def test_another_owners_pets_do_not_count_toward_the_limit() -> None:
    pets = InMemoryPetProfileRepository()
    plus = LIMITS_BY_PLAN["plus"]
    service = CreatePetProfileService(pets, owner_limits=lambda _owner, _email: plus)
    for index in range(plus.max_pets):
        _create_pet(service, "owner-a", f"Pet {index}")

    _create_pet(service, "owner-b")  # owner B still has all their room

    assert len(pets.list_by_owner("owner-b")) == 1


def test_developers_and_services_without_plans_have_no_pet_limit() -> None:
    unlimited = CreatePetProfileService(
        InMemoryPetProfileRepository(), owner_limits=lambda _owner, _email: None
    )
    without_plans = CreatePetProfileService(InMemoryPetProfileRepository())

    for service in (unlimited, without_plans):
        for index in range(LIMITS_BY_PLAN["ultra"].max_pets + 1):
            _create_pet(service, "owner-a", f"Pet {index}")


def test_an_expired_owner_cannot_create_a_pet() -> None:
    service = CreatePetProfileService(
        InMemoryPetProfileRepository(), owner_limits=lambda _owner, _email: NO_ACCESS_LIMITS
    )

    with pytest.raises(PlanLimitError):
        _create_pet(service, "owner-a")


def test_the_pet_limit_is_read_with_the_owners_email() -> None:
    seen: list[tuple[str, str | None]] = []

    def lookup(owner_id: str, email: str | None) -> PlanLimits | None:
        seen.append((owner_id, email))
        return None

    service = CreatePetProfileService(InMemoryPetProfileRepository(), owner_limits=lookup)
    service.execute(
        CreatePetProfileInput(
            owner_id="owner-a", owner_email="owner@example.com", name="Milo", species="Cane"
        )
    )

    assert seen == [("owner-a", "owner@example.com")]


# --- questions per day ------------------------------------------------------


def _budget(**kwargs: object) -> LlmBudget:
    return LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={_MAIN: 1000},
        default_budget=1000,
        clock=lambda: _NOON,
        refresh_seconds=3600.0,
        **kwargs,  # type: ignore[arg-type]
    )


def test_the_plans_daily_questions_replace_the_deployment_default() -> None:
    budget = _budget(user_daily_limit=20)

    admitted = [budget.admit(owner_id="anna", models=[_MAIN], user_daily_limit=3) for _ in range(3)]
    fourth = budget.admit(owner_id="anna", models=[_MAIN], user_daily_limit=3)

    assert admitted == [None, None, None]
    assert fourth is not None
    assert fourth.reason == "user_limit"
    assert fourth.daily_limit == 3


def test_a_plan_can_allow_more_than_the_deployment_default() -> None:
    budget = _budget(user_daily_limit=2)

    results = [budget.admit(owner_id="anna", models=[_MAIN], user_daily_limit=5) for _ in range(5)]

    assert results == [None] * 5


def test_zero_plan_questions_means_none_allowed_not_unlimited() -> None:
    budget = _budget(user_daily_limit=0)  # deployment default "no limit"

    denial = budget.admit(owner_id="anna", models=[_MAIN], user_daily_limit=0)

    assert denial is not None
    assert denial.reason == "user_limit"


def test_without_a_plan_the_deployment_default_still_applies() -> None:
    budget = _budget(user_daily_limit=1)

    assert budget.admit(owner_id="anna", models=[_MAIN]) is None
    assert budget.admit(owner_id="anna", models=[_MAIN]) is not None


def test_the_daily_count_is_per_owner() -> None:
    budget = _budget(user_daily_limit=20)
    budget.admit(owner_id="anna", models=[_MAIN], user_daily_limit=1)

    assert budget.admit(owner_id="anna", models=[_MAIN], user_daily_limit=1) is not None
    assert budget.admit(owner_id="bruno", models=[_MAIN], user_daily_limit=1) is None


def test_exempt_accounts_ignore_the_plan_limit() -> None:
    budget = _budget(user_daily_limit=20)

    results = [
        budget.admit(owner_id="dev", models=[_MAIN], exempt=True, user_daily_limit=0)
        for _ in range(3)
    ]

    assert results == [None] * 3


# --- chats per pet ----------------------------------------------------------


class _FakeLLM:
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        return LLMResponse(content="Risposta.", provider="fake", model="fake", token_count=1)


def _chat_service(
    limits: PlanLimits | None, pets: InMemoryPetProfileRepository
) -> SendChatMessageService:
    orchestrator = ChatOrchestrator(_FakeLLM(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    return SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pets,
        owner_limits=lambda _owner, _email: limits,
    )


def test_a_plan_caps_the_chats_per_pet() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    plus = LIMITS_BY_PLAN["plus"]
    service = _chat_service(plus, pets)

    for index in range(plus.max_chats_per_pet):
        service.execute(
            SendChatMessageInput(
                owner_id="owner-a", pet_id="pet-a", user_message=f"Domanda {index}"
            )
        )

    with pytest.raises(ValidationError, match="conversation_limit_reached"):
        service.execute(
            SendChatMessageInput(owner_id="owner-a", pet_id="pet-a", user_message="Un'altra")
        )


def test_chats_of_another_owners_pet_do_not_use_up_the_room() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    pets.save(PetProfile(id="pet-b", owner_id="owner-b", name="Rex", species="Cane"))
    plus = LIMITS_BY_PLAN["plus"]
    service = _chat_service(plus, pets)
    for index in range(plus.max_chats_per_pet):
        service.execute(
            SendChatMessageInput(
                owner_id="owner-a", pet_id="pet-a", user_message=f"Domanda {index}"
            )
        )

    result = service.execute(
        SendChatMessageInput(owner_id="owner-b", pet_id="pet-b", user_message="Ciao")
    )

    assert result.conversation.owner_id == "owner-b"


# --- the access gate --------------------------------------------------------


def _gate_container(
    monkeypatch: pytest.MonkeyPatch, repository: InMemorySubscriptionRepository, email: str
) -> None:
    service = GetOrCreateSubscriptionService(repository, _DEVELOPERS)
    user = SimpleNamespace(id="owner-a", email=email)
    container = SimpleNamespace(
        auth_provider=SimpleNamespace(get_current_user=lambda: user),
        get_or_create_subscription_service=lambda: service,
    )
    monkeypatch.setattr(gate, "get_container", lambda: container)


def test_the_gate_lets_a_trial_owner_through(monkeypatch: pytest.MonkeyPatch) -> None:
    _gate_container(monkeypatch, InMemorySubscriptionRepository(), "owner@example.com")

    gate.require_active_subscription()


def test_the_gate_stops_an_expired_owner_without_a_plan(monkeypatch: pytest.MonkeyPatch) -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="owner-a", trial_ends_at=utc_now() - timedelta(days=1)))
    _gate_container(monkeypatch, repository, "owner@example.com")

    with pytest.raises(SubscriptionRequiredError):
        gate.require_active_subscription()


def test_the_gate_lets_through_an_expired_owner_who_chose_a_plan(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(
        Subscription(owner_id="owner-a", trial_ends_at=utc_now() - timedelta(days=1), plan="pro")
    )
    _gate_container(monkeypatch, repository, "owner@example.com")

    gate.require_active_subscription()


def test_the_gate_lets_through_a_developer_after_the_trial(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="owner-a", trial_ends_at=utc_now() - timedelta(days=1)))
    _gate_container(monkeypatch, repository, "DEV@example.com")

    gate.require_active_subscription()


def test_the_gate_fails_open_when_the_subscription_cannot_be_read(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def broken() -> object:
        raise RuntimeError("database down")

    user = SimpleNamespace(id="owner-a", email="owner@example.com")
    container = SimpleNamespace(
        auth_provider=SimpleNamespace(get_current_user=lambda: user),
        get_or_create_subscription_service=broken,
    )
    monkeypatch.setattr(gate, "get_container", lambda: container)

    gate.require_active_subscription()


# --- what the app receives --------------------------------------------------


def test_subscription_required_answers_402_with_a_stable_code() -> None:
    response = asyncio.run(
        api_main.handle_subscription_required(None, SubscriptionRequiredError("x"))  # type: ignore[arg-type]
    )

    assert response.status_code == 402
    assert b'"code":"subscription_required"' in response.body


def test_plan_limit_answers_403_with_kind_and_limit() -> None:
    response = asyncio.run(
        api_main.handle_plan_limit(
            None,  # type: ignore[arg-type]
            PlanLimitError("pets", limit=3, message="il tuo piano consente fino a 3 animali."),
        )
    )

    assert response.status_code == 403
    assert b'"code":"plan_limit_reached"' in response.body
    assert b'"kind":"pets"' in response.body
    assert b'"limit":3' in response.body

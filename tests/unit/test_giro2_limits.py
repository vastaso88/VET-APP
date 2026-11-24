"""Synthetic users, round 2 (2026-11-16), points 4 and 7 of the report:

* the per-pet chat limit is the same for every message (24/11/2026: the two more chats
  for emergencies are gone, the app does not handle urgencies and every question takes the
  same path): the owner can go on in a chat they already have;
* the limit refusals reach a client that is not the app without the technical prefix
  and in the owner's language;
* choosing a plan with fewer places than the owner has pets is no longer silent.
"""

from __future__ import annotations

import asyncio
import json
import re
from datetime import timedelta
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi.testclient import TestClient
from llm_fakes import RecordingLLMClient
from starlette.requests import Request

from apps.api import main as api_main
from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.application.services.select_plan import SelectPlanInput, SelectPlanService
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageOutput,
    SendChatMessageService,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.localization import translate
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.subscription.limits import (
    LIMITS_BY_PLAN,
    PlanLimits,
)
from packages.core.domain.subscription.store import Store, StoreState, VerifiedStorePurchase
from packages.infrastructure.billing.fake_store import FakeStore
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemorySubscriptionRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ConversationLimitError, PlanLimitError, ValidationError

PLUS = LIMITS_BY_PLAN["plus"]
URGENT = "ha mangiato il veleno per topi"
ROUTINE = "quanto deve dormire?"


# --- 4. the per-pet chat limit is the same for every message ---------------------------------


def _chat_service(limit_per_pet: int) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    pets.save(PetProfile(id="pet-b", owner_id="owner-b", name="Luna", species="Gatto"))
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        answer_models=["main"],
    )
    return SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pets,
        max_active_conversations_per_pet=limit_per_pet,
    )


def _send(
    service: SendChatMessageService, text: str, *, owner: str = "owner-a", pet: str = "pet-a"
) -> SendChatMessageOutput:
    return service.execute(SendChatMessageInput(owner_id=owner, pet_id=pet, user_message=text))


def _fill(service: SendChatMessageService, count: int) -> list[str]:
    ids = []
    for index in range(count):
        ids.append(_send(service, f"{ROUTINE} {index}").conversation.id)
    return ids


@pytest.mark.parametrize("text", [URGENT, ROUTINE, "Il mio gatto non riesce a urinare da ieri"])
def test_at_the_limit_every_message_gets_the_same_refusal(text: str) -> None:
    service = _chat_service(limit_per_pet=2)
    old = _fill(service, 2)

    with pytest.raises(ConversationLimitError) as caught:
        _send(service, text)

    assert str(caught.value) == "conversation_limit_reached: " + translate(
        "conversation_limit", "it", limit=2, pet_name="Milo"
    )
    assert [c.id for c in service._repository.list_by_pet("pet-a")] == old  # noqa: SLF001


def test_at_the_limit_the_same_message_is_answered_in_a_chat_that_exists() -> None:
    service = _chat_service(limit_per_pet=2)
    old = _fill(service, 2)

    answered = service.execute(
        SendChatMessageInput(
            owner_id="owner-a", pet_id="pet-a", user_message=URGENT, conversation_id=old[0]
        )
    )

    assert answered.conversation.id == old[0]
    assert answered.mode == "triage"


@pytest.mark.parametrize("language", ["it", "en", "es", "de", "fr"])
def test_the_chat_limit_text_is_calm_and_has_no_phone_number(language: str) -> None:
    text = translate("conversation_limit", language, limit=2, pet_name="Milo")
    assert not re.search(r"\+?\d{3,}", text)
    assert "!" not in text
    assert not re.search(
        r"non aspettare|subito|adesso|do not wait|straight away|right now|ahora|no esperes|"
        r"sofort|warten sie nicht|tout de suite|n'attendez pas",
        text.lower(),
    )


def test_a_message_that_is_not_an_emergency_is_still_refused_at_the_limit() -> None:
    service = _chat_service(limit_per_pet=1)
    _fill(service, 1)

    with pytest.raises(ConversationLimitError) as caught:
        _send(service, "e quanto mangia?")

    assert len(service._repository.list_by_pet("pet-a")) == 1  # noqa: SLF001
    assert caught.value.limit == 1


def test_the_refusal_is_a_validation_error_with_the_prefix_the_app_reads() -> None:
    service = _chat_service(limit_per_pet=1)
    _fill(service, 1)

    with pytest.raises(ValidationError, match=r"^conversation_limit_reached: Hai già 1 chat") as e:
        _send(service, "e quanto mangia?")

    assert isinstance(e.value, ConversationLimitError)


def test_the_refusal_also_carries_the_text_without_the_technical_prefix() -> None:
    error = ConversationLimitError("Hai già 4 chat aperte per Merlino.", limit=4)

    response = asyncio.run(api_main.handle_conversation_limit(None, error))  # type: ignore[arg-type]
    body = json.loads(bytes(response.body))

    assert response.status_code == 400
    assert body["detail"] == "conversation_limit_reached: Hai già 4 chat aperte per Merlino."
    assert body["code"] == "conversation_limit_reached"
    assert body["message"] == "Hai già 4 chat aperte per Merlino."
    assert "conversation_limit_reached" not in body["message"]
    assert body["limit"] == 4


def test_user_b_is_not_stopped_by_what_user_a_has_open() -> None:
    service = _chat_service(limit_per_pet=1)
    _fill(service, 1)  # user A is at the limit on pet-a

    other = _send(service, ROUTINE, owner="owner-b", pet="pet-b")

    assert other.conversation.owner_id == "owner-b"
    with pytest.raises(ConversationLimitError):  # and A is still stopped
        _send(service, "e quanto mangia?")


def test_a_deleted_chat_is_gone_for_good() -> None:
    # Giro 2 (Lucia): "a deleted chat relives". It does not: the id is refused, and an
    # emergency never lands in it.
    from packages.core.application.services.delete_conversation import (
        DeleteConversationInput,
        DeleteConversationService,
    )

    service = _chat_service(limit_per_pet=1)
    chat_id = _send(service, ROUTINE).conversation.id
    DeleteConversationService(service._repository).execute(  # noqa: SLF001
        DeleteConversationInput(owner_id="owner-a", conversation_id=chat_id)
    )

    with pytest.raises(ValidationError, match="conversation not found"):
        service.execute(
            SendChatMessageInput(
                owner_id="owner-a", pet_id="pet-a", conversation_id=chat_id, user_message=ROUTINE
            )
        )
    urgent = _send(service, URGENT)

    assert urgent.conversation.id != chat_id


# --- 7. the refusals are in the owner's language, and a plan change tells -------------------------


def _request(accept_language: str | None = None) -> Request:
    headers = [(b"accept-language", accept_language.encode())] if accept_language else []
    return Request({"type": "http", "headers": headers})


def _refusal(error: PlanLimitError, language: str) -> dict[str, Any]:
    response = asyncio.run(api_main.handle_plan_limit(_request(language), error))
    return json.loads(bytes(response.body))  # type: ignore[no-any-return]


@pytest.mark.parametrize(
    "language, fragment",
    [
        ("it", "Il tuo piano consente fino a 4 animali"),
        ("en", "Your plan allows up to 4 pets"),
        ("de", "Ihr Tarif erlaubt bis zu 4 Tiere"),
        ("es", "Tu plan permite hasta 4 animales"),
        ("fr", "Votre offre permet jusqu'à 4 animaux"),
    ],
)
def test_the_pets_limit_refusal_is_in_the_language_of_the_request(
    language: str, fragment: str
) -> None:
    error = PlanLimitError("pets", limit=4, message="il tuo piano consente fino a 4 animali.")

    response = asyncio.run(api_main.handle_plan_limit(_request(language), error))
    body = json.loads(bytes(response.body))

    assert response.status_code == 403
    assert fragment in body["message"]
    assert body["detail"] == f"plan_limit_reached: {body['message']}"
    assert body["code"] == "plan_limit_reached" and body["kind"] == "pets" and body["limit"] == 4


def test_it_names_the_plan_above_when_there_is_one_and_never_for_the_top_plan() -> None:
    with_plan = PlanLimitError("pets", limit=4, message="x", upgrade_to="pro")
    top = PlanLimitError("pets", limit=15, message="x")

    above = _refusal(with_plan, "en")
    nothing_above = _refusal(top, "en")

    assert "Pro" in above["message"]
    assert "switch" not in nothing_above["message"] and "Ultra" not in nothing_above["message"]


def test_a_kind_without_a_translation_keeps_its_own_message() -> None:
    error = PlanLimitError("something_else", limit=1, message="the original text")

    assert _refusal(error, "de")["message"] == "the original text"


def test_the_pet_that_does_not_fit_names_the_plan_above_in_the_service() -> None:
    pets = InMemoryPetProfileRepository()
    for index in range(PLUS.max_pets):
        pets.save(PetProfile(owner_id="owner-a", name=f"P{index}", species="Cane"))
    service = CreatePetProfileService(pets, owner_limits=lambda _o, _e: PLUS)

    with pytest.raises(PlanLimitError) as caught:
        service.execute(CreatePetProfileInput(owner_id="owner-a", name="Extra", species="Gatto"))

    assert caught.value.upgrade_to == "pro"


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch, request: pytest.FixtureRequest) -> TestClient:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    request.getfixturevalue("adult_everyone")
    return TestClient(app)


def test_over_the_api_the_ninth_pet_is_refused_in_german_without_a_second_language(
    client: TestClient,
) -> None:
    limit = get_container().owner_limits_lookup()("demo-user", "demo@example.com")
    assert isinstance(limit, PlanLimits)
    for index in range(limit.max_pets):
        created = client.post("/pets", json={"name": f"Tier{index}", "species": "Cane"})
        assert created.status_code == 200, created.text

    refused = client.post(
        "/pets",
        json={"name": "Eins zu viel", "species": "Cane"},
        headers={"Accept-Language": "de-DE,de;q=0.9"},
    )

    assert refused.status_code == 403
    body = refused.json()
    assert body["code"] == "plan_limit_reached"
    assert "Tarif" in body["message"] and "Tiere" in body["message"]
    assert "il tuo piano" not in body["message"].lower()


# --- 7. choosing a plan with fewer places than pets --------------------------------------------


def _plans(pets: InMemoryPetProfileRepository | None) -> SelectPlanService:
    return SelectPlanService(InMemorySubscriptionRepository(), pets=pets)


def _owner_with(pets: InMemoryPetProfileRepository, owner: str, count: int) -> None:
    for index in range(count):
        pets.save(PetProfile(owner_id=owner, name=f"{owner}-{index}", species="Cane"))


def test_choosing_plus_with_more_pets_than_it_allows_says_so_and_still_goes_through() -> None:
    pets = InMemoryPetProfileRepository()
    _owner_with(pets, "owner-a", PLUS.max_pets + 3)

    over = _plans(pets).pets_over_limit("owner-a", "plus")

    assert over is not None
    assert over.count == PLUS.max_pets + 3
    assert over.limit == PLUS.max_pets
    assert over.plan == "plus"
    # Nothing is deleted or moved (Terms it/03 section 4).
    assert len(pets.list_by_owner("owner-a")) == PLUS.max_pets + 3


def test_exactly_as_many_pets_as_the_plan_allows_is_not_over_the_limit() -> None:
    pets = InMemoryPetProfileRepository()
    _owner_with(pets, "owner-a", PLUS.max_pets)

    assert _plans(pets).pets_over_limit("owner-a", "plus") is None


def test_a_plan_with_room_says_nothing() -> None:
    pets = InMemoryPetProfileRepository()
    _owner_with(pets, "owner-a", PLUS.max_pets + 3)

    assert _plans(pets).pets_over_limit("owner-a", "ultra") is None


def test_user_b_pets_never_count_for_user_a() -> None:
    pets = InMemoryPetProfileRepository()
    _owner_with(pets, "owner-b", PLUS.max_pets + 5)
    _owner_with(pets, "owner-a", 1)

    assert _plans(pets).pets_over_limit("owner-a", "plus") is None


def test_pets_in_ricordi_take_no_place_once_the_profile_carries_the_flag() -> None:
    # `is_memorial` is not on the profile on every branch yet: a pet that carries it
    # and is true is skipped, one that does not carry it counts, as before.
    class _Repo(InMemoryPetProfileRepository):
        def list_by_owner(self, owner_id: str):  # type: ignore[no-untyped-def]
            active = [SimpleNamespace(is_memorial=False) for _ in range(PLUS.max_pets)]
            kept = [SimpleNamespace(is_memorial=True) for _ in range(5)]
            plain = [SimpleNamespace()]  # an older profile without the flag: counts
            return [*active, *kept, *plain]

    over = SelectPlanService(InMemorySubscriptionRepository(), pets=_Repo()).pets_over_limit(
        "owner-a", "plus"
    )

    assert over is not None
    assert over.count == PLUS.max_pets + 1  # the five in Ricordi are out


def test_a_failed_count_says_nothing_and_never_fails() -> None:
    class _Broken(InMemoryPetProfileRepository):
        def list_by_owner(self, owner_id: str):  # type: ignore[no-untyped-def]
            raise RuntimeError("database down")

    service = SelectPlanService(InMemorySubscriptionRepository(), pets=_Broken())

    assert service.pets_over_limit("owner-a", "plus") is None


def test_nothing_is_said_during_the_public_test_when_nothing_changes() -> None:
    pets = InMemoryPetProfileRepository()
    _owner_with(pets, "owner-a", PLUS.max_pets + 3)
    service = SelectPlanService(InMemorySubscriptionRepository(), test_plan="pro", pets=pets)

    result = service.execute(SelectPlanInput(owner_id="owner-a", plan="plus"))

    assert result.changed is False and result.pets_over_limit is None


@pytest.mark.parametrize(
    "language, fragment",
    [
        ("it", "Non cancelliamo e non spostiamo niente"),
        ("en", "We won't delete or move anything"),
        ("de", "Wir löschen und verschieben nichts"),
        ("es", "No borramos ni movemos nada"),
        ("fr", "Nous ne supprimons et ne déplaçons rien"),
    ],
)
def test_the_warning_text_exists_in_every_language_with_its_numbers(
    language: str, fragment: str
) -> None:
    text = translate("plan_over_pet_limit", language, count=7, limit=4, plan="Plus")

    assert fragment in text
    assert "7" in text and "4" in text and "Plus" in text
    assert "{" not in text


@pytest.fixture
def store_client(monkeypatch: pytest.MonkeyPatch, request: pytest.FixtureRequest) -> TestClient:
    """Billing on, with a store double: a plan comes from a verified purchase."""
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    monkeypatch.setenv("BILLING_ENABLED", "true")
    monkeypatch.setenv("BILLING_ACCOUNT_TOKEN_SECRET", "test-secret-not-real")
    monkeypatch.setenv("BILLING_STORE_ENVIRONMENT", "sandbox")
    request.getfixturevalue("adult_everyone")
    service = get_container().store_billing_service()
    assert service is not None
    apple = FakeStore()
    apple.answers["1000"] = VerifiedStorePurchase(
        store=Store.APPLE,
        store_subscription_id="1000",
        product_id="net.quokkapet.plus.monthly",
        state=StoreState.ACTIVE,
        expires_at=utc_now() + timedelta(days=30),
        auto_renew=True,
        environment="sandbox",
        account_token=service.account_token("demo-user"),
    )
    service._verifiers = {Store.APPLE: apple}  # type: ignore[assignment]
    return TestClient(app)


def _buy_plus(client: TestClient, language: str = "it") -> dict[str, object]:
    response = client.post(
        "/billing/purchases/verify",
        json={"store": "apple", "store_subscription_id": "1000"},
        headers={"Accept-Language": language},
    )
    assert response.status_code == 200, response.text
    body: dict[str, object] = response.json()
    return body


def test_over_the_api_a_purchase_of_a_smaller_plan_carries_the_warning_in_the_owners_language(
    store_client: TestClient,
) -> None:
    for index in range(PLUS.max_pets + 2):
        created = store_client.post("/pets", json={"name": f"Tier{index}", "species": "Cane"})
        assert created.status_code == 200, created.text

    body = _buy_plus(store_client, "en")

    assert body["pets_over_limit"] == {
        "count": PLUS.max_pets + 2,
        "limit": PLUS.max_pets,
        "plan": "plus",
    }
    assert body["code"] == "pets_over_plan_limit"
    assert "We won't delete or move anything" in str(body["message"])


def test_over_the_api_a_purchase_with_room_carries_no_warning(store_client: TestClient) -> None:
    store_client.post("/pets", json={"name": "Solo", "species": "Cane"})

    body = _buy_plus(store_client)

    assert body["pets_over_limit"] is None
    assert "code" not in body and "message" not in body

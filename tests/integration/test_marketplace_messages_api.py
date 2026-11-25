"""The messages of the Mercatino through the routes: who can write, who can read
and, for every route, what a third person ("user B") gets. The backend uses the
service role, so these checks are the only protection."""

from __future__ import annotations

import logging
from collections.abc import Callable, Iterator
from datetime import timedelta
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app, rate_limiter
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.application.services.export_account_data import ExportAccountDataInput
from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.messaging import MESSAGE_MAX_LENGTH, MarketplaceMessage
from packages.core.domain.marketplace.models import ListingStatus, MarketplaceListing
from packages.core.domain.subscription.limits import MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY
from packages.core.domain.subscription.models import Subscription

pytestmark = pytest.mark.usefixtures("adult_everyone")

SwitchUser = Callable[[str], None]


@pytest.fixture(autouse=True)
def _normal_behaviour(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    rate_limiter._hits.clear()
    yield
    rate_limiter._hits.clear()


@pytest.fixture
def act_as(monkeypatch: pytest.MonkeyPatch) -> SwitchUser:
    """The signed-in user for the next requests (the token decides, in production)."""
    provider = get_container().auth_provider

    def switch(user_id: str) -> None:
        monkeypatch.setattr(
            provider,
            "get_current_user",
            lambda: AuthenticatedUser(id=user_id, email=f"{user_id}@example.com"),
        )

    return switch


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def _people() -> tuple[str, str, str]:
    tag = uuid4().hex[:8]
    return f"buyer-{tag}", f"seller-{tag}", f"stranger-{tag}"


def _ad(seller: str, *, status: ListingStatus = "active") -> str:
    listing = MarketplaceListing(
        owner_id=seller,
        title="Trasportino",
        category="kennels_carriers",
        condition="good",
        status=status,
        location=Coordinates(latitude=45.46, longitude=9.19),
    )
    get_container().marketplace_listing_repository.save(listing)
    # Publishing needs an open trial or a plan: the seller has a subscription row.
    subscriptions = get_container().subscription_repository
    if subscriptions.get(seller) is None:
        subscriptions.save(Subscription(owner_id=seller))
    return listing.id


def _open(client: TestClient, act_as: SwitchUser, buyer: str, listing_id: str) -> str:
    act_as(buyer)
    response = client.post(
        f"/marketplace/listings/{listing_id}/conversations", json={"text": "Ciao"}
    )
    assert response.status_code == 200, response.text
    return str(response.json()["conversation"]["id"])


def _lapse(user_id: str) -> None:
    get_container().subscription_repository.save(
        Subscription(owner_id=user_id, trial_ends_at=utc_now() - timedelta(days=1))
    )


def _set_status(listing_id: str, status: ListingStatus) -> None:
    repository = get_container().marketplace_listing_repository
    listing = repository.get(listing_id)
    assert listing is not None
    repository.save(listing.model_copy(update={"status": status}))


def test_a_buyer_writes_and_the_seller_answers_without_learning_who_the_other_is(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    conversation_id = _open(client, act_as, buyer, _ad(seller))

    act_as(seller)
    inbox = client.get("/marketplace/conversations").json()
    assert inbox["unread_total"] == 1
    assert inbox["conversations"][0]["role"] == "seller"
    assert inbox["conversations"][0]["unread_count"] == 1
    assert client.get("/marketplace/conversations/unread-count").json() == {"unread_total": 1}

    thread = client.get(f"/marketplace/conversations/{conversation_id}").json()
    assert [(m["body"], m["mine"]) for m in thread["messages"]] == [("Ciao", False)]
    assert thread["conversation"]["can_write"] is True

    assert client.post(f"/marketplace/conversations/{conversation_id}/read").json() == {"ok": True}
    assert client.get("/marketplace/conversations/unread-count").json() == {"unread_total": 0}

    answer = client.post(
        f"/marketplace/conversations/{conversation_id}/messages", json={"text": "Buongiorno"}
    )
    assert answer.status_code == 200

    act_as(buyer)
    assert client.get("/marketplace/conversations/unread-count").json() == {"unread_total": 1}
    body = client.get(f"/marketplace/conversations/{conversation_id}").text
    assert seller not in body and buyer not in body, "an account id left the backend"
    assert "@example.com" not in body


def test_the_same_buyer_and_ad_stay_in_one_conversation(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    first = _open(client, act_as, buyer, listing_id)

    again = _open(client, act_as, buyer, listing_id)

    assert again == first
    found = client.get(f"/marketplace/listings/{listing_id}/conversation").json()
    assert found["conversation"]["id"] == first
    assert len(client.get(f"/marketplace/conversations/{first}").json()["messages"]) == 2


def test_the_seller_cannot_write_first(client: TestClient, act_as: SwitchUser) -> None:
    _, seller, _ = _people()
    listing_id = _ad(seller)
    act_as(seller)

    response = client.post(
        f"/marketplace/listings/{listing_id}/conversations", json={"text": "Ti interessa?"}
    )

    assert response.status_code == 404
    assert client.get("/marketplace/conversations").json()["conversations"] == []


@pytest.mark.parametrize("status", ["sold", "removed", "removed_policy"])
def test_a_closed_ad_opens_no_conversation(
    client: TestClient, act_as: SwitchUser, status: ListingStatus
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller, status=status)
    act_as(buyer)

    response = client.post(
        f"/marketplace/listings/{listing_id}/conversations", json={"text": "Ciao"}
    )

    assert response.status_code == 404


@pytest.mark.parametrize("text", ["", "   \n ", "x" * (MESSAGE_MAX_LENGTH + 1)])
def test_empty_or_too_long_text_is_refused(
    client: TestClient, act_as: SwitchUser, text: str
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    act_as(buyer)

    response = client.post(f"/marketplace/listings/{listing_id}/conversations", json={"text": text})

    assert response.status_code in (400, 422)
    assert client.get("/marketplace/conversations").json()["conversations"] == []


def test_a_closed_ad_leaves_the_conversation_readable_but_not_writable(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)
    _set_status(listing_id, "sold")

    for person in (buyer, seller):
        act_as(person)
        thread = client.get(f"/marketplace/conversations/{conversation_id}").json()
        assert thread["messages"][0]["body"] == "Ciao"
        assert thread["conversation"]["can_write"] is False
        assert thread["conversation"]["closed_reason"] == "closed"
        refused = client.post(
            f"/marketplace/conversations/{conversation_id}/messages", json={"text": "Ancora?"}
        )
        assert refused.status_code == 409
        listed = client.get("/marketplace/conversations").json()["conversations"][0]
        assert listed["can_write"] is False


def test_a_deleted_ad_closes_the_conversation_too(client: TestClient, act_as: SwitchUser) -> None:
    """The app deletes its ads directly from the table; the column goes null."""
    buyer, seller, _ = _people()
    conversation_id = _open(client, act_as, buyer, _ad(seller))
    repository = get_container().marketplace_messaging_repository
    conversation = repository.get_conversation(conversation_id)
    assert conversation is not None
    repository.conversations[conversation_id] = conversation.model_copy(  # type: ignore[attr-defined]
        update={"listing_id": None}
    )

    thread = client.get(f"/marketplace/conversations/{conversation_id}").json()

    assert thread["conversation"]["listing_title"] == "Trasportino"
    assert thread["conversation"]["can_write"] is False


def test_the_new_conversations_a_day_are_limited_replies_are_not(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    first = _open(client, act_as, buyer, _ad(seller))
    for _ in range(MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY - 1):
        _open(client, act_as, buyer, _ad(seller))

    response = client.post(
        f"/marketplace/listings/{_ad(seller)}/conversations", json={"text": "Ciao"}
    )

    assert response.status_code == 429
    assert response.json()["kind"] == "marketplace_new_conversations"
    assert response.json()["limit"] == MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY
    assert "Retry-After" in response.headers

    reply = client.post(f"/marketplace/conversations/{first}/messages", json={"text": "Altro"})
    assert reply.status_code == 200


def test_a_block_stops_both_sides_and_does_not_tell_the_other_one(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)

    act_as(seller)
    blocked = client.post(f"/marketplace/conversations/{conversation_id}/block").json()
    assert blocked["conversation"]["closed_reason"] == "blocked_by_me"
    url = f"/marketplace/conversations/{conversation_id}/messages"
    assert client.post(url, json={"text": "No"}).status_code == 409

    act_as(buyer)
    assert client.post(url, json={"text": "Ci sei?"}).status_code == 409
    view = client.get(f"/marketplace/conversations/{conversation_id}").json()["conversation"]
    assert view["closed_reason"] == "closed", "being blocked must look like a closed chat"

    # On another ad of the same seller: as if the ad were not there.
    other_ad = _ad(seller)
    response = client.post(f"/marketplace/listings/{other_ad}/conversations", json={"text": "Ciao"})
    assert response.status_code == 404

    act_as(seller)
    client.delete(f"/marketplace/conversations/{conversation_id}/block")
    assert client.post(url, json={"text": "Scusa"}).status_code == 200


def test_without_a_plan_one_reads_blocks_and_reports_but_does_not_write(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)
    other_ad = _ad(seller)
    _lapse(buyer)
    base = f"/marketplace/conversations/{conversation_id}"

    assert client.post(f"{base}/messages", json={"text": "Ciao"}).status_code == 402
    response = client.post(f"/marketplace/listings/{other_ad}/conversations", json={"text": "Ciao"})
    assert response.status_code == 402

    assert client.get(base).status_code == 200
    assert client.get("/marketplace/conversations").status_code == 200
    assert client.post(f"{base}/read").status_code == 200
    assert client.post(f"{base}/report", json={"reason": "scam"}).status_code == 200
    assert client.post(f"{base}/block").status_code == 200


def test_a_seller_who_could_not_answer_gets_no_new_conversation(
    client: TestClient, act_as: SwitchUser
) -> None:
    """Owner decision 2026-11-07: no new conversation with a seller without an
    active plan, and nothing in the answer says why."""
    buyer, seller, other_buyer = _people()
    listing_id = _ad(seller)
    existing = _open(client, act_as, buyer, listing_id)
    _lapse(seller)

    act_as(other_buyer)
    status = client.get(f"/marketplace/listings/{listing_id}/conversation").json()
    refused = client.post(
        f"/marketplace/listings/{listing_id}/conversations", json={"text": "Ciao"}
    )
    missing = client.post("/marketplace/listings/no-such-ad/conversations", json={"text": "Ciao"})

    assert status == {"conversation": None, "can_start": False}
    assert refused.status_code == 404
    assert refused.json() == missing.json(), "a lapsed seller looks like any unavailable ad"

    # The conversation opened before stays readable for both.
    act_as(buyer)
    assert client.get(f"/marketplace/conversations/{existing}").status_code == 200
    act_as(seller)
    assert client.get(f"/marketplace/conversations/{existing}").status_code == 200


def test_the_ad_page_learns_whether_a_conversation_can_start(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    act_as(buyer)
    assert client.get(f"/marketplace/listings/{listing_id}/conversation").json() == {
        "conversation": None,
        "can_start": True,
    }
    act_as(seller)
    own = client.get(f"/marketplace/listings/{listing_id}/conversation").json()
    assert own == {"conversation": None, "can_start": False}


def test_user_b_gets_not_found_on_every_route(client: TestClient, act_as: SwitchUser) -> None:
    buyer, seller, stranger = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)
    base = f"/marketplace/conversations/{conversation_id}"
    act_as(stranger)

    attempts = [
        client.get(base),
        client.post(f"{base}/messages", json={"text": "Entro anch'io"}),
        client.post(f"{base}/read"),
        client.post(f"{base}/block"),
        client.delete(f"{base}/block"),
        client.post(f"{base}/report", json={"reason": "spam"}),
    ]

    assert [response.status_code for response in attempts] == [404] * len(attempts)
    missing = client.get("/marketplace/conversations/does-not-exist")
    assert attempts[0].json() == missing.json(), "someone else's looks exactly like a missing one"

    assert client.get("/marketplace/conversations").json() == {
        "conversations": [],
        "unread_total": 0,
    }
    assert client.get("/marketplace/conversations/unread-count").json() == {"unread_total": 0}
    assert client.get(f"/marketplace/listings/{listing_id}/conversation").json() == {
        "conversation": None,
        "can_start": True,
    }

    repository = get_container().marketplace_messaging_repository
    assert [m.body for m in repository.list_messages(conversation_id, 10)] == ["Ciao"]
    assert repository.blocks_involving(stranger) == []
    assert repository.find_report(conversation_id, stranger) is None


def test_user_b_starts_their_own_conversation_on_the_same_ad(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, stranger = _people()
    listing_id = _ad(seller)
    first = _open(client, act_as, buyer, listing_id)

    second = _open(client, act_as, stranger, listing_id)

    assert second != first
    thread = client.get(f"/marketplace/conversations/{second}").json()
    assert [m["body"] for m in thread["messages"]] == ["Ciao"]
    act_as(seller)
    assert len(client.get("/marketplace/conversations").json()["conversations"]) == 2


def test_reporting_twice_keeps_one_report(client: TestClient, act_as: SwitchUser) -> None:
    buyer, seller, _ = _people()
    conversation_id = _open(client, act_as, buyer, _ad(seller))

    for reason in ("scam", "spam"):
        response = client.post(
            f"/marketplace/conversations/{conversation_id}/report", json={"reason": reason}
        )
        assert response.status_code == 200

    report = get_container().marketplace_messaging_repository.find_report(conversation_id, buyer)
    assert report is not None and report.reason == "scam"
    bad = client.post(
        f"/marketplace/conversations/{conversation_id}/report", json={"reason": "whatever"}
    )
    assert bad.status_code == 422


def test_moderation_in_the_portal_needs_an_admin_and_can_close_the_conversation(
    client: TestClient, act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch
) -> None:
    buyer, seller, _ = _people()
    conversation_id = _open(client, act_as, buyer, _ad(seller))
    client.post(f"/marketplace/conversations/{conversation_id}/report", json={"reason": "scam"})
    report = get_container().marketplace_messaging_repository.find_report(conversation_id, buyer)
    assert report is not None
    queue_url = "/admin/moderation/marketplace_messages"
    detail_url = f"{queue_url}/{report.id}"

    # Not an admin: nothing, whoever they are.
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({"admin-1@example.com"}),
    )
    assert client.get(queue_url).status_code == 403
    assert client.get(detail_url).status_code == 403
    assert client.post(detail_url, json={"action": "dismiss_report"}).status_code == 403

    act_as("admin-1")
    queue = client.get(queue_url).json()["reports"]
    assert any(item["id"] == report.id for item in queue)
    detail = client.get(detail_url).json()["item"]
    # Every look of the team is written down, with who and when.
    assert [(a["admin_id"], a["action"]) for a in detail["accesses"]] == [("admin-1", "read")]
    assert detail["kept_until"] is None
    assert detail["reason"] == "scam"
    assert [(m["body"], m["role"]) for m in detail["messages"]] == [("Ciao", "buyer")]

    closed = client.post(detail_url, json={"action": "close_conversation", "resolution_note": "ok"})
    assert closed.json()["report"]["status"] == "resolved"
    act_as(buyer)
    url = f"/marketplace/conversations/{conversation_id}/messages"
    assert client.post(url, json={"text": "Ancora"}).status_code == 409

    act_as("admin-1")
    reopened = client.post(detail_url, json={"action": "reopen_report"})
    assert reopened.json()["report"]["status"] == "open"
    assert client.get(f"{queue_url}/missing").status_code == 404
    act_as(buyer)
    assert client.post(url, json={"text": "Ancora"}).status_code == 200


def test_the_export_holds_my_conversations_without_the_other_persons_id(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, stranger = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)
    _open(client, act_as, stranger, listing_id)
    act_as(seller)
    client.post(f"/marketplace/conversations/{conversation_id}/messages", json={"text": "Sì"})

    export = (
        get_container()
        .export_account_data_service()
        .execute(ExportAccountDataInput(owner_id=buyer))
    )

    assert [row["id"] for row in export.data["marketplace_conversations"]] == [conversation_id]
    bodies = {row["body"]: row["sender_id"] for row in export.data["marketplace_messages"]}
    assert bodies == {"Ciao": buyer, "Sì": None}
    assert seller not in str(export.data["marketplace_conversations"])
    assert stranger not in str(export.data)


LISTING_PAYLOAD = {
    "private_seller_declared": True,
    "title": "Cuccia",
    "category": "kennels_carriers",
    "condition": "good",
    "latitude": 45.46,
    "longitude": 9.19,
}


def _as_admin(act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({"admin-1@example.com"}),
    )
    act_as("admin-1")


def test_the_team_keeps_someone_out_of_the_marketplace_and_lets_them_back(
    client: TestClient, act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)
    other_ad = _ad(seller)
    restrictions = "/admin/moderation/marketplace_restrictions"

    _as_admin(act_as, monkeypatch)
    created = client.post(
        restrictions, json={"owner_id": buyer, "reason": "scam", "note": "tre segnalazioni"}
    )
    assert created.status_code == 200
    assert created.json()["restriction"]["created_by_admin_id"] == "admin-1"

    act_as(buyer)
    mine = client.get("/marketplace/restriction").json()
    assert mine["restricted"] is True and mine["reason"] == "scam" and mine["since"]
    assert "note" not in mine, "the team's own words stay in the portal"

    for response in (
        client.post("/marketplace/listings", json=LISTING_PAYLOAD),
        client.put(f"/marketplace/listings/{listing_id}", json=LISTING_PAYLOAD),
        client.post(f"/marketplace/listings/{other_ad}/conversations", json={"text": "Ciao"}),
        client.post(
            f"/marketplace/conversations/{conversation_id}/messages", json={"text": "Ciao"}
        ),
    ):
        assert response.status_code == 403, response.text
        assert response.json()["code"] == "marketplace_restricted"
        assert response.json()["reason"] == "scam"

    # Reading and the safety tools stay open.
    thread = client.get(f"/marketplace/conversations/{conversation_id}").json()
    assert thread["conversation"]["closed_reason"] == "restricted"
    assert (
        client.post(
            f"/marketplace/conversations/{conversation_id}/report", json={"reason": "spam"}
        ).status_code
        == 200
    )
    report = client.post(f"/marketplace/listings/{listing_id}/report", json={"reason": "spam"})
    assert report.status_code == 200

    # The other side only sees a closed conversation, and cannot start a new one.
    act_as(seller)
    view = client.get(f"/marketplace/conversations/{conversation_id}").json()["conversation"]
    assert view["closed_reason"] == "closed" and view["can_write"] is False
    assert client.get("/marketplace/restriction").json()["restricted"] is False

    _as_admin(act_as, monkeypatch)
    listed = client.get(restrictions).json()["restrictions"]
    assert any(item["owner_id"] == buyer and item["note"] == "tre segnalazioni" for item in listed)
    lifted = client.post(f"{restrictions}/{buyer}/lift")
    assert lifted.json()["restriction"]["lifted_at"] is not None
    assert client.post(f"{restrictions}/nobody/lift").status_code == 404

    act_as(buyer)
    assert client.get("/marketplace/restriction").json()["restricted"] is False
    again = client.post(
        f"/marketplace/conversations/{conversation_id}/messages", json={"text": "Ciao"}
    )
    assert again.status_code == 200


def test_nobody_but_the_team_handles_restrictions(
    client: TestClient, act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch
) -> None:
    buyer, _, stranger = _people()
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({"admin-1@example.com"}),
    )
    restrictions = "/admin/moderation/marketplace_restrictions"
    act_as(stranger)

    assert client.get(restrictions).status_code == 403
    assert client.post(restrictions, json={"owner_id": buyer, "reason": "spam"}).status_code == 403
    assert client.post(f"{restrictions}/{buyer}/lift").status_code == 403
    assert get_container().marketplace_messaging_repository.get_restriction(buyer) is None

    bad = client.post(restrictions, json={"owner_id": buyer, "reason": "because"})
    assert bad.status_code in (403, 422)


def test_a_restricted_seller_gets_no_new_conversation(
    client: TestClient, act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    _as_admin(act_as, monkeypatch)
    client.post(
        "/admin/moderation/marketplace_restrictions",
        json={"owner_id": seller, "reason": "prohibited_items"},
    )

    act_as(buyer)
    status = client.get(f"/marketplace/listings/{listing_id}/conversation").json()
    refused = client.post(
        f"/marketplace/listings/{listing_id}/conversations", json={"text": "Ciao"}
    )

    assert status["can_start"] is False
    assert refused.status_code == 404


def test_the_export_holds_my_restriction_without_the_team_members_id(
    client: TestClient, act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch
) -> None:
    buyer, _, _ = _people()
    _as_admin(act_as, monkeypatch)
    client.post(
        "/admin/moderation/marketplace_restrictions", json={"owner_id": buyer, "reason": "spam"}
    )

    export = (
        get_container()
        .export_account_data_service()
        .execute(ExportAccountDataInput(owner_id=buyer))
    )

    [row] = export.data["marketplace_user_restrictions"]
    assert row["reason"] == "spam"
    assert "created_by_admin_id" not in row


def test_messages_are_throttled_through_both_doors_with_one_count(
    client: TestClient, act_as: SwitchUser
) -> None:
    """Security review 2026-11-08: the ad's route also continues an existing
    conversation, and it was outside the per-minute limit, so a script could
    flood a seller through it. Both doors now share one count."""
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    conversation_id = _open(client, act_as, buyer, listing_id)

    statuses = [
        client.post(
            f"/marketplace/listings/{listing_id}/conversations", json={"text": "Ancora io"}
        ).status_code
        for _ in range(70)
    ]

    assert 429 in statuses
    assert statuses.index(429) == 59, "60 messages a minute in total, the first one included"
    other_door = client.post(
        f"/marketplace/conversations/{conversation_id}/messages", json={"text": "E qui?"}
    )
    assert other_door.status_code == 429
    assert "Retry-After" in other_door.headers


# -- hidden characters, contacts and codes (F27) --------------------------


def test_a_contact_or_a_code_passes_with_a_caution(client: TestClient, act_as: SwitchUser) -> None:
    buyer, seller, _ = _people()
    act_as(buyer)
    first = client.post(
        f"/marketplace/listings/{_ad(seller)}/conversations",
        json={"text": "Scrivimi a mario@example.com"},
    )
    assert first.status_code == 200
    conversation_id = first.json()["conversation"]["id"]
    url = f"/marketplace/conversations/{conversation_id}"
    assert first.json()["message"]["caution"] is True

    act_as(seller)
    code = client.post(f"{url}/messages", json={"text": "Mandami il codice di verifica"})
    plain = client.post(f"{url}/messages", json={"text": "Va bene il 25/11/2026 alle 10:30?"})
    assert (code.status_code, code.json()["message"]["caution"]) == (200, True)
    assert (plain.status_code, plain.json()["message"]["caution"]) == (200, False)

    # The one who reads is warned too, with a yes or no and nothing else.
    act_as(buyer)
    messages = client.get(url).json()["messages"]
    assert [(m["body"], m["mine"], m["caution"]) for m in messages] == [
        ("Scrivimi a mario@example.com", True, True),
        ("Mandami il codice di verifica", False, True),
        ("Va bene il 25/11/2026 alle 10:30?", False, False),
    ]
    assert set(messages[0]) == {"id", "body", "mine", "created_at", "caution"}


def test_hidden_characters_are_taken_out_before_saving(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    act_as(buyer)
    hidden = "Ci\u200bao \u202e<b>io</b>\u202c\x00\x07 \U0001f468\u200d\U0001f469"
    clean = "Ciao <b>io</b> \U0001f468\u200d\U0001f469"
    first = client.post(f"/marketplace/listings/{listing_id}/conversations", json={"text": hidden})
    conversation_id = first.json()["conversation"]["id"]
    again = client.post(
        f"/marketplace/conversations/{conversation_id}/messages", json={"text": hidden}
    )

    assert first.json()["message"]["body"] == again.json()["message"]["body"] == clean
    repository = get_container().marketplace_messaging_repository
    assert [m.body for m in repository.list_messages(conversation_id, 10)] == [clean, clean]


def test_a_message_of_hidden_characters_only_is_empty(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    act_as(buyer)
    url = f"/marketplace/listings/{listing_id}/conversations"
    assert client.post(url, json={"text": "\u200b\u2060 \u202e"}).status_code == 400
    repository = get_container().marketplace_messaging_repository
    assert repository.find_conversation(listing_id, buyer) is None, "no conversation, no slot used"

    conversation_id = _open(client, act_as, buyer, listing_id)
    sent = client.post(
        f"/marketplace/conversations/{conversation_id}/messages", json={"text": "\ufeff\u3164"}
    )
    assert sent.status_code == 400
    assert len(repository.list_messages(conversation_id, 10)) == 1


def test_an_older_message_is_cleaned_when_it_is_shown(
    client: TestClient, act_as: SwitchUser, monkeypatch: pytest.MonkeyPatch
) -> None:
    buyer, seller, stranger = _people()
    conversation_id = _open(client, act_as, buyer, _ad(seller))
    repository = get_container().marketplace_messaging_repository
    repository.add_message(
        MarketplaceMessage(
            conversation_id=conversation_id,
            sender_id=buyer,
            body="Il nu\u200bmero \u202e\u00e8 333\u200b1234567",
        )
    )
    url = f"/marketplace/conversations/{conversation_id}"
    act_as(seller)
    shown = client.get(url).json()["messages"][-1]
    assert (shown["body"], shown["caution"]) == ("Il numero \u00e8 3331234567", True)

    # User B: the same answer as for a conversation that does not exist.
    act_as(stranger)
    for response in (
        client.get(url),
        client.post(f"{url}/messages", json={"text": "333 1234567"}),
    ):
        assert response.status_code == 404
        assert "caution" not in response.text and "3331234567" not in response.text

    # The team reads it clean too, and only the team.
    act_as(seller)
    client.post(f"{url}/report", json={"reason": "scam"})
    report = repository.find_report(conversation_id, seller)
    assert report is not None
    detail_url = f"/admin/moderation/marketplace_messages/{report.id}"
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({"admin-1@example.com"}),
    )
    for person in (stranger, seller):
        act_as(person)
        assert client.get(detail_url).status_code == 403
    act_as("admin-1")
    detail = client.get(detail_url).json()["item"]
    assert detail["messages"][-1]["body"] == "Il numero \u00e8 3331234567"


def test_the_text_of_a_message_is_never_logged_nor_given_back_in_a_refusal(
    client: TestClient, act_as: SwitchUser, caplog: pytest.LogCaptureFixture
) -> None:
    buyer, seller, _ = _people()
    listing_id = _ad(seller)
    secret = "codice 482913 mario@example.com"
    with caplog.at_level(logging.DEBUG):
        conversation_id = _open(client, act_as, buyer, listing_id)
        url = f"/marketplace/conversations/{conversation_id}"
        assert client.post(f"{url}/messages", json={"text": secret}).status_code == 200
        assert client.get(url).status_code == 200
        too_long = client.post(f"{url}/messages", json={"text": secret * 100})
        missing = client.post("/marketplace/conversations/nope/messages", json={"text": secret})
    assert (too_long.status_code, missing.status_code) == (422, 404)
    assert "482913" not in too_long.text + missing.text
    assert "482913" not in caplog.text and "mario@example.com" not in caplog.text


def test_half_a_surrogate_pair_is_not_an_error_of_the_server(
    client: TestClient, act_as: SwitchUser
) -> None:
    buyer, seller, _ = _people()
    conversation_id = _open(client, act_as, buyer, _ad(seller))
    response = client.post(
        f"/marketplace/conversations/{conversation_id}/messages",
        content=b'{"text": "ci\\ud800ao"}',
        headers={"content-type": "application/json"},
    )
    assert response.status_code in (200, 422)

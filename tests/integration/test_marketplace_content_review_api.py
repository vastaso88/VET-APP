"""The routes of the confirmation for sensitive words and of the team's check (owner
decisions of 2026-11-23). Synthetic data only."""

from collections.abc import Callable, Iterator
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.application.services.report_listing import ReportListingInput
from packages.core.domain.localization import translate
from packages.infrastructure.persistence.in_memory_listing_reviews import (
    InMemoryListingReviewRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryListingReportRepository,
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import InMemoryListingPhotoVault

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
ADMIN = "33333333-3333-4333-8333-333333333333"
EMAILS = {USER_A: "owner@example.com", USER_B: "other@example.com", ADMIN: "team@example.com"}
AD = {
    "title": "Ciotola per crocchette",
    "category": "feeding",
    "condition": "good",
    "latitude": 45.4642,
    "longitude": 9.1900,
    "private_seller_declared": True,
}
NEARBY = {"latitude": 45.46, "longitude": 9.19, "radius_km": 10}
Switch = Callable[..., None]


@pytest.fixture(autouse=True)
def _own_repositories(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "pro")
    container = get_container()
    monkeypatch.setattr(
        container, "marketplace_listing_repository", InMemoryMarketplaceListingRepository()
    )
    monkeypatch.setattr(container, "listing_review_repository", InMemoryListingReviewRepository())
    monkeypatch.setattr(container, "listing_photo_vault", InMemoryListingPhotoVault())
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({EMAILS[ADMIN]}),
    )


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[Switch]:
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    current: dict[str, Any] = {"id": USER_A, "locale": "it"}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(
            id=current["id"],
            email=EMAILS[current["id"]],
            email_verified=True,
            preferred_locale=current["locale"],
        ),
    )

    def switch(user_id: str, locale: str = "it") -> None:
        current.update(id=user_id, locale=locale)

    client = TestClient(app)
    today = datetime.now(UTC).date()
    for user in (ADMIN, USER_B, USER_A):
        switch(user)
        birth = today.replace(year=today.year - 30).isoformat()
        assert client.post("/account/age", json={"birth_date": birth}).status_code == 200
    yield switch


def _publish(client: TestClient, **changes: object) -> str:
    response = client.post(
        "/marketplace/listings", json={**AD, "content_confirmations": ["food"], **changes}
    )
    assert response.status_code == 200, response.text
    return str(response.json()["listing"]["id"])


def _review_id(client: TestClient, as_user: Switch) -> str:
    as_user(ADMIN)
    return str(client.get("/admin/moderation/listing_reviews").json()["reviews"][0]["id"])


def test_the_refusal_says_which_box_and_which_words_in_the_language_of_the_request(
    as_user: Switch,
) -> None:
    client = TestClient(app)

    refused = client.post("/marketplace/listings", json=AD, headers={"Accept-Language": "en"})

    assert refused.status_code == 400
    body = refused.json()
    assert body["code"] == "content_confirmation_required"
    # An app too old to know the code shows `detail` as it comes.
    assert body["detail"] == body["message"]
    assert body["message"] == translate("marketplace_content_confirmation_required", "en")
    assert body["fix"]["value"] == ["food"]
    assert body["fix"]["terms"] == [{"notice": "food", "text": "crocchette"}]


@pytest.mark.parametrize("bad", [["everything"], ["food", "food", "food"], "food"])
def test_an_unknown_confirmation_is_refused(as_user: Switch, bad: object) -> None:
    response = TestClient(app).post(
        "/marketplace/listings", json={**AD, "content_confirmations": bad}
    )

    assert response.status_code == 422


def test_once_confirmed_everyone_sees_it_at_once_and_nothing_tells_of_the_check(
    as_user: Switch,
) -> None:
    client = TestClient(app)
    listing_id = _publish(client)

    as_user(USER_B)
    listed = client.get("/marketplace/listings", params=NEARBY).json()["listings"]
    (row,) = [item for item in listed if item["id"] == listing_id]
    assert not {"removal", "review", "terms", "notices"} & set(row)


def test_an_edit_asks_again(as_user: Switch) -> None:
    client = TestClient(app)
    listing_id = _publish(client, title="Cuccia", content_confirmations=[])

    refused = client.put(f"/marketplace/listings/{listing_id}", json=AD)

    assert refused.status_code == 400
    assert refused.json()["code"] == "content_confirmation_required"


def test_only_the_team_reaches_the_queue(as_user: Switch) -> None:
    client = TestClient(app)
    _publish(client)
    review_id = _review_id(client, as_user)

    for user in (USER_A, USER_B):
        as_user(user)
        assert client.get("/admin/moderation/listing_reviews").status_code == 403
        assert client.get(f"/admin/moderation/listing_reviews/{review_id}").status_code == 403
        assert (
            client.post(
                f"/admin/moderation/listing_reviews/{review_id}", json={"outcome": "checked"}
            ).status_code
            == 403
        )


def test_a_removal_is_explained_to_the_seller_only(as_user: Switch) -> None:
    client = TestClient(app)
    listing_id = _publish(client)
    review_id = _review_id(client, as_user)

    path = f"/admin/moderation/listing_reviews/{review_id}"
    detail = client.get(path).json()["item"]
    assert {"text": "crocchette", "hit": True} in detail["highlighted_title"]
    assert client.post(path, json={"outcome": "removed"}).status_code == 422, "no reason given"
    decided = client.post(path, json={"outcome": "removed", "reason": "food", "note": "interna"})
    assert decided.json() == {"listing_id": listing_id, "listing_status": "removed_policy"}

    as_user(USER_A)
    (mine,) = client.get("/marketplace/listings/mine").json()["listings"]
    assert mine["status"] == "removed_policy"
    assert mine["removal"]["reason"] == "food" and mine["removal"]["terms"] == ["crocchette"]
    assert set(mine["removal"]) == {"kind", "reason", "decided_at", "terms"}
    assert mine["removal"]["kind"] == "team"
    answer = client.get("/marketplace/listings/mine").text
    assert ADMIN not in answer and "interna" not in answer

    as_user(USER_B)
    assert client.get(f"/marketplace/listings/{listing_id}").status_code == 404
    assert client.get("/marketplace/listings/mine").json()["listings"] == []
    listed = client.get("/marketplace/listings", params=NEARBY).json()["listings"]
    assert listing_id not in [item["id"] for item in listed]


def test_a_checked_ad_stays_and_the_seller_sees_nothing(as_user: Switch) -> None:
    client = TestClient(app)
    _publish(client)
    review_id = _review_id(client, as_user)
    client.post(f"/admin/moderation/listing_reviews/{review_id}", json={"outcome": "checked"})

    as_user(USER_A)
    (mine,) = client.get("/marketplace/listings/mine").json()["listings"]
    assert mine["status"] == "active" and mine["removal"] is None


def test_a_restored_ad_is_visible_again(as_user: Switch) -> None:
    client = TestClient(app)
    listing_id = _publish(client)
    path = f"/admin/moderation/listing_reviews/{_review_id(client, as_user)}"
    client.post(path, json={"outcome": "removed", "reason": "other"})
    assert client.post(path, json={"outcome": "restored"}).status_code == 200

    as_user(USER_B)
    assert client.get(f"/marketplace/listings/{listing_id}").status_code == 200


def test_a_decision_on_an_ad_edited_meanwhile_is_refused(as_user: Switch) -> None:
    client = TestClient(app)
    listing_id = _publish(client)
    path = f"/admin/moderation/listing_reviews/{_review_id(client, as_user)}"
    as_user(USER_A)
    edited = client.put(
        f"/marketplace/listings/{listing_id}",
        json={**AD, "title": "Distributore di crocchette", "content_confirmations": ["food"]},
    )
    assert edited.status_code == 200

    as_user(ADMIN)
    assert client.post(path, json={"outcome": "removed", "reason": "food"}).status_code == 409
    missing = client.post("/admin/moderation/listing_reviews/nope", json={"outcome": "checked"})
    assert missing.status_code == 404


def test_the_photos_of_a_removed_ad_leave_the_public_bucket_and_come_back(
    as_user: Switch,
) -> None:
    client = TestClient(app)
    vault = get_container().listing_photo_vault
    assert isinstance(vault, InMemoryListingPhotoVault)
    vault.public.add(f"{USER_A}/ad/1.jpg")
    listing_id = _publish(client, photo_urls=[f"{USER_A}/ad/1.jpg"])
    (path,) = vault.public
    assert path.startswith(f"published/{listing_id}/"), "copied, and the original deleted"
    review = f"/admin/moderation/listing_reviews/{_review_id(client, as_user)}"

    client.post(review, json={"outcome": "removed", "reason": "food"})
    assert vault.public == set() and vault.held == {path}
    # The team still sees them, with a short link.
    assert client.get(review).json()["item"]["photo_urls"] == [f"https://signed.example.com/{path}"]

    client.post(review, json={"outcome": "restored"})
    assert vault.public == {path} and vault.held == set()


def test_a_refused_medicine_names_the_words_found_and_keeps_nothing(as_user: Switch) -> None:
    client = TestClient(app)
    refused = client.post(
        "/marketplace/listings",
        json={**AD, "title": "Collare Anti-Pulci", "description": "con ricetta"},
    )

    assert refused.status_code == 400
    body = refused.json()
    assert body["detail"].startswith("Sul Mercatino non si possono vendere farmaci")
    assert body["code"] == "content_refused"
    assert body["terms"] == ["collare anti pulci", "ricetta"]
    assert client.get("/marketplace/listings/mine").json()["listings"] == []


def test_the_hourly_job_needs_the_scheduler_token(as_user: Switch) -> None:
    client = TestClient(app)
    route = "/admin/lifecycle/prune-removed-listings"
    for user in (USER_A, ADMIN):
        as_user(user)
        assert client.post(route).status_code in (401, 403, 503)
        assert client.post(route, headers={"X-VetApp-Scheduler": "x"}).status_code in (
            401,
            403,
            503,
        )


def test_an_ad_hidden_by_reports_tells_its_seller_only_the_day(
    as_user: Switch, monkeypatch: pytest.MonkeyPatch
) -> None:
    client = TestClient(app)
    monkeypatch.setattr(
        get_container(), "listing_report_repository", InMemoryListingReportRepository()
    )
    listing_id = _publish(client, title="Cuccia", content_confirmations=[])
    for index in range(3):
        get_container().report_listing_service().execute(
            ReportListingInput(
                listing_id=listing_id, reporter_owner_id=f"reporter-{index}", reason="scam"
            )
        )

    (mine,) = client.get("/marketplace/listings/mine").json()["listings"]
    removal = mine["removal"]
    assert (removal["kind"], removal["reason"]) == ("reports", None)
    assert len(removal["decided_at"]) == len("2026-11-23"), "the day, not the minute"
    answer = client.get("/marketplace/listings/mine").text
    assert "reporter-" not in answer and "scam" not in answer

    as_user(USER_B)
    assert client.get("/marketplace/listings/mine").json()["listings"] == []
    assert client.get(f"/marketplace/listings/{listing_id}").status_code == 404


class _Reports:
    """The admin route reads and writes the reports with the Supabase client."""

    def __init__(self, listing_id: str) -> None:
        self.row: dict[str, Any] = {"id": "rep-1", "listing_id": listing_id, "reason": "scam"}

    def table(self, name: str) -> "_Reports":
        self._table = name
        return self

    def select(self, *_: object) -> "_Reports":
        return self

    def eq(self, *_: object) -> "_Reports":
        return self

    def limit(self, *_: object) -> "_Reports":
        return self

    def update(self, values: dict[str, Any]) -> "_Reports":
        assert "status" not in values or self._table == "marketplace_listing_reports"
        if self._table == "marketplace_listing_reports":
            self.row.update(values)
        return self

    def execute(self) -> Any:
        return SimpleNamespace(data=[dict(self.row)])


@pytest.mark.parametrize(
    ("chosen", "told"), [(None, "scam"), ("prohibited_item", "prohibited_item")]
)
def test_a_removal_from_the_reports_is_explained_too(
    as_user: Switch, monkeypatch: pytest.MonkeyPatch, chosen: str | None, told: str
) -> None:
    client = TestClient(app)
    listing_id = _publish(client, title="Cuccia", content_confirmations=[])
    fake = _Reports(listing_id)
    monkeypatch.setattr("apps.api.routes.admin_moderation._admin_client", lambda: fake)
    path = "/admin/moderation/marketplace/rep-1"

    for user in (USER_A, USER_B):
        as_user(user)
        assert client.post(path, json={"action": "remove_listing"}).status_code == 403
    as_user(ADMIN)
    body = {"action": "remove_listing", "removal_reason": chosen, "resolution_note": "interna"}
    assert client.post(path, json=body).status_code == 200
    assert fake.row["resolution_action"] == "remove_listing"

    as_user(USER_A)
    (mine,) = client.get("/marketplace/listings/mine").json()["listings"]
    assert (mine["status"], mine["removal"]["kind"]) == ("removed_policy", "team")
    assert mine["removal"]["reason"] == told

    as_user(ADMIN)
    assert client.post(path, json={"action": "restore_listing"}).status_code == 200
    as_user(USER_A)
    (mine,) = client.get("/marketplace/listings/mine").json()["listings"]
    assert mine["status"] == "active" and mine["removal"] is None


def test_the_hourly_job_fails_when_the_leftovers_are_too_many(
    as_user: Switch, monkeypatch: pytest.MonkeyPatch
) -> None:
    client = TestClient(app)
    monkeypatch.setattr("apps.api.routes.lifecycle._require_scheduler_token", lambda _token: None)
    vault = get_container().listing_photo_vault
    assert isinstance(vault, InMemoryListingPhotoVault)
    vault.public = {f"published/gone-{index}/1.jpg" for index in range(60)}
    route = "/admin/lifecycle/prune-removed-listings"

    blocked = client.post(route)
    assert blocked.status_code == 500
    assert blocked.json()["leftovers"] == 60 and blocked.json()["leftovers_blocked"]
    assert len(vault.public) == 60

    assert client.post(route, params={"allow_leftovers": -1}).status_code == 422
    assert client.post(route, params={"allow_leftovers": 60}).status_code == 200
    assert vault.public == set()

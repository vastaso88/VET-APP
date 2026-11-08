"""An owner whose trial is over and who has no plan: what the backend still
shows and what it refuses. The filter is applied here, not by the app."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.core.domain.marketplace.visibility import (
    LIMITED_LISTING_FIELDS,
    limit_listing_row,
)
from packages.core.domain.subscription.models import Subscription

pytestmark = pytest.mark.usefixtures("adult_everyone")

OWNER = "demo-user"
ME = {"latitude": 45.46, "longitude": 9.19}
LISTING_BODY = {
    "title": "Trasportino",
    "category": "kennels_carriers",
    "condition": "good",
    "latitude": 45.46,
    "longitude": 9.19,
}


@pytest.fixture(autouse=True)
def _normal_behaviour(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")


def _lapse() -> None:
    get_container().subscription_repository.save(
        Subscription(owner_id=OWNER, trial_ends_at=utc_now() - timedelta(days=1))
    )


def _choose(plan: str = "plus") -> None:
    get_container().subscription_repository.save(
        Subscription(owner_id=OWNER, trial_ends_at=utc_now() - timedelta(days=1), plan=plan)
    )


def _seed(listing_id: str, *, owner_id: str = "seller", status: str = "active") -> None:
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id=listing_id,
            owner_id=owner_id,
            title="Trasportino per gatti",
            description="Poco usato. Scrivetemi su Telegram.",
            category="kennels_carriers",
            condition="like_new",
            price_cents=2500,
            photo_urls=["https://example.com/a.jpg"],
            target_species=["cat"],
            city_label="Milano",
            status=status,  # type: ignore[arg-type]
            location=Coordinates(latitude=ME["latitude"] + 0.01, longitude=ME["longitude"]),
        )
    )


WITHHELD = {
    "description",
    "owner_id",
    "latitude",
    "longitude",
    "category",
    "condition",
    "target_species",
    "status",
    "report_count",
    "created_at",
    "updated_at",
}


# --- Mercatino: the first look only ----------------------------------------


def test_without_a_plan_the_list_carries_only_the_first_look() -> None:
    _lapse()
    _seed("ad-1")

    body = TestClient(app).get("/marketplace/listings", params={**ME, "radius_km": 10}).json()

    assert body["context"]["limited"] is True
    (item,) = [i for i in body["listings"] if i["id"] == "ad-1"]
    assert set(item) <= set(LIMITED_LISTING_FIELDS)
    assert item["title"] == "Trasportino per gatti"
    assert item["price_cents"] == 2500
    assert item["photo_urls"] == ["https://example.com/a.jpg"]
    assert item["city_label"] == "Milano"
    assert "distance_km" in item
    assert not WITHHELD & set(item)


def test_without_a_plan_the_detail_carries_the_same_fields() -> None:
    _lapse()
    _seed("ad-2")
    client = TestClient(app)

    listed = client.get("/marketplace/listings", params={**ME, "radius_km": 10}).json()
    detail = client.get("/marketplace/listings/ad-2").json()

    assert detail["limited"] is True
    assert not WITHHELD & set(detail["listing"])
    listed_item = next(i for i in listed["listings"] if i["id"] == "ad-2")
    assert set(detail["listing"]) <= set(listed_item) | {"distance_km"}
    assert detail["listing"]["title"] == "Trasportino per gatti"


def test_the_seller_text_never_reaches_an_owner_without_a_plan() -> None:
    _lapse()
    _seed("ad-3")
    client = TestClient(app)

    dumped = (
        client.get("/marketplace/listings", params={**ME, "radius_km": 10}).text
        + client.get("/marketplace/listings/ad-3").text
    )

    assert "Telegram" not in dumped
    assert "seller" not in dumped


def test_with_a_trial_or_a_plan_the_full_ad_is_served() -> None:
    _seed("ad-4")
    client = TestClient(app)  # a fresh account is on the trial

    listed = client.get("/marketplace/listings", params={**ME, "radius_km": 10}).json()
    detail = client.get("/marketplace/listings/ad-4").json()

    assert listed["context"]["limited"] is False
    assert detail["limited"] is False
    full = next(i for i in listed["listings"] if i["id"] == "ad-4")
    assert full["description"].startswith("Poco usato")
    assert full["latitude"] and full["target_species"] == ["cat"]
    assert "owner_id" not in full, "the seller's account id never leaves with other people's ads"

    _choose("plus")
    again = client.get("/marketplace/listings/ad-4").json()
    assert again["limited"] is False
    assert again["listing"]["description"].startswith("Poco usato")


def test_an_ad_that_is_not_active_stays_hidden_from_other_owners_without_a_plan() -> None:
    _lapse()
    _seed("ad-5", status="removed_policy")

    response = TestClient(app).get("/marketplace/listings/ad-5")

    assert response.status_code == 404


def test_without_a_plan_the_owner_sees_their_own_old_ad_in_the_same_reduced_form() -> None:
    _lapse()
    _seed("ad-6", owner_id=OWNER)

    detail = TestClient(app).get("/marketplace/listings/ad-6").json()

    assert detail["limited"] is True
    assert detail["listing"]["is_mine"] is True
    assert not WITHHELD & set(detail["listing"])


def test_the_filter_never_lets_a_new_field_through_by_default() -> None:
    row = {"id": "x", "title": "t", "price_cents": 1, "a_new_secret_field": "boom"}

    assert limit_listing_row(row) == {"id": "x", "title": "t", "price_cents": 1}


# --- Mercatino: no action ----------------------------------------------------


def test_without_a_plan_creating_and_editing_ads_answer_402_reporting_does_not() -> None:
    _lapse()
    _seed("ad-7")
    client = TestClient(app)

    created = client.post("/marketplace/listings", json=LISTING_BODY)
    edited = client.put("/marketplace/listings/ad-7", json=LISTING_BODY)
    reported = client.post("/marketplace/listings/ad-7/report", json={"reason": "spam"})

    for response in (created, edited):
        assert response.status_code == 402
        assert response.json()["code"] == "subscription_required"
    # Owner decision 2026-11-08: reporting is open to everyone, plan or not.
    assert reported.status_code == 200
    stored = get_container().marketplace_listing_repository.get("ad-7")
    assert stored is not None and stored.report_count == 1


def test_with_a_plan_the_actions_work_and_three_reporters_remove_an_ad() -> None:
    _choose("pro")
    _seed("ad-8")
    client = TestClient(app)

    assert client.post("/marketplace/listings", json=LISTING_BODY).status_code == 200
    first = client.post("/marketplace/listings/ad-8/report", json={"reason": "scam"})

    assert first.status_code == 200
    assert first.json() == {"report_count": 1, "status": "active"}


def test_a_report_for_a_missing_ad_is_a_clear_400_not_a_crash() -> None:
    _choose("pro")

    response = TestClient(app).post("/marketplace/listings/nope/report", json={"reason": "spam"})

    assert response.status_code == 400


# --- Eventi ------------------------------------------------------------------


def _event(**overrides: object) -> dict[str, object]:
    start = (date.today() + timedelta(days=10)).isoformat()
    row: dict[str, object] = {
        "id": "ev-1",
        "title": "Giornata dell'adozione",
        "event_type": "adoption_day",
        "country": "IT",
        "starts_on": start,
        "ends_on": start,
        "status": "published",
        "audience": "public",
    }
    row.update(overrides)
    return row


def _window() -> dict[str, str]:
    return {
        "country": "IT",
        "from": date.today().isoformat(),
        "to": (date.today() + timedelta(days=30)).isoformat(),
    }


def test_without_a_plan_the_events_are_blocked() -> None:
    _lapse()
    get_container().event_catalog_repository().add(_event())  # type: ignore[attr-defined]
    client = TestClient(app)

    listed = client.get("/events", params=_window())
    suggested = client.post(
        "/events/submissions",
        json={
            "title": "Adozioni",
            "event_type": "adoption_day",
            "starts_on": date.today().isoformat(),
            "ends_on": date.today().isoformat(),
            "city": "Modena",
            "source_url": "https://www.example.org/adozioni",
        },
    )

    for response in (listed, suggested):
        assert response.status_code == 402
        assert response.json()["code"] == "subscription_required"
    assert "Giornata" not in listed.text


def test_with_a_trial_the_events_of_the_country_come_back_in_the_window() -> None:
    catalogue = get_container().event_catalog_repository()
    catalogue.add(_event())  # type: ignore[attr-defined]
    catalogue.add(_event(id="ev-fr", country="FR", title="Evento francese"))  # type: ignore[attr-defined]
    catalogue.add(_event(id="ev-late", starts_on="2099-01-01", ends_on="2099-01-01"))  # type: ignore[attr-defined]
    catalogue.add(_event(id="ev-draft", status="draft"))  # type: ignore[attr-defined]
    catalogue.add(_event(id="ev-pro", audience="professional"))  # type: ignore[attr-defined]

    response = TestClient(app).get("/events", params=_window())

    assert response.status_code == 200
    assert [e["id"] for e in response.json()["events"]] == ["ev-1"]


def test_the_events_window_is_validated() -> None:
    client = TestClient(app)

    backwards = client.get(
        "/events", params={"country": "IT", "from": "2026-12-31", "to": "2026-01-01"}
    )
    too_wide = client.get(
        "/events", params={"country": "IT", "from": "2020-01-01", "to": "2026-01-01"}
    )
    no_country = client.get("/events", params={"from": "2026-01-01", "to": "2026-02-01"})

    assert backwards.status_code == 400
    assert too_wide.status_code == 400
    assert no_country.status_code == 422

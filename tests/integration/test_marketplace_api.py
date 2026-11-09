from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.core.domain.subscription.models import Subscription

pytestmark = pytest.mark.usefixtures("adult_everyone")

ME = {"latitude": 45.46, "longitude": 9.19}


def _seed(listing_id: str, km_north: float, country: str = "IT") -> None:
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id=listing_id,
            owner_id="seller",
            title=listing_id,
            category="toys",
            condition="good",
            country=country,
            location=Coordinates(
                latitude=ME["latitude"] + km_north / 111.2, longitude=ME["longitude"]
            ),
        )
    )


def test_a_search_without_radius_is_rejected() -> None:
    client = TestClient(app)

    response = client.get("/marketplace/listings", params=ME)

    assert response.status_code == 422


def test_a_search_needs_no_country_distance_is_the_filter() -> None:
    client = TestClient(app)

    response = client.get("/marketplace/listings", params={**ME, "radius_km": 10})

    assert response.status_code == 200


def test_a_radius_above_the_maximum_is_rejected() -> None:
    client = TestClient(app)

    for radius in (300.5, 301, 5000, 0, 0.5, -3):
        response = client.get("/marketplace/listings", params={**ME, "radius_km": radius})
        assert response.status_code == 400, radius


def test_the_ads_inside_the_radius_come_back_across_the_border_too() -> None:
    _seed("api-it-near", 2)
    _seed("api-it-far", 40)
    _seed("api-fr-near", 1, "FR")
    client = TestClient(app)

    body = client.get("/marketplace/listings", params={**ME, "radius_km": 10}).json()

    ids = [item["id"] for item in body["listings"]]
    assert "api-it-near" in ids
    assert "api-it-far" not in ids
    assert "api-fr-near" in ids
    foreign = next(item for item in body["listings"] if item["id"] == "api-fr-near")
    assert foreign["country"] == "FR"
    assert body["context"] == {
        "radius_km": 10.0,
        "min_radius_km": 1.0,
        "max_radius_km": 300.0,
        "limited": False,
    }
    near = next(item for item in body["listings"] if item["id"] == "api-it-near")
    assert near["latitude"] and near["country"] == "IT" and "location" not in near


def test_the_maximum_radius_itself_is_served() -> None:
    _seed("api-it-45km", 45)
    client = TestClient(app)

    response = client.get("/marketplace/listings", params={**ME, "radius_km": 50})

    assert response.status_code == 200
    assert "api-it-45km" in [item["id"] for item in response.json()["listings"]]


def test_the_new_wide_radii_are_served() -> None:
    _seed("api-it-120km", 120)
    client = TestClient(app)

    narrow = client.get("/marketplace/listings", params={**ME, "radius_km": 100})
    wide = client.get("/marketplace/listings", params={**ME, "radius_km": 300})

    assert "api-it-120km" not in [item["id"] for item in narrow.json()["listings"]]
    assert "api-it-120km" in [item["id"] for item in wide.json()["listings"]]


PAYLOAD = {
    "private_seller_declared": True,
    "title": "Cuccia per cuccioli",
    "description": "Poco usata",
    "category": "kennels_carriers",
    "condition": "good",
    "price_cents": 2500,
    "photo_urls": [],
    "target_species": ["dog"],
    "latitude": 45.4642,
    "longitude": 9.19,
    "city_label": "Milano",
    "country": "IT",
}


def test_an_ad_for_objects_is_published_with_a_snapped_location() -> None:
    client = TestClient(app)

    response = client.post("/marketplace/listings", json=PAYLOAD)

    assert response.status_code == 200
    listing = response.json()["listing"]
    assert listing["status"] == "active" and listing["country"] == "IT"
    assert (listing["latitude"], listing["longitude"]) == (45.46, 9.19)
    assert get_container().marketplace_listing_repository.get(listing["id"]) is not None


def test_an_ad_that_offers_an_animal_is_refused_with_the_clear_message() -> None:
    client = TestClient(app)

    for title, description in (
        ("Vendo cane", None),
        ("Cuccioli di labrador disponibili", None),
        ("Cuccia", "vendo anche due gattini"),
    ):
        response = client.post(
            "/marketplace/listings", json={**PAYLOAD, "title": title, "description": description}
        )
        assert response.status_code == 400, title
        assert "solo oggetti per animali" in response.text


def test_an_ad_cannot_be_edited_into_an_animal_offer() -> None:
    client = TestClient(app)
    created = client.post("/marketplace/listings", json=PAYLOAD).json()["listing"]

    edited = client.put(
        f"/marketplace/listings/{created['id']}", json={**PAYLOAD, "title": "Cuccia nuova"}
    )
    refused = client.put(
        f"/marketplace/listings/{created['id']}", json={**PAYLOAD, "title": "Gattini in regalo"}
    )

    assert edited.status_code == 200 and edited.json()["listing"]["title"] == "Cuccia nuova"
    assert refused.status_code == 400
    stored = get_container().marketplace_listing_repository.get(created["id"])
    assert stored is not None and stored.title == "Cuccia nuova"


def test_someone_elses_ad_cannot_be_edited() -> None:
    _seed("api-not-mine", 1)

    response = TestClient(app).put("/marketplace/listings/api-not-mine", json=PAYLOAD)

    assert response.status_code == 400


def test_one_ad_by_id_the_detail_page_reads_through_the_backend() -> None:
    _seed("api-detail", 3)
    client = TestClient(app)

    ok = client.get("/marketplace/listings/api-detail")
    missing = client.get("/marketplace/listings/does-not-exist")

    assert ok.status_code == 200 and ok.json()["listing"]["id"] == "api-detail"
    assert "location" not in ok.json()["listing"]
    assert missing.status_code == 404


def test_a_hidden_ad_is_not_served_to_others() -> None:
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id="api-hidden",
            owner_id="seller",
            title="Cuccia",
            category="toys",
            condition="good",
            status="removed_policy",
            location=Coordinates(latitude=45.46, longitude=9.19),
        )
    )
    client = TestClient(app)

    assert client.get("/marketplace/listings/api-hidden").status_code == 404
    ids = [
        i["id"]
        for i in client.get("/marketplace/listings", params={**ME, "radius_km": 10}).json()[
            "listings"
        ]
    ]
    assert "api-hidden" not in ids


def test_another_sellers_account_id_never_leaves_only_mine_is_flagged() -> None:
    """Report 2026-11-06, 0.2: the public row carried `owner_id`. The caller
    (bootstrap user "demo-user") sees other sellers' ads without their id
    and their own ads with `is_mine`."""
    _seed("api-owner-other", 1)
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id="api-owner-mine",
            owner_id="demo-user",
            title="api-owner-mine",
            category="toys",
            condition="good",
            country="IT",
            location=Coordinates(latitude=ME["latitude"], longitude=ME["longitude"]),
        )
    )
    client = TestClient(app)

    body = client.get("/marketplace/listings", params={**ME, "radius_km": 10}).json()
    rows = {item["id"]: item for item in body["listings"]}

    other = rows["api-owner-other"]
    assert "owner_id" not in other and other["is_mine"] is False
    mine = rows["api-owner-mine"]
    assert mine["is_mine"] is True and mine["owner_id"] == "demo-user"

    detail = client.get("/marketplace/listings/api-owner-other").json()["listing"]
    assert "owner_id" not in detail and detail["is_mine"] is False


def test_contact_details_and_medicines_are_refused_with_a_clear_message() -> None:
    client = TestClient(app)
    base = {
        "title": "Cuccia imbottita",
        "category": "toys",
        "condition": "good",
        "latitude": ME["latitude"],
        "longitude": ME["longitude"],
        "private_seller_declared": True,
    }

    contacts = client.post(
        "/marketplace/listings",
        json={**base, "description": "Chiamami al 3331234567 o scrivi a davide@example.com"},
    )
    assert contacts.status_code == 400
    assert "telefoni" in contacts.json()["detail"]

    medicine = client.post(
        "/marketplace/listings",
        json={**base, "title": "Flaconi di ivermectina senza ricetta"},
    )
    assert medicine.status_code == 400
    assert "farmaci" in medicine.json()["detail"]

    animals = client.post(
        "/marketplace/listings", json={**base, "title": "Zwergkaninchen zu verkaufen"}
    )
    assert animals.status_code == 400


@pytest.mark.parametrize("status", ["sold", "removed", "removed_policy"])
def test_user_b_cannot_report_an_ad_of_a_that_is_no_longer_open(
    status: str, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Cleanup pass 2026-11-09: reporting someone else's closed or hidden ad
    answered 200 with its count and state; now it is a 404 like reading it."""
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id=f"api-report-{status}",
            owner_id="seller-a",
            title="Cuccia",
            category="toys",
            condition="good",
            status=status,  # type: ignore[arg-type]
            location=Coordinates(latitude=45.46, longitude=9.19),
        )
    )
    client = TestClient(app)

    hidden = client.post(
        f"/marketplace/listings/api-report-{status}/report", json={"reason": "spam"}
    )
    reading = client.get(f"/marketplace/listings/api-report-{status}")

    assert hidden.status_code == 404
    assert hidden.json() == reading.json()
    stored = get_container().marketplace_listing_repository.get(f"api-report-{status}")
    assert stored is not None and stored.report_count == 0


def test_a_valid_report_answers_without_count_or_state_even_without_a_plan(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    get_container().subscription_repository.save(
        Subscription(owner_id="demo-user", trial_ends_at=utc_now() - timedelta(days=1))
    )
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id="api-report-open",
            owner_id="seller-a",
            title="Cuccia",
            category="toys",
            condition="good",
            location=Coordinates(latitude=45.46, longitude=9.19),
        )
    )

    response = TestClient(app).post(
        "/marketplace/listings/api-report-open/report", json={"reason": "scam"}
    )

    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_publishing_or_editing_without_the_private_seller_declaration_is_refused() -> None:
    """Owner decision 2026-11-09: the Mercatino is for private people only."""
    client = TestClient(app)
    undeclared = {key: value for key, value in PAYLOAD.items() if key != "private_seller_declared"}

    refused = client.post("/marketplace/listings", json=undeclared)
    assert refused.status_code == 400
    assert refused.json()["detail"] == "private_seller_declaration_required"

    created = client.post("/marketplace/listings", json=PAYLOAD).json()["listing"]
    assert created["private_seller_declared_at"], "the seller sees their own declaration"
    stored = get_container().marketplace_listing_repository.get(created["id"])
    assert stored is not None and stored.private_seller_declared_at is not None
    assert stored.private_seller_declaration_version == "2026-11-09"
    first = stored.private_seller_declared_at

    edit = client.put(f"/marketplace/listings/{created['id']}", json=undeclared)
    assert edit.status_code == 400
    again = client.put(f"/marketplace/listings/{created['id']}", json=PAYLOAD)
    assert again.status_code == 200
    restored = get_container().marketplace_listing_repository.get(created["id"])
    assert restored is not None and restored.private_seller_declared_at is not None
    assert restored.private_seller_declared_at >= first


def test_user_b_neither_edits_a_declaration_of_a_nor_sees_it() -> None:
    _seed("api-declared-of-a", 1)
    repository = get_container().marketplace_listing_repository
    before = repository.get("api-declared-of-a")
    assert before is not None
    client = TestClient(app)

    refused = client.put("/marketplace/listings/api-declared-of-a", json=PAYLOAD)
    seen = client.get("/marketplace/listings/api-declared-of-a").json()["listing"]

    assert refused.status_code == 400
    after = repository.get("api-declared-of-a")
    assert (
        after is not None and after.private_seller_declared_at == before.private_seller_declared_at
    )
    assert "private_seller_declared_at" not in seen
    assert "private_seller_declaration_version" not in seen

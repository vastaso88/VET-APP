from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import MarketplaceListing

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
    assert body["context"] == {"radius_km": 10.0, "min_radius_km": 1.0, "max_radius_km": 300.0}
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

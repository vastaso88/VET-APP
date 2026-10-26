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

    response = client.get("/marketplace/listings", params={**ME, "country": "IT"})

    assert response.status_code == 422


def test_a_search_without_country_is_rejected() -> None:
    client = TestClient(app)

    response = client.get("/marketplace/listings", params={**ME, "radius_km": 10})

    assert response.status_code == 422


def test_a_radius_above_the_maximum_is_rejected() -> None:
    client = TestClient(app)

    for radius in (300.5, 301, 5000, 0, 0.5, -3):
        response = client.get(
            "/marketplace/listings", params={**ME, "radius_km": radius, "country": "IT"}
        )
        assert response.status_code == 400, radius


def test_only_the_ads_of_the_country_inside_the_radius_come_back() -> None:
    _seed("api-it-near", 2)
    _seed("api-it-far", 40)
    _seed("api-fr-near", 1, "FR")
    client = TestClient(app)

    body = client.get(
        "/marketplace/listings", params={**ME, "radius_km": 10, "country": "IT"}
    ).json()

    ids = [item["id"] for item in body["listings"]]
    assert "api-it-near" in ids
    assert "api-it-far" not in ids
    assert "api-fr-near" not in ids
    assert body["context"] == {"country": "IT", "radius_km": 10.0, "max_radius_km": 300.0}
    near = next(item for item in body["listings"] if item["id"] == "api-it-near")
    assert near["latitude"] and near["country"] == "IT" and "location" not in near


def test_the_maximum_radius_itself_is_served() -> None:
    _seed("api-it-45km", 45)
    client = TestClient(app)

    response = client.get("/marketplace/listings", params={**ME, "radius_km": 50, "country": "IT"})

    assert response.status_code == 200
    assert "api-it-45km" in [item["id"] for item in response.json()["listings"]]


def test_the_new_wide_radii_are_served() -> None:
    _seed("api-it-120km", 120)
    client = TestClient(app)

    narrow = client.get("/marketplace/listings", params={**ME, "radius_km": 100, "country": "IT"})
    wide = client.get("/marketplace/listings", params={**ME, "radius_km": 300, "country": "IT"})

    assert "api-it-120km" not in [item["id"] for item in narrow.json()["listings"]]
    assert "api-it-120km" in [item["id"] for item in wide.json()["listings"]]

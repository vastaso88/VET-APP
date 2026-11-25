from datetime import timedelta

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.services.get_pet_news import GetPetNewsService
from packages.core.domain.pet_news.models import RawNewsEntry
from packages.infrastructure.persistence.in_memory_pet_news import InMemoryPetNewsCacheRepository


class _Reader:
    def has_feeds(self, country: str) -> bool:
        return country == "IT"

    def read_all(self, country: str) -> list[RawNewsEntry]:
        return [RawNewsEntry(title="Il cane corre", source="Fonte", url="https://ex.test/1")]


def test_news_is_public_and_shaped_for_the_app() -> None:
    container = get_container()
    container._pet_news_service = GetPetNewsService(
        InMemoryPetNewsCacheRepository(), _Reader(), ttl=timedelta(hours=1)
    )
    try:
        response = TestClient(app).get("/news", params={"category": ["Cane", "Gatto"], "limit": 3})
    finally:
        container._pet_news_service = None

    body = response.json()
    assert response.status_code == 200
    assert body["stale"] is False
    assert (body["country"], body["country_has_news"]) == ("IT", True)
    assert body["categories"]["Gatto"] == []
    assert body["categories"]["Cane"] == [
        {
            "title": "Il cane corre",
            "source": "Fonte",
            "url": "https://ex.test/1",
            "published_at": None,
        }
    ]
    assert "Generale" in body["available_categories"]


def test_a_country_without_feeds_is_told_and_never_gets_the_italian_headlines() -> None:
    container = get_container()
    container._pet_news_service = GetPetNewsService(
        InMemoryPetNewsCacheRepository(), _Reader(), ttl=timedelta(hours=1)
    )
    try:
        client = TestClient(app)
        assert client.get("/news", params={"country": "it"}).json()["categories"]["Cane"]
        body = client.get("/news", params={"country": "fr"}).json()
    finally:
        container._pet_news_service = None

    assert (body["country"], body["country_has_news"]) == ("FR", False)
    assert body["categories"] == {}
    assert "Il cane corre" not in str(body)


def test_the_country_of_the_news_is_two_letters() -> None:
    for wrong in ("ITA", "1T", "I"):
        assert TestClient(app).get("/news", params={"country": wrong}).status_code == 422

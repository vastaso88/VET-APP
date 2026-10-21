from datetime import timedelta

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.services.get_pet_news import GetPetNewsService
from packages.core.domain.pet_news.models import RawNewsEntry
from packages.infrastructure.persistence.in_memory_pet_news import InMemoryPetNewsCacheRepository


class _Reader:
    def read_all(self, key: str) -> list[RawNewsEntry]:
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

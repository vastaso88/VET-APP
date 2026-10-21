from datetime import date, timedelta

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container


def _body(**overrides: object) -> dict[str, object]:
    start = (date.today() + timedelta(days=40)).isoformat()
    body: dict[str, object] = {
        "title": "Giornata dell'adozione",
        "event_type": "adoption_day",
        "starts_on": start,
        "ends_on": start,
        "city": "Modena",
        "province_code": "MO",
        "region": "Emilia-Romagna",
        "source_url": "https://www.example.org/adozioni",
    }
    body.update(overrides)
    return body


def test_a_suggestion_goes_to_the_moderation_queue_not_to_the_public_list() -> None:
    client = TestClient(app)
    repository = get_container().event_submission_repository()
    before = len(repository.list_pending())

    response = client.post("/events/submissions", json=_body())

    assert response.status_code == 201
    assert response.json()["status"] == "pending"
    assert len(repository.list_pending()) == before + 1


def test_invalid_suggestion_answers_400_with_a_message() -> None:
    response = TestClient(app).post("/events/submissions", json=_body(title="Tel 333 1234567"))

    assert response.status_code == 400
    assert "telefono" in response.json()["detail"]

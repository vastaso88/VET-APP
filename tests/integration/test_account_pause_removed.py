"""The pause of the account does not exist any more (owner, 25 November 2026): what an older app
that still asks for it receives, and what the server no longer offers."""

from __future__ import annotations

from fastapi.testclient import TestClient

from apps.api.main import app


def test_an_old_app_asking_for_the_pause_gets_a_calm_answer_and_nothing_changes() -> None:
    response = TestClient(app).post("/account/pause")

    assert response.status_code == 410
    body = response.json()
    assert body["code"] == "pause_not_available" and body["detail"] == "pause_not_available"
    assert "non è più prevista" in body["message"]
    assert "Traceback" not in response.text


def test_the_notice_calls_of_an_old_app_answer_that_nothing_ended() -> None:
    client = TestClient(app)

    assert client.get("/account/pause/notice").json() == {"resumed": False}
    assert client.post("/account/pause/notice/ack").json() == {"acknowledged": False}


def test_the_deletion_status_no_longer_carries_a_pause_window() -> None:
    response = TestClient(app).get("/account/deletion")

    assert response.status_code == 200
    assert "pause_max_months" not in response.json()


def test_the_scheduler_has_no_pause_purge_route_any_more() -> None:
    response = TestClient(app).post("/admin/lifecycle/purge-expired-pauses")

    assert response.status_code in (404, 405)

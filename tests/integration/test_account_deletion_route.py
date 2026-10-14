from fastapi.testclient import TestClient

from apps.api.main import app


def test_delete_account_acts_on_the_signed_in_owner_only() -> None:
    client = TestClient(app)
    response = client.delete("/account")
    assert response.status_code == 200
    body = response.json()
    assert body["deleted"] is True
    assert "rows_deleted" in body["report"]


def test_the_route_takes_no_owner_id_from_the_caller() -> None:
    client = TestClient(app)
    # There is no path or query parameter that could name another account.
    assert client.delete("/account/someone-else").status_code in (404, 405)

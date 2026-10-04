"""The upload exactly as the mobile app performs it (2026-10-04): a
multipart POST whose file part is declared application/octet-stream."""

from fastapi.testclient import TestClient

from apps.api.main import app

PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


def _pet_id(client: TestClient) -> str:
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()
    pet_id: str = created["pet_profile"]["id"]
    return pet_id


def test_the_apps_real_upload_request_is_accepted_and_the_file_is_served_back() -> None:
    client = TestClient(app)

    response = client.post(
        "/chat-attachments",
        data={"pet_id": _pet_id(client)},
        files={"file": ("zampa.png", PNG_BYTES, "application/octet-stream")},
    )

    assert response.status_code == 200
    attachment = response.json()["attachment"]
    assert attachment["content_type"] == "image/png"

    served = client.get(f"/chat-attachments/{attachment['id']}/file")

    assert served.status_code == 200
    assert served.headers["content-type"] == "image/png"
    assert served.content == PNG_BYTES


def test_an_unsupported_file_is_rejected_with_a_stable_error_code() -> None:
    client = TestClient(app)

    response = client.post(
        "/chat-attachments",
        data={"pet_id": _pet_id(client)},
        files={"file": ("nota.txt", b"just some text", "image/png")},
    )

    assert response.status_code == 400
    assert response.json()["detail"].startswith("unsupported_attachment_type")

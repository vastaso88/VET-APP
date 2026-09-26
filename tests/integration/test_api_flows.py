from fastapi.testclient import TestClient

from apps.api.main import app


def test_auth_me_endpoint() -> None:
    client = TestClient(app)

    response = client.get("/auth/me")

    assert response.status_code == 200
    assert response.json()["id"] == "demo-user"


def test_pet_create_list_and_update_flow() -> None:
    client = TestClient(app)

    create_response = client.post(
        "/pets", json={"name": "Milo", "species": "dog", "breed": "Beagle"}
    )
    assert create_response.status_code == 200
    pet_id = create_response.json()["pet_profile"]["id"]

    list_response = client.get("/pets")
    assert list_response.status_code == 200
    assert len(list_response.json()["pet_profiles"]) >= 1

    get_response = client.get(f"/pets/{pet_id}")
    assert get_response.status_code == 200
    assert get_response.json()["pet_profile"]["name"] == "Milo"

    update_response = client.put(
        f"/pets/{pet_id}",
        json={"name": "Milo Updated", "species": "dog", "breed": "Beagle", "age_years": 4},
    )
    assert update_response.status_code == 200
    assert update_response.json()["pet_profile"]["name"] == "Milo Updated"


def test_chat_validation_error_returns_400() -> None:
    client = TestClient(app)
    pet_response = client.post("/pets", json={"name": "Luna", "species": "cat"})
    pet_id = pet_response.json()["pet_profile"]["id"]

    response = client.post("/chat", json={"pet_id": pet_id, "user_message": "   "})

    assert response.status_code == 400
    assert response.json()["detail"] == "user_message must not be empty"


def test_chat_and_reminder_flow() -> None:
    client = TestClient(app)
    pet_response = client.post("/pets", json={"name": "Nina", "species": "dog"})
    pet_id = pet_response.json()["pet_profile"]["id"]

    chat_response = client.post("/chat", json={"pet_id": pet_id, "user_message": "Mangia poco"})
    assert chat_response.status_code == 200
    assert chat_response.json()["reply"]["role"] == "assistant"
    # 2026-09-21: the interview loop is opt-in (off by default) and most
    # intents (nutrition_question here) answer via the natural-answer
    # path rather than the strict evidence pipeline — see
    # ChatOrchestrator._strict_evidence_intents.
    assert chat_response.json()["mode"] == "natural"
    assert "confidence" in chat_response.json()
    assert "ai_generated" in chat_response.json()

    reminder_create = client.post(
        "/reminders",
        json={"pet_id": pet_id, "title": "Vaccino", "due_date": "2026-04-01"},
    )
    assert reminder_create.status_code == 200

    reminder_list = client.get("/reminders")
    assert reminder_list.status_code == 200
    assert len(reminder_list.json()["reminders"]) >= 1


def test_account_consents_flow() -> None:
    client = TestClient(app)

    initial = client.get("/account/consents")
    assert initial.status_code == 200
    assert initial.json()["account_consents"]["consents"] == {}
    assert "terms_of_service" in initial.json()["catalog"]

    accept_terms = client.post(
        "/account/consents", json={"consent_key": "terms_of_service", "granted": True}
    )
    assert accept_terms.status_code == 200
    accepted_consents = accept_terms.json()["account_consents"]["consents"]
    assert accepted_consents["terms_of_service"]["granted"] is True

    reject_marketing = client.post(
        "/account/consents", json={"consent_key": "marketing_email", "granted": False}
    )
    assert reject_marketing.status_code == 200

    revoke_terms = client.post(
        "/account/consents", json={"consent_key": "terms_of_service", "granted": False}
    )
    assert revoke_terms.status_code == 400

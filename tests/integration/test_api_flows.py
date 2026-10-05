import pytest
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


def test_conversation_history_includes_messages_after_chat() -> None:
    client = TestClient(app)
    pet_id = client.post("/pets", json={"name": "Bea", "species": "cat"}).json()["pet_profile"][
        "id"
    ]
    chat = client.post("/chat", json={"pet_id": pet_id, "user_message": "Mangia poco"}).json()
    conversation_id = chat["conversation"]["id"]

    response = client.get("/conversations")

    assert response.status_code == 200
    stored = next(c for c in response.json()["conversations"] if c["id"] == conversation_id)
    assert stored["pet_id"] == pet_id
    assert [m["role"] for m in stored["messages"]][:2] == ["user", "assistant"]
    assert stored["messages"][0]["content"] == "Mangia poco"


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


def test_local_services_places_flow() -> None:
    from apps.api.dependencies.container import get_container
    from packages.core.application.services.request_radar_places_ingestion import (
        RequestRadarPlacesIngestionInput,
    )
    from packages.core.domain.radar_places.models import RadarPlace

    class _FakeSource:
        name = "fake_source"

        def fetch_places(self, request_data: RequestRadarPlacesIngestionInput) -> list[RadarPlace]:
            return [
                RadarPlace(
                    coverage_key=request_data.coverage_window().coverage_key,
                    place_type="veterinary",
                    name="Veterinario Milano",
                    latitude=45.4650,
                    longitude=9.1910,
                    source_name=self.name,
                    source_external_id="node/1",
                    source_payload={"raw": True},
                )
            ]

    get_container().radar_places_source = _FakeSource()
    client = TestClient(app)

    response = client.get("/local-services/places", params={"latitude": 45.4642, "longitude": 9.19})

    assert response.status_code == 200
    body = response.json()
    assert body["coverage"]["status"] == "refreshed"
    assert body["context"]["search_radius_km"] == 10
    place = body["places"][0]
    assert place["name"] == "Veterinario Milano"
    assert place["distance_km"] < 1
    assert "source_payload" not in place
    assert "owner_id" not in place

    assert client.get("/local-services/places").status_code == 422


def test_local_services_sources_lists_imported_datasets() -> None:
    from datetime import UTC, datetime

    from apps.api.dependencies.container import get_container
    from packages.core.domain.radar_places.models import RadarDataSource

    catalog = get_container().radar_catalog_repository
    catalog.sources = [  # type: ignore[attr-defined]
        RadarDataSource(
            source="overture",
            release="2026-09-23.1",
            license="CDLA-Permissive-2.0",
            attribution="© Overture Maps Foundation — Places",
            imported_at=datetime(2026, 10, 4, tzinfo=UTC),
            place_count=15831,
        )
    ]
    client = TestClient(app)

    body = client.get("/local-services/sources").json()

    assert body["sources"] == [
        {
            "source": "overture",
            "release": "2026-09-23.1",
            "license": "CDLA-Permissive-2.0",
            "attribution": "© Overture Maps Foundation — Places",
            "url": None,
            "imported_at": "2026-10-04T00:00:00Z",
        }
    ]


def test_segnala_flow_needs_the_rules_then_shows_the_pending_place() -> None:
    from apps.api.dependencies.container import get_container
    from packages.core.application.services.request_radar_places_ingestion import (
        RequestRadarPlacesIngestionInput,
    )
    from packages.core.domain.radar_places.models import RadarPlace

    class _EmptySource:
        name = "fake_source"

        def fetch_places(self, request_data: RequestRadarPlacesIngestionInput) -> list[RadarPlace]:
            return []

    get_container().radar_places_source = _EmptySource()
    client = TestClient(app)
    report = {
        "kind": "missing",
        "place_type": "grooming",
        "name": "Toelettatura Bau",
        "latitude": 45.4650,
        "longitude": 9.1910,
    }

    options = client.get("/local-services/reports/options").json()
    assert options["enabled"] is True
    assert "grooming" in options["missing_place_types"]

    refused = client.post("/local-services/reports", json=report)
    assert refused.status_code == 403
    assert refused.json()["code"] == "contribution_rules_required"

    accepted = client.post(
        "/account/consents", json={"consent_key": "contribution_rules", "granted": True}
    )
    assert accepted.status_code == 200

    created = client.post("/local-services/reports", json=report)
    assert created.status_code == 200
    body = created.json()
    assert (body["status"], body["confirmations"], body["required"]) == ("pending", 0, 5)
    assert "reporter_pseudonym" not in body

    own_vote = client.post(
        f"/local-services/reports/{body['report_id']}/vote", json={"vote": "confirm"}
    )
    assert own_vote.status_code == 400

    places = client.get(
        "/local-services/places", params={"latitude": 45.4642, "longitude": 9.19}
    ).json()["places"]
    assert len(places) == 1
    place = places[0]
    assert place["name"] == "Toelettatura Bau"
    assert place["source_name"] == "vetapp_users"
    assert place["community"]["status"] == "pending"
    assert place["community"]["viewer_is_reporter"] is True
    assert "reporter_pseudonym" not in str(places)

    with_contact = client.post(
        "/local-services/reports", json={**report, "name": "Bau 02 0000 0001", "latitude": 45.5}
    )
    assert with_contact.status_code == 400


def _client_with_env(monkeypatch: pytest.MonkeyPatch, **env: str) -> TestClient:
    from apps.api.dependencies.container import reset_container
    from packages.shared.config.settings import reset_settings

    for name, value in env.items():
        monkeypatch.setenv(name, value)
    reset_settings()
    reset_container()
    return TestClient(app)


_REPORT = {
    "kind": "missing",
    "place_type": "grooming",
    "name": "Toelettatura Bau",
    "latitude": 45.4650,
    "longitude": 9.1910,
}
_RATING = {
    "source": "openstreetmap_overpass",
    "source_id": "way/1",
    "latitude": 45.4650,
    "longitude": 9.1910,
    "stars": 4,
}


def test_radar_switches_default_to_everything_on(monkeypatch: pytest.MonkeyPatch) -> None:
    options = _client_with_env(monkeypatch).get("/local-services/reports/options").json()

    assert options["enabled"] is True
    assert options["report_kinds"] == ["missing", "closed", "duplicate", "wrong_position"]
    assert options["ratings_enabled"] is True


def test_reports_switch_off_is_told_to_the_app_and_enforced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client = _client_with_env(monkeypatch, RADAR_REPORTS_ENABLED="false")

    options = client.get("/local-services/reports/options").json()
    assert (options["enabled"], options["report_kinds"]) == (False, [])
    assert options["missing_place_types"] == []
    assert options["ratings_enabled"] is True
    refused = client.post("/local-services/reports", json=_REPORT)
    assert (refused.status_code, refused.json()["code"]) == (503, "contributions_disabled")
    vote = client.post("/local-services/reports/any/vote", json={"vote": "confirm"})
    assert vote.status_code == 503


def test_closed_switch_off_refuses_only_that_kind(monkeypatch: pytest.MonkeyPatch) -> None:
    client = _client_with_env(monkeypatch, RADAR_REPORT_CLOSED_ENABLED="false")

    options = client.get("/local-services/reports/options").json()
    assert options["enabled"] is True
    assert options["report_kinds"] == ["missing", "duplicate", "wrong_position"]
    closed = client.post(
        "/local-services/reports",
        json={**_REPORT, "kind": "closed", "target_source": "overture", "target_source_id": "abc"},
    )
    assert closed.status_code == 400
    # A missing place gets as far as the rules, as usual.
    assert client.post("/local-services/reports", json=_REPORT).status_code == 403


def test_ratings_switch_off_is_told_to_the_app_and_enforced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client = _client_with_env(monkeypatch, RADAR_RATINGS_ENABLED="false")

    options = client.get("/local-services/reports/options").json()
    assert (options["enabled"], options["ratings_enabled"]) == (True, False)
    refused = client.put("/local-services/ratings", json=_RATING)
    assert (refused.status_code, refused.json()["code"]) == (503, "contributions_disabled")


class _NoPlacesSource:
    name = "fake_source"

    def fetch_places(self, request_data: object) -> list[object]:
        return []


def test_open_sources_switch_limits_places_and_the_sources_page(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from datetime import UTC, datetime

    from apps.api.dependencies.container import get_container
    from packages.core.domain.radar_places.models import RadarDataSource, RadarPlace

    def names(env: dict[str, str]) -> tuple[list[str], list[str]]:
        client = _client_with_env(monkeypatch, **env)
        # No live provider in a test: OpenStreetMap answers with nothing.
        get_container().radar_places_source = _NoPlacesSource()  # type: ignore[assignment]
        catalog = get_container().radar_catalog_repository
        catalog.sources = [  # type: ignore[attr-defined]
            RadarDataSource(
                source=name,
                release="test",
                license="test",
                attribution="test",
                imported_at=datetime(2026, 10, 4, tzinfo=UTC),
            )
            for name in ("overture", "comune_milano")
        ]
        catalog.open_places = [  # type: ignore[attr-defined]
            RadarPlace(
                coverage_key="catalog",
                place_type=place_type,
                name=name,
                latitude=latitude,
                longitude=9.19,
                source_name=source,
                source_external_id=name,
            )
            for name, place_type, latitude, source in (
                ("Clinica Esempio", "veterinary", 45.4700, "overture"),
                ("Area cani Esempio", "dog_park", 45.4660, "comune_milano"),
            )
        ]
        places = client.get(
            "/local-services/places", params={"latitude": 45.4642, "longitude": 9.19}
        ).json()["places"]
        sources = client.get("/local-services/sources").json()["sources"]
        return (
            sorted(place["source_name"] for place in places),
            sorted(source["source"] for source in sources),
        )

    both = ["comune_milano", "overture"]
    assert names({}) == (both, both)
    assert names({"RADAR_OPEN_SOURCES": '["comune_milano"]'}) == (
        ["comune_milano"],
        ["comune_milano"],
    )


def test_a_report_can_be_withdrawn_by_who_made_it_and_ratings_are_read_back(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from apps.api.dependencies.container import get_container
    from packages.core.domain.radar_places.models import RadarPlace

    client = _client_with_env(monkeypatch)
    get_container().radar_places_source = _NoPlacesSource()  # type: ignore[assignment]
    client.post("/account/consents", json={"consent_key": "contribution_rules", "granted": True})
    here = {"latitude": 45.4642, "longitude": 9.19}

    options = client.get("/local-services/reports/options").json()
    assert options["expiry_days"] == 7

    created = client.post("/local-services/reports", json=_REPORT).json()
    assert created["expires_in_days"] == 7
    listed = client.get("/local-services/places", params=here).json()["places"]
    assert listed[0]["community"]["expires_in_days"] == 7

    withdrawn = client.delete(f"/local-services/reports/{created['report_id']}")
    assert withdrawn.json() == {"withdrawn": True}
    assert client.get("/local-services/places", params=here).json()["places"] == []
    assert client.delete(f"/local-services/reports/{created['report_id']}").status_code == 400

    # A star vote is stored and comes back as the viewer's own on the next read.
    get_container().radar_catalog_repository.open_places = [  # type: ignore[attr-defined]
        RadarPlace(
            coverage_key="catalog",
            place_type="dog_park",
            name="Area cani Esempio",
            latitude=45.4660,
            longitude=9.19,
            source_name="comune_milano",
            source_external_id="park-1",
        )
    ]
    get_container().radar_catalog_repository.sources = [  # type: ignore[attr-defined]
        _data_source("comune_milano")
    ]
    rating = {
        "source": "comune_milano",
        "source_id": "park-1",
        "latitude": 45.4660,
        "longitude": 9.19,
        "stars": 4,
    }
    assert client.put("/local-services/ratings", json=rating).json() == {"stars": 4}
    park = client.get("/local-services/places", params=here).json()["places"][0]
    assert park["rating"] == {"can_rate": True, "count": 1, "average": None, "viewer_stars": 4}
    assert client.put("/local-services/ratings", json={**rating, "stars": 2}).status_code == 200
    park = client.get("/local-services/places", params=here).json()["places"][0]
    assert (park["rating"]["count"], park["rating"]["viewer_stars"]) == (1, 2)


def _data_source(name: str) -> object:
    from datetime import UTC, datetime

    from packages.core.domain.radar_places.models import RadarDataSource

    return RadarDataSource(
        source=name,
        release="test",
        license="test",
        attribution="test",
        imported_at=datetime(2026, 10, 4, tzinfo=UTC),
    )


def test_a_confirmed_user_reported_dog_park_is_rated_without_searching_the_area(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from apps.api.dependencies.container import get_container
    from packages.core.domain.radar_reports.models import RadarUserReport

    client = _client_with_env(monkeypatch)
    container = get_container()
    container.radar_places_source = _NoPlacesSource()  # type: ignore[assignment]
    client.post("/account/consents", json={"consent_key": "contribution_rules", "granted": True})
    report = container.radar_reports_repository.save_report(
        RadarUserReport(
            kind="missing",
            status="confirmed",
            place_type="dog_park",
            name="Area cani",
            latitude=45.4660,
            longitude=9.19,
            reporter_pseudonym="someone-else",
            confirmations=5,
        )
    )
    rating = {
        "source": "vetapp_users",
        "source_id": report.id,
        "latitude": 45.4660,
        "longitude": 9.19,
        "stars": 5,
    }

    assert client.put("/local-services/ratings", json=rating).json() == {"stars": 5}
    unknown = client.put("/local-services/ratings", json={**rating, "source_id": "nope"})
    assert unknown.status_code == 400

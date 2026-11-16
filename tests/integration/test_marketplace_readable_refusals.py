"""Round 2 of the synthetic users (2026-11-16): nobody could publish an ad,
because the answers `private_seller_declaration_required` and `age_required`
did not say what was missing. They still carry the code (the app compares it),
plus a sentence in the caller's language and the field to send."""

from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
AD = {
    "title": "Cuccia imbottita",
    "category": "kennels_carriers",
    "condition": "good",
    "latitude": 45.4642,
    "longitude": 9.1900,
}


@pytest.fixture(autouse=True)
def _normal_behaviour(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "pro")


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[object]:
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    current = {"id": USER_A, "locale": "it"}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(
            id=current["id"],
            email="owner@example.com",
            preferred_locale=current["locale"],  # type: ignore[arg-type]
        ),
    )

    def switch(user_id: str, locale: str = "it") -> None:
        current["id"] = user_id
        current["locale"] = locale

    yield switch


def _adult(client: TestClient) -> None:
    today = datetime.now(UTC).date()
    birth = today.replace(year=today.year - 30).isoformat()
    assert client.post("/account/age", json={"birth_date": birth}).status_code == 200


def test_without_a_date_of_birth_the_refusal_says_what_and_where(as_user: object) -> None:
    client = TestClient(app)
    as_user(USER_A, "en")  # type: ignore[operator]

    refused = client.post("/marketplace/listings", json={**AD, "private_seller_declared": True})

    assert refused.status_code == 403
    body = refused.json()
    assert body["code"] == body["detail"] == "age_required"
    assert "date of birth" in body["message"]
    assert body["fix"] == {
        "route": "POST /account/age",
        "field": "birth_date",
        "format": "YYYY-MM-DD",
    }


def test_a_minor_is_told_the_marketplace_is_for_adults(as_user: object) -> None:
    client = TestClient(app)
    today = datetime.now(UTC).date()
    client.post(
        "/account/age", json={"birth_date": today.replace(year=today.year - 16).isoformat()}
    )

    body = client.get("/marketplace/restriction").json()

    assert body["code"] == "marketplace_adults_only"
    assert "18" in body["message"]


def test_without_the_private_seller_box_the_refusal_says_what_to_tick(as_user: object) -> None:
    client = TestClient(app)
    _adult(client)

    refused = client.post("/marketplace/listings", json=AD)

    assert refused.status_code == 400
    body = refused.json()
    # The app still compares `detail`: it stays the bare code.
    assert body["detail"] == body["code"] == "private_seller_declaration_required"
    assert body["message"].startswith("Per pubblicare devi confermare di vendere come privato")
    assert body["fix"] == {"field": "private_seller_declared", "value": True}

    as_user(USER_A, "de")  # type: ignore[operator]
    german = client.post("/marketplace/listings", json=AD).json()
    assert "Privatperson" in german["message"]


def test_once_both_are_given_the_ad_is_published_and_user_b_still_has_to_give_them(
    as_user: object,
) -> None:
    client = TestClient(app)
    _adult(client)

    published = client.post("/marketplace/listings", json={**AD, "private_seller_declared": True})
    assert published.status_code == 200

    # Another owner does not inherit A's date or declaration.
    as_user(USER_B)  # type: ignore[operator]
    refused = client.post("/marketplace/listings", json={**AD, "private_seller_declared": True})
    assert refused.status_code == 403 and refused.json()["code"] == "age_required"


def test_the_language_of_the_request_wins(as_user: object) -> None:
    """Round 2 check: a caller sending Accept-Language: en got Italian."""
    client = TestClient(app)
    _adult(client)

    english = client.post("/marketplace/listings", json=AD, headers={"Accept-Language": "en"})

    assert english.json()["message"].startswith("To publish, you must confirm")


def test_others_do_not_see_how_many_times_an_ad_was_reported(as_user: object) -> None:
    client = TestClient(app)
    _adult(client)
    ad = client.post("/marketplace/listings", json={**AD, "private_seller_declared": True})
    ad_id = ad.json()["listing"]["id"]
    assert "report_count" in ad.json()["listing"], "the seller still sees it on their own ad"

    as_user(USER_B)  # type: ignore[operator]
    _adult(client)
    client.post(f"/marketplace/listings/{ad_id}/report", json={"reason": "spam"})
    seen = client.get(f"/marketplace/listings/{ad_id}").json()["listing"]
    listed = client.get(
        "/marketplace/listings", params={"latitude": 45.46, "longitude": 9.19, "radius_km": 10}
    ).json()["listings"]

    assert "report_count" not in seen
    assert all("report_count" not in row for row in listed)

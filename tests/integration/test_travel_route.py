from datetime import date

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.services.list_travel_cards import ListTravelCardsService
from packages.core.domain.travel.cards import TravelBlock, TravelCard, TravelSentence
from packages.shared.errors.base import AuthenticationError


def _card() -> TravelCard:
    return TravelCard(
        id="via-xx-can",
        country="XX",
        species="dog",
        title="Titolo",
        checked_on=date(2026, 11, 16),
        official_url="https://example.com/official",
        status="approved",
        blocks=(
            TravelBlock(
                kind="documenti", title="Documenti", sentences=(TravelSentence(text="Frase."),)
            ),
        ),
    )


def test_cards_need_a_signed_in_user() -> None:
    container = get_container()
    saved = container.auth_provider

    class _NoSession:
        def get_current_user(self) -> object:
            raise AuthenticationError("Missing access token")

    container.auth_provider = _NoSession()  # type: ignore[assignment]
    try:
        assert TestClient(app).get("/travel/cards").status_code == 401
    finally:
        container.auth_provider = saved


def test_cards_are_served_whole_and_the_route_takes_no_parameter() -> None:
    container = get_container()
    saved = container.travel_cards_service
    container.travel_cards_service = lambda: ListTravelCardsService(  # type: ignore[method-assign]
        [_card()], today=lambda: date(2026, 11, 16)
    )
    try:
        response = TestClient(app).get("/travel/cards")
        parameters = app.openapi()["paths"]["/travel/cards"]["get"].get("parameters", [])
    finally:
        container.travel_cards_service = saved  # type: ignore[method-assign]

    assert response.status_code == 200
    assert [c["id"] for c in response.json()["cards"]] == ["via-xx-can"]
    # Privacy (docs/compliance/17 A.14): no country, no species in the address.
    assert parameters == []

from fastapi import APIRouter

from apps.api.dependencies.container import get_container

router = APIRouter(prefix="/travel", tags=["travel"])


@router.get("/cards")
def list_travel_cards() -> dict[str, object]:
    """Around the world: every approved travel card. General content, the same
    for everybody, but it needs a signed-in user like the rest of the app.

    There is deliberately no filter (no country, no species): the app picks the
    card on the phone, so the pair of countries a person looks at never reaches
    the server nor its logs (docs/compliance/17 A.14)."""
    container = get_container()
    container.auth_provider.get_current_user()
    return {"cards": container.travel_cards_service().execute()}

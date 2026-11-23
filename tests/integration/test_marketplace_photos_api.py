"""The photos of the ads, from the API. Synthetic data only."""

from collections.abc import Callable, Iterator
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.infrastructure.persistence.in_memory_listing_reviews import (
    InMemoryListingReviewRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import InMemoryListingPhotoVault

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
ADMIN = "33333333-3333-4333-8333-333333333333"
PUBLIC = "https://storage.invalid/storage/v1/object/public/marketplace-photos/"
MINE = f"{USER_A}/listing-1/photo-1.jpg"
MINE_2 = f"{USER_A}/listing-1/photo-2.jpg"
OTHERS = f"{USER_B}/listing-1/photo-1.jpg"
AD = {
    "title": "Cuccia imbottita",
    "category": "kennels_carriers",
    "condition": "good",
    "latitude": 45.4642,
    "longitude": 9.1900,
    "private_seller_declared": True,
}
NEARBY = {"latitude": 45.46, "longitude": 9.19, "radius_km": 10}
Switch = Callable[[str], None]

BAD = [
    "https://example.com/1.jpg",
    f"https://example.com/storage/v1/object/public/marketplace-photos/{MINE}",
    f"http://storage.invalid/storage/v1/object/public/marketplace-photos/{MINE}",
    "data:image/jpeg;base64,AAAA",
    f"{PUBLIC}{USER_A}/../{USER_B}/listing-1/photo-1.jpg",
    f"{USER_A}/../x/1.jpg",
    f"{PUBLIC}{OTHERS}",
    OTHERS,
    "published/another-ad/1.jpg",
    f"{PUBLIC}published/another-ad/1.jpg",
]


@pytest.fixture(autouse=True)
def _own_repositories(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "pro")
    container = get_container()
    monkeypatch.setattr(
        container, "marketplace_listing_repository", InMemoryMarketplaceListingRepository()
    )
    monkeypatch.setattr(container, "listing_review_repository", InMemoryListingReviewRepository())
    monkeypatch.setattr(container.settings, "supabase_url", "")
    vault = InMemoryListingPhotoVault()
    vault.public = {MINE, MINE_2, OTHERS}
    monkeypatch.setattr(container, "listing_photo_vault", vault)
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({"team@example.com"}),
    )


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[Switch]:
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    current: dict[str, Any] = {"id": USER_A}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(
            id=current["id"],
            email="team@example.com" if current["id"] == ADMIN else "owner@example.com",
            email_verified=True,
            preferred_locale="it",
        ),
    )

    def switch(user_id: str) -> None:
        current["id"] = user_id

    today = datetime.now(UTC).date()
    for user in (ADMIN, USER_B, USER_A):
        switch(user)
        birth = today.replace(year=today.year - 30).isoformat()
        assert TestClient(app).post("/account/age", json={"birth_date": birth}).status_code == 200
    yield switch


def _post(client: TestClient, photos: list[str]) -> Any:
    return client.post("/marketplace/listings", json={**AD, "photo_urls": photos})


def _vault() -> InMemoryListingPhotoVault:
    vault = get_container().listing_photo_vault
    assert isinstance(vault, InMemoryListingPhotoVault)
    return vault


def _links(client: TestClient) -> list[str]:
    (mine,) = client.get("/marketplace/listings/mine").json()["listings"]
    return list(mine["photo_urls"])


@pytest.mark.parametrize("link", BAD)
def test_publishing_with_any_other_link_is_refused_and_nothing_is_saved(
    as_user: Switch, link: str
) -> None:
    client = TestClient(app)

    for photos in ([link], [f"{PUBLIC}{MINE}", link]):
        refused = _post(client, photos)
        assert refused.status_code == 400
        assert refused.json()["code"] == "photo_refused"
        assert "foto" in refused.json()["detail"]
    assert client.get("/marketplace/listings/mine").json()["listings"] == []
    assert _vault().public == {MINE, MINE_2, OTHERS}, "nothing copied, nothing deleted"


@pytest.mark.parametrize("link", BAD)
def test_editing_with_any_other_link_is_refused_and_nothing_changes(
    as_user: Switch, link: str
) -> None:
    client = TestClient(app)
    listing_id = _post(client, [MINE]).json()["listing"]["id"]
    before = (_links(client), set(_vault().public))

    refused = client.put(
        f"/marketplace/listings/{listing_id}",
        json={**AD, "title": "Altro", "photo_urls": [MINE_2, link]},
    )

    assert refused.status_code == 400
    assert (_links(client), _vault().public) == before


@pytest.mark.parametrize("sent", [MINE, f"{PUBLIC}{MINE}"])
def test_the_photo_is_copied_where_the_seller_cannot_write(as_user: Switch, sent: str) -> None:
    client = TestClient(app)
    listing = _post(client, [sent]).json()["listing"]

    (link,) = listing["photo_urls"]
    assert link.startswith(f"{PUBLIC}published/{listing['id']}/")
    assert MINE not in _vault().public, "the original is gone"
    assert link.removeprefix(PUBLIC) in _vault().public

    as_user(USER_B)
    for answer in (
        client.get(f"/marketplace/listings/{listing['id']}"),
        client.get("/marketplace/listings", params=NEARBY),
    ):
        assert link in answer.text
        assert USER_A not in answer.text, "not even in the address of the photo"


def test_an_edit_keeps_adds_and_takes_off_photos(as_user: Switch) -> None:
    client = TestClient(app)
    path = f"/marketplace/listings/{_post(client, [MINE]).json()['listing']['id']}"
    (first,) = _links(client)

    both = client.put(path, json={**AD, "photo_urls": [MINE_2, first]}).json()["listing"]
    assert both["photo_urls"][1] == first, "the order of the seller"
    second = both["photo_urls"][0]
    assert MINE_2 not in _vault().public

    client.put(path, json={**AD, "photo_urls": [second]})
    assert _links(client) == [second]
    assert _vault().public == {second.removeprefix(PUBLIC), OTHERS}, "no copy left over"


def test_a_confirmation_asked_first_does_not_copy_anything(as_user: Switch) -> None:
    client = TestClient(app)
    body = {**AD, "title": "Ciotola per crocchette", "photo_urls": [MINE]}

    assert client.post("/marketplace/listings", json=body).status_code == 400
    assert _vault().public == {MINE, MINE_2, OTHERS}
    confirmed = client.post(
        "/marketplace/listings", json={**body, "content_confirmations": ["food"]}
    )

    assert confirmed.status_code == 200
    assert len(_vault().public) == 3, "one copy, its original gone"


def test_user_b_cannot_use_the_photos_of_user_a(as_user: Switch) -> None:
    client = TestClient(app)
    (published,) = _post(client, [MINE]).json()["listing"]["photo_urls"]

    as_user(USER_B)
    for link in (f"{PUBLIC}{MINE_2}", MINE_2, published, published.removeprefix(PUBLIC)):
        assert _post(client, [link]).status_code == 400
    own = _post(client, [OTHERS])
    assert own.status_code == 200
    edit = client.put(
        f"/marketplace/listings/{own.json()['listing']['id']}",
        json={**AD, "photo_urls": [published]},
    )
    assert edit.status_code == 400


def test_too_long_or_too_many_are_refused_before_anything_else(as_user: Switch) -> None:
    client = TestClient(app)

    assert _post(client, ["x" * 501]).status_code == 422
    assert _post(client, [MINE] * 7).status_code == 422


def test_a_missing_photo_is_refused(as_user: Switch) -> None:
    client = TestClient(app)

    assert _post(client, [f"{USER_A}/listing-1/never-uploaded.jpg"]).status_code == 400
    assert client.get("/marketplace/listings/mine").json()["listings"] == []


def test_links_already_in_the_database_are_shown_to_nobody(as_user: Switch) -> None:
    """Rows older than the rule, or written straight into the table."""
    client = TestClient(app)
    copy = "published/old/1.jpg"
    get_container().marketplace_listing_repository.save(
        MarketplaceListing(
            id="old",
            owner_id=USER_A,
            title="Cuccia",
            category="toys",
            condition="good",
            location=Coordinates(latitude=45.46, longitude=9.19),
            photo_urls=[*BAD, f"{PUBLIC}{MINE}", f"{PUBLIC}{copy}"],
        )
    )
    # The seller still sees their own old upload, or editing the ad would lose it.
    assert _links(client) == [f"{PUBLIC}{MINE}", f"{PUBLIC}{copy}"]

    as_user(USER_B)
    for answer in (
        client.get("/marketplace/listings", params=NEARBY),
        client.get("/marketplace/listings/old"),
    ):
        assert answer.status_code == 200
        assert f"{PUBLIC}{copy}" in answer.text
        assert "example.com" not in answer.text and "data:" not in answer.text
        assert USER_A not in answer.text and "another-ad" not in answer.text


def test_the_team_is_not_sent_there_either(as_user: Switch) -> None:
    client = TestClient(app)
    title = {"title": "Ciotola per crocchette", "content_confirmations": ["food"]}
    listing_id = client.post(
        "/marketplace/listings", json={**AD, **title, "photo_urls": [MINE]}
    ).json()["listing"]["id"]
    (link,) = _links(client)
    repository = get_container().marketplace_listing_repository
    listing = repository.get(listing_id)
    assert listing is not None
    repository.save(listing.model_copy(update={"photo_urls": [*listing.photo_urls, *BAD]}))

    as_user(ADMIN)
    (review,) = client.get("/admin/moderation/listing_reviews").json()["reviews"]
    item = client.get(f"/admin/moderation/listing_reviews/{review['id']}").json()["item"]

    assert item["photo_urls"] == [link]
    assert item["photos_not_shown"] == len(BAD)


def test_the_seller_deletes_the_ad_and_its_photos_at_once(as_user: Switch) -> None:
    client = TestClient(app)
    path = f"/marketplace/listings/{_post(client, [MINE]).json()['listing']['id']}"

    as_user(USER_B)
    assert client.delete(path).status_code == 404
    as_user(USER_A)
    assert client.delete(path).status_code == 200
    assert client.delete(path).status_code == 404
    assert client.get("/marketplace/listings/mine").json()["listings"] == []
    assert _vault().public == {MINE_2, OTHERS}

import pytest

from packages.core.application.services.list_nearby_listings import (
    ListNearbyListingsInput,
    ListNearbyListingsService,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryMarketplaceListingRepository,
)
from packages.shared.errors.base import ValidationError

ME = Coordinates(latitude=45.46, longitude=9.19)


def _listing(listing_id: str, km_north: float, country: str = "IT") -> MarketplaceListing:
    return MarketplaceListing(
        id=listing_id,
        owner_id="seller",
        title=listing_id,
        category="toys",
        condition="good",
        country=country,
        location=Coordinates(latitude=ME.latitude + km_north / 111.2, longitude=ME.longitude),
    )


def _service(*listings: MarketplaceListing) -> ListNearbyListingsService:
    repository = InMemoryMarketplaceListingRepository()
    for listing in listings:
        repository.save(listing)
    return ListNearbyListingsService(repository)


def _search(radius: float, buyer: Coordinates = ME) -> ListNearbyListingsInput:
    return ListNearbyListingsInput(buyer_location=buyer, max_distance_km=radius)


def test_only_ads_inside_the_radius_nearest_first() -> None:
    service = _service(_listing("far", 30), _listing("near", 2), _listing("mid", 10))

    result = service.execute(_search(25))

    assert [item.id for item in result.listings] == ["near", "mid"]
    assert result.distances_km["near"] == pytest.approx(2, abs=0.05)


def test_distance_is_the_filter_ads_across_a_border_are_returned_too() -> None:
    service = _service(_listing("it-ad", 1), _listing("fr-ad", 1, "FR"), _listing("ch-ad", 2, "CH"))

    result = service.execute(_search(10))

    assert {i.id for i in result.listings} == {"it-ad", "fr-ad", "ch-ad"}
    assert {i.id: i.country for i in result.listings}["ch-ad"] == "CH"


def test_como_sees_lugano_within_25_km_but_not_within_10() -> None:
    como = Coordinates(latitude=45.8081, longitude=9.0852)
    lugano = MarketplaceListing(
        id="lugano-toy",
        owner_id="seller",
        title="Palla",
        category="toys",
        condition="good",
        country="CH",
        city_label="Lugano",
        location=Coordinates(latitude=46.0037, longitude=8.9511),
    )
    service = _service(lugano, _listing("milano", 0))

    assert "lugano-toy" in [i.id for i in service.execute(_search(25, como)).listings]
    assert "lugano-toy" not in [i.id for i in service.execute(_search(10, como)).listings]


def test_ads_that_are_not_active_are_never_returned() -> None:
    hidden = _listing("hidden", 1).model_copy(update={"status": "removed_policy"})
    service = _service(_listing("shown", 1), hidden)

    assert [i.id for i in service.execute(_search(10)).listings] == ["shown"]


@pytest.mark.parametrize("radius", [0, 0.5, 0.99, -1, 300.01, 301, 5000, float("nan")])
def test_a_radius_outside_one_to_three_hundred_km_is_refused(radius: float) -> None:
    service = _service(_listing("a", 1))

    with pytest.raises(ValidationError):
        service.execute(_search(radius))


def test_the_maximum_radius_itself_is_accepted() -> None:
    service = _service(_listing("a", 49), _listing("b", 60), _listing("c", 299), _listing("d", 310))

    assert [i.id for i in service.execute(_search(50)).listings] == ["a"]
    assert [i.id for i in service.execute(_search(300)).listings] == ["a", "b", "c"]


def test_the_minimum_radius_itself_is_accepted() -> None:
    service = _service(_listing("a", 0.5), _listing("b", 5))

    assert [i.id for i in service.execute(_search(1)).listings] == ["a"]


def test_the_search_input_has_no_default_radius() -> None:
    with pytest.raises(ValueError):
        ListNearbyListingsInput(buyer_location=ME)  # type: ignore[call-arg]

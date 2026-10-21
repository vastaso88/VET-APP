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


def _search(radius: float, country: str = "IT") -> ListNearbyListingsInput:
    return ListNearbyListingsInput(buyer_location=ME, max_distance_km=radius, country=country)


def test_only_ads_inside_the_radius_nearest_first() -> None:
    service = _service(_listing("far", 30), _listing("near", 2), _listing("mid", 10))

    result = service.execute(_search(25))

    assert [item.id for item in result.listings] == ["near", "mid"]
    assert result.distances_km["near"] == pytest.approx(2, abs=0.05)


def test_ads_of_other_countries_are_never_returned_however_close() -> None:
    service = _service(_listing("it-ad", 1), _listing("fr-ad", 1, "FR"), _listing("ch-ad", 2, "CH"))

    assert [i.id for i in service.execute(_search(10, "IT")).listings] == ["it-ad"]
    assert [i.id for i in service.execute(_search(10, "fr")).listings] == ["fr-ad"]
    assert service.execute(_search(10, "DE")).listings == []


@pytest.mark.parametrize("radius", [0, -1, 50.01, 51, 1000, float("nan")])
def test_a_radius_outside_zero_to_fifty_km_is_refused(radius: float) -> None:
    service = _service(_listing("a", 1))

    with pytest.raises(ValidationError):
        service.execute(_search(radius))


def test_the_maximum_radius_itself_is_accepted() -> None:
    service = _service(_listing("a", 49), _listing("b", 60))

    assert [i.id for i in service.execute(_search(50)).listings] == ["a"]


def test_an_unknown_country_is_refused() -> None:
    with pytest.raises(ValidationError):
        _service(_listing("a", 1)).execute(_search(10, "ZZ"))


def test_the_search_input_has_no_default_radius_or_country() -> None:
    with pytest.raises(ValueError):
        ListNearbyListingsInput(buyer_location=ME)  # type: ignore[call-arg]

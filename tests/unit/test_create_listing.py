import pytest

from packages.core.application.services.create_listing import (
    CreateListingInput,
    CreateListingService,
)
from packages.core.domain.geo.models import (
    Coordinates,
    approximate_coordinates,
    haversine_distance_km,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryMarketplaceListingRepository,
)
from packages.shared.errors.base import ValidationError


def test_create_listing_never_stores_the_exact_coordinates() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())
    exact = Coordinates(latitude=45.4642, longitude=9.1900)

    result = service.execute(
        CreateListingInput(
            owner_id="user-1",
            title="Trasportino per gatti",
            category="kennels_carriers",
            condition="good",
            exact_location=exact,
        )
    )

    assert result.listing.location == Coordinates(latitude=45.46, longitude=9.19)
    assert result.listing.location != exact
    distance_meters = haversine_distance_km(exact, result.listing.location) * 1000
    assert distance_meters < 700


def test_create_listing_defaults_to_active_status() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    result = service.execute(
        CreateListingInput(
            owner_id="user-1",
            title="Cuccia usata",
            category="other",
            condition="worn",
            exact_location=Coordinates(latitude=45.4642, longitude=9.1900),
        )
    )

    assert result.listing.status == "active"
    assert result.listing.report_count == 0


def test_approximate_coordinates_matches_the_app_and_database_rounding() -> None:
    # Negative values round symmetrically (away from zero), like the app.
    assert approximate_coordinates(
        Coordinates(latitude=-33.8688, longitude=-70.6483)
    ) == Coordinates(latitude=-33.87, longitude=-70.65)
    assert approximate_coordinates(
        Coordinates(latitude=45.46423, longitude=9.18951)
    ) == Coordinates(latitude=45.46, longitude=9.19)


def test_same_cell_sellers_share_one_point() -> None:
    a = approximate_coordinates(Coordinates(latitude=45.4612, longitude=9.1876))
    b = approximate_coordinates(Coordinates(latitude=45.4581, longitude=9.1932))
    assert a == b


def test_create_listing_keeps_target_species() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    result = service.execute(
        CreateListingInput(
            owner_id="user-1",
            title="Tiragraffi",
            category="toys",
            condition="like_new",
            target_species=["cat"],
            exact_location=Coordinates(latitude=45.4642, longitude=9.1900),
        )
    )

    assert result.listing.target_species == ["cat"]


def _input(country: str) -> CreateListingInput:
    return CreateListingInput(
        owner_id="user-1",
        title="Guinzaglio",
        category="leashes_collars",
        condition="good",
        exact_location=Coordinates(latitude=48.1371, longitude=11.5754),
        country=country,
    )


def test_listing_carries_the_country_of_its_seller() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    assert service.execute(_input("US")).listing.country == "US"
    assert service.execute(_input("it")).listing.country == "IT"


@pytest.mark.parametrize("country", ["IT", "US", "AU", "DE", "AT", "CH", "FR", "BE", "ES", "GB"])
def test_every_country_publishes_objects_the_same_way(country: str) -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    assert service.execute(_input(country)).listing.country == country


@pytest.mark.parametrize("country", ["IT", "US", "AU", "DE", "FR", "ES", "GB", "CH"])
@pytest.mark.parametrize(
    "title",
    [
        "Vendo cane",
        "Cuccioli di labrador",
        "Kittens for sale",
        "Welpen zu verkaufen",
        "Chiots à vendre",
    ],
)
def test_no_animals_in_any_country_not_even_italy(country: str, title: str) -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())
    payload = _input(country).model_copy(update={"title": title})

    with pytest.raises(ValidationError, match="solo oggetti per animali"):
        service.execute(payload)


def test_the_description_is_checked_too() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())
    payload = _input("IT").model_copy(
        update={"title": "Cuccia", "description": "Vendo anche due gattini di un mese"}
    )

    with pytest.raises(ValidationError):
        service.execute(payload)


def test_an_accessory_that_names_its_animal_is_published() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())
    payload = _input("IT").model_copy(
        update={"title": "Cuccia per cuccioli", "description": "Trasportino per gatto incluso"}
    )

    assert service.execute(payload).listing.title == "Cuccia per cuccioli"


def test_an_unknown_country_cannot_publish() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    with pytest.raises(ValidationError):
        service.execute(_input("ZZ"))

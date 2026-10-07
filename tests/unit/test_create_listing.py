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

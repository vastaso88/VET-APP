from packages.core.application.services.create_listing import (
    CreateListingInput,
    CreateListingService,
)
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
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
            category="transport_carriers",
            condition="good",
            exact_location=exact,
        )
    )

    distance_meters = haversine_distance_km(exact, result.listing.location) * 1000
    assert 300 <= distance_meters <= 800


def test_create_listing_defaults_to_active_status() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    result = service.execute(
        CreateListingInput(
            owner_id="user-1",
            title="Cuccia usata",
            category="accessories",
            condition="worn",
            exact_location=Coordinates(latitude=45.4642, longitude=9.1900),
        )
    )

    assert result.listing.status == "active"
    assert result.listing.report_count == 0

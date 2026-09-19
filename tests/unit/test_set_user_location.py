from packages.core.application.services.get_user_location import (
    GetUserLocationInput,
    GetUserLocationService,
)
from packages.core.application.services.set_user_location import (
    SetUserLocationInput,
    SetUserLocationService,
)
from packages.core.domain.geo.models import Coordinates
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryUserLocationRepository,
)


def test_get_user_location_returns_an_empty_default_when_none_saved() -> None:
    service = GetUserLocationService(InMemoryUserLocationRepository())

    result = service.execute(GetUserLocationInput(owner_id="user-1"))

    assert result.user_location.owner_id == "user-1"
    assert result.user_location.home is None
    assert result.user_location.current is None


def test_set_user_location_saves_a_manual_home_location() -> None:
    repository = InMemoryUserLocationRepository()
    service = SetUserLocationService(repository)

    result = service.execute(
        SetUserLocationInput(
            owner_id="user-1",
            home=Coordinates(latitude=45.4642, longitude=9.1900),
            home_label="Milano",
        )
    )

    assert result.user_location.home == Coordinates(latitude=45.4642, longitude=9.1900)
    assert result.user_location.home_label == "Milano"


def test_updating_current_position_does_not_erase_an_existing_home() -> None:
    repository = InMemoryUserLocationRepository()
    service = SetUserLocationService(repository)
    service.execute(
        SetUserLocationInput(
            owner_id="user-1",
            home=Coordinates(latitude=45.4642, longitude=9.1900),
            home_label="Milano",
        )
    )

    result = service.execute(
        SetUserLocationInput(
            owner_id="user-1",
            current=Coordinates(latitude=41.9028, longitude=12.4964),
            current_label="Roma",
            current_source="device_gps",
        )
    )

    assert result.user_location.home_label == "Milano"
    assert result.user_location.current_label == "Roma"
    assert result.user_location.current_source == "device_gps"
    assert result.user_location.current_captured_at is not None

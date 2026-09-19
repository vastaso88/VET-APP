from packages.core.application.services.create_local_activity import (
    CreateLocalActivityInput,
    CreateLocalActivityService,
)
from packages.core.application.services.list_nearby_activities import (
    ListNearbyActivitiesInput,
    ListNearbyActivitiesService,
)
from packages.core.domain.geo.models import Coordinates
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryLocalActivityRepository,
)

MILAN = Coordinates(latitude=45.4642, longitude=9.1900)
ROME = Coordinates(latitude=41.9028, longitude=12.4964)


def test_only_activities_within_range_are_returned() -> None:
    repository = InMemoryLocalActivityRepository()
    CreateLocalActivityService(repository).execute(
        CreateLocalActivityInput(kind="event", title="Fiera vicina", location=MILAN)
    )
    CreateLocalActivityService(repository).execute(
        CreateLocalActivityInput(kind="event", title="Fiera lontana", location=ROME)
    )

    result = ListNearbyActivitiesService(repository).execute(
        ListNearbyActivitiesInput(center=MILAN, max_distance_km=50)
    )

    titles = [activity.title for activity in result.activities]
    assert titles == ["Fiera vicina"]


def test_results_are_sorted_by_distance_ascending() -> None:
    repository = InMemoryLocalActivityRepository()
    near = Coordinates(latitude=45.47, longitude=9.19)
    far = Coordinates(latitude=45.60, longitude=9.30)
    CreateLocalActivityService(repository).execute(
        CreateLocalActivityInput(kind="service", title="Lontano", location=far)
    )
    CreateLocalActivityService(repository).execute(
        CreateLocalActivityInput(kind="service", title="Vicino", location=near)
    )

    result = ListNearbyActivitiesService(repository).execute(
        ListNearbyActivitiesInput(center=MILAN, max_distance_km=100)
    )

    assert [activity.title for activity in result.activities] == ["Vicino", "Lontano"]


def test_filtering_by_kind() -> None:
    repository = InMemoryLocalActivityRepository()
    CreateLocalActivityService(repository).execute(
        CreateLocalActivityInput(kind="event", title="Evento", location=MILAN)
    )
    CreateLocalActivityService(repository).execute(
        CreateLocalActivityInput(kind="service", title="Servizio", location=MILAN)
    )

    result = ListNearbyActivitiesService(repository).execute(
        ListNearbyActivitiesInput(center=MILAN, max_distance_km=10, kind="service")
    )

    assert [activity.title for activity in result.activities] == ["Servizio"]

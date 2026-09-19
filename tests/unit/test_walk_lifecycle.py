import pytest

from packages.core.application.services.end_walk import EndWalkInput, EndWalkService
from packages.core.application.services.record_route_point import (
    RecordRoutePointInput,
    RecordRoutePointService,
)
from packages.core.application.services.start_walk import StartWalkInput, StartWalkService
from packages.core.domain.dog_walk.models import estimate_steps
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryDogWalkRepository,
    InMemoryPetProfileRepository,
)
from packages.shared.errors.base import ValidationError


def _pet_repository() -> InMemoryPetProfileRepository:
    repository = InMemoryPetProfileRepository()
    repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Moka", species="dog"))
    return repository


def test_start_walk_rejects_an_unknown_pet() -> None:
    service = StartWalkService(InMemoryDogWalkRepository(), InMemoryPetProfileRepository())

    with pytest.raises(ValidationError):
        service.execute(StartWalkInput(owner_id="user-1", pet_id="missing-pet"))


def test_start_walk_creates_an_in_progress_session() -> None:
    service = StartWalkService(InMemoryDogWalkRepository(), _pet_repository())

    result = service.execute(StartWalkInput(owner_id="user-1", pet_id="pet-1"))

    assert result.walk.status == "in_progress"
    assert result.walk.distance_meters == 0.0
    assert result.walk.route == []


def test_recording_route_points_accumulates_distance() -> None:
    walk_repository = InMemoryDogWalkRepository()
    walk = StartWalkService(walk_repository, _pet_repository()).execute(
        StartWalkInput(owner_id="user-1", pet_id="pet-1")
    ).walk
    service = RecordRoutePointService(walk_repository)

    service.execute(
        RecordRoutePointInput(
            walk_id=walk.id, coordinates=Coordinates(latitude=45.4642, longitude=9.1900)
        )
    )
    result = service.execute(
        RecordRoutePointInput(
            walk_id=walk.id, coordinates=Coordinates(latitude=45.4650, longitude=9.1910)
        )
    )

    assert len(result.walk.route) == 2
    assert result.walk.distance_meters > 0


def test_recording_a_point_on_a_finished_walk_is_rejected() -> None:
    walk_repository = InMemoryDogWalkRepository()
    walk = StartWalkService(walk_repository, _pet_repository()).execute(
        StartWalkInput(owner_id="user-1", pet_id="pet-1")
    ).walk
    EndWalkService(walk_repository).execute(EndWalkInput(walk_id=walk.id))

    with pytest.raises(ValidationError):
        RecordRoutePointService(walk_repository).execute(
            RecordRoutePointInput(
                walk_id=walk.id, coordinates=Coordinates(latitude=45.4642, longitude=9.1900)
            )
        )


def test_ending_a_walk_sets_duration_and_estimated_steps() -> None:
    walk_repository = InMemoryDogWalkRepository()
    walk = StartWalkService(walk_repository, _pet_repository()).execute(
        StartWalkInput(owner_id="user-1", pet_id="pet-1")
    ).walk
    RecordRoutePointService(walk_repository).execute(
        RecordRoutePointInput(
            walk_id=walk.id, coordinates=Coordinates(latitude=45.4642, longitude=9.1900)
        )
    )
    RecordRoutePointService(walk_repository).execute(
        RecordRoutePointInput(
            walk_id=walk.id, coordinates=Coordinates(latitude=45.4700, longitude=9.1950)
        )
    )

    result = EndWalkService(walk_repository).execute(EndWalkInput(walk_id=walk.id))

    assert result.walk.status == "completed"
    assert result.walk.ended_at is not None
    assert result.walk.duration_seconds is not None
    assert result.walk.step_count_estimate == estimate_steps(result.walk.distance_meters)


def test_ending_an_already_finished_walk_is_rejected() -> None:
    walk_repository = InMemoryDogWalkRepository()
    walk = StartWalkService(walk_repository, _pet_repository()).execute(
        StartWalkInput(owner_id="user-1", pet_id="pet-1")
    ).walk
    EndWalkService(walk_repository).execute(EndWalkInput(walk_id=walk.id))

    with pytest.raises(ValidationError):
        EndWalkService(walk_repository).execute(EndWalkInput(walk_id=walk.id))


def test_estimate_steps_is_zero_for_no_distance() -> None:
    assert estimate_steps(0) == 0


def test_estimate_steps_uses_the_default_stride() -> None:
    assert estimate_steps(75, stride_meters=0.75) == 100

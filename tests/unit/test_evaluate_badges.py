from packages.core.domain.dog_walk.models import WalkSession, evaluate_badges


def _completed_walk(pet_id: str, distance_meters: float) -> WalkSession:
    return WalkSession(
        owner_id="user-1",
        pet_id=pet_id,
        status="completed",
        distance_meters=distance_meters,
    )


def test_no_completed_walks_yields_no_badges() -> None:
    in_progress = WalkSession(owner_id="user-1", pet_id="pet-1", status="in_progress")

    assert evaluate_badges([in_progress]) == []


def test_first_completed_walk_unlocks_the_first_walk_badge_for_that_pet() -> None:
    badges = evaluate_badges([_completed_walk("pet-1", distance_meters=500)])

    assert badges == ["first_walk_pet_pet-1"]


def test_badges_are_tracked_separately_per_pet() -> None:
    badges = evaluate_badges(
        [
            _completed_walk("pet-1", distance_meters=500),
            _completed_walk("pet-2", distance_meters=500),
        ]
    )

    assert "first_walk_pet_pet-1" in badges
    assert "first_walk_pet_pet-2" in badges


def test_crossing_a_distance_threshold_unlocks_that_badge() -> None:
    walks = [_completed_walk("pet-1", distance_meters=6_000) for _ in range(2)]

    badges = evaluate_badges(walks)

    assert "distance_10km_pet_pet-1" in badges
    assert "distance_50km_pet_pet-1" not in badges


def test_crossing_a_higher_distance_threshold_also_keeps_the_lower_ones() -> None:
    walks = [_completed_walk("pet-1", distance_meters=60_000) for _ in range(1)]

    badges = evaluate_badges(walks)

    assert "distance_10km_pet_pet-1" in badges
    assert "distance_50km_pet_pet-1" in badges
    assert "distance_100km_pet_pet-1" not in badges


def test_crossing_a_walk_count_threshold_unlocks_that_badge() -> None:
    walks = [_completed_walk("pet-1", distance_meters=100) for _ in range(10)]

    badges = evaluate_badges(walks)

    assert "walks_10_pet_pet-1" in badges
    assert "walks_30_pet_pet-1" not in badges


def test_in_progress_and_discarded_walks_do_not_count_toward_badges() -> None:
    walks = [
        _completed_walk("pet-1", distance_meters=100),
        WalkSession(
            owner_id="user-1", pet_id="pet-1", status="in_progress", distance_meters=50_000
        ),
        WalkSession(
            owner_id="user-1", pet_id="pet-1", status="discarded", distance_meters=50_000
        ),
    ]

    badges = evaluate_badges(walks)

    assert "distance_10km_pet_pet-1" not in badges
    assert badges == ["first_walk_pet_pet-1"]

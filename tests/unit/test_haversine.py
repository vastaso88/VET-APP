from packages.core.domain.geo.models import Coordinates, fuzz_coordinates, haversine_distance_km


def test_distance_between_identical_points_is_zero() -> None:
    point = Coordinates(latitude=41.9028, longitude=12.4964)

    assert haversine_distance_km(point, point) == 0.0


def test_distance_is_symmetric() -> None:
    rome = Coordinates(latitude=41.9028, longitude=12.4964)
    milan = Coordinates(latitude=45.4642, longitude=9.1900)

    assert haversine_distance_km(rome, milan) == haversine_distance_km(milan, rome)


def test_one_degree_of_longitude_at_the_equator_is_about_111_km() -> None:
    origin = Coordinates(latitude=0, longitude=0)
    one_degree_east = Coordinates(latitude=0, longitude=1)

    distance = haversine_distance_km(origin, one_degree_east)

    assert 111.0 < distance < 111.4


def test_fuzz_coordinates_stays_within_the_expected_radius() -> None:
    exact = Coordinates(latitude=45.4642, longitude=9.1900)

    fuzzed = fuzz_coordinates(exact, listing_id="listing-1")

    distance_meters = haversine_distance_km(exact, fuzzed) * 1000
    assert 300 <= distance_meters <= 800


def test_fuzz_coordinates_is_deterministic_per_listing_id() -> None:
    exact = Coordinates(latitude=45.4642, longitude=9.1900)

    first = fuzz_coordinates(exact, listing_id="listing-1")
    second = fuzz_coordinates(exact, listing_id="listing-1")

    assert first == second


def test_fuzz_coordinates_differs_across_listings() -> None:
    exact = Coordinates(latitude=45.4642, longitude=9.1900)

    first = fuzz_coordinates(exact, listing_id="listing-1")
    second = fuzz_coordinates(exact, listing_id="listing-2")

    assert first != second

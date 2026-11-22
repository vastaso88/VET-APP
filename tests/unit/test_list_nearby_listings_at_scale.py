"""QK-08: the Mercatino search narrows its candidates in the database (category + a
latitude/longitude box) and keeps the exact distance, the visibility rules and the
order in Python.

Synthetic data only. `_Client` is a stand-in for the database that returns at most
1000 rows per request (the provider window) and counts what it sends, so the tests show
both that ads inside the radius are complete beyond that window and how many candidates
reach Python (`_Counting` wraps the repository)."""

from __future__ import annotations

import math
import random
from collections.abc import Callable
from typing import Any

import pytest

from packages.core.application.services.list_nearby_listings import (
    ListNearbyListingsInput,
    ListNearbyListingsService,
)
from packages.core.domain.geo.bounding_box import bounding_box
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.marketplace.models import ListingCategory, MarketplaceListing
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.persistence.supabase import supabase_repositories as sb
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseMarketplaceListingRepository,
)

WINDOW = 1000
MILAN = Coordinates(latitude=45.4642, longitude=9.19)
KM_PER_DEGREE = 111.195


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, client: _Client) -> None:
        self._client = client
        self._filters: list[Callable[[dict[str, Any]], bool]] = []
        self._range: tuple[int, int] | None = None
        self.description: list[tuple[str, str, Any]] = []

    def select(self, _columns: str) -> _Query:
        return self

    def eq(self, column: str, value: Any) -> _Query:
        self.description.append(("eq", column, value))
        self._filters.append(lambda row: row[column] == value)
        return self

    def gte(self, column: str, value: float) -> _Query:
        self.description.append(("gte", column, value))
        self._filters.append(lambda row: row[column] >= value)
        return self

    def lte(self, column: str, value: float) -> _Query:
        self.description.append(("lte", column, value))
        self._filters.append(lambda row: row[column] <= value)
        return self

    def order(self, _column: str) -> _Query:
        return self

    def range(self, start: int, end: int) -> _Query:
        self._range = (start, end)
        return self

    def execute(self) -> _Response:
        rows = [row for row in self._client.rows if all(check(row) for check in self._filters)]
        rows.sort(key=lambda row: row["id"])
        start, end = self._range if self._range is not None else (0, WINDOW - 1)
        rows = rows[start : min(end + 1, start + WINDOW)]  # the provider window
        self._client.requests += 1
        self._client.rows_sent += len(rows)
        self._client.queries.append(self.description)
        return _Response([dict(row) for row in rows])


class _Client:
    def __init__(self, listings: list[MarketplaceListing]) -> None:
        self.rows = [sb._listing_to_row(item) for item in listings]
        self.requests = 0
        self.rows_sent = 0
        self.queries: list[list[tuple[str, str, Any]]] = []

    def table(self, _name: str) -> _Query:
        return _Query(self)


class _Counting:
    """Wraps a repository and counts the candidates that reach the service."""

    def __init__(self, inner: Any) -> None:
        self._inner = inner
        self.candidates = 0

    def list_active_in_box(self, box: Any, category: Any = None) -> list[MarketplaceListing]:
        found: list[MarketplaceListing] = self._inner.list_active_in_box(box, category)
        self.candidates += len(found)
        return found

    def __getattr__(self, name: str) -> Any:
        return getattr(self._inner, name)


def _ad(
    index: int,
    latitude: float,
    longitude: float,
    *,
    owner: str = "seller",
    category: ListingCategory = "toys",
    status: str = "active",
    country: str = "IT",
) -> MarketplaceListing:
    return MarketplaceListing(
        id=f"ad-{index:05d}",
        owner_id=owner,
        title=f"Annuncio {index}",
        category=category,
        condition="good",
        country=country,
        status=status,  # type: ignore[arg-type]
        location=Coordinates(latitude=latitude, longitude=longitude),
    )


def _around(rng: random.Random, center: Coordinates, max_km: float) -> tuple[float, float]:
    """A random point within about max_km of center (a square, so some are beyond)."""
    dlat = rng.uniform(-max_km, max_km) / KM_PER_DEGREE
    dlng = rng.uniform(-max_km, max_km) / (KM_PER_DEGREE * max(0.05, abs(_cos(center.latitude))))
    return (
        max(-90.0, min(90.0, center.latitude + dlat)),
        ((center.longitude + dlng + 180.0) % 360.0) - 180.0,
    )


def _cos(degrees: float) -> float:
    return math.cos(math.radians(degrees))


def _expected(
    listings: list[MarketplaceListing],
    buyer: Coordinates,
    radius: float,
    *,
    category: str | None = None,
    hidden: set[str] | None = None,
) -> list[tuple[str, float]]:
    """Brute force over EVERY ad: what the search must return, nearest first."""
    found = [
        (item.id, haversine_distance_km(buyer, item.location))
        for item in listings
        if item.status == "active"
        and item.owner_id not in (hidden or set())
        and (category is None or item.category == category)
    ]
    return sorted(((i, d) for i, d in found if d <= radius), key=lambda pair: (pair[1], pair[0]))


def _search(
    repository: Any,
    buyer: Coordinates,
    radius: float,
    *,
    category: ListingCategory | None = None,
    hidden: set[str] | None = None,
) -> tuple[list[str], dict[str, float]]:
    service = ListNearbyListingsService(repository, hidden_owner_ids=lambda: hidden or set())
    result = service.execute(
        ListNearbyListingsInput(buyer_location=buyer, max_distance_km=radius, category=category)
    )
    return [item.id for item in result.listings], result.distances_km


def _dataset() -> list[MarketplaceListing]:
    """4,300 active ads: 1,500 within ~20 km of Milan (more than one provider window),
    300 more in the box but outside a 25 km radius, and 2,500 elsewhere in the world."""
    rng = random.Random(20261122)
    listings: list[MarketplaceListing] = []
    index = 0
    for _ in range(1500):
        listings.append(_ad(index, *_around(rng, MILAN, 20.0), category="toys"))
        index += 1
    for _ in range(300):
        lat, lng = _around(rng, MILAN, 60.0)
        listings.append(_ad(index, lat, lng, category="food"))
        index += 1
    for center in (
        Coordinates(latitude=41.9, longitude=12.5),  # Rome
        Coordinates(latitude=48.85, longitude=2.35),  # Paris
        Coordinates(latitude=-33.87, longitude=151.2),  # Sydney
        Coordinates(latitude=40.7, longitude=-74.0),  # New York
    ):
        for _ in range(625):
            listings.append(_ad(index, *_around(rng, center, 30.0), country="XX"))
            index += 1
    return listings


@pytest.fixture(scope="module")
def dataset() -> list[MarketplaceListing]:
    return _dataset()


def _supabase(listings: list[MarketplaceListing]) -> tuple[_Counting, _Client]:
    client = _Client(listings)
    return _Counting(SupabaseMarketplaceListingRepository(client)), client  # type: ignore[arg-type]


def _memory(listings: list[MarketplaceListing]) -> _Counting:
    inner = InMemoryMarketplaceListingRepository()
    for item in listings:
        inner.save(item)
    return _Counting(inner)


# ------------------------------------------------------- completeness and order


def test_ads_inside_the_radius_are_complete_and_ordered_beyond_the_provider_window(
    dataset: list[MarketplaceListing],
) -> None:
    repository, client = _supabase(dataset)
    expected = _expected(dataset, MILAN, 25)
    assert len(expected) > WINDOW  # the point of the test: more than one window of results

    ids, distances = _search(repository, MILAN, 25)

    assert ids == [ad_id for ad_id, _ in expected]  # complete, nearest first, id breaks ties
    assert distances == pytest.approx({ad_id: d for ad_id, d in expected})
    # The old read took the first window of EVERY active ad and filtered it afterwards:
    old = InMemoryMarketplaceListingRepository()
    for item in dataset:
        old.save(item)
    first_window = {item.id for item in old.list_active()[:WINDOW]}
    assert not {ad_id for ad_id, _ in expected} <= first_window  # it would have lost ads
    assert client.requests >= 2  # and the new read paged through them


def test_how_many_candidates_reach_python_before_and_after(
    dataset: list[MarketplaceListing],
) -> None:
    repository, _ = _supabase(dataset)
    _search(repository, MILAN, 25)
    # Before: every active ad (here 4,300; the real provider cut it at 1,000 rows).
    before = len([item for item in dataset if item.status == "active"])
    assert before == 4300
    # After: only the box around the circle, and only the category asked for.
    assert repository.candidates < before / 2
    assert repository.candidates >= len(_expected(dataset, MILAN, 25))
    toys_only, _ = _supabase(dataset)
    _search(toys_only, MILAN, 25, category="toys")
    assert toys_only.candidates < repository.candidates  # 'food' ads never left the database


def test_a_small_radius_reads_few_rows(dataset: list[MarketplaceListing]) -> None:
    repository, client = _supabase(dataset)
    ids, _ = _search(repository, MILAN, 3)
    assert ids == [i for i, _ in _expected(dataset, MILAN, 3)]
    assert client.rows_sent < 200  # a city centre, not the Mercatino of the whole world


def test_category_and_box_travel_in_the_query_not_in_python(
    dataset: list[MarketplaceListing],
) -> None:
    repository, client = _supabase(dataset)
    _search(repository, MILAN, 25, category="food")
    operations = {(op, column) for query in client.queries for op, column, _ in query}
    assert {("eq", "status"), ("eq", "category"), ("gte", "latitude"), ("lte", "latitude")} <= (
        operations
    )
    assert {("gte", "longitude"), ("lte", "longitude")} <= operations
    ids, _ = _search(repository, MILAN, 25, category="food")
    assert ids == [i for i, _ in _expected(dataset, MILAN, 25, category="food")]


@pytest.mark.parametrize("adapter", ["supabase", "memory"])
def test_the_two_adapters_agree(dataset: list[MarketplaceListing], adapter: str) -> None:
    repository = _supabase(dataset)[0] if adapter == "supabase" else _memory(dataset)
    for radius in (1, 7, 25, 120, 300):
        ids, _ = _search(repository, MILAN, radius)
        assert ids == [i for i, _ in _expected(dataset, MILAN, radius)], radius


# ------------------------------------------------------------ edges and rules


def test_the_radius_edge_is_exact_inside_and_outside_the_box_corner() -> None:
    # 24.9 km and 25.1 km due north, and a point in the corner of the box (inside the
    # box, farther than 25 km from the centre): only the first is within 25 km.
    north = lambda km: MILAN.latitude + km / KM_PER_DEGREE  # noqa: E731
    box = bounding_box(MILAN, 25)
    corner = Coordinates(
        latitude=box.max_latitude - 0.001, longitude=box.longitude_ranges[0][1] - 0.001
    )
    assert box.contains(corner) and haversine_distance_km(MILAN, corner) > 25
    listings = [
        _ad(1, north(24.9), MILAN.longitude),
        _ad(2, north(25.1), MILAN.longitude),
        _ad(3, corner.latitude, corner.longitude),
    ]
    for repository in (_supabase(listings)[0], _memory(listings)):
        assert _search(repository, MILAN, 25)[0] == ["ad-00001"]
        assert _search(repository, MILAN, 25.2)[0] == ["ad-00001", "ad-00002"]


def test_the_largest_radius_includes_the_ad_on_its_edge() -> None:
    far = Coordinates(latitude=MILAN.latitude + 299.9 / KM_PER_DEGREE, longitude=MILAN.longitude)
    beyond = Coordinates(latitude=MILAN.latitude + 300.5 / KM_PER_DEGREE, longitude=MILAN.longitude)
    listings = [_ad(1, far.latitude, far.longitude), _ad(2, beyond.latitude, beyond.longitude)]
    for repository in (_supabase(listings)[0], _memory(listings)):
        assert _search(repository, MILAN, 300)[0] == ["ad-00001"]


def test_ads_across_a_national_border_are_found_by_distance_not_by_country() -> None:
    como = Coordinates(latitude=45.8081, longitude=9.0852)
    listings = [
        _ad(1, 46.0037, 8.9511, country="CH"),  # Lugano, ~25 km
        _ad(2, 45.8, 9.1, country="IT"),
        _ad(3, 47.37, 8.54, country="CH"),  # Zurich, far
    ]
    for repository in (_supabase(listings)[0], _memory(listings)):
        assert _search(repository, como, 30)[0] == ["ad-00002", "ad-00001"]
        assert _search(repository, como, 10)[0] == ["ad-00002"]


def test_hidden_sellers_never_appear_and_the_others_stay_complete(
    dataset: list[MarketplaceListing],
) -> None:
    # Sellers asking for erasure or paused: 600 of the ads near Milan belong to them.
    hidden_owner = "paused-seller"
    listings = [
        item.model_copy(update={"owner_id": hidden_owner}) if i % 5 == 0 and i < 3000 else item
        for i, item in enumerate(dataset)
    ]
    repository, _ = _supabase(listings)
    ids, _ = _search(repository, MILAN, 25, hidden={hidden_owner})
    expected = _expected(listings, MILAN, 25, hidden={hidden_owner})
    assert ids == [i for i, _ in expected]
    assert len(ids) > 800
    owners = {item.id: item.owner_id for item in listings}
    assert all(owners[i] != hidden_owner for i in ids)
    # Not hidden any more (the deletion was cancelled): they are back.
    again, _ = _search(repository, MILAN, 25, hidden=set())
    assert len(again) > len(ids)


def test_inactive_ads_are_never_candidates() -> None:
    listings = [_ad(1, 45.47, 9.19), _ad(2, 45.47, 9.19, status="removed_policy")]
    for repository in (_supabase(listings)[0], _memory(listings)):
        assert _search(repository, MILAN, 10)[0] == ["ad-00001"]


# --------------------------------------------------- antimeridian, poles, the box


def test_a_search_across_the_antimeridian_finds_both_sides() -> None:
    buyer = Coordinates(latitude=-17.0, longitude=179.9)  # Fiji
    listings = [
        _ad(1, -17.0, 179.5),  # same side, ~42 km
        _ad(2, -17.0, -179.8),  # other side of 180°, ~34 km
        _ad(3, -17.0, -178.0),  # other side, ~210 km: out of a 100 km radius
        _ad(4, -17.0, 170.0),  # far on the same side
    ]
    box = bounding_box(buyer, 100)
    assert len(box.longitude_ranges) == 2
    for repository in (_supabase(listings)[0], _memory(listings)):
        assert _search(repository, buyer, 100)[0] == ["ad-00002", "ad-00001"]
    repository, client_ = _supabase(listings)
    _search(repository, buyer, 100)
    assert client_.requests == 2  # one request per longitude range


def test_a_search_near_the_pole_covers_every_longitude() -> None:
    buyer = Coordinates(latitude=89.5, longitude=10.0)
    listings = [
        _ad(1, 89.7, -170.0),  # over the pole: (0.5 + 0.3) deg ~ 89 km
        _ad(2, 89.5, 11.0),  # ~0.5 km
        _ad(3, 85.0, 10.0),  # ~500 km
    ]
    box = bounding_box(buyer, 100)
    assert box.longitude_ranges == ((-180.0, 180.0),)
    for repository in (_supabase(listings)[0], _memory(listings)):
        assert _search(repository, buyer, 100)[0] == ["ad-00002", "ad-00001"]
    south = Coordinates(latitude=-89.9, longitude=0.0)
    listings = [_ad(1, -89.95, 180.0), _ad(2, -80.0, 0.0)]
    assert _search(_memory(listings), south, 50)[0] == ["ad-00001"]


def test_the_box_always_contains_the_whole_circle() -> None:
    """Property: whatever is within the radius (haversine) is inside the box."""
    rng = random.Random(7)
    for _ in range(3000):
        centre = Coordinates(
            latitude=rng.choice([rng.uniform(-90, 90), rng.uniform(80, 90), rng.uniform(-90, -80)]),
            longitude=rng.uniform(-180, 180),
        )
        radius = rng.choice([1.0, 5.0, 50.0, 300.0, rng.uniform(1, 300)])
        box = bounding_box(centre, radius)
        for _ in range(30):
            point = Coordinates(
                latitude=max(-90.0, min(90.0, centre.latitude + rng.uniform(-4, 4))),
                longitude=((centre.longitude + rng.uniform(-40, 40) + 180) % 360) - 180,
            )
            if haversine_distance_km(centre, point) <= radius:
                assert box.contains(point), (centre, radius, point)


# --------------------------------------------------------------------- safety


def test_more_candidates_than_the_safety_limit_is_an_error_not_a_cut_list(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    rng = random.Random(3)
    listings = [_ad(i, *_around(rng, MILAN, 5.0)) for i in range(2500)]
    monkeypatch.setattr(sb, "_MAX_BOX_ROWS", 2000)
    repository, _ = _supabase(listings)
    with pytest.raises(RuntimeError):
        _search(repository, MILAN, 25)

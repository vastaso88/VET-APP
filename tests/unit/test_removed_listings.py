"""Ads the team took down: photos out of the public bucket, deletion 6 months after the
decision, register of decisions after 24 (owner decisions of 2026-11-23). Synthetic data."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.listing_review_repository import ListingReviewsUnavailable
from packages.core.application.services.listing_review import ListingReviewService
from packages.core.application.services.removed_listings import PruneRemovedListingsService
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.content_review import ListingDecision, ListingReview
from packages.core.domain.marketplace.models import ListingStatus, MarketplaceListing
from packages.core.domain.marketplace.photos import LOCAL_PHOTO_BASE
from packages.infrastructure.persistence.in_memory_listing_reviews import (
    InMemoryListingReviewRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryListingReportRepository,
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import (
    HELD_BUCKET,
    PUBLIC_BUCKET,
    InMemoryListingPhotoVault,
    SupabaseListingPhotoVault,
)

NOW = datetime(2026, 11, 23, 12, 0, tzinfo=UTC)


def _url(path: str) -> str:
    return f"https://storage.invalid/storage/v1/object/public/{PUBLIC_BUCKET}/{path}"


class _World:
    def __init__(self) -> None:
        self.listings = InMemoryMarketplaceListingRepository()
        self.reviews = InMemoryListingReviewRepository()
        self.vault = InMemoryListingPhotoVault()
        self.job = PruneRemovedListingsService(self.listings, self.reviews, self.vault)

    def ad(
        self, name: str, status: ListingStatus = "removed_policy", *, owner: str = "a"
    ) -> MarketplaceListing:
        path = f"published/{name}/1.jpg"
        self.vault.public.add(path)
        return self.listings.save(
            MarketplaceListing(
                id=name,
                owner_id=owner,
                title="Ciotola per crocchette",
                category="toys",
                condition="good",
                location=Coordinates(latitude=45.46, longitude=9.19),
                photo_urls=[_url(path)],
                status=status,
                updated_at=NOW - timedelta(days=1),
            )
        )

    def decided(self, listing: MarketplaceListing, days_ago: int, status: str = "removed") -> None:
        self.reviews.save(
            ListingReview(
                listing_id=listing.id,
                owner_id=listing.owner_id,
                status=status,  # type: ignore[arg-type]
                title=listing.title,
                category=listing.category,
                photo_urls=listing.photo_urls,
                decided_at=NOW - timedelta(days=days_ago),
            )
        )


@pytest.fixture
def world() -> _World:
    return _World()


def test_after_six_months_the_ad_and_its_photos_are_deleted(world: _World) -> None:
    old, recent = world.ad("old"), world.ad("recent")
    world.decided(old, 184)
    world.decided(recent, 150)

    report = world.job.run(NOW)

    assert (report.listings_deleted, report.photos_deleted) == (1, 1)
    assert world.listings.get("old") is None and world.listings.get("recent") is not None
    assert world.vault.public == set(), "the recent one is out of the public bucket too"
    assert world.vault.held == {"published/recent/1.jpg"}
    again = world.job.run(NOW)
    assert (again.listings_deleted, again.photos_deleted) == (0, 0)


def test_the_last_decision_counts(world: _World) -> None:
    twice = world.ad("twice")
    world.decided(twice, 300)
    world.decided(twice, 30)

    assert world.job.run(NOW).listings_deleted == 0


def test_only_ads_the_team_took_down_are_touched(world: _World) -> None:
    animals = world.ad("animals")  # hidden by the rule on animals: never deleted here
    checked = world.ad("checked", "active")
    world.decided(checked, 400, status="checked")
    restored = world.ad("restored", "active")
    world.decided(restored, 400)

    report = world.job.run(NOW)

    assert report.listings_deleted == 0
    assert {animals.id, checked.id, restored.id} == {
        item.id for item in world.listings.list_by_owner("a", 10)
    }
    assert world.vault.public == {"published/checked/1.jpg", "published/restored/1.jpg"}
    assert world.vault.held == {"published/animals/1.jpg"}


def test_a_photo_another_ad_still_shows_stays_public(world: _World) -> None:
    shown = world.ad("shown", "active")
    down = world.ad("down")
    world.listings.save(down.model_copy(update={"photo_urls": shown.photo_urls}))
    world.decided(down, 10)

    world.job.run(NOW)

    assert "published/shown/1.jpg" in world.vault.public


def test_photos_of_an_ad_its_seller_deleted_go_at_the_next_run(world: _World) -> None:
    world.vault.held.add("published/gone/1.jpg")

    report = world.job.run(NOW)

    assert report.photos_deleted == 1 and world.vault.held == set()


def test_photos_held_for_an_ad_that_is_back_return(world: _World) -> None:
    back = world.ad("back", "active")
    world.vault.withhold(world.vault.paths(back))

    world.job.run(NOW)

    assert world.vault.public == {"published/back/1.jpg"} and world.vault.held == set()


def test_the_register_is_kept_for_24_months(world: _World) -> None:
    for name, days in (("old", 731), ("recent", 700)):
        world.reviews.log_decision(
            ListingDecision(
                listing_id=name,
                outcome="removed",
                reason="food",
                admin_id="admin",
                decided_at=NOW - timedelta(days=days),
            )
        )

    assert world.job.run(NOW).decisions_deleted == 1
    assert [item.listing_id for item in world.reviews.decisions] == ["recent"]


def test_before_the_sql_the_job_says_so_and_touches_nothing(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    def missing(_before: datetime) -> int:
        raise ListingReviewsUnavailable

    monkeypatch.setattr(world.reviews, "prune_decisions", missing)
    world.ad("old")

    assert world.job.run(NOW).table_available is False
    assert world.listings.get("old") is not None


def test_a_storage_failure_does_not_undo_the_decision(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    listing = world.ad("ad", "active")
    world.decided(listing, 0, status="open")
    review = world.reviews.list_by_listings(["ad"])[0]

    def broken(_paths: list[str]) -> None:
        raise RuntimeError("storage down")

    service = ListingReviewService(
        world.listings, world.reviews, world.vault, InMemoryListingReportRepository()
    )
    with monkeypatch.context() as patch:
        patch.setattr(world.vault, "withhold", broken)
        service.decide(review.id, "removed", admin_id="admin", reason="food")
    stored = world.listings.get("ad")
    assert stored is not None and stored.status == "removed_policy"

    world.job.run(datetime.now(UTC) + timedelta(hours=1))  # the hourly job tries again
    assert world.vault.held == {"published/ad/1.jpg"}


# --- the Supabase adapter -------------------------------------------------------------


_Paths = list[str]


class _Bucket:
    def __init__(self, files: dict[str, bytes], calls: list[str], name: str) -> None:
        self._files, self._calls, self._name = files, calls, name

    def list(self, prefix: str, options: dict[str, Any]) -> list[dict[str, Any]]:
        start = f"{prefix}/" if prefix else ""
        names: dict[str, bool] = {}
        for path in self._files:
            if path.startswith(start):
                head, _, rest = path[len(start) :].partition("/")
                names[head] = bool(rest)
        wanted = options.get("search")
        found = [
            {"name": name, "id": None if folder else name}
            for name, folder in sorted(names.items())
            if wanted is None or wanted in name
        ]
        return found[options["offset"] : options["offset"] + options["limit"]]

    def download(self, path: str) -> bytes:
        return self._files[path]

    def upload(self, path: str, content: bytes, options: dict[str, str]) -> None:
        self._calls.append(f"upload {self._name}")
        assert options["upsert"] == "true"
        self._files[path] = content

    def remove(self, paths: _Paths) -> None:
        self._calls.append(f"remove {self._name}")
        for path in paths:
            self._files.pop(path, None)

    def create_signed_url(self, path: str, seconds: int) -> dict[str, str]:
        if path not in self._files:
            raise RuntimeError("not found")
        return {"signedURL": f"https://signed.example.com/{path}?{seconds}"}


class _Storage:
    def __init__(self) -> None:
        self.files: dict[str, dict[str, bytes]] = {PUBLIC_BUCKET: {}, HELD_BUCKET: {}}
        self.calls: list[str] = []

    def from_(self, bucket: str) -> _Bucket:
        return _Bucket(self.files[bucket], self.calls, bucket)


class _Client:
    def __init__(self) -> None:
        self.storage = _Storage()


def test_the_supabase_vault_copies_before_it_removes_and_back() -> None:
    client = _Client()
    vault = SupabaseListingPhotoVault(client, LOCAL_PHOTO_BASE)  # type: ignore[arg-type]
    storage = client.storage
    storage.files[PUBLIC_BUCKET]["published/ad/1.jpg"] = b"jpeg"

    vault.withhold(["published/ad/1.jpg", "a/ad/missing.jpg"])

    assert storage.calls == [f"upload {HELD_BUCKET}", f"remove {PUBLIC_BUCKET}"]
    assert storage.files == {PUBLIC_BUCKET: {}, HELD_BUCKET: {"published/ad/1.jpg": b"jpeg"}}
    assert [item.path for item in vault.held_files()] == ["published/ad/1.jpg"]
    assert vault.signed_urls(["published/ad/1.jpg", "a/ad/missing.jpg"]) == [
        "https://signed.example.com/published/ad/1.jpg?600"
    ]

    vault.release(["published/ad/1.jpg"])
    assert storage.files == {PUBLIC_BUCKET: {"published/ad/1.jpg": b"jpeg"}, HELD_BUCKET: {}}

    assert vault.purge([]) == 0
    assert vault.purge(["published/ad/1.jpg"]) == 1
    assert storage.files == {PUBLIC_BUCKET: {}, HELD_BUCKET: {}}


def test_the_supabase_vault_lists_more_than_one_page() -> None:
    client = _Client()
    client.storage.files[HELD_BUCKET] = {f"a/ad/{n:03}.jpg": b"" for n in range(250)}

    vault = SupabaseListingPhotoVault(client, LOCAL_PHOTO_BASE)  # type: ignore[arg-type]

    assert len(vault.held_files()) == 250

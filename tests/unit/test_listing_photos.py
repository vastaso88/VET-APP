"""From the seller's folder to the copies other people see (K23): all the photos or none,
no copy left over. Synthetic data only."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.listing_photo_vault import PhotoUnusableError
from packages.core.application.services.create_listing import (
    CreateListingInput,
    CreateListingService,
)
from packages.core.application.services.listing_photos import (
    DeleteListingService,
    PublishExistingPhotosService,
)
from packages.core.application.services.removed_listings import PruneRemovedListingsService
from packages.core.application.services.update_listing import (
    UpdateListingInput,
    UpdateListingService,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.content_review import ListingReview
from packages.core.domain.marketplace.models import ListingStatus, MarketplaceListing
from packages.core.domain.marketplace.photos import (
    LOCAL_PHOTO_BASE,
    PHOTO_MAX_BYTES,
    photo_link,
)
from packages.infrastructure.persistence.in_memory_listing_reviews import (
    InMemoryListingReviewRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import (
    HELD_BUCKET,
    PUBLIC_BUCKET,
    InMemoryListingPhotoVault,
    SupabaseListingPhotoVault,
    clean_photo,
)

PLACE = Coordinates(latitude=45.46, longitude=9.19)
ONE, TWO = "seller/up/1.jpg", "seller/up/2.jpg"
# A whole JPEG: a comment, the frame (16 x 16), a scan with data, the end of the image.
_HEAD = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
_COMMENT = b"\xff\xfe\x00\x06GPS!"
_FRAME = b"\xff\xc0\x00\x0b\x08\x00\x10\x00\x10\x01\x01\x11\x00"
_SCAN = b"\xff\xda\x00\x08\x01\x01\x00\x00\x3f\x00" + b"\x11\x22\x33\x44"
_END = b"\xff\xd9"
JPEG = _HEAD + _COMMENT + _FRAME + _SCAN + _END


class _World:
    def __init__(self) -> None:
        self.listings = InMemoryMarketplaceListingRepository()
        self.reviews = InMemoryListingReviewRepository()
        self.vault = InMemoryListingPhotoVault()
        self.vault.public = {ONE, TWO}
        self.job = PruneRemovedListingsService(self.listings, self.reviews, self.vault)
        self.existing = PublishExistingPhotosService(self.listings, self.reviews, self.vault)

    def create(self, title: str = "Cuccia", photos: list[str] | None = None) -> MarketplaceListing:
        return (
            CreateListingService(self.listings, self.reviews, self.vault)
            .execute(
                CreateListingInput(
                    owner_id="seller",
                    title=title,
                    category="toys",
                    condition="good",
                    exact_location=PLACE,
                    photo_urls=photos or [],
                    content_confirmations=["food"],
                )
            )
            .listing
        )

    def edit(self, listing: MarketplaceListing, photos: list[str]) -> MarketplaceListing:
        return (
            UpdateListingService(self.listings, self.reviews, self.vault)
            .execute(
                UpdateListingInput(
                    owner_id="seller",
                    listing_id=listing.id,
                    title=listing.title,
                    category="toys",
                    condition="good",
                    exact_location=PLACE,
                    photo_urls=photos,
                    content_confirmations=["food"],
                )
            )
            .listing
        )

    def old(
        self, *links: str, name: str = "old", status: ListingStatus = "active"
    ) -> MarketplaceListing:
        return self.listings.save(
            MarketplaceListing(
                id=name,
                owner_id="seller",
                title="Cuccia",
                category="toys",
                condition="good",
                location=PLACE,
                status=status,
                photo_urls=list(links),
            )
        )


@pytest.fixture
def world() -> _World:
    return _World()


def _fails(*_args: object, **_kwargs: object) -> Any:
    raise RuntimeError("down")


# --- all or none ------------------------------------------------------------------------


@pytest.mark.parametrize("title", ["Cuccia", "Ciotola per crocchette"])
def test_an_ad_that_cannot_be_saved_leaves_no_copy_and_keeps_the_originals(
    world: _World, monkeypatch: pytest.MonkeyPatch, title: str
) -> None:
    monkeypatch.setattr(world.listings, "save", _fails)

    with pytest.raises(RuntimeError):
        world.create(title, [ONE, TWO])

    assert world.vault.public == {ONE, TWO}


def test_a_confirmation_that_cannot_be_saved_leaves_nothing(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(world.reviews, "save", _fails)

    with pytest.raises(RuntimeError):
        world.create("Ciotola per crocchette", [ONE])

    assert world.vault.public == {ONE, TWO}
    assert world.listings.list_by_owner("seller", 10) == []


def test_an_edit_that_cannot_be_saved_leaves_the_ad_its_photos_and_its_check(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    listing = world.create("Ciotola per crocchette", [ONE])
    before = set(world.vault.public)

    with monkeypatch.context() as patch, pytest.raises(RuntimeError):
        patch.setattr(world.listings, "save", _fails)
        world.edit(listing, [*listing.photo_urls, TWO])

    assert world.vault.public == before
    assert world.listings.get(listing.id) == listing
    open_reviews = [item for item in world.reviews.items.values() if item.status == "open"]
    assert len(open_reviews) == 1
    assert open_reviews[0].covers(
        listing.title, listing.description, listing.category, listing.photo_urls
    )


def test_a_lost_answer_does_not_take_the_photos_of_an_ad_that_was_saved(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    saved = world.listings.save

    def saved_but_the_answer_is_lost(listing: MarketplaceListing) -> MarketplaceListing:
        saved(listing)
        raise TimeoutError

    with monkeypatch.context() as patch, pytest.raises(TimeoutError):
        patch.setattr(world.listings, "save", saved_but_the_answer_is_lost)
        world.create(photos=[ONE])

    (listing,) = world.listings.list_by_owner("seller", 10)
    assert set(world.vault.paths(listing)) <= world.vault.public


def test_a_photo_two_old_ads_share_stays_until_the_last_one(world: _World) -> None:
    link = photo_link(ONE, LOCAL_PHOTO_BASE)
    first, second = world.old(link, name="first"), world.old(link, name="second")

    world.edit(first, [link])
    assert ONE in world.vault.public, "the other ad still shows it"
    world.edit(second, [])
    assert ONE not in world.vault.public


def test_deleting_an_old_ad_keeps_the_photo_another_one_shows(world: _World) -> None:
    link = photo_link(ONE, LOCAL_PHOTO_BASE)
    world.old(link, name="first")
    world.old(link, name="second")
    service = DeleteListingService(world.listings, world.vault)

    assert service.execute("first", "user-b") is False
    assert service.execute("first", "seller") and ONE in world.vault.public
    assert service.execute("second", "seller") and ONE not in world.vault.public


def test_a_failed_clean_up_does_not_fail_the_ad_and_the_hourly_job_ends_it(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    with monkeypatch.context() as patch:
        patch.setattr(world.vault, "discard", _fails)
        listing = world.create(photos=[ONE])
    assert ONE in world.vault.public

    world.job.run(datetime.now(UTC) + timedelta(days=2))

    (copy,) = world.vault.public
    assert listing.photo_urls == [photo_link(copy, LOCAL_PHOTO_BASE)]


# --- the hourly job ---------------------------------------------------------------------


def test_copies_without_their_ad_go_but_not_one_being_published(world: _World) -> None:
    now = datetime.now(UTC)
    world.vault.public = {"published/gone/1.jpg", "published/saving/1.jpg"}
    world.vault.created = {"published/saving/1.jpg": now - timedelta(minutes=5)}

    world.job.run(now)

    assert world.vault.public == {"published/saving/1.jpg"}


def test_uploads_nobody_published_go_after_a_day(world: _World) -> None:
    now = datetime.now(UTC)
    world.vault.created = {ONE: now - timedelta(hours=23), TWO: now - timedelta(hours=25)}

    world.job.run(now)

    assert world.vault.public == {ONE}


def test_the_uploads_of_an_ad_older_than_the_copies_stay(world: _World) -> None:
    world.old(photo_link(ONE, LOCAL_PHOTO_BASE))

    world.job.run()

    assert world.vault.public == {ONE}, "the other one is nobody's"


def test_the_photos_of_an_ad_deleted_by_an_installed_app_go(world: _World) -> None:
    listing = world.create(photos=[ONE])
    world.vault.withhold(list(world.vault.public))
    world.listings.delete(listing.id)

    world.job.run(datetime.now(UTC) + timedelta(hours=2))

    assert not any(path.startswith("published/") for path in world.vault.held)


def _many(world: _World, count: int, name: str = "ad") -> None:
    for index in range(count):
        path = f"published/{name}-{index}/1.jpg"
        world.vault.public.add(path)
        world.old(photo_link(path, LOCAL_PHOTO_BASE), name=f"{name}-{index}")


def test_another_address_of_the_storage_deletes_nothing(world: _World) -> None:
    world.vault.public = set()
    _many(world, 4)
    moved = InMemoryListingPhotoVault("https://photos.example.com")
    moved.public = {*world.vault.public, "published/gone/1.jpg"}
    files = set(moved.public)

    job = PruneRemovedListingsService(world.listings, world.reviews, moved)
    for allowed in (0, 100):
        output = job.run(allow_leftovers=allowed)
        assert output.leftovers_blocked and output.photos_deleted == 0
    assert moved.public == files


@pytest.mark.parametrize(("live", "left"), [(1000, 51), (60, 10), (0, 51)])
def test_too_many_leftovers_delete_nothing_until_someone_has_looked(
    world: _World, live: int, left: int
) -> None:
    world.vault.public = set()
    _many(world, live)
    leftovers = {f"published/gone-{index}/1.jpg" for index in range(left)}
    world.vault.public |= leftovers

    output = world.job.run()

    assert (output.leftovers, output.leftovers_blocked) == (left, True)
    assert output.photos_deleted == 0 and leftovers <= world.vault.public

    assert world.job.run(allow_leftovers=left - 1).leftovers_blocked
    allowed = world.job.run(allow_leftovers=left)
    assert (allowed.photos_deleted, allowed.leftovers_blocked) == (left, False)
    assert len(world.vault.public) == live


def test_every_file_at_once_is_never_believed_while_there_are_ads_with_photos(
    world: _World,
) -> None:
    world.vault.public = {"published/gone/1.jpg"}
    world.old("https://elsewhere.example.com/1.jpg")

    assert world.job.run().leftovers_blocked
    assert world.vault.public == {"published/gone/1.jpg"}


def test_the_photos_of_an_ad_six_months_after_go_even_with_another_address(
    world: _World,
) -> None:
    world.vault.public = {"published/old/1.jpg"}
    listing = world.old("https://was.example.com/x/1.jpg", status="removed_policy")
    world.reviews.save(
        ListingReview(
            listing_id=listing.id,
            owner_id="seller",
            status="removed",
            title="t",
            category="toys",
            decided_at=datetime.now(UTC) - timedelta(days=200),
        )
    )

    assert world.job.run().listings_deleted == 1
    assert world.vault.public == set()


# --- ads older than the copies ----------------------------------------------------------


def test_the_count_changes_nothing(world: _World) -> None:
    world.old(photo_link(ONE, LOCAL_PHOTO_BASE), "https://example.com/1.jpg")

    output = world.existing.run()

    assert (output.listings, output.to_publish, output.photos, output.other_links) == (1, 1, 1, 1)
    assert output.published == 0 and world.vault.public == {ONE, TWO}


def test_old_ads_are_copied_once_with_their_checks(world: _World) -> None:
    link = photo_link(ONE, LOCAL_PHOTO_BASE)
    listing = world.old(link, "https://example.com/1.jpg")
    review = world.reviews.save(
        ListingReview(
            listing_id=listing.id,
            owner_id="seller",
            title=listing.title,
            category=listing.category,
            photo_urls=[link, "https://example.com/1.jpg"],
        )
    )

    assert world.existing.run(apply=True).published == 1

    after = world.listings.get("old")
    assert after is not None and len(after.photo_urls) == 1
    assert after.photo_urls[0].startswith(f"{LOCAL_PHOTO_BASE}/storage/v1/object/public/")
    assert "/published/old/" in after.photo_urls[0]
    stored = world.reviews.get(review.id)
    assert stored is not None
    assert stored.covers(after.title, after.description, after.category, after.photo_urls)
    assert ONE not in world.vault.public
    again = world.existing.run(apply=True)
    assert (again.to_publish, again.published, again.failed) == (0, 0, 0)


@pytest.mark.parametrize(
    "stops_at", ["set_photos", "the answer of set_photos", "reviews", "discard"]
)
def test_a_run_that_stops_is_completed_by_the_next(
    world: _World, monkeypatch: pytest.MonkeyPatch, stops_at: str
) -> None:
    link = photo_link(ONE, LOCAL_PHOTO_BASE)
    listing = world.old(link)
    review = world.reviews.save(
        ListingReview(
            listing_id=listing.id,
            owner_id="seller",
            title=listing.title,
            category=listing.category,
            photo_urls=[link],
        )
    )
    write = world.listings.set_photos

    def written_but_the_answer_is_lost(listing_id: str, links: list[str]) -> None:
        write(listing_id, links)
        raise TimeoutError

    with monkeypatch.context() as patch, pytest.raises((RuntimeError, TimeoutError)):
        if stops_at == "set_photos":
            patch.setattr(world.listings, "set_photos", _fails)
        elif stops_at == "the answer of set_photos":
            patch.setattr(world.listings, "set_photos", written_but_the_answer_is_lost)
        elif stops_at == "reviews":
            patch.setattr(world.reviews, "save", _fails)
        else:
            patch.setattr(world.vault, "discard", _fails)
        world.existing.run(apply=True)

    world.existing.run(apply=True)
    world.job.run(datetime.now(UTC) + timedelta(days=2))

    after = world.listings.get("old")
    stored = world.reviews.get(review.id)
    assert after is not None and stored is not None
    assert stored.covers(after.title, after.description, after.category, after.photo_urls)
    assert world.vault.public == set(world.vault.paths(after)), "one copy, no original"


def test_two_old_ads_with_the_same_photo_both_get_their_copy(world: _World) -> None:
    link = photo_link(ONE, LOCAL_PHOTO_BASE)
    world.old(link, name="first")
    world.old(link, name="second")

    output = world.existing.run(apply=True)

    assert (output.published, output.failed) == (2, 0)
    for name in ("first", "second"):
        listing = world.listings.get(name)
        assert listing is not None
        assert set(world.vault.paths(listing)) <= world.vault.public
    assert ONE not in world.vault.public


def test_an_old_ad_with_a_missing_photo_is_left_as_it_was(world: _World) -> None:
    links = [photo_link(ONE, LOCAL_PHOTO_BASE), photo_link("seller/up/lost.jpg", LOCAL_PHOTO_BASE)]
    world.old(*links)
    world.old(photo_link(TWO, LOCAL_PHOTO_BASE), name="other")

    output = world.existing.run(apply=True, page=1)

    assert (output.listings, output.published, output.failed) == (2, 1, 1)
    left = world.listings.get("old")
    assert left is not None and left.photo_urls == links
    assert ONE in world.vault.public


def test_the_photos_of_an_old_hidden_ad_stay_private(world: _World) -> None:
    world.old(photo_link(ONE, LOCAL_PHOTO_BASE), status="removed_policy")
    world.vault.withhold([ONE])

    world.existing.run(apply=True)

    assert world.vault.public == {TWO}
    (held,) = world.vault.held
    assert held.startswith("published/old/")


# --- the files --------------------------------------------------------------------------


def test_only_a_jpeg_of_the_right_size_goes_on_and_without_its_metadata() -> None:
    assert b"GPS!" not in clean_photo(JPEG)
    for content in (b"", b"<svg onload=1>", b"GIF89a", b"\x89PNG\r\n\x1a\n"):
        with pytest.raises(PhotoUnusableError):
            clean_photo(content)
    with pytest.raises(PhotoUnusableError):
        clean_photo(JPEG + b"0" * PHOTO_MAX_BYTES)
    assert clean_photo(JPEG).endswith(_FRAME + _SCAN + _END)


@pytest.mark.parametrize(
    "content",
    [
        b"\xff\xd8\xff",
        b"\xff\xd8\xff" + b"<html>" * 20,
        _HEAD + _END,
        _HEAD + _FRAME + _END,
        _HEAD + _SCAN + _END,
        _HEAD + _FRAME + _SCAN,
        JPEG[:-4],
        JPEG[:40],
        _HEAD + _FRAME + _SCAN[:10] + _END,
        _HEAD + _FRAME.replace(b"\x00\x10\x00\x10", b"\x00\x00\x00\x10") + _SCAN + _END,
        _HEAD + b"\xff\xc0\xff\xff" + _SCAN + _END,
    ],
    ids=[
        "three bytes",
        "three bytes and something else",
        "no picture",
        "no scan",
        "no frame",
        "no end",
        "cut at the end",
        "cut in the middle",
        "an empty scan",
        "no height",
        "a wrong length",
    ],
)
def test_a_jpeg_that_is_not_whole_is_refused(content: bytes) -> None:
    with pytest.raises(PhotoUnusableError):
        clean_photo(content)


class _Bucket:
    def __init__(self, files: dict[str, bytes], fail_upload_of: int | None) -> None:
        self._files, self._fail = files, fail_upload_of

    def list(self, folder: str, options: dict[str, Any]) -> Any:
        names = [path.rpartition("/")[2] for path in self._files if path.startswith(f"{folder}/")]
        return [{"name": name, "id": name} for name in names if options["search"] in name]

    def download(self, path: str) -> bytes:
        return self._files[path]

    def upload(self, path: str, content: bytes, options: dict[str, str]) -> None:
        assert options["content-type"] == "image/jpeg"
        assert int(options["cache-control"]) <= 300
        if path in self._files:
            assert options["upsert"] == "true"
        copies = [name for name in self._files if name.startswith("published/")]
        if self._fail is not None and len(copies) >= self._fail:
            raise RuntimeError("storage down")
        self._files[path] = content

    def remove(self, paths: Any) -> None:
        for path in paths:
            self._files.pop(path, None)


class _Client:
    def __init__(self, files: dict[str, bytes], fail_upload_of: int | None = None) -> None:
        self.files: dict[str, dict[str, bytes]] = {PUBLIC_BUCKET: files, HELD_BUCKET: {}}
        self._fail = fail_upload_of
        self.storage = self

    def from_(self, bucket: str) -> _Bucket:
        return _Bucket(self.files[bucket], self._fail)


def test_the_supabase_copies_keep_the_order_and_the_originals() -> None:
    uploads = {f"seller/up/{index}.jpg": JPEG + bytes([index]) for index in range(6)}
    client = _Client(dict(uploads))
    vault = SupabaseListingPhotoVault(client, LOCAL_PHOTO_BASE)  # type: ignore[arg-type]

    copies = vault.publish("ad", list(uploads))

    assert len(set(copies)) == 6
    assert all(path.startswith("published/ad/") for path in copies)
    assert set(client.files[PUBLIC_BUCKET]) == {*uploads, *copies}


@pytest.mark.parametrize("failure", ["storage", "missing", "not a jpeg"])
def test_a_supabase_copy_that_fails_leaves_none(failure: str) -> None:
    uploads = {f"seller/up/{index}.jpg": JPEG for index in range(6)}
    wanted = list(uploads)
    if failure == "missing":
        wanted.append("seller/up/lost.jpg")
    if failure == "not a jpeg":
        uploads["seller/up/5.jpg"] = b"<svg>"
    client = _Client(dict(uploads), fail_upload_of=3 if failure == "storage" else None)
    vault = SupabaseListingPhotoVault(client, LOCAL_PHOTO_BASE)  # type: ignore[arg-type]

    with pytest.raises(RuntimeError if failure == "storage" else PhotoUnusableError):
        vault.publish("ad", wanted)

    assert client.files[PUBLIC_BUCKET] == uploads

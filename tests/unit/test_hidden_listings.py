"""Ads hidden or taken down after reports (Mercatino rules v2, point 6): the seller reads
the reason and the date, the photos are not public, the team's decision is never lost.
Synthetic data only."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from packages.core.application.services.listing_review import (
    HiddenNotice,
    ListingReviewNotFoundError,
    ListingReviewService,
)
from packages.core.application.services.removed_listings import PruneRemovedListingsService
from packages.core.application.services.report_listing import (
    ReportListingInput,
    ReportListingService,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import (
    ListingReport,
    ListingReportReason,
    ListingStatus,
    MarketplaceListing,
)
from packages.infrastructure.persistence.in_memory_listing_reviews import (
    InMemoryListingReviewRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryListingReportRepository,
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import (
    PUBLIC_BUCKET,
    InMemoryListingPhotoVault,
)

ADMIN = "admin-1"
DAY = datetime(2026, 11, 20, 9, 30, tzinfo=UTC)


class _World:
    def __init__(self) -> None:
        self.listings = InMemoryMarketplaceListingRepository()
        self.reviews = InMemoryListingReviewRepository()
        self.reports = InMemoryListingReportRepository()
        self.vault = InMemoryListingPhotoVault()
        self.service = ListingReviewService(self.listings, self.reviews, self.vault, self.reports)
        self.reporting = ReportListingService(self.listings, self.reports, self.vault)
        self.job = PruneRemovedListingsService(self.listings, self.reviews, self.vault)

    def ad(self, name: str = "ad", status: ListingStatus = "active") -> MarketplaceListing:
        path = f"published/{name}/1.jpg"
        self.vault.public.add(path)
        return self.listings.save(
            MarketplaceListing(
                id=name,
                owner_id="seller",
                title="Cuccia",
                category="toys",
                condition="good",
                location=Coordinates(latitude=45.46, longitude=9.19),
                photo_urls=[
                    f"https://storage.invalid/storage/v1/object/public/{PUBLIC_BUCKET}/{path}"
                ],
                status=status,
                updated_at=DAY,
            )
        )

    def report(self, name: str, *reasons: ListingReportReason) -> None:
        for index, reason in enumerate(reasons):
            self.reporting.execute(
                ReportListingInput(
                    listing_id=name, reporter_owner_id=f"reporter-{index}", reason=reason
                )
            )

    def status(self, name: str = "ad") -> str:
        listing = self.listings.get(name)
        assert listing is not None
        return listing.status

    def notice(self, owner: str = "seller") -> HiddenNotice | None:
        (own,) = self.service.own_listings(owner)
        return own.hidden


@pytest.fixture
def world() -> _World:
    return _World()


def test_three_reports_hide_the_ad_without_saying_what_people_wrote(world: _World) -> None:
    world.ad()
    world.report("ad", "scam", "spam", "scam")

    assert world.status() == "removed"
    notice = world.notice()
    assert notice is not None
    assert (notice.kind, notice.reason, notice.terms) == ("reports", None, [])
    assert world.vault.public == set() and world.vault.held == {"published/ad/1.jpg"}


def test_the_date_is_that_of_the_report_that_hid_it(world: _World) -> None:
    world.ad(status="removed")
    for index in range(4):
        world.reports.save(
            ListingReport(
                listing_id="ad",
                reporter_owner_id=f"r{index}",
                reason="spam",
                created_at=DAY + timedelta(days=index),
            )
        )

    notice = world.notice()

    assert notice is not None and notice.since == DAY + timedelta(days=2)


def test_when_the_reporters_have_gone_there_is_still_a_date(world: _World) -> None:
    world.ad(status="removed")

    assert world.notice() == HiddenNotice(kind="reports", since=DAY)


def test_an_ad_hidden_by_the_rule_on_animals_says_so(world: _World) -> None:
    world.ad(status="removed_policy")

    assert world.notice() == HiddenNotice(kind="rule", reason="sells_animals", since=DAY)


@pytest.mark.parametrize("status", ["active", "reserved", "sold"])
def test_a_visible_ad_has_no_notice(world: _World, status: ListingStatus) -> None:
    world.ad(status=status)

    assert world.notice() is None


def test_the_team_takes_down_a_reported_ad_like_any_other(world: _World) -> None:
    world.ad()
    world.report("ad", "scam")

    world.service.remove_reported("ad", "scam", admin_id=ADMIN, note="  verificato ")

    assert world.status() == "removed_policy"
    notice = world.notice()
    assert notice is not None and (notice.kind, notice.reason) == ("team", "scam")
    (review,) = world.reviews.list_by_listings(["ad"])
    assert (review.origin, review.note, review.decided_by_admin_id) == (
        "report",
        "verificato",
        ADMIN,
    )
    (entry,) = world.reviews.decisions
    assert (entry.outcome, entry.reason) == ("removed", "scam")
    assert "seller" not in entry.model_dump_json()
    assert world.vault.public == set()


def test_taking_it_down_twice_changes_nothing(world: _World) -> None:
    world.ad()
    world.service.remove_reported("ad", "scam", admin_id=ADMIN)
    world.service.remove_reported("ad", "spam", admin_id="admin-2")

    notice = world.notice()
    assert notice is not None and notice.reason == "scam"
    assert len(world.reviews.decisions) == 1


def test_a_missing_ad_is_not_found(world: _World) -> None:
    with pytest.raises(ListingReviewNotFoundError):
        world.service.remove_reported("nope", "scam", admin_id=ADMIN)
    with pytest.raises(ListingReviewNotFoundError):
        world.service.restore_reported("nope", admin_id=ADMIN)


@pytest.mark.parametrize("by_the_team", [True, False])
def test_the_team_can_put_it_back(world: _World, by_the_team: bool) -> None:
    world.ad()
    if by_the_team:
        world.service.remove_reported("ad", "scam", admin_id=ADMIN)
    else:
        world.report("ad", "spam", "spam", "spam")

    world.service.restore_reported("ad", admin_id=ADMIN)

    assert world.status() == "active" and world.notice() is None
    assert world.vault.public == {"published/ad/1.jpg"} and world.vault.held == set()
    assert world.reviews.decisions[-1].outcome == "restored"


def test_putting_back_a_visible_or_sold_ad_changes_nothing(world: _World) -> None:
    world.ad(status="sold")

    world.service.restore_reported("ad", admin_id=ADMIN)

    assert world.status() == "sold" and world.reviews.decisions == []


def test_reports_after_the_decision_of_the_team_do_not_undo_it(world: _World) -> None:
    world.ad()
    world.report("ad", "scam", "scam")
    world.service.remove_reported("ad", "scam", admin_id=ADMIN)
    world.reporting.execute(
        ReportListingInput(listing_id="ad", reporter_owner_id="seller", reason="other")
    )
    world.job.run(datetime.now(UTC) + timedelta(hours=1))

    assert world.status() == "removed_policy"
    notice = world.notice()
    assert notice is not None and notice.kind == "team"
    assert world.vault.public == set()


def test_dismissed_reports_do_not_count(world: _World) -> None:
    world.ad()
    for index in range(2):
        world.reports.save(
            ListingReport(
                listing_id="ad",
                reporter_owner_id=f"old-{index}",
                reason="spam",
                status="dismissed",
            )
        )

    world.report("ad", "spam")

    listing = world.listings.get("ad")
    assert listing is not None and (listing.status, listing.report_count) == ("active", 1)


def test_a_report_never_writes_over_what_changed_meanwhile(world: _World) -> None:
    """The whole row was written back as it was read at the start."""
    world.ad()
    saved = world.reports.save

    def seller_edits_meanwhile(report: ListingReport) -> ListingReport:
        current = world.listings.get("ad")
        assert current is not None
        world.listings.save(current.model_copy(update={"title": "Cuccia nuova"}))
        return saved(report)

    world.reports.save = seller_edits_meanwhile  # type: ignore[method-assign]
    world.report("ad", "spam")

    listing = world.listings.get("ad")
    assert listing is not None and listing.title == "Cuccia nuova" and listing.report_count == 1


def test_only_the_teams_decisions_are_deleted_after_six_months(world: _World) -> None:
    world.ad("reported", status="removed")
    world.ad("taken-down")
    world.service.remove_reported("taken-down", "scam", admin_id=ADMIN)

    report = world.job.run(datetime.now(UTC) + timedelta(days=200))

    assert report.listings_deleted == 1
    assert world.listings.get("taken-down") is None
    assert world.status("reported") == "removed", "still waits for the team"
    assert world.vault.public == set()


def test_an_ad_being_published_is_left_alone(world: _World) -> None:
    listing = world.ad(status="removed")
    world.listings.save(listing.model_copy(update={"updated_at": datetime.now(UTC)}))

    world.job.run()

    assert world.vault.public == {"published/ad/1.jpg"}


def test_user_b_sees_nothing_of_it(world: _World) -> None:
    world.ad()
    world.report("ad", "spam", "spam", "spam")

    assert world.service.own_listings("user-b") == []

import pytest

from packages.core.application.services.create_listing import (
    CreateListingInput,
    CreateListingService,
)
from packages.core.application.services.report_listing import (
    ReportListingInput,
    ReportListingService,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import REPORT_COUNT_AUTO_REMOVE_THRESHOLD
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryListingReportRepository,
    InMemoryMarketplaceListingRepository,
)
from packages.shared.errors.base import ValidationError


def _create_listing(repository: InMemoryMarketplaceListingRepository) -> str:
    result = CreateListingService(repository).execute(
        CreateListingInput(
            owner_id="seller-1",
            title="Guinzaglio",
            category="accessories",
            condition="good",
            exact_location=Coordinates(latitude=45.4642, longitude=9.1900),
        )
    )
    return result.listing.id


def test_reporting_an_unknown_listing_is_rejected() -> None:
    service = ReportListingService(
        InMemoryMarketplaceListingRepository(), InMemoryListingReportRepository()
    )

    with pytest.raises(ValidationError):
        service.execute(
            ReportListingInput(listing_id="missing", reporter_owner_id="user-1", reason="spam")
        )


def test_a_single_report_does_not_remove_the_listing() -> None:
    listing_repository = InMemoryMarketplaceListingRepository()
    listing_id = _create_listing(listing_repository)
    service = ReportListingService(listing_repository, InMemoryListingReportRepository())

    result = service.execute(
        ReportListingInput(listing_id=listing_id, reporter_owner_id="user-1", reason="spam")
    )

    assert result.listing.status == "active"
    assert result.listing.report_count == 1


def test_reaching_the_threshold_of_distinct_reporters_removes_the_listing() -> None:
    listing_repository = InMemoryMarketplaceListingRepository()
    listing_id = _create_listing(listing_repository)
    service = ReportListingService(listing_repository, InMemoryListingReportRepository())

    result = None
    for i in range(REPORT_COUNT_AUTO_REMOVE_THRESHOLD):
        result = service.execute(
            ReportListingInput(
                listing_id=listing_id, reporter_owner_id=f"user-{i}", reason="scam"
            )
        )

    assert result is not None
    assert result.listing.status == "removed"
    assert result.listing.report_count == REPORT_COUNT_AUTO_REMOVE_THRESHOLD


def test_repeated_reports_from_the_same_user_do_not_count_multiple_times() -> None:
    listing_repository = InMemoryMarketplaceListingRepository()
    listing_id = _create_listing(listing_repository)
    service = ReportListingService(listing_repository, InMemoryListingReportRepository())

    for _ in range(REPORT_COUNT_AUTO_REMOVE_THRESHOLD):
        result = service.execute(
            ReportListingInput(listing_id=listing_id, reporter_owner_id="user-1", reason="spam")
        )

    assert result.listing.status == "active"
    assert result.listing.report_count == 1

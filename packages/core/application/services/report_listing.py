from pydantic import BaseModel

from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.marketplace.models import (
    REPORT_COUNT_AUTO_REMOVE_THRESHOLD,
    ListingReport,
    ListingReportReason,
    MarketplaceListing,
)
from packages.shared.errors.base import ValidationError


class ReportListingInput(BaseModel):
    listing_id: str
    reporter_owner_id: str
    reason: ListingReportReason


class ReportListingOutput(BaseModel):
    listing: MarketplaceListing
    report: ListingReport


class ReportListingService:
    """No moderation queue for MVP: enough distinct reports auto-removes
    the listing (docs/maps/) - a real editorial review is a later
    concern, not a blocker for shipping the reporting lever itself."""

    def __init__(
        self,
        listing_repository: MarketplaceListingRepository,
        report_repository: ListingReportRepository,
    ) -> None:
        self._listing_repository = listing_repository
        self._report_repository = report_repository

    def execute(self, data: ReportListingInput) -> ReportListingOutput:
        listing = self._listing_repository.get(data.listing_id)
        if listing is None:
            raise ValidationError("listing not found")

        report = self._report_repository.save(
            ListingReport(
                listing_id=data.listing_id,
                reporter_owner_id=data.reporter_owner_id,
                reason=data.reason,
            )
        )
        # Distinct reporters, not raw report rows - otherwise one user could
        # force a removal by reporting the same listing repeatedly.
        reports = self._report_repository.list_by_listing(data.listing_id)
        report_count = len({r.reporter_owner_id for r in reports})

        updates: dict[str, object] = {"report_count": report_count}
        # A sale already concluded (or a prior removal) is a final state -
        # a flood of reports afterward shouldn't relabel it as "removed".
        if report_count >= REPORT_COUNT_AUTO_REMOVE_THRESHOLD and listing.status not in (
            "sold",
            "removed",
        ):
            updates["status"] = "removed"
        listing = self._listing_repository.save(listing.model_copy(update=updates))

        return ReportListingOutput(listing=listing, report=report)

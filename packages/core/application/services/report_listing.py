from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import ListingPhotoVault
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.services.removed_listings import move_photos
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
    """Enough distinct open reports hide the ad on their own, until the team decides
    (admin portal). The seller is told when and why (services/listing_review.py)."""

    def __init__(
        self,
        listing_repository: MarketplaceListingRepository,
        report_repository: ListingReportRepository,
        vault: ListingPhotoVault | None = None,
    ) -> None:
        self._listing_repository = listing_repository
        self._report_repository = report_repository
        self._vault = vault

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
        # Distinct reporters, not raw report rows - otherwise one user could force a removal
        # by reporting the same listing repeatedly. Reports the team dismissed do not count.
        reports = self._report_repository.list_by_listing(data.listing_id)
        report_count = len({r.reporter_owner_id for r in reports if r.status == "open"})
        # Only a visible ad is hidden: a sale already concluded, and a removal by the team
        # (with its reason and its date), are final states.
        self._listing_repository.record_reports(
            data.listing_id,
            report_count,
            hide=report_count >= REPORT_COUNT_AUTO_REMOVE_THRESHOLD,
        )
        updated = self._listing_repository.get(data.listing_id) or listing
        if updated.status == "removed" and self._vault is not None:
            move_photos(updated, self._listing_repository, self._vault)
        return ReportListingOutput(listing=updated, report=report)

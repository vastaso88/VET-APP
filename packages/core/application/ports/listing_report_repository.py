from typing import Protocol

from packages.core.domain.marketplace.models import ListingReport


class ListingReportRepository(Protocol):
    def save(self, report: ListingReport) -> ListingReport: ...

    def list_by_listing(self, listing_id: str) -> list[ListingReport]: ...

from typing import Protocol

from packages.core.domain.geo.bounding_box import GeoBox
from packages.core.domain.marketplace.models import ListingCategory, MarketplaceListing


class MarketplaceListingRepository(Protocol):
    def save(self, listing: MarketplaceListing) -> MarketplaceListing: ...

    def get(self, listing_id: str) -> MarketplaceListing | None: ...

    def list_active(self, country: str | None = None) -> list[MarketplaceListing]: ...

    def list_active_in_box(
        self, box: GeoBox, category: ListingCategory | None = None
    ) -> list[MarketplaceListing]:
        """Every active ad whose position is inside [box] (and in [category], when
        given), however many there are: an adapter must page through the provider's row
        window, never return a silently cut list. The box is a superset of the search
        circle; the exact distance is the caller's job."""
        ...

    def statuses(self, listing_ids: list[str]) -> dict[str, str]:
        """Current status by id; a deleted ad is simply absent."""
        ...

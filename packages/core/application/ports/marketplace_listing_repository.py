from typing import Protocol

from packages.core.domain.marketplace.models import MarketplaceListing


class MarketplaceListingRepository(Protocol):
    def save(self, listing: MarketplaceListing) -> MarketplaceListing: ...

    def get(self, listing_id: str) -> MarketplaceListing | None: ...

    def list_active(self, country: str | None = None) -> list[MarketplaceListing]: ...

    def statuses(self, listing_ids: list[str]) -> dict[str, str]:
        """Current status by id; a deleted ad is simply absent."""
        ...

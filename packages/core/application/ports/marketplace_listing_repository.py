from typing import Protocol

from packages.core.domain.marketplace.models import MarketplaceListing


class MarketplaceListingRepository(Protocol):
    def save(self, listing: MarketplaceListing) -> MarketplaceListing: ...

    def get(self, listing_id: str) -> MarketplaceListing | None: ...

    def list_active(self) -> list[MarketplaceListing]: ...

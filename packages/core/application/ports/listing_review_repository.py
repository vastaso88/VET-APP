from datetime import datetime
from typing import Protocol

from packages.core.domain.marketplace.content_review import ListingDecision, ListingReview


class ListingReviewsUnavailable(Exception):
    """The tables are not there yet: the SQL is applied by hand."""


class ListingReviewRepository(Protocol):
    def save(self, review: ListingReview) -> ListingReview: ...

    def get(self, review_id: str) -> ListingReview | None: ...

    def list_by_listings(self, listing_ids: list[str]) -> list[ListingReview]:
        """Every confirmation of these ads, in no particular order."""
        ...

    def list_by_owner(self, owner_id: str) -> list[ListingReview]: ...

    def list_for_team(self, limit: int) -> list[ListingReview]:
        """To be checked first (oldest first), then the decided ones (newest first)."""
        ...

    def list_removed(self) -> list[ListingReview]:
        """Every decision to take an ad down."""
        ...

    def log_decision(self, decision: ListingDecision) -> None: ...

    def prune_decisions(self, before: datetime) -> int: ...

from datetime import datetime

from packages.core.domain.marketplace.content_review import ListingDecision, ListingReview


class InMemoryListingReviewRepository:
    def __init__(self) -> None:
        self.items: dict[str, ListingReview] = {}
        self.decisions: list[ListingDecision] = []

    def save(self, review: ListingReview) -> ListingReview:
        self.items[review.id] = review
        return review

    def get(self, review_id: str) -> ListingReview | None:
        return self.items.get(review_id)

    def list_by_listings(self, listing_ids: list[str]) -> list[ListingReview]:
        wanted = set(listing_ids)
        return [item for item in self.items.values() if item.listing_id in wanted]

    def list_by_owner(self, owner_id: str) -> list[ListingReview]:
        return [item for item in self.items.values() if item.owner_id == owner_id]

    def list_for_team(self, limit: int) -> list[ListingReview]:
        waiting = sorted(
            (item for item in self.items.values() if item.status == "open"),
            key=lambda item: item.confirmed_at,
        )
        decided = sorted(
            (item for item in self.items.values() if item.status in ("checked", "removed")),
            key=lambda item: item.confirmed_at,
            reverse=True,
        )
        return [*waiting[:limit], *decided[:limit]]

    def list_removed(self) -> list[ListingReview]:
        return [item for item in self.items.values() if item.status == "removed"]

    def prune_decisions(self, before: datetime) -> int:
        kept = [item for item in self.decisions if item.decided_at >= before]
        pruned = len(self.decisions) - len(kept)
        self.decisions = kept
        return pruned

    def log_decision(self, decision: ListingDecision) -> None:
        self.decisions.append(decision)

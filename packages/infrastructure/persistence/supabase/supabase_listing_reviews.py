"""Confirmations and checks of Mercatino ads on Supabase (service-role client): tables
created by scripts/setup/marketplace_content_review.sql. The service role ignores
row-level security; who may read what is decided in the services."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.listing_review_repository import (
    ListingReviewsUnavailable,
)
from packages.core.domain.marketplace.content_review import ListingDecision, ListingReview
from packages.infrastructure.persistence.supabase.missing_table import is_missing_table

if TYPE_CHECKING:
    from supabase import Client

_TABLE = "marketplace_listing_reviews"
_LOG = "marketplace_listing_decision_log"
# Ids per request: a longer `in` list would not fit the request line.
_CHUNK = 100


def _reviews(response: Any) -> list[ListingReview]:
    rows = cast(list[dict[str, Any]], response.data or [])
    return [ListingReview.model_validate(row) for row in rows]


class SupabaseListingReviewRepository:
    def __init__(self, client: Client) -> None:
        self._client = client

    def save(self, review: ListingReview) -> ListingReview:
        self._client.table(_TABLE).upsert(review.model_dump(mode="json")).execute()
        return review

    def get(self, review_id: str) -> ListingReview | None:
        found = _reviews(
            self._client.table(_TABLE).select("*").eq("id", review_id).limit(1).execute()
        )
        return found[0] if found else None

    def list_by_listings(self, listing_ids: list[str]) -> list[ListingReview]:
        ids = sorted(set(listing_ids))
        found: list[ListingReview] = []
        for start in range(0, len(ids), _CHUNK):
            found.extend(
                _reviews(
                    self._client.table(_TABLE)
                    .select("*")
                    .in_("listing_id", ids[start : start + _CHUNK])
                    .execute()
                )
            )
        return found

    def list_by_owner(self, owner_id: str) -> list[ListingReview]:
        return _reviews(self._client.table(_TABLE).select("*").eq("owner_id", owner_id).execute())

    def list_for_team(self, limit: int) -> list[ListingReview]:
        waiting = _reviews(
            self._client.table(_TABLE)
            .select("*")
            .eq("status", "open")
            .order("confirmed_at")
            .limit(limit)
            .execute()
        )
        decided = _reviews(
            self._client.table(_TABLE)
            .select("*")
            .in_("status", ["checked", "removed"])
            .order("confirmed_at", desc=True)
            .limit(limit)
            .execute()
        )
        return [*waiting, *decided]

    def list_removed(self) -> list[ListingReview]:
        try:
            return _reviews(
                self._client.table(_TABLE)
                .select("*")
                .eq("status", "removed")
                .order("decided_at")
                .limit(1000)
                .execute()
            )
        except Exception as exc:
            if is_missing_table(exc):
                raise ListingReviewsUnavailable from exc
            raise

    def prune_decisions(self, before: datetime) -> int:
        try:
            response = (
                self._client.table(_LOG).delete().lt("decided_at", before.isoformat()).execute()
            )
        except Exception as exc:
            if is_missing_table(exc):
                raise ListingReviewsUnavailable from exc
            raise
        return len(response.data or [])

    def log_decision(self, decision: ListingDecision) -> None:
        self._client.table(_LOG).insert(decision.model_dump(mode="json")).execute()

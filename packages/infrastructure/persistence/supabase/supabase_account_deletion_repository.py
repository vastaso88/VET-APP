from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.account_deletion_repository import (
    AccountDeletionRepository,
)
from packages.core.domain.account_deletion.models import AccountDeletionRequest

if TYPE_CHECKING:
    from supabase import Client

TABLE = "account_deletion_requests"


def _to_model(row: dict[str, Any]) -> AccountDeletionRequest:
    return AccountDeletionRequest(
        owner_id=str(row["owner_id"]),
        requested_at=datetime.fromisoformat(str(row["requested_at"])),
        purge_after=datetime.fromisoformat(str(row["purge_after"])),
    )


class SupabaseAccountDeletionRepository(AccountDeletionRepository):
    """Written only by the backend (service role). Nothing here is logged."""

    def __init__(self, client: Client) -> None:
        self._client = client

    def get(self, owner_id: str) -> AccountDeletionRequest | None:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("*").eq("owner_id", owner_id).limit(1).execute().data
            or [],
        )
        return _to_model(rows[0]) if rows else None

    def create(self, request: AccountDeletionRequest) -> bool:
        response = (
            self._client.table(TABLE)
            .upsert(
                {
                    "owner_id": request.owner_id,
                    "requested_at": request.requested_at.isoformat(),
                    "purge_after": request.purge_after.isoformat(),
                },
                on_conflict="owner_id",
                ignore_duplicates=True,
            )
            .execute()
        )
        return bool(response.data)

    def delete(self, owner_id: str) -> bool:
        response = self._client.table(TABLE).delete().eq("owner_id", owner_id).execute()
        return bool(response.data)

    def list_due(self, now: datetime) -> list[AccountDeletionRequest]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("*").lte("purge_after", now.isoformat()).execute().data
            or [],
        )
        return [_to_model(row) for row in rows]

    def pending_owner_ids(self) -> set[str]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("owner_id").execute().data or [],
        )
        return {str(row["owner_id"]) for row in rows}

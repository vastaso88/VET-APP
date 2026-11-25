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
        last_notice=row.get("last_notice"),
        last_notice_at=(
            datetime.fromisoformat(str(row["last_notice_at"]))
            if row.get("last_notice_at")
            else None
        ),
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

    def list_pending(self) -> list[AccountDeletionRequest]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("*").execute().data or [],
        )
        return [_to_model(row) for row in rows]

    def notice_log_available(self) -> bool:
        try:
            self._client.table(TABLE).select("last_notice, last_notice_at").limit(1).execute()
        except Exception:  # noqa: BLE001 - no such column (or the table is unreachable)
            return False
        return True

    def claim_notice(self, owner_id: str, notice: str, previous: str | None, at: datetime) -> bool:
        # A conditional update: it changes the row only while last_notice is still what the
        # caller read, so of two runs only one gets a row back.
        query = (
            self._client.table(TABLE)
            .update({"last_notice": notice, "last_notice_at": at.isoformat()})
            .eq("owner_id", owner_id)
        )
        if previous is None:
            query = query.is_("last_notice", "null")
        else:
            query = query.eq("last_notice", previous)
        return bool(query.execute().data)

    def release_notice(
        self,
        owner_id: str,
        notice: str,
        previous: str | None,
        previous_at: datetime | None,
    ) -> None:
        self._client.table(TABLE).update(
            {
                "last_notice": previous,
                "last_notice_at": previous_at.isoformat() if previous_at else None,
            }
        ).eq("owner_id", owner_id).eq("last_notice", notice).execute()

    def pending_owner_ids(self) -> set[str]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("owner_id").execute().data or [],
        )
        return {str(row["owner_id"]) for row in rows}

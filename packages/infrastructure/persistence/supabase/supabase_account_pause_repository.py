from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.account_pause_repository import AccountPauseRepository
from packages.core.domain.account_pause.models import AccountPause

if TYPE_CHECKING:
    from supabase import Client

TABLE = "account_pauses"


def _to_model(row: dict[str, Any]) -> AccountPause:
    notice_at = row.get("last_notice_at")
    resumed_at = row.get("resumed_at")
    return AccountPause(
        owner_id=str(row["owner_id"]),
        paused_at=datetime.fromisoformat(str(row["paused_at"])),
        last_notice=row.get("last_notice"),
        last_notice_at=datetime.fromisoformat(str(notice_at)) if notice_at else None,
        resumed_at=datetime.fromisoformat(str(resumed_at)) if resumed_at else None,
    )


class SupabaseAccountPauseRepository(AccountPauseRepository):
    """Written only by the backend (service role). Nothing here is logged."""

    def __init__(self, client: Client) -> None:
        self._client = client

    def get(self, owner_id: str) -> AccountPause | None:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("*").eq("owner_id", owner_id).limit(1).execute().data
            or [],
        )
        return _to_model(rows[0]) if rows else None

    def is_paused(self, owner_id: str) -> bool:
        pause = self.get(owner_id)
        return pause is not None and pause.active

    def paused_owner_ids(self) -> frozenset[str]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("owner_id").is_("resumed_at", "null").execute().data
            or [],
        )
        return frozenset(str(row["owner_id"]) for row in rows)

    def create(self, pause: AccountPause) -> bool:
        # An ended pause nobody acknowledged is replaced by the new one.
        self._client.table(TABLE).delete().eq("owner_id", pause.owner_id).not_.is_(
            "resumed_at", "null"
        ).execute()
        response = (
            self._client.table(TABLE)
            .upsert(
                {"owner_id": pause.owner_id, "paused_at": pause.paused_at.isoformat()},
                on_conflict="owner_id",
                ignore_duplicates=True,
            )
            .execute()
        )
        return bool(response.data)

    def resume(self, owner_id: str, at: datetime) -> None:
        self._client.table(TABLE).update({"resumed_at": at.isoformat()}).eq(
            "owner_id", owner_id
        ).is_("resumed_at", "null").execute()

    def acknowledge(self, owner_id: str) -> bool:
        response = (
            self._client.table(TABLE)
            .delete()
            .eq("owner_id", owner_id)
            .not_.is_("resumed_at", "null")
            .execute()
        )
        return bool(response.data)

    def delete(self, owner_id: str) -> bool:
        response = self._client.table(TABLE).delete().eq("owner_id", owner_id).execute()
        return bool(response.data)

    def record_notice(self, owner_id: str, notice: str, at: datetime) -> None:
        self._client.table(TABLE).update(
            {"last_notice": notice, "last_notice_at": at.isoformat()}
        ).eq("owner_id", owner_id).is_("resumed_at", "null").execute()

    def list_all(self) -> list[AccountPause]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("*").is_("resumed_at", "null").execute().data or [],
        )
        return [_to_model(row) for row in rows]

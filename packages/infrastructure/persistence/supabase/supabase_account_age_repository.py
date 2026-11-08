from __future__ import annotations

from datetime import date, datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.domain.age.models import AccountAge

if TYPE_CHECKING:
    from supabase import Client

TABLE = "account_age"


def _to_model(row: dict[str, Any]) -> AccountAge:
    guardian = row.get("guardian_ok_at")
    return AccountAge(
        owner_id=str(row["owner_id"]),
        birth_date=date.fromisoformat(str(row["birth_date"])[:10]),
        declared_at=datetime.fromisoformat(str(row["declared_at"])),
        guardian_ok_at=datetime.fromisoformat(str(guardian)) if guardian else None,
    )


class SupabaseAccountAgeRepository(AccountAgeRepository):
    """The declared date of birth, in a table of its own that only the backend
    writes (the service role). It is not kept in `user_metadata`: the owner
    can edit that themselves. Nothing here is logged."""

    def __init__(self, client: Client) -> None:
        self._client = client

    def get(self, owner_id: str) -> AccountAge | None:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE).select("*").eq("owner_id", owner_id).limit(1).execute().data
            or [],
        )
        return _to_model(rows[0]) if rows else None

    def create(self, age: AccountAge) -> bool:
        response = (
            self._client.table(TABLE)
            .upsert(
                {
                    "owner_id": age.owner_id,
                    "birth_date": age.birth_date.isoformat(),
                    "declared_at": age.declared_at.isoformat(),
                },
                on_conflict="owner_id",
                ignore_duplicates=True,
            )
            .execute()
        )
        # An ignored duplicate returns no row: the declaration already existed.
        return bool(response.data)

    def mark_guardian_ok(self, owner_id: str, at: datetime) -> AccountAge | None:
        response = (
            self._client.table(TABLE)
            .update({"guardian_ok_at": at.isoformat()})
            .eq("owner_id", owner_id)
            .execute()
        )
        rows = cast(list[dict[str, Any]], response.data or [])
        return _to_model(rows[0]) if rows else None

    def list_declared_before(self, cutoff: datetime) -> list[AccountAge]:
        rows = cast(
            list[dict[str, Any]],
            self._client.table(TABLE)
            .select("*")
            .lt("declared_at", cutoff.isoformat())
            .execute()
            .data
            or [],
        )
        return [_to_model(row) for row in rows]

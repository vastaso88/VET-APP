"""The two support tables of scripts/setup/plan_access_rules.sql, written with
the service-role client (the app has no privilege on them)."""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from supabase import Client


class SupabasePlanAccessStore:
    def __init__(self, client: Client) -> None:
        self._client = client

    def set_test_plan(self, plan: str | None) -> None:
        self._client.table("plan_access_config").upsert({"id": 1, "test_plan": plan}).execute()

    def set_unlimited(self, owner_id: str, unlimited: bool) -> None:
        table = self._client.table("plan_access_unlimited")
        if unlimited:
            table.upsert({"owner_id": owner_id}, on_conflict="owner_id").execute()
        else:
            table.delete().eq("owner_id", owner_id).execute()

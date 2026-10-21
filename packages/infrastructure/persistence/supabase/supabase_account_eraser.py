"""Account deletion against Supabase (service-role client).

Coverage is explicit: every table that stores something created by or about
the owner is listed in [OWNER_TABLES] (or handled in [erase_data]); every
other table is listed in [NOT_PERSONAL_TABLES] with the reason. A test reads
scripts/setup/supabase_schema.sql and fails when a table is in neither list,
so a new table cannot silently escape the deletion."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any, cast
from uuid import UUID

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.core.domain.radar_reports.models import contributor_pseudonym

if TYPE_CHECKING:
    from supabase import Client

_LIST_PAGE = 100
PET_PHOTOS_BUCKET = "pet-photos"
MARKETPLACE_PHOTOS_BUCKET = "marketplace-photos"

# (table, column holding the owner id), children before parents. Rows that
# hang off a pet or a listing (clinical_events, chat_response_reports of the
# owner's chats, listing reports) are removed explicitly as well, because the
# live database was set up by hand and cascades cannot be taken for granted.
OWNER_TABLES: tuple[tuple[str, str], ...] = (
    ("marketplace_listing_reports", "reporter_owner_id"),
    ("marketplace_listings", "owner_id"),
    ("chat_response_reports", "reporter_owner_id"),
    ("chat_attachments", "owner_id"),
    ("pet_photos", "owner_id"),
    ("pet_weight_measurements", "owner_id"),
    ("pet_conditions", "owner_id"),
    ("dog_walks", "owner_id"),
    ("reminders", "owner_id"),
    ("conversations", "owner_id"),
    ("pet_profiles", "owner_id"),
    ("account_consents", "owner_id"),
    ("subscriptions", "owner_id"),
    ("user_locations", "owner_id"),
    ("chat_user_daily_usage", "owner_id"),
    ("local_activities", "submitted_by_owner_id"),
    ("event_submissions", "submitted_by"),
)

# Tables keyed by a keyed pseudonym of the owner instead of the id.
CHAT_REPORT_REF = ("chat_response_reports", "reporter_ref")
RADAR_PSEUDONYM_TABLES: tuple[tuple[str, str], ...] = (
    ("radar_report_votes", "voter_pseudonym"),
    ("radar_place_ratings", "voter_pseudonym"),
    ("radar_user_reports", "reporter_pseudonym"),
)

# Tables handled by a dedicated step rather than by [OWNER_TABLES].
HANDLED_ELSEWHERE = frozenset({"clinical_events"})

# Tables that hold nothing about an individual owner, and why.
NOT_PERSONAL_TABLES: dict[str, str] = {
    "data_sources": "public catalogue of data sources",
    "radar_coverage_cells": "map coverage bookkeeping, no user data",
    "radar_places_cache": "cache of public places",
    "radar_places_osm": "public OpenStreetMap places",
    "radar_places_open": "public open-data places",
    "radar_place_overrides": "moderation of public places by the team",
    "events": "public events catalogue",
    "pet_news_snapshots": "cache of public headlines, no user data",
    "admin_ingestion_schedules": "team-only ingestion schedule",
    "llm_usage": "aggregate model usage, no owner column",
    "llm_usage_daily": "aggregate model usage, no owner column",
    "chat_answer_cache": "anonymised answer cache, no owner column",
    "chat_response_report_counters": "aggregate counters, no owner column",
}


class SupabaseAccountEraser:
    def __init__(
        self,
        client: Client,
        *,
        media_bucket: str,
        chat_reporter_secret: str,
        radar_pseudonym_key: str | None,
    ) -> None:
        self._client = client
        self._media_bucket = media_bucket
        self._chat_reporter_secret = chat_reporter_secret
        self._radar_pseudonym_key = radar_pseudonym_key

    @staticmethod
    def _require_user_id(owner_id: str) -> None:
        """An empty id would list the whole bucket as "the owner's folder" and
        delete every user's files; anything that is not a UUID is not a user."""
        try:
            UUID(owner_id)
        except (ValueError, AttributeError, TypeError) as exc:
            raise ValueError("owner_id must be a valid user UUID") from exc

    def erase_data(self, owner_id: str) -> ErasureReport:
        self._require_user_id(owner_id)
        report = ErasureReport()
        self._remove_files(owner_id, report)

        pets = self._client.table("pet_profiles").select("id").eq("owner_id", owner_id).execute()
        pet_ids = [str(row["id"]) for row in self._rows(pets)]
        if pet_ids:
            response = (
                self._client.table("clinical_events").delete().in_("pet_id", pet_ids).execute()
            )
            self._count(report, "clinical_events", response)

        if self._radar_pseudonym_key:
            pseudonym = contributor_pseudonym(owner_id, key=self._radar_pseudonym_key)
            for table, column in RADAR_PSEUDONYM_TABLES:
                self._delete_where(report, table, column, pseudonym)

        if self._chat_reporter_secret:
            table, column = CHAT_REPORT_REF
            self._delete_where(
                report, table, column, reporter_ref(owner_id, self._chat_reporter_secret)
            )

        for table, column in OWNER_TABLES:
            self._delete_where(report, table, column, owner_id)
        return report

    def delete_identity(self, owner_id: str) -> None:
        self._require_user_id(owner_id)
        self._client.auth.admin.delete_user(owner_id)

    # -- files -----------------------------------------------------------

    def _remove_files(self, owner_id: str, report: ErasureReport) -> None:
        # Chat/medical-record attachment bytes sit under generated keys, only
        # known from the rows that point at them.
        attachments = (
            self._client.table("chat_attachments")
            .select("storage_key")
            .eq("owner_id", owner_id)
            .execute()
        )
        keys = [str(row["storage_key"]) for row in self._rows(attachments)]
        report.files_removed += self._remove(self._media_bucket, keys)
        # Pet gallery, account photo and marketplace photos live under "<uid>/".
        for bucket in (PET_PHOTOS_BUCKET, MARKETPLACE_PHOTOS_BUCKET):
            report.files_removed += self._remove(bucket, self._list_all(bucket, owner_id))

    def _list_all(self, bucket: str, prefix: str) -> list[str]:
        paths: list[str] = []
        offset = 0
        while True:
            # Storage lists at most `limit` entries per call: page through them,
            # or an owner with a big gallery would keep files after deletion.
            listing = cast(
                list[dict[str, Any]],
                self._client.storage.from_(bucket).list(
                    prefix, {"limit": _LIST_PAGE, "offset": offset}
                ),
            )
            for entry in listing or []:
                path = f"{prefix}/{entry['name']}"
                if entry.get("id") is None:  # a folder
                    paths.extend(self._list_all(bucket, path))
                else:
                    paths.append(path)
            if len(listing or []) < _LIST_PAGE:
                return paths
            offset += _LIST_PAGE

    def _remove(self, bucket: str, paths: list[str]) -> int:
        if not paths:
            return 0
        self._client.storage.from_(bucket).remove(paths)
        return len(paths)

    # -- rows ------------------------------------------------------------

    @staticmethod
    def _rows(response: Any) -> list[dict[str, Any]]:
        return cast(list[dict[str, Any]], response.data or [])

    def _delete_where(self, report: ErasureReport, table: str, column: str, value: str) -> None:
        response = self._client.table(table).delete().eq(column, value).execute()
        self._count(report, table, response)

    @staticmethod
    def _count(report: ErasureReport, table: str, response: Any) -> None:
        deleted = len(response.data or [])
        report.rows_deleted[table] = report.rows_deleted.get(table, 0) + deleted

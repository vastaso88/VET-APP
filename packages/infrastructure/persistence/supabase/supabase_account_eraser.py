"""Account deletion against Supabase (service-role client).

Coverage is explicit: every table that stores something created by or about
the owner is listed in [OWNER_TABLES] (or handled in [erase_data]); every
other table is listed in [NOT_PERSONAL_TABLES] or, when only a pseudonym is
kept on purpose, in [RETAINED_AFTER_DELETION], each with the reason. A test reads
scripts/setup/supabase_schema.sql and fails when a table is in neither list,
so a new table cannot silently escape the deletion. A second one does the same
with the tables production really has (scripts/security/production_tables.json):
some were made by hand long ago and are in no script of the repository."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any, cast
from uuid import UUID

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.core.domain.marketplace.messaging import (
    DELETED_PARTICIPANT_IDS,
    KEEPING_REPORT_STATUSES,
)
from packages.core.domain.marketplace.photos import PUBLISHED, is_plain_name
from packages.core.domain.radar_reports.models import contributor_pseudonym
from packages.infrastructure.persistence.supabase.missing_table import (
    is_missing_table,
    missing_table_note,
)

if TYPE_CHECKING:
    from supabase import Client

logger = logging.getLogger(__name__)
_LIST_PAGE = 100
PET_PHOTOS_BUCKET = "pet-photos"
MARKETPLACE_PHOTOS_BUCKET = "marketplace-photos"
# Photos of ads taken down by the team (storage/listing_photo_vaults.py).
MARKETPLACE_HELD_PHOTOS_BUCKET = "marketplace-photos-held"
# Documents of the old system (clinical_documents), in production only.
LEGACY_DOCUMENTS_BUCKET = "clinical-documents"

# (table, column holding the owner id), children before parents. Rows that
# hang off a pet or a listing (clinical_events, chat_response_reports of the
# owner's chats, listing reports) are removed explicitly as well, because the
# live database was set up by hand and cascades cannot be taken for granted.
OWNER_TABLES: tuple[tuple[str, str], ...] = (
    ("user_login_events", "owner_id"),
    ("admin_user_actions", "owner_id"),
    ("admin_plan_changes", "owner_id"),
    ("marketplace_listing_reports", "reporter_owner_id"),
    ("marketplace_user_restrictions", "owner_id"),
    ("marketplace_listing_reviews", "owner_id"),
    ("marketplace_listings", "owner_id"),
    ("chat_response_reports", "reporter_owner_id"),
    ("chat_message_keys", "owner_id"),
    ("chat_attachments", "owner_id"),
    ("pet_photos", "owner_id"),
    ("pet_weight_measurements", "owner_id"),
    ("pet_conditions", "owner_id"),
    ("dog_walks", "owner_id"),
    ("reminders", "owner_id"),
    ("conversations", "owner_id"),
    ("pet_profiles", "owner_id"),
    ("account_age", "owner_id"),
    ("account_consents", "owner_id"),
    ("account_pauses", "owner_id"),
    ("subscriptions", "owner_id"),
    ("store_subscriptions", "owner_id"),
    ("store_events", "owner_id"),
    ("store_account_tokens", "owner_id"),
    ("user_devices", "owner_id"),
    ("user_locations", "owner_id"),
    ("chat_user_daily_usage", "owner_id"),
    ("local_activities", "submitted_by_owner_id"),
    ("event_submissions", "submitted_by"),
)

# The same, for tables that exist only in production: no script of the repository
# creates them (found 2026-11-23, docs/security/02_audit.md DB-9). Where they do not
# exist (the twin, a new install, production once they are dropped) nothing is missing:
# they are skipped without a note. Any other error still stops the deletion.
LEGACY_OWNER_TABLES: tuple[tuple[str, str], ...] = (
    ("adoption_contact_requests", "owner_id"),
    ("adoption_listings", "owner_id"),
    # The old billing: everything hangs off owner_profiles, which goes last.
    ("billing_founder_slots", "owner_id"),
    ("billing_one_time_purchases", "owner_id"),
    ("billing_subscriptions", "owner_id"),
    ("billing_customers", "owner_id"),
    ("owner_billing_entitlements", "owner_id"),
    ("owner_profiles", "owner_id"),
    ("clinical_documents", "owner_id"),
    ("local_service_reviews", "owner_id"),
    ("local_service_events", "owner_id"),
    ("local_service_venues", "owner_id"),
    # The old radar kept who searched and around which point.
    ("radar_place_ingestion_jobs", "owner_id"),
    ("radar_place_coverages", "owner_id"),
    ("radar_coverages", "owner_id"),
    ("radar_places", "owner_id"),
)

# Tables keyed by a keyed pseudonym of the owner instead of the id.
CHAT_REPORT_REF = ("chat_response_reports", "reporter_ref")
RADAR_PSEUDONYM_TABLES: tuple[tuple[str, str], ...] = (
    ("radar_report_votes", "voter_pseudonym"),
    ("radar_place_ratings", "voter_pseudonym"),
    ("radar_user_reports", "reporter_pseudonym"),
    ("radar_competence_claims", "reporter_pseudonym"),
)

# The two sides of a Mercatino conversation (see _erase_marketplace_messages).
MARKETPLACE_PARTICIPANT_COLUMNS: tuple[str, ...] = ("buyer_id", "seller_id")

# Tables handled by a dedicated step rather than by [OWNER_TABLES].
# account_deletion_requests: the end-of-period purge removes that row last, once
# the identity is gone (if anything failed before, the row is what makes the
# next run try again).
HANDLED_ELSEWHERE = frozenset(
    {
        "account_deletion_requests",
        "clinical_events",
        "marketplace_conversations",
        "marketplace_messages",
        "marketplace_user_blocks",
        "marketplace_conversation_reports",
    }
)

# Pseudonymised data deliberately KEPT after the owner is erased (not a table
# "without personal data": a fingerprint of the id is still a pseudonym), and why.
# Not exported to the owner, not erased: it is the proof of the erasure and what
# lets a restore from backup apply it again.
RETAINED_AFTER_DELETION: dict[str, str] = {
    "marketplace_listing_decision_log": (
        "registro delle decisioni del team sugli annunci (docs/compliance/24): id "
        "dell'annuncio, esito, motivo, data, id di chi ha deciso; nessun id di chi vende e "
        "nessun testo; 24 mesi"
    ),
    "account_deletion_log": (
        "art. 17(3)(b)/(e) e 5(2), impronta senza dati identificativi; conservato "
        "per la finestra di ripristino dei backup e, come prova, per 5 anni"
    ),
}

# Tables that hold nothing about an individual owner, and why.
NOT_PERSONAL_TABLES: dict[str, str] = {
    "data_sources": "public catalogue of data sources",
    "radar_coverage_cells": "map coverage bookkeeping, no user data",
    "radar_country_coverage": "per-country import bookkeeping, no user data",
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
    "marketplace_moderation_access_log": (
        "team-only trail of who read or decided a reported conversation: team ids and "
        "random report/conversation ids, no owner column"
    ),
}

# The same answer for the tables of production that supabase_schema.sql does not create:
# old ones made by hand (see LEGACY_OWNER_TABLES) and a few made by a migration only.
# One with a column that names a person is here only with the reason why it is not an
# owner's data.
LEGACY_NOT_PERSONAL_TABLES: dict[str, str] = {
    "admin_plan_totp_attempts": "team-only: failed codes of an administrator, no owner column",
    "admin_plan_totp_replay": "team-only: used codes of an administrator, no owner column",
    "billing_plans": "old price list",
    "billing_webhook_events": "events of the old payment provider, no owner column",
    "health_cards": "old health cards of the team, no owner column",
    "plan_access_config": "plan limits read by the database rules, no owner column",
    "pricing_admin_audit": "team-only trail of price changes: the id is the administrator's",
    "pricing_plan_features": "what each plan includes; updated_by is the administrator's id",
    "pricing_store_prices": "price list; updated_by is the administrator's id",
    "scrape_runs": "team-only trail of the imports: the id is the administrator's, or 'shared'",
    "system_settings": "service settings, no owner column",
}
# Gone with the sign-in account itself: foreign key to auth.users, on delete cascade.
ERASED_WITH_THE_IDENTITY: frozenset[str] = frozenset({"plan_access_unlimited"})


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

        self._erase_marketplace_messages(owner_id, report)

        if self._radar_pseudonym_key:
            pseudonym = contributor_pseudonym(owner_id, key=self._radar_pseudonym_key)
            for table, column in RADAR_PSEUDONYM_TABLES:
                self._delete_where(report, table, column, pseudonym)

        if self._chat_reporter_secret:
            table, column = CHAT_REPORT_REF
            self._delete_where(
                report, table, column, reporter_ref(owner_id, self._chat_reporter_secret)
            )

        for table, column in LEGACY_OWNER_TABLES:
            self._delete_where(report, table, column, owner_id, may_be_absent=True)
        for table, column in OWNER_TABLES:
            self._delete_where(report, table, column, owner_id)
        return report

    def _erase_marketplace_messages(self, owner_id: str, report: ErasureReport) -> None:
        """A conversation goes as a whole when one of the two deletes the account:
        the other person's replies can quote the deleted owner's details, and the
        row names them. Children first and explicitly, like the rest of this file;
        blocks go in both directions, because both ids identify the owner.

        Except a conversation under review (owner decision 2026-11-08, legal opinion
        docs/compliance/10 §2.3): with a report still open or upheld by the team it
        stays, for the team only, with the deleted owner's id replaced by the role
        everywhere it appears (conversation, messages, report). The nightly cleanup
        removes it 6 months after the decision, or as soon as the report is
        dismissed. It applies whoever deletes: the reported person or the reporter."""
        roles: dict[str, str] = {}
        for column, role in zip(MARKETPLACE_PARTICIPANT_COLUMNS, ("buyer", "seller"), strict=True):
            response = (
                self._client.table("marketplace_conversations")
                .select("id")
                .eq(column, owner_id)
                .execute()
            )
            roles.update({str(row["id"]): role for row in self._rows(response)})

        kept: set[str] = set()
        if roles:
            reports = (
                self._client.table("marketplace_conversation_reports")
                .select("conversation_id,status")
                .in_("conversation_id", sorted(roles))
                .execute()
            )
            kept = {
                str(row["conversation_id"])
                for row in self._rows(reports)
                if row.get("status") in KEEPING_REPORT_STATUSES
            }
        gone = sorted(set(roles) - kept)
        if gone:
            for table in ("marketplace_conversation_reports", "marketplace_messages"):
                response = self._client.table(table).delete().in_("conversation_id", gone).execute()
                self._count(report, table, response)
            response = (
                self._client.table("marketplace_conversations").delete().in_("id", gone).execute()
            )
            self._count(report, "marketplace_conversations", response)

        now = datetime.now(UTC).isoformat()
        for conversation_id in sorted(kept):
            role = roles[conversation_id]
            placeholder = DELETED_PARTICIPANT_IDS[role]
            self._client.table("marketplace_conversations").update(
                {
                    f"{role}_id": placeholder,
                    "erased_participant_at": now,
                    "buyer_unread": 0,
                    "seller_unread": 0,
                }
            ).eq("id", conversation_id).execute()
            for table, column in (
                ("marketplace_messages", "sender_id"),
                ("marketplace_conversation_reports", "reporter_id"),
            ):
                self._client.table(table).update({column: placeholder}).eq(
                    "conversation_id", conversation_id
                ).eq(column, owner_id).execute()
        if kept:
            report.rows_deleted["marketplace_conversations_kept_for_review"] = len(kept)

        for column in ("blocker_id", "blocked_id"):
            self._delete_where(report, "marketplace_user_blocks", column, owner_id)

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
        report.files_removed += self._remove(
            LEGACY_DOCUMENTS_BUCKET, self._legacy_document_paths(owner_id)
        )
        # Pet gallery, account photo and marketplace photos live under "<uid>/".
        for bucket in (
            PET_PHOTOS_BUCKET,
            MARKETPLACE_PHOTOS_BUCKET,
            MARKETPLACE_HELD_PHOTOS_BUCKET,
        ):
            report.files_removed += self._remove(bucket, self._list_all(bucket, owner_id))
        # The copies of the ads' photos are under the id of the ad, not of the owner: read
        # while the rows still say whose they are.
        ads = (
            self._client.table("marketplace_listings")
            .select("id")
            .eq("owner_id", owner_id)
            .execute()
        )
        for row in self._rows(ads):
            if not is_plain_name(row.get("id")):
                continue  # no folder of ours has such a name
            folder = f"{PUBLISHED}/{row['id']}"
            for bucket in (MARKETPLACE_PHOTOS_BUCKET, MARKETPLACE_HELD_PHOTOS_BUCKET):
                report.files_removed += self._remove(bucket, self._list_all(bucket, folder))

    def _legacy_document_paths(self, owner_id: str) -> list[str]:
        """Files of the old clinical_documents, known only from its rows. Read before the
        rows are erased; where the old table does not exist there is nothing to remove."""
        try:
            response = (
                self._client.table("clinical_documents")
                .select("file_path")
                .eq("owner_id", owner_id)
                .execute()
            )
        except Exception as exc:
            if not is_missing_table(exc):
                raise
            return []
        prefix = f"{LEGACY_DOCUMENTS_BUCKET}/"
        paths = [str(row.get("file_path") or "").lstrip("/") for row in self._rows(response)]
        return [path.removeprefix(prefix) for path in paths if path]

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

    def _delete_where(
        self,
        report: ErasureReport,
        table: str,
        column: str,
        value: str,
        *,
        may_be_absent: bool = False,
    ) -> None:
        try:
            response = self._client.table(table).delete().eq(column, value).execute()
        except Exception as exc:
            # A table that does not exist yet holds no data: skip it, say so.
            # Any other failure stops the deletion (the identity is kept).
            if not is_missing_table(exc):
                raise
            if may_be_absent:
                return
            note = missing_table_note(table)
            if note not in report.notes:
                report.notes.append(note)
            logger.warning("account erasure: %s", note)
            return
        self._count(report, table, response)

    @staticmethod
    def _count(report: ErasureReport, table: str, response: Any) -> None:
        deleted = len(response.data or [])
        report.rows_deleted[table] = report.rows_deleted.get(table, 0) + deleted

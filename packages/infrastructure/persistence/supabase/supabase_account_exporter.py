"""Account data export against Supabase (service-role client).

Reads exactly the tables [SupabaseAccountEraser] deletes, keyed the same
way (owner id, pet ids, keyed pseudonyms), so "download my data" and
"delete my account" can never disagree about what the service holds. Files
are not copied into the document: each one gets a signed link that stops
working after [SIGNED_URL_SECONDS]."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING, Any
from uuid import UUID

from packages.core.application.ports.account_exporter import AccountExport, ExportedFile
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.core.domain.radar_reports.models import contributor_pseudonym
from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
    CHAT_REPORT_REF,
    OWNER_TABLES,
    PET_PHOTOS_BUCKET,
    RADAR_PSEUDONYM_TABLES,
)

if TYPE_CHECKING:
    from supabase import Client

SIGNED_URL_SECONDS = 15 * 60
_LIST_PAGE = 100
# Columns that only make sense inside the service (keyed pseudonyms of the
# owner themself): they are the owner's data, but meaningless outside and
# would only help someone correlate rows if the file leaked.
_INTERNAL_COLUMNS = frozenset({"reporter_ref", "reporter_pseudonym", "voter_pseudonym"})

# The tables the export reads, derived from the eraser's lists so a table
# added to one side shows up missing on the other in the alignment test.
EXPORTED_TABLES: frozenset[str] = frozenset(
    {table for table, _ in OWNER_TABLES}
    | {table for table, _ in RADAR_PSEUDONYM_TABLES}
    | {CHAT_REPORT_REF[0], "clinical_events"}
)


class SupabaseAccountExporter:
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
        try:
            UUID(owner_id)
        except (ValueError, AttributeError, TypeError) as exc:
            raise ValueError("owner_id must be a valid user UUID") from exc

    def export_data(self, owner_id: str) -> AccountExport:
        self._require_user_id(owner_id)
        now = datetime.now(UTC)
        export = AccountExport(generated_at=now, owner_id=owner_id)
        export.account = self._account(owner_id)

        for table, column in OWNER_TABLES:
            export.data[table] = self._select_where(table, column, owner_id)

        pet_ids = [str(row["id"]) for row in export.data.get("pet_profiles", []) if "id" in row]
        export.data["clinical_events"] = (
            self._rows(
                self._client.table("clinical_events").select("*").in_("pet_id", pet_ids).execute()
            )
            if pet_ids
            else []
        )

        if self._radar_pseudonym_key:
            pseudonym = contributor_pseudonym(owner_id, key=self._radar_pseudonym_key)
            for table, column in RADAR_PSEUDONYM_TABLES:
                export.data[table] = self._select_where(table, column, pseudonym)
        else:
            for table, _ in RADAR_PSEUDONYM_TABLES:
                export.data.setdefault(table, [])
            export.notes.append("radar contributions not exported: pseudonym key not configured")

        if self._chat_reporter_secret:
            table, column = CHAT_REPORT_REF
            keyed = self._select_where(
                table, column, reporter_ref(owner_id, self._chat_reporter_secret)
            )
            seen = {row.get("id") for row in export.data.get(table, [])}
            export.data[table] = export.data.get(table, []) + [
                row for row in keyed if row.get("id") not in seen
            ]

        for table, rows in export.data.items():
            export.data[table] = [
                {key: value for key, value in row.items() if key not in _INTERNAL_COLUMNS}
                for row in rows
            ]

        export.files = self._files(owner_id, export.data, now)
        export.notes.append(
            f"file links expire {SIGNED_URL_SECONDS // 60} minutes after generated_at"
        )
        return export

    # -- identity ------------------------------------------------------------

    def _account(self, owner_id: str) -> dict[str, Any]:
        try:
            response = self._client.auth.admin.get_user_by_id(owner_id)
        except Exception:
            return {"id": owner_id}
        user = getattr(response, "user", None)
        if user is None:
            return {"id": owner_id}
        metadata = getattr(user, "user_metadata", None) or {}
        account: dict[str, Any] = {
            "id": owner_id,
            "email": getattr(user, "email", None),
            "email_confirmed_at": _iso(getattr(user, "email_confirmed_at", None)),
            "created_at": _iso(getattr(user, "created_at", None)),
            "last_sign_in_at": _iso(getattr(user, "last_sign_in_at", None)),
        }
        if isinstance(metadata, dict):
            # display name, surname, optional phone, language: all the
            # owner's own profile fields, nothing technical.
            account["profile"] = {
                key: value for key, value in metadata.items() if not key.startswith("_")
            }
        return account

    # -- files ---------------------------------------------------------------

    def _files(
        self, owner_id: str, data: dict[str, list[dict[str, Any]]], now: datetime
    ) -> list[ExportedFile]:
        files: list[ExportedFile] = []
        for row in data.get("chat_attachments", []):
            key = row.get("storage_key")
            if isinstance(key, str) and key:
                files.append(self._signed(self._media_bucket, key, "chat_attachment", now))
        for row in data.get("pet_photos", []):
            path = row.get("storage_path")
            if isinstance(path, str) and path:
                files.append(self._signed(PET_PHOTOS_BUCKET, path, "pet_media", now))
        # The profile photo has no table row: it lives under <owner>/account/.
        for path in self._list_all(PET_PHOTOS_BUCKET, f"{owner_id}/account"):
            files.append(self._signed(PET_PHOTOS_BUCKET, path, "profile_photo", now))
        return files

    def _signed(self, bucket: str, path: str, kind: str, now: datetime) -> ExportedFile:
        try:
            response = self._client.storage.from_(bucket).create_signed_url(
                path, SIGNED_URL_SECONDS
            )
        except Exception:
            return ExportedFile(bucket=bucket, path=path, kind=kind, note="link unavailable")
        url = None
        if isinstance(response, dict):
            url = response.get("signedURL") or response.get("signedUrl")
        if not isinstance(url, str) or not url:
            return ExportedFile(bucket=bucket, path=path, kind=kind, note="link unavailable")
        return ExportedFile(
            bucket=bucket,
            path=path,
            kind=kind,
            url=url,
            url_expires_at=now + timedelta(seconds=SIGNED_URL_SECONDS),
        )

    def _list_all(self, bucket: str, prefix: str) -> list[str]:
        paths: list[str] = []
        offset = 0
        try:
            while True:
                page = self._client.storage.from_(bucket).list(
                    prefix, {"limit": _LIST_PAGE, "offset": offset}
                )
                if not page:
                    break
                for entry in page:
                    if entry.get("id") is not None:
                        paths.append(f"{prefix}/{entry['name']}")
                if len(page) < _LIST_PAGE:
                    break
                offset += _LIST_PAGE
        except Exception:
            return paths
        return paths

    # -- helpers -------------------------------------------------------------

    def _select_where(self, table: str, column: str, value: str) -> list[dict[str, Any]]:
        response = self._client.table(table).select("*").eq(column, value).execute()
        return self._rows(response)

    @staticmethod
    def _rows(response: Any) -> list[dict[str, Any]]:
        data = getattr(response, "data", None) or []
        return [dict(row) for row in data if isinstance(row, dict)]


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)

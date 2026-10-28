from datetime import UTC, datetime

from pydantic import BaseModel

from packages.core.application.ports.account_exporter import AccountExport, AccountExporter


class ExportAccountDataInput(BaseModel):
    owner_id: str
    # What the verified access token says about the caller; merged into the
    # export so the file is self-describing even without the identity
    # provider's record.
    email: str = ""
    display_name: str | None = None
    preferred_locale: str | None = None
    now: datetime | None = None


class ExportAccountDataService:
    """Right of access and portability (GDPR art. 15 and 20): one JSON
    document with every row and a short-lived link to every file of the
    owner. Only ever reads the caller's own id (the route takes it from
    the token), never logs the content, and mirrors the tables the account
    deletion erases so the two stay aligned."""

    def __init__(self, exporter: AccountExporter) -> None:
        self._exporter = exporter

    def execute(self, data: ExportAccountDataInput) -> AccountExport:
        export = self._exporter.export_data(data.owner_id)
        account = dict(export.account)
        account.setdefault("id", data.owner_id)
        if data.email:
            account.setdefault("email", data.email)
        if data.display_name:
            account.setdefault("display_name", data.display_name)
        if data.preferred_locale:
            account.setdefault("preferred_locale", data.preferred_locale)
        return export.model_copy(
            update={
                "account": account,
                "generated_at": data.now or export.generated_at or datetime.now(UTC),
            }
        )

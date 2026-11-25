"""Collaudo F44: the file links of the data export live a few minutes; a refused (expired) link
showed the storage's own English error. The export now says until when the links work and, in the
caller's language, what to do when one has expired."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.application.ports.account_exporter import AccountExport, ExportedFile
from packages.core.application.services.export_account_data import (
    ExportAccountDataInput,
    ExportAccountDataService,
)

NOW = datetime(2026, 11, 25, 12, 0, tzinfo=UTC)


class _Exporter:
    def __init__(self, files: list[ExportedFile]) -> None:
        self._files = files

    def export_data(self, owner_id: str) -> AccountExport:
        return AccountExport(generated_at=NOW, owner_id=owner_id, files=self._files)


def _file(minutes: int | None, name: str = "a.jpg") -> ExportedFile:
    if minutes is None:
        return ExportedFile(bucket="b", path=name, kind="pet_media", note="link unavailable")
    return ExportedFile(
        bucket="b",
        path=name,
        kind="pet_media",
        url=f"https://files.example.com/{name}",
        url_expires_at=NOW + timedelta(minutes=minutes),
    )


def _export(files: list[ExportedFile], language: str | None = None) -> AccountExport:
    return ExportAccountDataService(_Exporter(files)).execute(
        ExportAccountDataInput(owner_id="owner-a", language=language)
    )


def test_the_export_says_until_when_the_links_work() -> None:
    export = _export([_file(15, "a.jpg"), _file(15, "b.jpg"), _file(None, "c.jpg")])

    assert export.links_valid_until == NOW + timedelta(minutes=15)
    assert export.links_expired_notice == (
        "I collegamenti ai file valgono 15 minuti: se sono scaduti, genera di nuovo l'esportazione."
    )


@pytest.mark.parametrize(
    ("language", "start"),
    [
        ("en", "The file links are valid for 15 minutes"),
        ("es", "Los enlaces a los archivos son válidos durante 15 minutos"),
        ("de", "Die Links zu den Dateien gelten 15 Minuten"),
        ("fr", "Les liens vers les fichiers sont valables 15 minutes"),
    ],
)
def test_the_notice_is_in_the_callers_language(language: str, start: str) -> None:
    assert (_export([_file(15)], language).links_expired_notice or "").startswith(start)


def test_without_any_link_there_is_nothing_to_expire() -> None:
    export = _export([_file(None)])

    assert export.links_valid_until is None and export.links_expired_notice is None
    assert _export([]).links_expired_notice is None


def test_the_route_carries_the_fields_and_follows_accept_language() -> None:
    response = TestClient(app).get(
        "/account/export",
        headers={"Accept-Language": "de", "X-Forwarded-For": "203.0.113.77"},
    )

    assert response.status_code == 200
    body = response.json()
    assert "links_valid_until" in body and "links_expired_notice" in body
    # No file in the local demo: no link, so no sentence; the fields are there for the app.
    assert body["links_expired_notice"] is None

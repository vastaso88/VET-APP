"""The team's tool for accounts closed by age: only an admin reaches it, it names
accounts by a keyed reference, and it erases with the account eraser."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.application.ports.owner_contact_lookup import OwnerContact
from packages.core.domain.age.models import AccountAge

ADMIN = "admin-1"
CHILD_OLD = "child-old"
CHILD_NEW = "child-new"
ADULT = "adult-1"
MINOR = "minor-1"
NOW = datetime.now(UTC)


class _SpyEraser:
    def __init__(self) -> None:
        self.erased: list[str] = []
        self.identities: list[str] = []

    def erase_data(self, owner_id: str) -> ErasureReport:
        self.erased.append(owner_id)
        return ErasureReport(rows_deleted={"pet_profiles": 2, "reminders": 3}, files_removed=4)

    def delete_identity(self, owner_id: str) -> None:
        self.identities.append(owner_id)


def _born(years: int) -> date:
    today = NOW.date()
    return today.replace(year=today.year - years)


@pytest.fixture
def team(monkeypatch: pytest.MonkeyPatch) -> tuple[TestClient, _SpyEraser, Callable[[str], None]]:
    container = get_container()
    spy = _SpyEraser()
    monkeypatch.setattr(container, "_build_account_eraser", lambda: spy)
    monkeypatch.setattr(
        "apps.api.routes.admin._configured_admin_emails",
        lambda: frozenset({f"{ADMIN}@example.com"}),
    )
    repository = container.account_age_repository
    for owner, years, declared in (
        (CHILD_OLD, 10, NOW - timedelta(days=45)),
        (CHILD_NEW, 12, NOW - timedelta(days=3)),
        (ADULT, 30, NOW - timedelta(days=100)),
        (MINOR, 16, NOW - timedelta(days=100)),
    ):
        repository.create(AccountAge(owner_id=owner, birth_date=_born(years), declared_at=declared))
    lookup: Any = container.owner_contact_lookup
    lookup.register(CHILD_OLD, OwnerContact(email="mario@example.com", email_confirmed=True))

    def act_as(user_id: str) -> None:
        monkeypatch.setattr(
            container.auth_provider,
            "get_current_user",
            lambda: AuthenticatedUser(id=user_id, email=f"{user_id}@example.com"),
        )

    act_as(ADMIN)
    return TestClient(app), spy, act_as


def _refs(client: TestClient) -> dict[bool, str]:
    """Reference of the old closed account (True) and of the recent one (False)."""
    accounts = client.get("/admin/age/closed").json()["accounts"]
    return {item["past_deadline"]: item["ref"] for item in accounts}


def test_an_ordinary_user_gets_403_on_every_route_and_nothing_is_touched(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, spy, act_as = team
    ref = _refs(client)[True]

    act_as(MINOR)  # a normal owner, whoever they are
    assert client.get("/admin/age/closed").status_code == 403
    assert client.post(f"/admin/age/closed/{ref}/erase", json={"confirm": ref}).status_code == 403
    assert (
        client.post(
            f"/admin/age/closed/{ref}/correct", json={"birth_date": "1990-01-01"}
        ).status_code
        == 403
    )
    assert (
        client.post(
            f"/admin/age/closed/{ref}/correction-requested", json={"requested": True}
        ).status_code
        == 403
    )
    assert spy.erased == []


def test_the_list_has_only_closed_accounts_and_no_id_date_or_full_email(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, _, _ = team
    response = client.get("/admin/age/closed")
    accounts = response.json()["accounts"]

    assert [item["days_closed"] for item in accounts] == [45, 3]  # oldest first
    assert [item["past_deadline"] for item in accounts] == [True, False]
    assert accounts[0]["email_hint"] == "m***@example.com"
    assert accounts[1]["email_hint"] is None
    text = response.text
    for forbidden in (CHILD_OLD, CHILD_NEW, ADULT, MINOR, "mario@", "birth"):
        assert forbidden not in text


def test_erasing_uses_the_account_eraser_and_answers_only_numbers(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, spy, _ = team
    ref = _refs(client)[True]

    wrong = client.post(f"/admin/age/closed/{ref}/erase", json={"confirm": "nope"})
    assert 400 <= wrong.status_code < 500
    assert spy.erased == []

    done = client.post(f"/admin/age/closed/{ref}/erase", json={"confirm": ref})
    assert done.status_code == 200
    assert done.json() == {"erased": True, "outcome": {"rows_deleted": 5, "files_removed": 4}}
    assert spy.erased == [CHILD_OLD] and spy.identities == [CHILD_OLD]


def test_only_a_closed_account_can_be_named_other_owners_cannot(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, spy, _ = team
    service = get_container().age_review_admin_service()
    adult_ref = service.ref_of(ADULT)
    minor_ref = service.ref_of(MINOR)

    for ref in (adult_ref, minor_ref, "made-up"):
        assert (
            client.post(f"/admin/age/closed/{ref}/erase", json={"confirm": ref}).status_code == 404
        )
        assert (
            client.post(
                f"/admin/age/closed/{ref}/correct", json={"birth_date": "2000-01-01"}
            ).status_code
            == 404
        )
    assert spy.erased == []


def test_a_pending_correction_blocks_the_erase_until_it_is_cleared(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, spy, _ = team
    ref = _refs(client)[True]

    noted = client.post(f"/admin/age/closed/{ref}/correction-requested", json={"requested": True})
    assert noted.status_code == 200
    listed = client.get("/admin/age/closed").json()["accounts"]
    assert [item["correction_requested"] for item in listed] == [True, False]

    blocked = client.post(f"/admin/age/closed/{ref}/erase", json={"confirm": ref})
    assert 400 <= blocked.status_code < 500 and spy.erased == []

    client.post(f"/admin/age/closed/{ref}/correction-requested", json={"requested": False})
    assert client.post(f"/admin/age/closed/{ref}/erase", json={"confirm": ref}).status_code == 200


def test_support_corrects_a_mistyped_date_and_the_account_opens_again(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, spy, _ = team
    ref = _refs(client)[True]
    client.post(f"/admin/age/closed/{ref}/correction-requested", json={"requested": True})

    result = client.post(
        f"/admin/age/closed/{ref}/correct", json={"birth_date": _born(20).isoformat()}
    )

    assert result.status_code == 200 and result.json() == {"corrected": True, "band": "adult"}
    remaining = client.get("/admin/age/closed").json()["accounts"]
    assert len(remaining) == 1  # only the recent closed account is left
    record = get_container().account_age_repository.get(CHILD_OLD)
    assert record is not None and record.correction_requested_at is None
    assert spy.erased == []


def test_an_impossible_corrected_date_is_refused(
    team: tuple[TestClient, _SpyEraser, Callable[[str], None]],
) -> None:
    client, _, _ = team
    ref = _refs(client)[True]
    tomorrow = (NOW + timedelta(days=2)).date().isoformat()
    refused = client.post(f"/admin/age/closed/{ref}/correct", json={"birth_date": tomorrow})
    assert 400 <= refused.status_code < 500

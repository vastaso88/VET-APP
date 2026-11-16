"""Deleting an account: deactivated at once, erased when the period ends, and the
owner can cancel until then. Everything acts on the signed-in owner only."""

from collections.abc import Callable, Iterator
from datetime import UTC, date, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.age.models import AccountAge

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"


class _SpyEraser:
    def __init__(self) -> None:
        self.erased: list[str] = []
        self.identities: list[str] = []

    def erase_data(self, owner_id: str) -> ErasureReport:
        self.erased.append(owner_id)
        return ErasureReport(rows_deleted={"pet_profiles": 1}, files_removed=0)

    def delete_identity(self, owner_id: str) -> None:
        self.identities.append(owner_id)


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[Callable[[str], None]]:
    """Who the fake sign-in says the caller is, and an eraser that records."""
    container = get_container()
    spy = _SpyEraser()
    monkeypatch.setattr(container, "_build_account_eraser", lambda: spy)
    monkeypatch.setattr(container, "spy", spy, raising=False)
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    current = {"id": USER_A}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=current["id"], email="owner@example.com"),
    )

    def switch(user_id: str) -> None:
        current["id"] = user_id

    yield switch


def _spy() -> _SpyEraser:
    return get_container().spy  # type: ignore[attr-defined,no-any-return]


def test_delete_account_deactivates_the_owner_and_erases_nothing_yet(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    assert client.get("/pets").status_code == 200

    response = client.delete("/account")

    assert response.status_code == 200
    body = response.json()
    assert body["deleted"] is True and body["scheduled"] is True
    assert body["pending"] is True and body["grace_days"] == 30
    assert datetime.fromisoformat(body["purge_after"]) - datetime.fromisoformat(
        body["requested_at"]
    ) == timedelta(days=30)
    assert _spy().erased == [] and _spy().identities == []

    # From now on nothing of the account works, except reading the status.
    blocked = client.get("/pets")
    assert blocked.status_code == 403 and blocked.json()["code"] == "account_deactivated"
    assert client.get("/account/deletion").json()["pending"] is True


def test_the_period_is_a_setting_not_a_number_in_the_code(
    as_user: Callable[[str], None], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("ACCOUNT_DELETION_GRACE_DAYS", "14")
    from packages.bootstrap.container import reset_container
    from packages.shared.config.settings import reset_settings

    reset_settings()
    reset_container()
    container = get_container()
    monkeypatch.setattr(container, "_build_account_eraser", lambda: _SpyEraser())
    monkeypatch.setattr(
        container.auth_provider._inner,  # type: ignore[attr-defined]
        "get_current_user",
        lambda: AuthenticatedUser(id=USER_A, email="owner@example.com"),
    )

    body = TestClient(app).delete("/account").json()

    assert body["grace_days"] == 14


def test_asking_twice_keeps_the_first_date(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    first = client.delete("/account").json()
    second = client.delete("/account").json()
    assert second["purge_after"] == first["purge_after"]


def test_the_owner_can_cancel_and_everything_works_again(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    client.delete("/account")
    assert client.get("/pets").status_code == 403

    cancelled = client.post("/account/deletion/cancel")

    assert cancelled.status_code == 200 and cancelled.json()["pending"] is False
    assert client.get("/pets").status_code == 200
    assert _spy().erased == []


def test_a_stale_sign_in_can_neither_delete_nor_cancel(
    as_user: Callable[[str], None], monkeypatch: pytest.MonkeyPatch
) -> None:
    client = TestClient(app)
    container = get_container()
    stale = datetime.now(UTC) - timedelta(hours=1)
    monkeypatch.setattr(container.auth_provider, "last_sign_in_at", lambda: stale)

    # The app reads 401 as "ask for the password again" (reauth_required).
    assert client.delete("/account").status_code == 401
    assert client.get("/pets").status_code == 200  # nothing was deactivated

    monkeypatch.undo()
    as_user(USER_A)


def test_one_owner_deleting_does_not_touch_another(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    client.delete("/account")  # user A

    as_user(USER_B)
    assert client.get("/pets").status_code == 200
    assert client.get("/account/deletion").json()["pending"] is False
    # B cannot cancel A's deletion: the route acts on B's own id only.
    assert client.post("/account/deletion/cancel").json()["pending"] is False

    as_user(USER_A)
    assert client.get("/account/deletion").json()["pending"] is True


def test_the_route_takes_no_owner_id_from_the_caller(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    # There is no path or query parameter that could name another account.
    assert client.delete("/account/someone-else").status_code in (404, 405)


def test_an_account_closed_for_age_is_erased_at_once_without_waiting(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    today = datetime.now(UTC).date()
    get_container().account_age_repository.create(
        AccountAge(
            owner_id=USER_A,
            birth_date=date(today.year - 10, 1, 1),
            declared_at=datetime.now(UTC),
        )
    )

    response = client.delete("/account")

    assert response.status_code == 200
    body = response.json()
    assert body["scheduled"] is False and "report" in body
    assert _spy().erased == [USER_A] and _spy().identities == [USER_A]


def test_delete_now_erases_at_once_even_while_waiting_and_clears_the_request(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    client.delete("/account")  # deactivated, waiting
    assert _spy().erased == []

    response = client.delete("/account?immediate=true")

    assert response.status_code == 200
    assert response.json()["scheduled"] is False
    assert _spy().erased == [USER_A] and _spy().identities == [USER_A]
    assert get_container().account_deletion_repository.get(USER_A) is None


def test_delete_now_needs_a_recent_sign_in_too(
    as_user: Callable[[str], None], monkeypatch: pytest.MonkeyPatch
) -> None:
    client = TestClient(app)
    container = get_container()
    stale = datetime.now(UTC) - timedelta(hours=1)
    monkeypatch.setattr(container.auth_provider, "last_sign_in_at", lambda: stale)

    assert client.delete("/account?immediate=true").status_code == 401
    assert _spy().erased == []

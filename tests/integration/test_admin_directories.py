"""QK-07: the admin users/pets directories are paged at the source.

Synthetic data only. `Directories` is a stand-in for the database that (a) caps every
plain table read at the provider window (1000 rows, like PostgREST) and (b) answers the
two `rpc` functions with a Python reference of supabase/migrations/
20261122100000_admin_directories.sql. It counts every row sent to the API, so the tests
show what crosses the wire. The SQL itself is exercised by tests/sql/admin_directories.mjs
(embedded Postgres); here only the routes and their contract are tested."""

import logging
from collections import Counter
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import Any
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.infrastructure.admin import user_reports as reports

WINDOW = 1000  # rows the provider returns per plain read
N_USERS = 2500
N_PETS = 1500
BASE = datetime(2026, 1, 1, tzinfo=UTC)
COUNTRIES = ["IT", "ES", "FR", None]  # None: no residence country -> "unknown"

# What the app stores in `species` (its Italian labels) and, written out here on purpose and
# not computed with the code under test, the group and "exotic" the panel must show (QK-07d).
SPECIES = [
    "Cane",
    "Gatto",
    "Piccoli mammiferi",
    "Uccello",
    "Rettili e anfibi",
    "Pesce",
    "Altro",
]
GROUP = {
    "Cane": ("dog", False),
    "Gatto": ("cat", False),
    "Piccoli mammiferi": ("small_mammal", True),
    "Uccello": ("bird", True),
    "Rettili e anfibi": ("reptile_amphibian", True),
    "Pesce": ("fish", True),
    "Altro": ("other", True),
}


def _user(index: int) -> dict[str, Any]:
    return {
        "id": f"u{index:05d}",
        "email": f"Person{index}@example.com",
        "created_at": (BASE + timedelta(minutes=index // 2)).isoformat(),  # ties on purpose
        "last_sign_in_at": None,
        "email_confirmed_at": BASE.isoformat(),
        "banned_until": None,
    }


def _location(index: int) -> dict[str, Any]:
    return {
        "owner_id": f"u{index:05d}",
        "home_country_code": COUNTRIES[index % 4],
        "home_city": f"Example city {index % 7}",
        "home_saved_at": None,
    }


def _pet(index: int) -> dict[str, Any]:
    species = SPECIES[index % 7]
    # Only the columns the app writes: the panel's three look-alike columns are not here.
    return {
        "id": f"p{index:05d}",
        "owner_id": f"u{index % N_USERS:05d}",
        "name": f"Pet{(index * 7) % N_PETS:05d}",  # not in id order, unique names
        "species": species,
        "breed": f"Breed{index % 11}",
        "is_memorial": index % 10 == 0,
    }


class _Rpc:
    def __init__(self, data: Any) -> None:
        self._data = data

    def execute(self) -> SimpleNamespace:
        return SimpleNamespace(data=self._data)


class _Table:
    def __init__(self, owner: "Directories", name: str) -> None:
        self.owner, self.name = owner, name
        self._in: tuple[str, list[str]] | None = None
        self._range: tuple[int, int] | None = None

    def select(self, *_: Any) -> "_Table":
        return self

    def order(self, *_: Any, **__: Any) -> "_Table":
        return self

    def range(self, start: int, end: int) -> "_Table":
        self._range = (start, end)
        return self

    def in_(self, column: str, values: list[str]) -> "_Table":
        self._in = (column, values)
        return self

    def execute(self) -> SimpleNamespace:
        rows = (
            self.owner.pets if self.name == "pet_profiles" else self.owner.tables.get(self.name, [])
        )
        if self._in:
            column, values = self._in
            rows = [row for row in rows if row[column] in values]
        if self._range is not None:
            rows = rows[self._range[0] : self._range[1] + 1]
        rows = rows[:WINDOW]  # the provider window
        self.owner.transferred += len(rows)
        return SimpleNamespace(data=[dict(row) for row in rows])


class Directories:
    def __init__(self) -> None:
        self.users = [_user(i) for i in range(N_USERS)]
        self.locations = {f"u{i:05d}": _location(i) for i in range(N_USERS)}
        self.pets = [_pet(i) for i in range(N_PETS)]
        self.tables: dict[str, list[dict[str, Any]]] = {
            "subscriptions": [],
            "user_locations": list(self.locations.values()),
        }
        self.transferred = 0
        self.rpc_calls: list[tuple[str, dict[str, Any]]] = []
        # The new path never lists Auth users; the old one (fallback) does, in pages.
        self.auth = Mock()
        self.auth.admin.list_users.side_effect = self._list_auth_users
        self.fail_with: Exception | None = None
        self.reply: Any = None  # force a malformed reply

    def _list_auth_users(self, page: int, per_page: int) -> list[SimpleNamespace]:
        chunk = self.users[(page - 1) * per_page : page * per_page]
        self.transferred += len(chunk)
        return [SimpleNamespace(**user) for user in chunk]

    def table(self, name: str) -> _Table:
        return _Table(self, name)

    def rpc(self, function: str, params: dict[str, Any]) -> _Rpc:
        self.rpc_calls.append((function, params))
        if self.fail_with is not None:
            raise self.fail_with
        data = self.reply if self.reply is not None else getattr(self, f"_{function}")(**params)
        if isinstance(data, dict):
            self.transferred += len(data.get("rows", []))
            self.transferred += len(data.get("countries", {}))
        return _Rpc(data)

    # -- Python reference of admin_users_directory
    def _admin_users_directory(
        self, p_q: str, p_country: str, p_page: int, p_page_size: int
    ) -> dict[str, Any]:
        size = min(max(p_page_size, 1), 100)
        needle = p_q.strip().lower()

        def bucket(user: dict[str, Any]) -> str:
            return self.locations[user["id"]]["home_country_code"] or "unknown"

        scope = [
            u for u in self.users if not needle or needle in u["email"].lower() or needle in u["id"]
        ]
        counts = Counter(bucket(u) for u in scope)
        picked = [u for u in scope if not p_country or bucket(u) == p_country]
        picked.sort(key=lambda u: (u["created_at"], u["id"]), reverse=True)
        pages = max(1, -(-len(picked) // size))
        page = min(max(p_page, 1), pages)
        rows = []
        for user in picked[(page - 1) * size : page * size]:
            place = self.locations[user["id"]]
            rows.append(
                {
                    **user,
                    "home_country_code": place["home_country_code"],
                    "home_city": place["home_city"],
                    "home_saved_at": place["home_saved_at"],
                }
            )
        return {
            "total": len(picked),
            "page": page,
            "page_size": size,
            "countries": dict(counts),
            "rows": rows,
        }

    # -- Python reference of admin_pets_directory
    def _admin_pets_directory(
        self,
        p_q: str,
        p_species: str,
        p_status: str,
        p_country: str,
        p_region: str,
        p_page: int,
        p_page_size: int,
    ) -> dict[str, Any]:
        size = min(max(p_page_size, 1), 100)
        needle = p_q.strip().lower()
        rows = []
        for pet in self.pets:
            place = self.locations[pet["owner_id"]]
            country, city = place["home_country_code"], place["home_city"]
            group, exotic = GROUP[pet["species"]]
            row = {
                **pet,
                "species_group": group,
                "is_exotic": exotic,
                "is_active": not pet["is_memorial"],
                "country": country,
                "city": city,
                "region": None,
            }
            haystack = (pet["name"], pet["id"], pet["owner_id"], pet["breed"])
            if needle and not any(needle in str(value).lower() for value in haystack):
                continue
            if p_country and (country or "").upper() != p_country.upper():
                continue
            if p_region and p_region.lower() not in (city or "").lower():
                continue
            if p_species and group != p_species:
                continue
            wanted = {
                "active": row["is_active"],
                "inactive": not row["is_active"],
                "exotic": exotic,
                "memorial": pet["is_memorial"],
            }
            if p_status and not wanted[p_status]:
                continue
            rows.append(row)
        rows.sort(key=lambda r: (r["name"].lower(), r["id"]))
        pages = max(1, -(-len(rows) // size))
        page = min(max(p_page, 1), pages)
        return {
            "total": len(rows),
            "page": page,
            "page_size": size,
            "rows": rows[(page - 1) * size : page * size],
        }


class _ApiError(Exception):
    """What the Supabase client raises for a failed call: a code (and maybe a status)."""

    def __init__(self, code: str = "", status: int | None = None) -> None:
        super().__init__("provider detail with person@example.com")
        self.code = code
        self.status = status


@pytest.fixture(autouse=True)
def _forget_missing_functions() -> None:
    reports._MISSING_FUNCTIONS.clear()


@pytest.fixture
def portal(monkeypatch: pytest.MonkeyPatch) -> tuple[TestClient, Directories]:
    monkeypatch.setattr(
        "apps.api.routes.admin_common._configured_admin_emails",
        lambda: frozenset({"admin@example.com"}),
    )
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(id="admin", email="admin@example.com", email_verified=True),
    )
    database = Directories()
    monkeypatch.setattr("apps.api.routes.admin_users._admin_client", lambda: database)
    monkeypatch.setattr("apps.api.routes.admin_pets._admin_client", lambda: database)
    return TestClient(app), database


# ------------------------------------------------------------------ users


def test_a_record_in_the_last_page_beyond_the_provider_window_is_found(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, database = portal
    # Searching: the 2,500th account is far past the 1,000-row window.
    body = browser.get("/admin/users", params={"q": "person0@example"}).json()
    assert body["total"] == 1 and body["users"][0]["id"] == "u00000"
    # Browsing: the oldest account sits on page 25 of 25 (100 per page).
    body = browser.get("/admin/users", params={"page": 25, "page_size": 100}).json()
    assert body["page"] == 25 and body["total"] == N_USERS
    assert "u00000" in [user["id"] for user in body["users"]]
    database.auth.admin.list_users.assert_not_called()


def test_no_row_is_repeated_or_lost_between_pages(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, _ = portal
    seen: list[str] = []
    for page in range(1, 26):
        body = browser.get("/admin/users", params={"page": page, "page_size": 100}).json()
        seen += [user["id"] for user in body["users"]]
    assert len(seen) == N_USERS and len(set(seen)) == N_USERS
    # Same newest-first order with the id as tie-breaker (created_at has ties).
    assert seen == [
        u["id"]
        for u in sorted(Directories().users, key=lambda u: (u["created_at"], u["id"]), reverse=True)
    ]


def test_totals_and_country_counts_are_exact_and_the_filter_is_global(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, _ = portal
    expected = Counter(c or "unknown" for c in (COUNTRIES[i % 4] for i in range(N_USERS)))
    body = browser.get("/admin/users", params={"country": "FR", "page_size": 10}).json()
    assert body["total"] == expected["FR"] == 625
    # The counts ignore the country filter, so the other countries stay visible.
    assert body["countries"] == dict(sorted(expected.items()))
    assert all(user["location"]["country_code"] == "FR" for user in body["users"])
    unknown = browser.get("/admin/users", params={"country": "unknown"}).json()
    assert unknown["total"] == expected["unknown"]
    assert all(user["location"] is not None for user in unknown["users"])  # city is set
    narrowed = browser.get("/admin/users", params={"q": "PERSON12"}).json()
    assert narrowed["total"] == sum(narrowed["countries"].values()) == 111


def test_a_page_past_the_end_is_the_last_page(portal: tuple[TestClient, Directories]) -> None:
    browser, _ = portal
    body = browser.get("/admin/users", params={"page": 2000, "page_size": 100}).json()
    assert body["page"] == 25 and len(body["users"]) == 100


def test_users_cross_the_wire_one_page_not_every_account(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, database = portal
    browser.get("/admin/users", params={"page": 1, "page_size": 50})
    # Before QK-07 the same request moved 5,000 rows (2,500 Auth users + 2,500 locations).
    # Now: 50 accounts + at most 4 country buckets (no subscriptions in this dataset).
    assert database.transferred <= 54
    assert [call[0] for call in database.rpc_calls] == ["admin_users_directory"]


def test_the_directory_parameters_are_passed_not_interpolated(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, database = portal
    browser.get("/admin/users", params={"q": "  a%_'; drop  ", "country": "IT", "page": 3})
    function, params = database.rpc_calls[-1]
    assert function == "admin_users_directory"
    assert params == {"p_q": "a%_'; drop", "p_country": "IT", "p_page": 3, "p_page_size": 50}


@pytest.mark.parametrize("path", ["/admin/users", "/admin/pets"])
@pytest.mark.parametrize("verified", [True, False])
def test_an_ordinary_account_is_refused_and_the_database_is_not_asked(
    portal: tuple[TestClient, Directories],
    monkeypatch: pytest.MonkeyPatch,
    path: str,
    verified: bool,
) -> None:
    browser, database = portal
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(id="b", email="b@example.com", email_verified=verified),
    )
    assert browser.get(path).status_code == 403
    assert database.rpc_calls == [] and database.transferred == 0


@pytest.mark.parametrize("path", ["/admin/users", "/admin/pets"])
def test_a_failing_or_malformed_directory_is_unavailable_not_empty_and_leaks_nothing(
    portal: tuple[TestClient, Directories], path: str
) -> None:
    browser, database = portal
    database.fail_with = RuntimeError("password=secret person@example.com")
    response = browser.get(path)
    assert response.status_code == 503
    assert "secret" not in response.text and "person@example.com" not in response.text
    database.fail_with = None
    database.reply = {"total": 0}  # no rows list: not a page
    assert browser.get(path).status_code == 503


# ------------------------------------------------------------------- pets


def test_the_last_pet_beyond_the_provider_window_is_found_and_totals_are_complete(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, database = portal
    # Before QK-07: one unpaged read cut at 1,000 rows, so this search said total 0 and an
    # unfiltered list said 1,000 pets of 1,500.
    body = browser.get("/admin/pets", params={"q": "Pet01499"}).json()
    assert body["total"] == 1 and body["pets"][0]["name"] == "Pet01499"
    assert browser.get("/admin/pets").json()["total"] == N_PETS
    assert database.transferred <= 1 + 50  # one pet, then one page of 50


def test_pet_pages_have_no_repeats_and_are_ordered_by_name_then_id(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, _ = portal
    names: list[str] = []
    ids: list[str] = []
    for page in range(1, 16):
        body = browser.get("/admin/pets", params={"page": page, "page_size": 100}).json()
        names += [pet["name"] for pet in body["pets"]]
        ids += [pet["id"] for pet in body["pets"]]
    assert len(ids) == N_PETS and len(set(ids)) == N_PETS
    assert names == sorted(names)


@pytest.mark.parametrize(
    ("params", "check"),
    [
        ({"species": "dog"}, lambda p: p["species"] == "Cane" and p["species_group"] == "dog"),
        ({"species": "small_mammal"}, lambda p: p["species"] == "Piccoli mammiferi"),
        ({"species": "other"}, lambda p: p["species"] == "Altro"),
        ({"status": "active"}, lambda p: p["is_active"] is True and p["is_memorial"] is False),
        ({"status": "memorial"}, lambda p: p["is_memorial"] is True),
        ({"status": "inactive"}, lambda p: p["is_active"] is False and p["is_memorial"] is True),
        ({"status": "exotic"}, lambda p: p["is_exotic"] is True and p["species"] != "Cane"),
        ({"country": "es"}, lambda p: p["country"] == "ES"),
        ({"region": "city 3"}, lambda p: "city 3" in p["city"].lower()),
    ],
)
def test_pet_filters_are_exact_over_the_whole_directory(
    portal: tuple[TestClient, Directories], params: dict[str, str], check: Any
) -> None:
    browser, database = portal
    expected = database._admin_pets_directory(
        "",
        params.get("species", ""),
        params.get("status", ""),
        params.get("country", ""),
        params.get("region", ""),
        1,
        100,
    )["total"]
    seen = 0
    page = 1
    while True:
        body = browser.get("/admin/pets", params={**params, "page": page, "page_size": 100}).json()
        assert body["total"] == expected and 0 < expected < N_PETS
        assert all(check(pet) for pet in body["pets"])
        seen += len(body["pets"])
        if seen >= expected:
            break
        page += 1
    assert seen == expected


def test_pet_rows_keep_their_shape_and_carry_no_medical_fields(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, _ = portal
    pet = browser.get("/admin/pets", params={"page_size": 1}).json()["pets"][0]
    assert set(pet) == {
        "id",
        "owner_id",
        "name",
        "species",
        "species_group",
        "breed",
        "is_active",
        "is_exotic",
        "is_memorial",
        "country",
        "region",
        "city",
    }
    assert pet["region"] is None


# ------------------------------------------------- temporary fallback (no function yet)

MISSING = [
    pytest.param(_ApiError("PGRST202"), id="PGRST202"),
    pytest.param(_ApiError("42883"), id="42883"),
    pytest.param(_ApiError(status=404), id="http-404"),
]
USER_QUERIES = [
    {},
    {"page": 7, "page_size": 100},
    {"country": "FR", "page_size": 40},
    {"country": "unknown", "page": 3, "page_size": 25},
    {"q": "PERSON12", "page_size": 100},
    {"q": "person0@example"},
    {"page": 2000, "page_size": 100},
]


def _users_page(browser: TestClient, params: dict[str, Any]) -> dict[str, Any]:
    response = browser.get("/admin/users", params=params)
    assert response.status_code == 200
    body: dict[str, Any] = response.json()
    return body


@pytest.mark.parametrize("error", MISSING)
@pytest.mark.parametrize("params", USER_QUERIES)
def test_without_the_users_function_the_old_logic_gives_the_same_pages(
    portal: tuple[TestClient, Directories], error: Exception, params: dict[str, Any]
) -> None:
    browser, database = portal
    with_function = _users_page(browser, params)
    reports._MISSING_FUNCTIONS.clear()
    database.fail_with = error
    without_function = _users_page(browser, params)
    assert without_function == with_function
    database.auth.admin.list_users.assert_called()  # it really took the old road


@pytest.mark.parametrize("error", MISSING)
def test_without_the_pets_function_the_old_logic_gives_the_same_pages(
    portal: tuple[TestClient, Directories], error: Exception
) -> None:
    browser, database = portal
    database.pets = database.pets[:900]  # the old read is cut at 1,000 rows: stay below
    queries: list[dict[str, Any]] = [
        {},
        {"page": 4, "page_size": 100},
        {"q": "pet00899"},
        {"species": "dog"},
        {"status": "memorial"},
        {"status": "inactive", "page_size": 100},
        {"country": "es"},
        {"region": "city 3", "page": 2, "page_size": 20},
        {"page": 2000},
    ]
    for params in queries:
        reports._MISSING_FUNCTIONS.clear()
        database.fail_with = None
        expected = browser.get("/admin/pets", params=params).json()
        reports._MISSING_FUNCTIONS.clear()
        database.fail_with = error
        assert browser.get("/admin/pets", params=params).json() == expected


def test_the_old_pets_read_keeps_its_old_limit_it_is_only_a_stop_gap(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, database = portal
    database.fail_with = _ApiError("PGRST202")
    assert browser.get("/admin/pets").json()["total"] == WINDOW  # of 1,500: as before QK-07


def test_a_missing_function_is_remembered_and_logged_without_personal_data(
    portal: tuple[TestClient, Directories], caplog: pytest.LogCaptureFixture
) -> None:
    browser, database = portal
    database.fail_with = _ApiError("PGRST202")
    with caplog.at_level(logging.WARNING, logger=reports.__name__):
        _users_page(browser, {})
        _users_page(browser, {"page": 2})
        browser.get("/admin/pets")
    # One attempt per function for the whole process, not one per request.
    assert [call[0] for call in database.rpc_calls] == [
        "admin_users_directory",
        "admin_pets_directory",
    ]
    warnings = [r.getMessage() for r in caplog.records if r.levelno == logging.WARNING]
    assert len(warnings) == 2
    assert all("admin_" in message and "20261122100000" in message for message in warnings)
    assert all("example.com" not in message for message in warnings)


@pytest.mark.parametrize("path", ["/admin/users", "/admin/pets"])
@pytest.mark.parametrize(
    "error", [_ApiError("42501"), _ApiError("PGRST301"), _ApiError(status=500), RuntimeError("x")]
)
def test_any_other_error_stays_a_503_and_is_not_remembered_as_missing(
    portal: tuple[TestClient, Directories], path: str, error: Exception
) -> None:
    browser, database = portal
    database.fail_with = error
    assert browser.get(path).status_code == 503
    assert reports._MISSING_FUNCTIONS == set()
    assert browser.get(path).status_code == 503
    assert len(database.rpc_calls) == 2  # asked again: a real failure is never cached
    database.auth.admin.list_users.assert_not_called()  # and the old road was not taken


@pytest.mark.parametrize("path", ["/admin/users", "/admin/pets"])
def test_a_failing_old_road_is_a_503_too_never_an_empty_list(
    portal: tuple[TestClient, Directories], path: str
) -> None:
    browser, database = portal
    database.fail_with = _ApiError("PGRST202")
    database.auth.admin.list_users.side_effect = RuntimeError("person@example.com")
    database.table = Mock(side_effect=RuntimeError("person@example.com"))  # type: ignore[method-assign]
    response = browser.get(path)
    assert response.status_code == 503 and "example.com" not in response.text


def test_with_the_function_present_the_new_road_is_taken(
    portal: tuple[TestClient, Directories],
) -> None:
    browser, database = portal
    _users_page(browser, {})
    browser.get("/admin/pets")
    assert [call[0] for call in database.rpc_calls] == [
        "admin_users_directory",
        "admin_pets_directory",
    ]
    database.auth.admin.list_users.assert_not_called()
    assert reports._MISSING_FUNCTIONS == set()


# ------------------------------------------------------------------ SQL file

MIGRATION = Path("supabase/migrations/20261122100000_admin_directories.sql")


def test_the_migration_is_read_only_idempotent_and_closed_to_everyone_but_the_api() -> None:
    sql = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
    assert "create table" not in sql
    # the only drop is the earlier draft of admin_species_bucket (two arguments)
    assert sql.count("drop ") == 1
    assert "drop function if exists public.admin_species_bucket(text, text);" in sql
    assert "insert " not in sql and "update " not in sql and "delete " not in sql
    functions = [
        "admin_users_directory(text, text, integer, integer)",
        "admin_species_bucket(text)",
        "admin_pets_scope(text, text, text, text, text)",
        "admin_pets_directory(text, text, text, text, text, integer, integer)",
    ]
    for signature in functions:
        assert f"create or replace function public.{signature.split('(')[0]}(" in sql
        assert f"revoke all on function public.{signature} from public, anon, authenticated;" in sql
        assert f"grant execute on function public.{signature} to service_role;" in sql
    # Only the users directory needs to read auth.users: only it is SECURITY DEFINER.
    assert sql.count("security definer set search_path") == 1
    assert sql.count("set search_path = ''") == 4

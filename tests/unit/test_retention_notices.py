"""Which e-mail an account would get before its data is erased, and what the
commercial one may quote (docs/compliance/12_avvisi_prima_della_cancellazione.md)."""

from __future__ import annotations

from datetime import date

import pytest

from packages.core.domain.subscription.retention import NOTICE_DAYS
from packages.core.domain.subscription.retention_notices import (
    COMMERCIAL,
    COMMERCIAL_CITES,
    SERVICE,
    AccountDataCounts,
    is_adult,
    plan_notice,
)
from packages.infrastructure.persistence.supabase.supabase_owner_contact_lookup import (
    _declared_birth_date,
)

RICH = AccountDataCounts(animals=2, documents=5, reminders=3)
EMPTY = AccountDataCounts(animals=0, documents=0, reminders=0)


def test_adult_on_the_eighteenth_birthday_and_not_the_day_before() -> None:
    assert is_adult(date(2008, 6, 1), date(2026, 6, 1)) is True
    assert is_adult(date(2008, 6, 2), date(2026, 6, 1)) is False


def test_a_leap_day_birthday_is_handled() -> None:
    assert is_adult(date(2008, 2, 29), date(2026, 2, 28)) is False
    assert is_adult(date(2008, 2, 29), date(2026, 3, 1)) is True


def test_no_date_of_birth_means_age_unknown_not_adult() -> None:
    assert is_adult(None, date(2026, 6, 1)) is None


@pytest.mark.parametrize("day", NOTICE_DAYS)
def test_without_a_consent_every_notice_is_the_service_one(day: int) -> None:
    plan = plan_notice(day, marketing_consent=False, adult=True, counts=RICH)

    assert plan.variant == SERVICE
    assert plan.cites == []
    assert plan.minor_note is False


@pytest.mark.parametrize("adult", [None, False])
def test_a_consent_alone_is_not_enough_without_a_declared_adult(adult: bool | None) -> None:
    plan = plan_notice(30, marketing_consent=True, adult=adult, counts=RICH)

    assert plan.variant == SERVICE
    assert plan.minor_note is (adult is False)


def test_the_commercial_notice_quotes_each_kind_the_account_really_has() -> None:
    plan = plan_notice(106, marketing_consent=True, adult=True, counts=RICH)

    assert plan.variant == COMMERCIAL
    assert plan.cites == ["animals", "documents", "reminders"]
    assert plan.nothing_to_cite is False


def test_a_kind_with_zero_is_dropped_from_the_text() -> None:
    counts = AccountDataCounts(animals=1, documents=0, reminders=2)

    plan = plan_notice(30, marketing_consent=True, adult=True, counts=counts)

    assert plan.cites == ["animals", "reminders"]


def test_an_empty_account_or_unknown_counts_quote_nothing() -> None:
    for counts in (EMPTY, None):
        plan = plan_notice(106, marketing_consent=True, adult=True, counts=counts)

        assert plan.variant == COMMERCIAL
        assert plan.cites == []
        assert plan.nothing_to_cite is True


def test_every_notice_day_of_the_calendar_has_a_text_to_quote() -> None:
    assert set(COMMERCIAL_CITES) == set(NOTICE_DAYS)


def test_only_the_two_notices_that_quote_counts_ask_for_them() -> None:
    with_counts = {
        day: [kind for kind in kinds if kind != "animals"]
        for day, kinds in COMMERCIAL_CITES.items()
    }

    assert {day for day, kinds in with_counts.items() if kinds} == {30, 106}


@pytest.mark.parametrize(
    ("metadata", "expected"),
    [
        ({"birth_date": "1990-05-20"}, date(1990, 5, 20)),
        ({"birth_date": "1990-05-20T00:00:00Z"}, date(1990, 5, 20)),
        ({"birth_date": "not a date"}, None),
        ({"birth_date": 1990}, None),
        ({}, None),
        (None, None),
        ("birth_date", None),
    ],
)
def test_the_declared_birth_date_is_read_leniently_and_never_fails(
    metadata: object, expected: date | None
) -> None:
    assert _declared_birth_date(metadata) == expected

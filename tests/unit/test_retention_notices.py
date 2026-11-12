"""Which e-mail an account would get before its data is erased, and what the
commercial one may quote (docs/compliance/12_avvisi_prima_della_cancellazione.md)."""

from __future__ import annotations

import pytest

from packages.core.domain.age.models import AgeBand
from packages.core.domain.subscription.retention import NOTICE_DAYS
from packages.core.domain.subscription.retention_notices import (
    COMMERCIAL,
    CONTENT_KINDS,
    COUNT_CITES,
    NO_NOTICE,
    SERVICE,
    AccountDataCounts,
    plan_notice,
)

RICH = AccountDataCounts(animals=2, documents=5, reminders=3, walks=4)
EMPTY = AccountDataCounts(animals=0, documents=0, reminders=0, walks=0)


@pytest.mark.parametrize("day", NOTICE_DAYS)
def test_without_a_consent_every_notice_is_the_service_one(day: int) -> None:
    plan = plan_notice(day, marketing_consent=False, age_band=AgeBand.ADULT, counts=RICH)

    assert plan.variant == SERVICE
    assert plan.contents == []
    assert plan.minor_note is False
    assert plan.nothing_to_cite is False


@pytest.mark.parametrize("band", [AgeBand.UNKNOWN, AgeBand.MINOR])
def test_a_consent_alone_is_not_enough_without_a_declared_adult(band: str) -> None:
    plan = plan_notice(30, marketing_consent=True, age_band=band, counts=RICH)

    assert plan.variant == SERVICE
    assert plan.contents == []


@pytest.mark.parametrize(
    ("band", "note"),
    [
        (AgeBand.MINOR, True),
        (AgeBand.ADULT, False),
        # An unknown age is not declared a minor either.
        (AgeBand.UNKNOWN, False),
    ],
)
def test_only_a_declared_minor_gets_the_parent_authorisation_note(band: str, note: bool) -> None:
    plan = plan_notice(30, marketing_consent=False, age_band=band, counts=RICH)

    assert plan.variant == SERVICE
    assert plan.minor_note is note


@pytest.mark.parametrize("day", NOTICE_DAYS)
@pytest.mark.parametrize("consent", [True, False])
def test_an_account_under_14_gets_no_notice_at_all(day: int, consent: bool) -> None:
    """Closed account, own 30-day procedure: not even the service notice, and
    never the commercial one whatever the consent says."""
    plan = plan_notice(day, marketing_consent=consent, age_band=AgeBand.UNDER_MINIMUM, counts=RICH)

    assert plan.variant == NO_NOTICE
    assert plan.minor_note is False
    assert plan.contents == []
    assert plan.counts_cited == []


# --- {elenco_contenuti} and rule 9 -------------------------------------------


def test_the_contents_list_follows_the_order_of_the_doc() -> None:
    assert CONTENT_KINDS == ("animals", "reminders", "documents", "walks")

    plan = plan_notice(0, marketing_consent=True, age_band=AgeBand.ADULT, counts=RICH)

    assert plan.variant == COMMERCIAL
    assert plan.contents == ["animals", "reminders", "documents", "walks"]


def test_walks_alone_are_enough_to_have_something_true_to_quote() -> None:
    counts = AccountDataCounts(animals=0, documents=0, reminders=0, walks=2)

    plan = plan_notice(0, marketing_consent=True, age_band=AgeBand.ADULT, counts=counts)

    assert plan.variant == COMMERCIAL
    assert plan.contents == ["walks"]


def test_a_kind_with_zero_is_left_out_of_the_list() -> None:
    counts = AccountDataCounts(animals=1, documents=0, reminders=2, walks=0)

    plan = plan_notice(0, marketing_consent=True, age_band=AgeBand.ADULT, counts=counts)

    assert plan.contents == ["animals", "reminders"]


@pytest.mark.parametrize("counts", [EMPTY, None], ids=["empty account", "counts unreadable"])
def test_nothing_true_to_quote_means_the_service_notice(counts: AccountDataCounts | None) -> None:
    """Rule 9: consent and adult age are not enough on their own."""
    plan = plan_notice(106, marketing_consent=True, age_band=AgeBand.ADULT, counts=counts)

    assert plan.variant == SERVICE
    assert plan.contents == []
    assert plan.counts_cited == []
    assert plan.nothing_to_cite is True


def test_the_two_notices_that_quote_counts_cite_only_the_kinds_above_zero() -> None:
    counts = AccountDataCounts(animals=2, documents=0, reminders=3, walks=1)

    day_30 = plan_notice(30, marketing_consent=True, age_band=AgeBand.ADULT, counts=counts)
    day_106 = plan_notice(106, marketing_consent=True, age_band=AgeBand.ADULT, counts=counts)
    day_60 = plan_notice(60, marketing_consent=True, age_band=AgeBand.ADULT, counts=counts)

    assert day_30.counts_cited == ["reminders"]
    assert day_106.counts_cited == ["animals", "reminders"]
    assert day_60.counts_cited == []


def test_only_notices_e2_and_e5_quote_counts() -> None:
    assert set(COUNT_CITES) == {30, 106}
    assert set(COUNT_CITES) <= set(NOTICE_DAYS)

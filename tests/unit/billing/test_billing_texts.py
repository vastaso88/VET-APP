"""The billing texts reviewed on 25 November 2026 are the ones the app and the store pages show,
and the limits written in them are the ones the server enforces."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from packages.core.domain.subscription.limits import LIMITS_BY_PLAN
from packages.core.domain.subscription.models import SubscriptionPlan

ROOT = Path(__file__).parents[3]
REVIEWED: dict[str, dict[str, str]] = json.loads(
    (ROOT / "tests" / "fixtures" / "billing_texts_2026_11_25.json").read_text(encoding="utf-8")
)
LANGUAGES = ["it", "en", "es", "de", "fr"]
L10N = ROOT / "apps" / "mobile_app" / "lib" / "l10n"


def _arb(language: str) -> dict[str, str]:
    strings: dict[str, str] = json.loads((L10N / f"app_{language}.arb").read_text(encoding="utf-8"))
    return strings


@pytest.mark.parametrize("language", LANGUAGES)
@pytest.mark.parametrize(
    "key",
    [
        "renewMonthly",
        "renewYearly",
        "renewCancelLine",
        "subscribeButton",
        "cancelButton",
        "cancelButtonNote",
    ],
)
def test_the_app_s_strings_are_the_reviewed_ones(key: str, language: str) -> None:
    assert _arb(language)[key] == REVIEWED[key][language]


@pytest.mark.parametrize("language", LANGUAGES)
@pytest.mark.parametrize(
    ("key", "plan"),
    [("planLimitsPro", SubscriptionPlan.PRO), ("planLimitsUltra", SubscriptionPlan.ULTRA)],
)
def test_the_limits_line_is_the_reviewed_one_with_the_server_s_numbers(
    key: str, plan: str, language: str
) -> None:
    """The numbers are never written in the app: the reviewed words, filled with the numbers the
    server enforces today, are the reviewed line. If a limit changes, this says which texts and
    documents still show the old number."""
    limits = LIMITS_BY_PLAN[plan]
    template = _arb(language)[key]
    assert not any(character.isdigit() for character in template)
    line = template.format(
        perChat=limits.daily_questions_per_chat,
        perDay=limits.daily_questions,
        devices=limits.max_devices,
    )
    assert line == REVIEWED[key][language]


def test_plus_has_no_limit_per_chat() -> None:
    assert LIMITS_BY_PLAN[SubscriptionPlan.PLUS].daily_questions_per_chat is None


@pytest.mark.parametrize(
    ("listing", "language"),
    [
        ("it", "it"),
        ("en-GB", "en"),
        ("en-US", "en"),
        ("en-AU", "en"),
        ("es", "es"),
        ("de", "de"),
        ("fr", "fr"),
    ],
)
def test_the_store_pages_say_that_the_plan_renews(listing: str, language: str) -> None:
    page = (ROOT / "docs" / "store" / "listings" / f"{listing}.md").read_text(encoding="utf-8")
    # One for the App Store, one for Google Play.
    assert page.splitlines().count(REVIEWED["storeListingRenewalLine"][language]) == 2

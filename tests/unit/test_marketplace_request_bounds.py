"""What an ad's request may carry (round 1 of the test network, K20 and K21)."""

from __future__ import annotations

from typing import Any, get_args

import pytest
from pydantic import ValidationError

from apps.api.routes.marketplace import ListingPayload
from packages.core.domain.marketplace.models import (
    LISTING_MAX_PRICE_CENTS,
    ListingCategory,
    PublishableCategory,
)

POSTGRES_INTEGER_MAX = 2_147_483_647


def _payload(**changes: Any) -> dict[str, Any]:
    return {
        "title": "Cuccia",
        "category": "kennels_carriers",
        "condition": "good",
        "latitude": 45.0,
        "longitude": 9.0,
        **changes,
    }


def test_every_current_category_is_accepted_and_every_legacy_one_is_a_bad_request() -> None:
    for category in get_args(PublishableCategory):
        assert ListingPayload(**_payload(category=category)).category == category
    legacy = set(get_args(ListingCategory)) - set(get_args(PublishableCategory))
    assert legacy == {
        "food",
        "accessories",
        "health_wellness",
        "transport_carriers",
        "grooming",
    }
    for category in legacy:
        with pytest.raises(ValidationError):
            ListingPayload(**_payload(category=category))


def test_the_price_has_a_ceiling_the_column_can_hold() -> None:
    assert LISTING_MAX_PRICE_CENTS < POSTGRES_INTEGER_MAX
    assert ListingPayload(**_payload(price_cents=LISTING_MAX_PRICE_CENTS)).price_cents
    for price in (0, LISTING_MAX_PRICE_CENTS + 1, POSTGRES_INTEGER_MAX + 1):
        with pytest.raises(ValidationError):
            ListingPayload(**_payload(price_cents=price))


def test_the_species_list_has_an_end() -> None:
    with pytest.raises(ValidationError):
        ListingPayload(**_payload(target_species=["dog"] * 50))

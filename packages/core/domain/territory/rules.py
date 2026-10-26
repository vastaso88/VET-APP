"""Per-country rules, in ONE table.

What depends on the country the owner lives in (currency, whether the
Mercatino may carry ads for living animals, the largest search radius) is a
row here, never an ``if country == ...`` somewhere else. The Flutter app has
the same table in ``features/territory/domain/territory.dart``; the tests on
both sides pin the same values, so a change made on one side only fails there.

The country is the one of the language variant the owner picked in the app
(IT, GB, US, AU, DE, FR, ES); AT, CH and BE are listed because their legal
rules are already written (docs/compliance/at|ch|be).
"""

from __future__ import annotations

from dataclasses import dataclass

# Mercatino search radius, in whole kilometres: 1 to 300 (owner decision
# 2026-10-26, default 50 in the app). Miles are only a display unit, the app
# always sends km. 30 miles (48.3 km) fits inside. There is no "everywhere".
MARKETPLACE_MIN_RADIUS_KM = 1.0
MARKETPLACE_MAX_RADIUS_KM = 300.0

SOURCE_COUNTRY = "IT"


@dataclass(frozen=True)
class TerritoryRules:
    country: str
    currency_code: str
    currency_symbol: str


_RULES: dict[str, TerritoryRules] = {
    rules.country: rules
    for rules in (
        TerritoryRules("IT", "EUR", "€"),
        TerritoryRules("GB", "GBP", "£"),
        TerritoryRules("US", "USD", "$"),
        TerritoryRules("AU", "AUD", "A$"),
        TerritoryRules("DE", "EUR", "€"),
        TerritoryRules("AT", "EUR", "€"),
        TerritoryRules("CH", "CHF", "CHF"),
        TerritoryRules("FR", "EUR", "€"),
        TerritoryRules("BE", "EUR", "€"),
        TerritoryRules("ES", "EUR", "€"),
    )
}

KNOWN_COUNTRIES: frozenset[str] = frozenset(_RULES)


def normalize_country(country: str | None) -> str:
    return (country or "").strip().upper()


def is_known_country(country: str | None) -> bool:
    return normalize_country(country) in _RULES


def rules_for(country: str | None) -> TerritoryRules:
    """The rules of ``country``; an unknown or missing one gets the source
    country's, never a guess from another."""
    return _RULES.get(normalize_country(country), _RULES[SOURCE_COUNTRY])

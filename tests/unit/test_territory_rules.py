import pytest

from packages.core.domain.territory.rules import (
    KNOWN_COUNTRIES,
    MARKETPLACE_MAX_RADIUS_KM,
    is_known_country,
    normalize_country,
    rules_for,
)

# Mirrors apps/mobile_app/test/territory/territory_test.dart: the same values
# are pinned on both sides.


def test_each_country_has_its_currency() -> None:
    assert (rules_for("IT").currency_code, rules_for("IT").currency_symbol) == ("EUR", "€")
    assert (rules_for("GB").currency_code, rules_for("GB").currency_symbol) == ("GBP", "£")
    assert (rules_for("US").currency_code, rules_for("US").currency_symbol) == ("USD", "$")
    assert (rules_for("AU").currency_code, rules_for("AU").currency_symbol) == ("AUD", "A$")
    assert (rules_for("CH").currency_code, rules_for("CH").currency_symbol) == ("CHF", "CHF")
    assert rules_for("de").currency_code == "EUR"


@pytest.mark.parametrize("country", ["DE", "AT", "CH", "FR", "BE", "ES", "GB"])
def test_no_live_animal_ads_in_these_countries(country: str) -> None:
    assert rules_for(country).live_animal_listings_allowed is False


@pytest.mark.parametrize("country", ["IT", "US", "AU"])
def test_live_animal_rule_is_open_elsewhere(country: str) -> None:
    assert rules_for(country).live_animal_listings_allowed is True


def test_unknown_country_gets_the_source_country_rules_not_a_guess() -> None:
    assert rules_for(None).country == "IT"
    assert rules_for("ZZ").country == "IT"
    assert not is_known_country("ZZ")
    assert not is_known_country(None)


def test_normalisation_and_known_set() -> None:
    assert normalize_country(" gb ") == "GB"
    assert {"IT", "GB", "US", "AU", "DE", "FR", "ES"} <= KNOWN_COUNTRIES


def test_thirty_miles_fit_inside_the_maximum_radius() -> None:
    assert MARKETPLACE_MAX_RADIUS_KM == 50.0
    assert 30 * 1.609344 <= MARKETPLACE_MAX_RADIUS_KM

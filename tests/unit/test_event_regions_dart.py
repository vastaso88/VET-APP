"""The app offers exactly the countries and the regions the server accepts for an event."""

import re
from pathlib import Path

from packages.core.domain.events.regions import COUNTRIES, REGIONS_BY_COUNTRY

APP = Path("apps/mobile_app/lib/features")


def test_the_regions_of_the_form_are_those_of_the_server() -> None:
    dart = (APP / "events/domain/event_regions.dart").read_text(encoding="utf-8")
    table = {
        country: {
            single or double for single, double in re.findall(r"'([^'\n]+)',|\"([^\"]+)\",", rows)
        }
        for country, rows in re.findall(r"'([A-Z]{2})': \[(.*?)\n  \],", dart, flags=re.DOTALL)
    }

    assert table == {country: set(regions) for country, regions in REGIONS_BY_COUNTRY.items()}


def test_the_countries_of_the_form_are_those_of_the_server() -> None:
    dart = (APP / "territory/domain/territory.dart").read_text(encoding="utf-8")
    rows = dart.split("const _territories", 1)[1].split("};", 1)[0]

    assert set(re.findall(r"^  '([A-Z]{2})': Territory\(", rows, flags=re.MULTILINE)) == COUNTRIES

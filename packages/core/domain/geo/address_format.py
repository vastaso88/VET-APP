"""The one place that decides how a postal address is written.

Every country writes the same facts in its own order: "Via Roma 12, 20100
Milano", "12 Main St, Springfield, IL 62704", "Musterstraße 12, 10115
Berlin". The radar importers (OpenStreetMap `addr:*` tags) and anything else
on the backend that needs a one-line address call `format_address`; the app
has its own twin in lib/features/location/domain/address_format.dart that is
tested against the same cases.
"""

import re
from dataclasses import dataclass

# Number after the street, postcode before the city: Italy, Germany, Spain
# and the default for any country not listed.
_STREET_THEN_NUMBER = "street_number"
# Number before the street: the English-speaking countries and France.
_NUMBER_THEN_STREET = "number_street"

_STYLES: dict[str, tuple[str, str]] = {
    # country -> (street line style, locality line style)
    "IT": (_STREET_THEN_NUMBER, "postcode_city"),
    "DE": (_STREET_THEN_NUMBER, "postcode_city"),
    "ES": (_STREET_THEN_NUMBER, "postcode_city"),
    "FR": (_NUMBER_THEN_STREET, "postcode_city"),
    "GB": (_NUMBER_THEN_STREET, "city_postcode"),
    "US": (_NUMBER_THEN_STREET, "city_state_postcode"),
    "AU": (_NUMBER_THEN_STREET, "city_state_postcode_nocomma"),
}
_DEFAULT_STYLE = (_STREET_THEN_NUMBER, "postcode_city")

_STATE_CODE = re.compile(r"^[A-Za-z]{2,3}$")


@dataclass(frozen=True)
class AddressParts:
    street: str | None = None
    house_number: str | None = None
    postcode: str | None = None
    city: str | None = None
    # US state or Australian state/territory, as the 2-3 letter code
    # ("IL", "NSW") or an ISO 3166-2 code ("US-IL"). Ignored elsewhere.
    state: str | None = None


def _clean(value: str | None) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


def _state_code(state: str | None) -> str:
    text = _clean(state)
    if "-" in text:
        text = text.rsplit("-", 1)[1]
    # A full name ("Illinois") is not abbreviated here: shown as given.
    return text.upper() if _STATE_CODE.match(text) else text


def format_address(parts: AddressParts, country_code: str | None) -> str:
    """One-line address in the country's order; parts that are missing are
    left out, and a completely empty address gives an empty string."""
    street_style, locality_style = _STYLES.get((country_code or "").upper(), _DEFAULT_STYLE)
    street, number = _clean(parts.street), _clean(parts.house_number)
    city, postcode = _clean(parts.city), _clean(parts.postcode)
    state = _state_code(parts.state)

    if street_style == _NUMBER_THEN_STREET:
        street_line = " ".join(item for item in (number, street) if item)
    else:
        street_line = " ".join(item for item in (street, number) if item)

    if locality_style == "postcode_city":
        locality = " ".join(item for item in (postcode, city) if item)
    elif locality_style == "city_postcode":
        locality = " ".join(item for item in (city, postcode) if item)
    elif locality_style == "city_state_postcode":
        # "Springfield, IL 62704"
        state_zip = " ".join(item for item in (state, postcode) if item)
        locality = ", ".join(item for item in (city, state_zip) if item)
    else:
        # "Sydney NSW 2000"
        locality = " ".join(item for item in (city, state, postcode) if item)

    return ", ".join(item for item in (street_line, locality) if item)

from collections.abc import Mapping
from typing import Any

# What an owner without a plan (trial over) still sees of an ad: the first
# look a shop window gives, enough to know there is something worth a plan.
# The description, the category and condition details, the species, the seller's
# account id and the map position are withheld; the city and the distance stay
# because the list is built on them. Changing this tuple is the one place that
# decides what a non-subscriber sees; the filter is applied by the backend, so
# it does not depend on what the app shows.
LIMITED_LISTING_FIELDS: tuple[str, ...] = (
    "id",
    "title",
    "price_cents",
    "photo_urls",
    "city_label",
    "country",
    "distance_km",
    "is_mine",
)


def limit_listing_row(row: Mapping[str, Any]) -> dict[str, Any]:
    """[row] reduced to [LIMITED_LISTING_FIELDS]: a new dict, so a field added
    to the full row later is withheld until it is listed on purpose."""
    return {key: row[key] for key in LIMITED_LISTING_FIELDS if key in row}

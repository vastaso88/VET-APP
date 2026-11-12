from typing import Protocol

from pydantic import BaseModel, Field


class GeocodedPlace(BaseModel):
    """One answer of the geocoding provider, reduced to what the app uses:
    the position and the address parts it formats in the user's country
    order (street, house number, postcode, town...)."""

    latitude: float
    longitude: float
    display_name: str = ""
    # Provider address parts, strings only (e.g. {"road": ..., "city": ...}).
    address: dict[str, str] = Field(default_factory=dict)


class Geocoder(Protocol):
    """Address <-> position. Implementations must not log the queries:
    they are home addresses and positions of users."""

    def search(
        self, query: str, *, country_code: str | None, language: str | None
    ) -> list[GeocodedPlace]: ...

    def reverse(
        self, latitude: float, longitude: float, *, zoom: int, language: str | None
    ) -> GeocodedPlace | None: ...

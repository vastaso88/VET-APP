"""Geocoding for the app, run by the backend (security audit APP-6).

The app used to call OpenStreetMap's Nominatim itself, which sent the
user's home address together with their IP address to a third party.
Now the app asks this service, authenticated, and only the backend talks
to the provider: the provider sees our server, never the user.
"""

import time
from collections import defaultdict, deque
from collections.abc import Callable
from threading import Lock

from packages.core.application.ports.geocoder import GeocodedPlace, Geocoder
from packages.shared.errors.base import VetAppError

# Per account. A person typing their address and saving it, or placing a
# few reports, stays far below; anything above is bulk use, which the
# provider's policy forbids and this endpoint must not become a way into.
DEFAULT_REQUESTS_PER_MINUTE = 20


class GeocodingRateLimitedError(VetAppError):
    """Too many geocoding requests from one account in the last minute."""


class GeocodingService:
    def __init__(
        self,
        geocoder: Geocoder,
        *,
        requests_per_minute: int = DEFAULT_REQUESTS_PER_MINUTE,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._geocoder = geocoder
        self._limit = requests_per_minute
        self._clock = clock
        self._recent: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def search(
        self, user_id: str, query: str, *, country_code: str | None, language: str | None
    ) -> list[GeocodedPlace]:
        self._count(user_id)
        return self._geocoder.search(
            query.strip(),
            country_code=country_code.lower() if country_code else None,
            language=language,
        )

    def reverse(
        self,
        user_id: str,
        latitude: float,
        longitude: float,
        *,
        zoom: int,
        language: str | None,
    ) -> GeocodedPlace | None:
        self._count(user_id)
        return self._geocoder.reverse(latitude, longitude, zoom=zoom, language=language)

    def _count(self, user_id: str) -> None:
        now = self._clock()
        with self._lock:
            recent = self._recent[user_id]
            while recent and now - recent[0] >= 60:
                recent.popleft()
            if len(recent) >= self._limit:
                raise GeocodingRateLimitedError(
                    "Troppe ricerche di indirizzi in poco tempo. Riprova tra un minuto."
                )
            recent.append(now)

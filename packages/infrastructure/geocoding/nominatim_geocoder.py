"""OpenStreetMap's Nominatim, called from the backend only.

Usage policy (https://operations.osmfoundation.org/policies/nominatim/):
an identifying User-Agent, at most one request per second, results
cached, no bulk or autocomplete use. The one-per-second spacing here is
per server process; the per-account limit in GeocodingService and the
fact that the app only geocodes on an explicit action keep the total far
below it.

Queries are home addresses and positions: they are never logged, and the
cache lives only in this process's memory.
"""

from __future__ import annotations

import json
import logging
import threading
import time
from collections import OrderedDict
from collections.abc import Callable
from typing import Any
from urllib import error, parse, request

from packages.core.application.ports.geocoder import GeocodedPlace
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

_logger = logging.getLogger(__name__)

MIN_SECONDS_BETWEEN_REQUESTS = 1.0
# Beyond this wait for a free slot, the request is refused rather than
# holding a serverless function open.
MAX_WAIT_SECONDS = 5.0
REQUEST_TIMEOUT_SECONDS = 10.0
CACHE_TTL_SECONDS = 24 * 60 * 60
CACHE_MAX_ENTRIES = 2000

# Shared by every instance in the process: the policy limit is per client.
_rate_lock = threading.Lock()
_last_request_at: list[float] = [float("-inf")]


def _reset_rate_limit_for_tests() -> None:
    _last_request_at[0] = float("-inf")


class NominatimGeocoder:
    def __init__(
        self,
        settings: Settings,
        *,
        opener: Callable[..., Any] = request.urlopen,
        clock: Callable[[], float] = time.monotonic,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self._base_url = settings.nominatim_base_url.rstrip("/")
        self._user_agent = settings.nominatim_user_agent
        self._opener = opener
        self._clock = clock
        self._sleep = sleep
        self._cache: OrderedDict[tuple[Any, ...], tuple[float, Any]] = OrderedDict()
        self._cache_lock = threading.Lock()

    def search(
        self, query: str, *, country_code: str | None, language: str | None
    ) -> list[GeocodedPlace]:
        if not query:
            return []
        key = ("search", query.casefold(), country_code, language)
        cached = self._cached(key)
        if cached is not None:
            return list(cached)
        params = {"q": query, "format": "jsonv2", "limit": "1", "addressdetails": "1"}
        if country_code:
            params["countrycodes"] = country_code
        if language:
            params["accept-language"] = language
        payload = self._get("/search", params)
        results = [
            place
            for item in (payload if isinstance(payload, list) else [])
            for place in [_place(item)]
            if place is not None
        ]
        self._store(key, results)
        return results

    def reverse(
        self, latitude: float, longitude: float, *, zoom: int, language: str | None
    ) -> GeocodedPlace | None:
        # ~1 m: the same door asked twice is one request.
        lat, lon = round(latitude, 5), round(longitude, 5)
        key = ("reverse", lat, lon, zoom, language)
        cached = self._cached(key)
        if cached is not None:
            return cached or None
        params = {
            "lat": str(lat),
            "lon": str(lon),
            "zoom": str(zoom),
            "format": "jsonv2",
            "addressdetails": "1",
        }
        if language:
            params["accept-language"] = language
        payload = self._get("/reverse", params)
        place = _place(payload) if isinstance(payload, dict) else None
        # A miss is cached too (as False), so it is not asked again.
        self._store(key, place or False)
        return place

    def _get(self, path: str, params: dict[str, str]) -> Any:
        self._wait_for_slot()
        http_request = request.Request(
            f"{self._base_url}{path}?{parse.urlencode(params)}",
            headers={"User-Agent": self._user_agent, "Accept": "application/json"},
        )
        try:
            with self._opener(http_request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                return json.load(response)
        except error.HTTPError as exc:
            # Status only: the URL holds the user's address.
            _logger.warning("Nominatim answered HTTP %s", exc.code)
        except (error.URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
            _logger.warning("Nominatim unreachable: %s", type(exc).__name__)
        raise ProviderError("Il servizio degli indirizzi non risponde. Riprova più tardi.")

    def _wait_for_slot(self) -> None:
        with _rate_lock:
            wait = _last_request_at[0] + MIN_SECONDS_BETWEEN_REQUESTS - self._clock()
            if wait > MAX_WAIT_SECONDS:
                raise ProviderError("Il servizio degli indirizzi è occupato. Riprova tra poco.")
            if wait > 0:
                self._sleep(wait)
            _last_request_at[0] = self._clock()

    def _cached(self, key: tuple[Any, ...]) -> Any:
        with self._cache_lock:
            entry = self._cache.get(key)
            if entry is None:
                return None
            expires_at, value = entry
            if expires_at <= self._clock():
                del self._cache[key]
                return None
            self._cache.move_to_end(key)
            return value

    def _store(self, key: tuple[Any, ...], value: Any) -> None:
        with self._cache_lock:
            self._cache[key] = (self._clock() + CACHE_TTL_SECONDS, value)
            self._cache.move_to_end(key)
            while len(self._cache) > CACHE_MAX_ENTRIES:
                self._cache.popitem(last=False)


def _place(item: Any) -> GeocodedPlace | None:
    if not isinstance(item, dict):
        return None
    try:
        latitude, longitude = float(item["lat"]), float(item["lon"])
    except (KeyError, TypeError, ValueError):
        return None
    raw_address = item.get("address")
    address = (
        {str(k): v for k, v in raw_address.items() if isinstance(v, str)}
        if isinstance(raw_address, dict)
        else {}
    )
    display_name = item.get("display_name")
    return GeocodedPlace(
        latitude=latitude,
        longitude=longitude,
        display_name=display_name if isinstance(display_name, str) else "",
        address=address,
    )

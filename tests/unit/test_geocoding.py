import io
import json
from typing import Any
from urllib import error, parse

import pytest

from packages.core.application.ports.geocoder import GeocodedPlace
from packages.core.application.services.geocoding import (
    GeocodingRateLimitedError,
    GeocodingService,
)
from packages.infrastructure.geocoding import nominatim_geocoder
from packages.infrastructure.geocoding.nominatim_geocoder import NominatimGeocoder
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError


class _Clock:
    def __init__(self) -> None:
        self.now = 1000.0
        self.slept: list[float] = []

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.slept.append(round(seconds, 3))
        self.now += seconds


class _Opener:
    """Answers like Nominatim and records what was asked."""

    def __init__(self, payload: Any, *, fail_with: int | None = None) -> None:
        self.payload = payload
        self.fail_with = fail_with
        self.requests: list[Any] = []

    def __call__(self, http_request: Any, timeout: float) -> io.BytesIO:
        self.requests.append(http_request)
        if self.fail_with is not None:
            raise error.HTTPError(http_request.full_url, self.fail_with, "busy", None, None)  # type: ignore[arg-type]
        return io.BytesIO(json.dumps(self.payload).encode())


_HIT = {
    "lat": "45.4642",
    "lon": "9.19",
    "display_name": "Via Esempio 1, Milano",
    "address": {"road": "Via Esempio", "house_number": "1", "city": "Milano", "extra": 3},
}


@pytest.fixture(autouse=True)
def _fresh_rate_limit() -> None:
    nominatim_geocoder._reset_rate_limit_for_tests()


def _geocoder(opener: _Opener, clock: _Clock) -> NominatimGeocoder:
    return NominatimGeocoder(Settings(), opener=opener, clock=clock, sleep=clock.sleep)


def test_search_identifies_the_app_limits_the_country_and_keeps_only_strings() -> None:
    opener, clock = _Opener([_HIT]), _Clock()

    results = _geocoder(opener, clock).search(
        "Via Esempio 1, Milano", country_code="it", language="it"
    )

    asked = opener.requests[0]
    params = parse.parse_qs(parse.urlsplit(asked.full_url).query)
    assert asked.get_header("User-agent").startswith("VET-APP/1.0")
    assert params["countrycodes"] == ["it"] and params["limit"] == ["1"]
    assert results == [
        GeocodedPlace(
            latitude=45.4642,
            longitude=9.19,
            display_name="Via Esempio 1, Milano",
            address={"road": "Via Esempio", "house_number": "1", "city": "Milano"},
        )
    ]


def test_requests_are_at_least_one_second_apart() -> None:
    opener, clock = _Opener([_HIT]), _Clock()
    geocoder = _geocoder(opener, clock)

    geocoder.search("Via Uno", country_code=None, language=None)
    clock.now += 0.3
    geocoder.search("Via Due", country_code=None, language=None)

    assert clock.slept == [0.7]
    assert len(opener.requests) == 2


def test_answers_are_cached_including_misses() -> None:
    opener, clock = _Opener({"error": "Unable to geocode"}), _Clock()
    geocoder = _geocoder(opener, clock)

    assert geocoder.reverse(45.4642001, 9.19, zoom=18, language="it") is None
    # The same door (to ~1 m) asked again: no new request.
    assert geocoder.reverse(45.4642004, 9.19, zoom=18, language="it") is None
    assert len(opener.requests) == 1

    opener.payload = [_HIT]
    geocoder.search("Via Esempio 1", country_code="it", language=None)
    geocoder.search("via esempio 1", country_code="it", language=None)
    assert len(opener.requests) == 2


def test_provider_errors_are_reported_without_the_address(caplog: pytest.LogCaptureFixture) -> None:
    opener, clock = _Opener([], fail_with=503), _Clock()

    with pytest.raises(ProviderError):
        _geocoder(opener, clock).search("Via Segreta 7, Milano", country_code="it", language=None)

    assert "Segreta" not in caplog.text
    assert "503" in caplog.text


def test_a_long_queue_is_refused_instead_of_waiting() -> None:
    opener, clock = _Opener([_HIT]), _Clock()
    nominatim_geocoder._last_request_at[0] = clock.now + 10

    with pytest.raises(ProviderError):
        _geocoder(opener, clock).search("Via Uno", country_code=None, language=None)
    assert opener.requests == []


class _FakeGeocoder:
    def __init__(self) -> None:
        self.calls = 0

    def search(
        self, query: str, *, country_code: str | None, language: str | None
    ) -> list[GeocodedPlace]:
        self.calls += 1
        return []

    def reverse(
        self, latitude: float, longitude: float, *, zoom: int, language: str | None
    ) -> GeocodedPlace | None:
        self.calls += 1
        return None


def test_each_account_has_its_own_limit_per_minute() -> None:
    clock = _Clock()
    fake = _FakeGeocoder()
    service = GeocodingService(fake, requests_per_minute=2, clock=clock)

    service.search("anna", "Via Uno", country_code="IT", language=None)
    service.reverse("anna", 45.0, 9.0, zoom=18, language=None)
    with pytest.raises(GeocodingRateLimitedError):
        service.search("anna", "Via Tre", country_code=None, language=None)
    # Someone else is not affected, and a minute later Anna can go on.
    service.search("bruno", "Via Uno", country_code=None, language=None)
    clock.now += 60
    service.search("anna", "Via Quattro", country_code=None, language=None)
    assert fake.calls == 4

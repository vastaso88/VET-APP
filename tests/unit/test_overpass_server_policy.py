"""Which Overpass servers the backend may use (decision of 26/11/2026):
none by default, never overpass-api.de (its robots.txt forbids /api/ to
programs), and the live search stays off while no server is configured."""

from __future__ import annotations

from typing import Any

import pytest

from packages.shared.config.external_hosts import forbidden_reason
from packages.shared.config.settings import Settings


def _settings(**values: Any) -> Settings:
    return Settings(_env_file=None, **values)  # type: ignore[call-arg]


def test_no_overpass_server_by_default_keeps_live_search_off() -> None:
    settings = _settings()
    assert settings.overpass_urls == ()
    assert not settings.radar_live_search_active
    # Switching the live search on is not enough without a server.
    switched_on = _settings(RADAR_LIVE_SEARCH_ENABLED=True)
    assert switched_on.radar_live_search_enabled
    assert not switched_on.radar_live_search_active


def test_live_search_runs_only_with_a_configured_server() -> None:
    settings = _settings(
        RADAR_LIVE_SEARCH_ENABLED=True, OVERPASS_BASE_URL="https://overpass.example/api/interpreter"
    )
    assert settings.radar_live_search_active
    assert settings.overpass_urls == ("https://overpass.example/api/interpreter",)


@pytest.mark.parametrize(
    "values",
    [
        {"OVERPASS_BASE_URL": "https://overpass-api.de/api/interpreter"},
        {"OVERPASS_BASE_URL": "https://z.overpass-api.de/api/interpreter"},
        {"OVERPASS_FALLBACK_URLS": "https://ok.example/api, https://OVERPASS-API.DE/api/x"},
    ],
)
def test_a_server_on_overpass_api_de_is_refused(
    values: dict[str, str], caplog: pytest.LogCaptureFixture
) -> None:
    # Refused without stopping the backend: the server is simply never used.
    settings = _settings(RADAR_LIVE_SEARCH_ENABLED=True, **values)
    assert not any("overpass-api.de" in url.lower() for url in settings.overpass_urls)
    assert "not allowed" in caplog.text and "robots.txt" in caplog.text
    if "OVERPASS_FALLBACK_URLS" not in values:
        assert not settings.radar_live_search_active


def test_forbidden_reason_matches_hosts_and_urls() -> None:
    assert forbidden_reason("overpass-api.de")
    assert forbidden_reason("https://lz4.overpass-api.de/api/status")
    assert forbidden_reason("overpass-api.de:443")
    assert forbidden_reason("https://overpass.private.coffee/api/interpreter") is None
    assert forbidden_reason("https://notoverpass-api.de/") is None
    assert forbidden_reason("") is None

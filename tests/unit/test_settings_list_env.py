"""List settings read from the environment accept JSON or comma-separated text.

Production crashed (FUNCTION_INVOCATION_FAILED on every route) when
ADMIN_EMAILS was set as plain text: pydantic-settings only decodes JSON for
list[str] fields and raised at import.
"""

import pytest

from packages.shared.config.settings import Settings

LIST_ENV_NAMES = (
    "DEVELOPER_EMAILS",
    "ADMIN_EMAILS",
    "OVERPASS_FALLBACK_URLS",
    "RADAR_REPORT_PLACE_TYPES",
    "RADAR_OPEN_SOURCES",
    "RETRIEVAL_LANGUAGES",
)


def _settings() -> Settings:
    return Settings(_env_file=None)  # type: ignore[call-arg]


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in LIST_ENV_NAMES:
        monkeypatch.delenv(name, raising=False)


def test_a_single_plain_address_is_accepted(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ADMIN_EMAILS", "a@b.it")
    monkeypatch.setenv("DEVELOPER_EMAILS", "a@b.it")
    settings = _settings()
    assert settings.admin_emails == ["a@b.it"]
    assert settings.developer_emails == ["a@b.it"]


def test_comma_separated_text_is_trimmed_and_empty_items_dropped(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ADMIN_EMAILS", " a@b.it ,c@d.it,, ,e@f.it,")
    assert _settings().admin_emails == ["a@b.it", "c@d.it", "e@f.it"]


def test_a_json_array_still_works(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ADMIN_EMAILS", '["a@b.it", " c@d.it ", ""]')
    monkeypatch.setenv("RETRIEVAL_LANGUAGES", '["en"]')
    settings = _settings()
    assert settings.admin_emails == ["a@b.it", "c@d.it"]
    assert settings.retrieval_languages == ["en"]


def test_malformed_json_does_not_crash_the_application(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ADMIN_EMAILS", "['a@b.it', 'c@d.it']")
    assert _settings().admin_emails == ["a@b.it", "c@d.it"]


def test_an_empty_value_is_an_empty_list(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ADMIN_EMAILS", "")
    monkeypatch.setenv("DEVELOPER_EMAILS", "   ")
    settings = _settings()
    assert settings.admin_emails == []
    assert settings.developer_emails == []


def test_every_list_setting_accepts_comma_separated_text(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("OVERPASS_FALLBACK_URLS", "https://one.example/api, https://two.example/api")
    monkeypatch.setenv("RADAR_REPORT_PLACE_TYPES", "veterinary, shop")
    monkeypatch.setenv("RADAR_OPEN_SOURCES", "overture,municipal")
    monkeypatch.setenv("RETRIEVAL_LANGUAGES", "it")
    settings = _settings()
    assert settings.overpass_fallback_urls == ["https://one.example/api", "https://two.example/api"]
    assert settings.radar_report_place_types == ["veterinary", "shop"]
    assert settings.radar_open_sources == ["overture", "municipal"]
    assert settings.retrieval_languages == ["it"]


def test_defaults_are_unchanged() -> None:
    settings = _settings()
    assert settings.developer_emails == []
    assert settings.admin_emails == []
    assert settings.radar_open_sources == ["*"]
    assert settings.retrieval_languages == ["en", "it"]
    assert settings.radar_report_place_types == [
        "veterinary",
        "grooming",
        "shop",
        "hotel",
        "dog_park",
        # Shelters reportable as missing from 2026-10-07 (owner's decision).
        "shelter",
    ]
    assert len(settings.overpass_fallback_urls) == 2


def test_values_passed_as_python_lists_are_untouched() -> None:
    settings = Settings(_env_file=None, ADMIN_EMAILS=["x@y.it"])  # type: ignore[call-arg]
    assert settings.admin_emails == ["x@y.it"]

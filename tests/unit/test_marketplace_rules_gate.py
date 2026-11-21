from dataclasses import dataclass, field
from types import SimpleNamespace

import pytest

from apps.api.dependencies import marketplace_rules
from packages.core.domain.consent.account_consent_text import (
    CURRENT_VERSIONS,
    build_consent_catalog,
)
from packages.core.domain.consent.models import AccountConsents, AccountConsentType, ConsentRecord
from packages.shared.errors.base import MarketplaceRulesRequiredError

OWNER = "owner-a"
KEY = AccountConsentType.MARKETPLACE_RULES


@dataclass
class _Repository:
    record: AccountConsents | None = None
    asked: list[str] = field(default_factory=list)

    def get(self, owner_id: str) -> AccountConsents | None:
        self.asked.append(owner_id)
        return self.record


def _container(repository: _Repository, *, required: bool) -> SimpleNamespace:
    return SimpleNamespace(
        settings=SimpleNamespace(marketplace_rules_required=required),
        auth_provider=SimpleNamespace(get_current_user=lambda: SimpleNamespace(id=OWNER)),
        account_consents_repository=repository,
    )


def _accepted(version: str, *, granted: bool = True) -> AccountConsents:
    from datetime import UTC, datetime

    return AccountConsents(
        owner_id=OWNER,
        consents={
            KEY: ConsentRecord(granted=granted, version=version, decided_at=datetime.now(UTC))
        },
    )


def _use(monkeypatch: pytest.MonkeyPatch, repository: _Repository, *, required: bool) -> None:
    monkeypatch.setattr(
        marketplace_rules, "get_container", lambda: _container(repository, required=required)
    )


def test_the_gate_is_off_by_default_so_nothing_changes_before_the_text_is_approved(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repository = _Repository()
    _use(monkeypatch, repository, required=False)

    marketplace_rules.require_marketplace_rules_accepted()

    assert repository.asked == [], "not even looked at"


def test_with_the_gate_on_no_acceptance_means_no_writing(monkeypatch: pytest.MonkeyPatch) -> None:
    _use(monkeypatch, _Repository(), required=True)

    with pytest.raises(MarketplaceRulesRequiredError):
        marketplace_rules.require_marketplace_rules_accepted()


def test_an_acceptance_of_the_current_version_lets_the_owner_through(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _use(monkeypatch, _Repository(_accepted(CURRENT_VERSIONS[KEY])), required=True)

    marketplace_rules.require_marketplace_rules_accepted()


def test_an_older_version_or_a_withdrawn_acceptance_does_not_count(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _use(monkeypatch, _Repository(_accepted("v0")), required=True)
    with pytest.raises(MarketplaceRulesRequiredError):
        marketplace_rules.require_marketplace_rules_accepted()

    _use(monkeypatch, _Repository(_accepted(CURRENT_VERSIONS[KEY], granted=False)), required=True)
    with pytest.raises(MarketplaceRulesRequiredError):
        marketplace_rules.require_marketplace_rules_accepted()


# What each language's app calls the feature (glossary), and what must NOT appear there.
_TERM = {
    "it": "Mercatino",
    "en": "marketplace",
    "es": "mercadillo",
    "de": "Gebrauchtmarkt",
    "fr": "marché de l'occasion",
}


def test_the_rules_are_in_the_catalog_with_a_version_in_every_language() -> None:
    for language, term in _TERM.items():
        entry = build_consent_catalog(language)[KEY]
        assert entry.version == "v1"
        assert term in entry.text, language
        if language != "it":
            assert "Mercatino" not in entry.text, language

    # No language, or one without a text, gets the English one (never the Italian).
    for language in (None, "ja"):
        assert build_consent_catalog(language)[KEY].version == "v1"
    assert build_consent_catalog("ja")[KEY].text == build_consent_catalog("en")[KEY].text


def test_the_texts_say_what_the_italian_says() -> None:
    texts = {language: build_consent_catalog(language)[KEY].text for language in _TERM}

    assert len(set(texts.values())) == len(_TERM), "five different texts"
    assert "Regole del Mercatino" in texts["it"]
    assert "il team di Quokka può leggerla" in texts["it"]
    for language, text in texts.items():
        # Eight numbered rules, the same everywhere.
        for number in range(1, 9):
            assert f"\n{number}. " in text, (language, number)
    # The English app: "own responsibility", not "own risk" (that reads as a disclaimer).
    assert "on your own responsibility" in texts["en"]
    assert "at your own risk" not in texts["en"]


def test_it_is_an_acceptance_that_never_gates_the_app() -> None:
    assert KEY in AccountConsentType.OPTIONAL
    assert KEY not in AccountConsentType.MANDATORY

"""The clause "Quokka non gestisce le urgenze" (docs/compliance/22): the app and the
server must agree on what is mandatory and on the words the owner accepts."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from packages.core.domain.consent.account_consent_text import (
    CONSENT_TEXTS_BY_LANGUAGE,
    CURRENT_VERSIONS,
)
from packages.core.domain.consent.models import AccountConsentType

APP = Path("apps/mobile_app")
LANGUAGES = ("it", "en", "es", "de", "fr")
CLAUSE_OPENING = {
    "it": "Quokka non gestisce le urgenze",
    "en": "Quokka does not handle emergencies",
    "es": "Quokka no gestiona urgencias",
    "de": "Quokka ist nicht für Notfälle zuständig",
    "fr": "Quokka ne gère pas les urgences",
}


def _arb(lang: str) -> dict[str, str]:
    path = APP / "lib" / "l10n" / f"app_{lang}.arb"
    return json.loads(path.read_text(encoding="utf-8"))  # type: ignore[no-any-return]


def test_the_apps_mandatory_keys_are_the_servers() -> None:
    """If they drift, the server refuses everything while the app shows no gate."""
    source = (APP / "lib/features/account_consents/domain/account_consent_models.dart").read_text(
        encoding="utf-8"
    )
    constants = dict(re.findall(r"static const (\w+) = '([a-z_]+)';", source))
    listed = re.search(r"static const mandatory = \[([^\]]*)\];", source)
    assert listed, "AccountConsentKeys.mandatory not found"
    names = [name.strip() for name in listed.group(1).split(",") if name.strip()]
    assert {constants[name] for name in names} == set(AccountConsentType.MANDATORY)


def test_the_emergency_notice_is_required_by_the_chat_only_and_versioned() -> None:
    assert AccountConsentType.EMERGENCY_NOTICE not in AccountConsentType.MANDATORY
    assert frozenset({AccountConsentType.EMERGENCY_NOTICE}) == AccountConsentType.CHAT_REQUIRED
    assert AccountConsentType.EMERGENCY_NOTICE in AccountConsentType.NOT_REVOCABLE
    assert AccountConsentType.EMERGENCY_NOTICE in CURRENT_VERSIONS
    # The Terms version rose when the clause joined them.
    assert CURRENT_VERSIONS[AccountConsentType.TERMS_OF_SERVICE] != "v1"


def test_the_app_remembers_the_version_the_server_pins() -> None:
    source = (APP / "lib/features/account_consents/domain/account_consent_models.dart").read_text(
        encoding="utf-8"
    )
    found = re.search(r"static const emergencyNoticeVersion = '(\w+)';", source)
    assert found and found.group(1) == CURRENT_VERSIONS[AccountConsentType.EMERGENCY_NOTICE]


@pytest.mark.parametrize("lang", LANGUAGES)
def test_the_short_version_on_screen_is_the_text_the_version_pins(lang: str) -> None:
    served = CONSENT_TEXTS_BY_LANGUAGE[lang][AccountConsentType.EMERGENCY_NOTICE]
    assert _arb(lang)["emergencyNoticeShort"] == served


@pytest.mark.parametrize("lang", LANGUAGES)
def test_the_clause_is_in_the_terms_summary_in_every_language(lang: str) -> None:
    terms = CONSENT_TEXTS_BY_LANGUAGE[lang][AccountConsentType.TERMS_OF_SERVICE]
    assert CLAUSE_OPENING[lang] in terms
    # The full clause says what to do instead and that silence does not reassure.
    assert terms.count(CLAUSE_OPENING[lang]) == 1


@pytest.mark.parametrize("lang", LANGUAGES)
def test_the_chat_info_carries_the_short_version(lang: str) -> None:
    served = CONSENT_TEXTS_BY_LANGUAGE[lang][AccountConsentType.EMERGENCY_NOTICE]
    assert _arb(lang)["noticeChatAi"].endswith(served)


@pytest.mark.parametrize("lang", LANGUAGES)
def test_the_new_texts_hold_no_phone_number(lang: str) -> None:
    """Owner rule (21 Nov): no number in any fixed text, for any country."""
    texts = [
        value
        for key, value in _arb(lang).items()
        if key.startswith(("emergencyNotice", "chatFixedLine", "consentGate"))
        and isinstance(value, str)
    ]
    texts += [
        CONSENT_TEXTS_BY_LANGUAGE[lang][AccountConsentType.EMERGENCY_NOTICE],
        CONSENT_TEXTS_BY_LANGUAGE[lang][AccountConsentType.TERMS_OF_SERVICE],
    ]
    for text in texts:
        assert not re.search(r"\d{3}", text), text

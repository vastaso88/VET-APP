from apps.api.dependencies.container import get_container
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType
from packages.shared.errors.base import MarketplaceRulesRequiredError


def require_marketplace_rules_accepted() -> None:
    """Publishing or changing an ad and writing a message need the owner to have
    accepted the CURRENT version of the Mercatino rules (docs/compliance/24):
    an acceptance, not a GDPR consent, recorded with its version and date. Off
    unless MARKETPLACE_RULES_REQUIRED is set, so it is switched on together with
    the app that shows the checkbox and after the owner approves the text."""
    container = get_container()
    if not container.settings.marketplace_rules_required:
        return
    user = container.auth_provider.get_current_user()
    record = container.account_consents_repository.get(user.id)
    consent = record.consents.get(AccountConsentType.MARKETPLACE_RULES) if record else None
    current = CURRENT_VERSIONS[AccountConsentType.MARKETPLACE_RULES]
    # Accepting an older wording does not cover the current one.
    if consent is None or not consent.granted or consent.version != current:
        raise MarketplaceRulesRequiredError()

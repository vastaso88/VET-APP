import logging

from apps.api.dependencies.container import get_container
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
)
from packages.shared.errors.base import ProviderError, SubscriptionRequiredError

logger = logging.getLogger(__name__)


def owner_has_access() -> bool:
    """Whether the signed-in owner may use the whole app (trial open, a plan,
    the developer allowlist or the public test). Billing deployments reject
    unverifiable access with a temporary provider error. Development retains
    the previous best-effort fallback."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        status = container.get_or_create_subscription_service().execute(
            GetOrCreateSubscriptionInput(owner_id=user.id, email=user.email)
        )
    except Exception as exc:  # noqa: BLE001 - preserve legacy development fallback
        logger.exception("could not check the owner's subscription")
        if container.settings.billing_enabled:
            raise ProviderError("Subscription verification unavailable") from exc
        return True
    return status.has_access


def require_active_subscription() -> None:
    """Route dependency: 402 `subscription_required` once the trial is over
    and the owner has no plan. After that an owner reaches only their own
    data (export, account deletion) and the subscription routes."""
    if not owner_has_access():
        raise SubscriptionRequiredError("subscription_required")

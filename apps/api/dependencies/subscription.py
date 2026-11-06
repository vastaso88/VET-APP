import logging

from apps.api.dependencies.container import get_container
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
)
from packages.shared.errors.base import SubscriptionRequiredError

logger = logging.getLogger(__name__)


def require_active_subscription() -> None:
    """Route dependency: 402 `subscription_required` once the trial is over
    and the owner has no plan. After that an owner reaches only their own
    data (export, account deletion) and the subscription routes.

    Fails open if the subscription cannot be read: a lookup outage must not
    lock owners out (the plan limits are also zero for an expired owner, so
    the services refuse on their own)."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        status = container.get_or_create_subscription_service().execute(
            GetOrCreateSubscriptionInput(owner_id=user.id, email=user.email)
        )
    except Exception:  # noqa: BLE001 - fail open
        logger.exception("could not check the owner's subscription")
        return
    if not status.has_access:
        raise SubscriptionRequiredError("subscription_required")

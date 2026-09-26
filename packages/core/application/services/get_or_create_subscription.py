from pydantic import BaseModel

from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.subscription.models import Subscription


class GetOrCreateSubscriptionInput(BaseModel):
    owner_id: str
    email: str


class GetOrCreateSubscriptionOutput(BaseModel):
    subscription: Subscription
    is_developer: bool
    has_access: bool


class GetOrCreateSubscriptionService:
    """Starts the 10-day free trial (spec: no card required) on first
    lookup, and reports whether the owner currently has access — always
    true for the developer allowlist, otherwise trial-or-plan."""

    def __init__(
        self, repository: SubscriptionRepository, developer_emails: frozenset[str]
    ) -> None:
        self._repository = repository
        self._developer_emails = developer_emails

    def execute(self, data: GetOrCreateSubscriptionInput) -> GetOrCreateSubscriptionOutput:
        subscription = self._repository.get(data.owner_id)
        if subscription is None:
            subscription = self._repository.save(Subscription(owner_id=data.owner_id))

        is_developer = data.email.strip().lower() in self._developer_emails
        return GetOrCreateSubscriptionOutput(
            subscription=subscription,
            is_developer=is_developer,
            has_access=subscription.has_access(is_developer=is_developer),
        )

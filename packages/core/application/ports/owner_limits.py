from collections.abc import Callable

from packages.core.domain.subscription.limits import PlanLimits

# (owner_id, e-mail) -> what the owner's plan allows; None = no limits
# (developer allowlist, or the lookup failed and the app fails open).
OwnerLimitsLookup = Callable[[str, str | None], PlanLimits | None]

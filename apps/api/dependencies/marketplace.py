from apps.api.dependencies.container import get_container
from packages.core.application.services.marketplace_messaging import raise_if_restricted


def require_marketplace_age() -> None:
    """Route dependency for the whole Mercatino: only a declared adult. 403
    `age_required` when no date of birth was declared yet (the app asks for it),
    403 `marketplace_adults_only` for a declared minor. Fails closed."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    container.age_gate_service().require_marketplace(user.id)


def require_marketplace_not_restricted() -> None:
    """Route dependency: 403 `marketplace_restricted` for an owner the moderation
    team kept out of the Mercatino (no new ads, no edits). Reading, reporting and
    deleting one's own ad stay open."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    raise_if_restricted(container.marketplace_messaging_repository.get_restriction(user.id))

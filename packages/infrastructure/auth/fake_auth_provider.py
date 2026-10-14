from datetime import UTC, datetime

from packages.core.application.ports.auth_provider import AuthenticatedUser, AuthProvider


class FakeAuthProvider(AuthProvider):
    def get_current_user(self) -> AuthenticatedUser:
        return AuthenticatedUser(id="demo-user", email="demo@vetapp.local")

    def last_sign_in_at(self) -> datetime | None:
        # Local development: there is no real sign-in to age.
        return datetime.now(UTC)

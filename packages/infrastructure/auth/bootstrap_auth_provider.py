from packages.core.application.ports.auth_provider import (
    AuthenticatedUser,
    AuthProvider,
    AuthSession,
)
from packages.shared.config.settings import Settings


class BootstrapAuthProvider(AuthProvider):
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def get_current_user(self) -> AuthenticatedUser:
        return AuthenticatedUser(
            id=self._settings.bootstrap_user_id,
            email=self._settings.bootstrap_user_email,
        )

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        _ = password
        return AuthSession(
            access_token="bootstrap-token",
            refresh_token=None,
            user=AuthenticatedUser(id=self._settings.bootstrap_user_id, email=email),
        )

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        return self.sign_in_with_password(email=email, password=password)

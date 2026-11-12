from datetime import UTC, datetime

from packages.core.application.ports.auth_provider import (
    AuthenticatedUser,
    AuthProvider,
    AuthSession,
)
from packages.core.domain.localization import SupportedLocale
from packages.shared.config.settings import Settings


class BootstrapAuthProvider(AuthProvider):
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._preferred_locale: SupportedLocale = "it"

    def get_current_user(self) -> AuthenticatedUser:
        return AuthenticatedUser(
            id=self._settings.bootstrap_user_id,
            email=self._settings.bootstrap_user_email,
            preferred_locale=self._preferred_locale,
        )

    def last_sign_in_at(self) -> datetime | None:
        return datetime.now(UTC)

    def update_preferred_locale(self, locale: SupportedLocale) -> AuthenticatedUser:
        self._preferred_locale = locale
        return self.get_current_user()

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        _ = password
        return AuthSession(
            access_token="bootstrap-token",
            refresh_token=None,
            user=AuthenticatedUser(id=self._settings.bootstrap_user_id, email=email),
        )

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        return self.sign_in_with_password(email=email, password=password)

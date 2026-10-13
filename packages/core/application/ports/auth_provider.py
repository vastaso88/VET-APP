from typing import Protocol

from pydantic import BaseModel

from packages.core.domain.localization import SupportedLocale


class AuthenticatedUser(BaseModel):
    id: str
    email: str
    # The name the owner gave at sign-up, when there is one.
    display_name: str | None = None
    preferred_locale: SupportedLocale = "it"


class AuthSession(BaseModel):
    access_token: str
    refresh_token: str | None = None
    user: AuthenticatedUser


class AuthProvider(Protocol):
    def get_current_user(self) -> AuthenticatedUser: ...

    def update_preferred_locale(self, locale: SupportedLocale) -> AuthenticatedUser: ...

    def sign_in_with_password(self, email: str, password: str) -> AuthSession: ...

    def sign_up(self, email: str, password: str) -> AuthSession | None: ...

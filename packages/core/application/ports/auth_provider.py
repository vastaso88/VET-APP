from typing import Protocol

from pydantic import BaseModel


class AuthenticatedUser(BaseModel):
    id: str
    email: str
    # The name the owner gave at sign-up, when there is one.
    display_name: str | None = None


class AuthSession(BaseModel):
    access_token: str
    refresh_token: str | None = None
    user: AuthenticatedUser


class AuthProvider(Protocol):
    def get_current_user(self) -> AuthenticatedUser: ...

    def sign_in_with_password(self, email: str, password: str) -> AuthSession: ...

    def sign_up(self, email: str, password: str) -> AuthSession | None: ...

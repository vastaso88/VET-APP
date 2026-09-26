from typing import TYPE_CHECKING, Any

from packages.core.application.ports.auth_provider import (
    AuthenticatedUser,
    AuthProvider,
    AuthSession,
)
from packages.shared.auth_context import get_access_token
from packages.shared.errors.base import AuthenticationError

if TYPE_CHECKING:
    from supabase import Client as SupabaseClient
else:
    SupabaseClient = Any

_SUPABASE_IMPORT_ERROR: ModuleNotFoundError | None
try:
    from supabase import Client as _SupabaseClient  # noqa: F401
except ModuleNotFoundError as exc:  # pragma: no cover - exercised by local runtime environments
    _SUPABASE_IMPORT_ERROR = exc
else:
    _SUPABASE_IMPORT_ERROR = None


class SupabaseAuthProvider(AuthProvider):
    def __init__(self, public_client: SupabaseClient, admin_client: SupabaseClient) -> None:
        if _SUPABASE_IMPORT_ERROR is not None:
            raise AuthenticationError(
                "Supabase auth provider requires the optional 'supabase' dependency"
            ) from _SUPABASE_IMPORT_ERROR
        self._public_client = public_client
        self._admin_client = admin_client

    def get_current_user(self) -> AuthenticatedUser:
        access_token = get_access_token()
        if not access_token:
            raise AuthenticationError("Missing access token")

        response = self._admin_client.auth.get_user(access_token)
        user = getattr(response, "user", None)
        if user is None:
            raise AuthenticationError("Invalid access token")

        return AuthenticatedUser(id=user.id, email=user.email or "")

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        response = self._public_client.auth.sign_in_with_password(
            {"email": email, "password": password}
        )
        return self._map_auth_session(response)

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        response = self._public_client.auth.sign_up({"email": email, "password": password})
        session = self._extract_session(response)
        if session is None:
            return None
        return self._map_auth_session(response)

    def _map_auth_session(self, response: Any) -> AuthSession:
        session = self._extract_session(response)
        user = getattr(response, "user", None)
        if session is None or user is None:
            raise AuthenticationError("Supabase did not return a valid session")

        return AuthSession(
            access_token=session.access_token,
            refresh_token=getattr(session, "refresh_token", None),
            user=AuthenticatedUser(id=user.id, email=user.email or ""),
        )

    @staticmethod
    def _extract_session(response: Any) -> Any | None:
        return getattr(response, "session", None)

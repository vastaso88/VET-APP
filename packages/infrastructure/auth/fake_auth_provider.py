from packages.core.application.ports.auth_provider import AuthenticatedUser, AuthProvider


class FakeAuthProvider(AuthProvider):
    def get_current_user(self) -> AuthenticatedUser:
        return AuthenticatedUser(id="demo-user", email="demo@vetapp.local")

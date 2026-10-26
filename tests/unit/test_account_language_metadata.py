from types import SimpleNamespace
from typing import Any

import pytest

from packages.core.domain.localization import SupportedLocale
from packages.infrastructure.auth import supabase_auth_provider as module


class _Admin:
    def __init__(self, user: SimpleNamespace) -> None:
        self.user = user
        self.updated_id: str | None = None

    def get_user_by_id(self, user_id: str) -> SimpleNamespace:
        assert user_id == self.user.id
        return SimpleNamespace(user=self.user)

    def update_user_by_id(self, user_id: str, attributes: dict[str, Any]) -> None:
        self.updated_id = user_id
        self.user.user_metadata = attributes["user_metadata"]


class _Auth:
    def __init__(self, user: SimpleNamespace) -> None:
        self.admin = _Admin(user)
        self.user = user

    def get_user(self, token: str) -> SimpleNamespace:
        assert token == "test-token"
        return SimpleNamespace(user=self.user)


@pytest.mark.parametrize("locale", ["it", "en", "es"])
def test_update_authenticates_owner_and_preserves_other_metadata(
    locale: SupportedLocale, monkeypatch: pytest.MonkeyPatch
) -> None:
    user = SimpleNamespace(
        id="authenticated-owner",
        email="owner@example.test",
        user_metadata={
            "display_name": "Owner",
            "onboarding_completed": True,
            "preferred_locale_variant": "en-US",
        },
    )
    client: Any = SimpleNamespace(auth=_Auth(user))
    monkeypatch.setattr(module, "_SUPABASE_IMPORT_ERROR", None)
    monkeypatch.setattr(module, "get_access_token", lambda: "test-token")
    provider = module.SupabaseAuthProvider(client, client)

    result = provider.update_preferred_locale(locale)

    assert result.preferred_locale == locale
    assert client.auth.admin.updated_id == "authenticated-owner"
    assert user.user_metadata == {
        "display_name": "Owner",
        "onboarding_completed": True,
        "preferred_locale": locale,
    }


@pytest.mark.parametrize(
    "metadata", [{}, {"preferred_locale": "unknown"}, {"preferred_locale": 123}]
)
def test_old_or_malformed_preferences_fall_back_to_italian(
    metadata: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    user = SimpleNamespace(id="owner", email="owner@example.test", user_metadata=metadata)
    client: Any = SimpleNamespace(auth=_Auth(user))
    monkeypatch.setattr(module, "_SUPABASE_IMPORT_ERROR", None)
    monkeypatch.setattr(module, "get_access_token", lambda: "test-token")
    assert module.SupabaseAuthProvider(client, client).get_current_user().preferred_locale == "it"

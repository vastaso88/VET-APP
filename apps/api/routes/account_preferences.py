from fastapi import APIRouter
from pydantic import BaseModel

from apps.api.dependencies.container import get_container
from packages.core.domain.localization import SupportedLocale

router = APIRouter(prefix="/account/preferences", tags=["account"])


class AccountPreferences(BaseModel):
    preferred_locale: SupportedLocale = "it"


class UpdateAccountPreferences(BaseModel):
    preferred_locale: SupportedLocale


@router.get("")
def get_preferences() -> AccountPreferences:
    user = get_container().auth_provider.get_current_user()
    return AccountPreferences(preferred_locale=user.preferred_locale)


@router.put("")
def update_preferences(request: UpdateAccountPreferences) -> AccountPreferences:
    user = get_container().auth_provider.update_preferred_locale(request.preferred_locale)
    return AccountPreferences(preferred_locale=user.preferred_locale)

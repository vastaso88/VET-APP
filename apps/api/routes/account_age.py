from datetime import date

from fastapi import APIRouter
from pydantic import BaseModel

from apps.api.dependencies.container import get_container
from packages.infrastructure.auth.age_guarded_auth_provider import (
    AgeGuardedAuthProvider,
    allow_closed_account,
)

router = APIRouter(prefix="/account", tags=["account-age"])


class DeclareAgeRequest(BaseModel):
    birth_date: date


def _forget_cached_answer(owner_id: str) -> None:
    provider = get_container().auth_provider
    if isinstance(provider, AgeGuardedAuthProvider):
        provider.forget(owner_id)


@router.get("/age")
def get_age_status() -> dict[str, object]:
    """The band and what it unlocks. The date itself is never returned: not
    to the app, not to anyone. A closed account may still read this (it is how
    the app knows to show the closure message)."""
    container = get_container()
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    body: dict[str, object] = container.age_gate_service().status(user.id).model_dump()
    # A closed account cannot reach the other routes, so the way to write to
    # support (to correct a mistyped date) comes with its status.
    body["support_contact_email"] = container.settings.support_contact_email.strip() or None
    return body


@router.post("/age")
def declare_age(request: DeclareAgeRequest) -> dict[str, object]:
    """Records the declared date of birth, once. 409 `age_already_declared`
    afterwards: a correction goes through support (right to rectification),
    otherwise a minor could simply type another date. A date under the
    minimum is kept too, because it is what keeps the account closed."""
    container = get_container()
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    status = container.age_gate_service().declare(user.id, request.birth_date)
    _forget_cached_answer(user.id)
    return status.model_dump()


@router.post("/guardian-authorization")
def confirm_guardian_authorization() -> dict[str, object]:
    """A declared minor says they have a parent's authorisation for a paid
    plan. Recorded with the date; nothing else is asked."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    return container.age_gate_service().confirm_guardian(user.id).model_dump()

from datetime import date

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _require_admin
from packages.infrastructure.auth.age_guarded_auth_provider import AgeGuardedAuthProvider

router = APIRouter(prefix="/admin/age", tags=["admin"])


class EraseRequest(BaseModel):
    # Must repeat the account's reference: the portal asks for it to be typed.
    confirm: str = Field(min_length=1, max_length=100)


class CorrectDateRequest(BaseModel):
    birth_date: date


class CorrectionRequestedRequest(BaseModel):
    requested: bool


def _not_found() -> HTTPException:
    return HTTPException(status_code=404, detail="Closed account not found")


@router.get("/closed")
def closed_accounts() -> dict[str, object]:
    """Accounts that declared an age under the minimum, oldest first: a keyed
    reference, when it was closed, the days since, whether it is past 30 days,
    whether a correction was requested and a hint of the e-mail. No id, no date
    of birth. Same admin protection as the other portal routes."""
    _require_admin()
    accounts = get_container().age_review_admin_service().closed_accounts()
    return {"accounts": [account.model_dump(mode="json") for account in accounts]}


@router.post("/closed/{ref}/erase")
def erase_closed_account(ref: str, request: EraseRequest) -> dict[str, object]:
    """Erases the account and every piece of its data with the same eraser as
    the owner's own deletion. The answer is the numbers, nothing else."""
    _require_admin()
    outcome = get_container().age_review_admin_service().erase(ref, request.confirm)
    if outcome is None:
        raise _not_found()
    return {"erased": True, "outcome": outcome.model_dump()}


@router.post("/closed/{ref}/correct")
def correct_closed_account(ref: str, request: CorrectDateRequest) -> dict[str, object]:
    """Support's correction of a mistyped date. If it makes the owner 14 or
    over, the account opens again (within a minute: the closure is cached)."""
    _require_admin()
    container = get_container()
    corrected = container.age_review_admin_service().correct_birth_date(ref, request.birth_date)
    if corrected is None:
        raise _not_found()
    provider = container.auth_provider
    if isinstance(provider, AgeGuardedAuthProvider):
        provider.forget(corrected.owner_id)
    return {"corrected": True, "band": corrected.band}


@router.post("/closed/{ref}/correction-requested")
def mark_correction_requested(ref: str, request: CorrectionRequestedRequest) -> dict[str, object]:
    """Notes that the owner wrote to say the date was a mistake (or clears the
    note). While it is set, the account cannot be erased from the portal."""
    _require_admin()
    done = (
        get_container().age_review_admin_service().set_correction_requested(ref, request.requested)
    )
    if not done:
        raise _not_found()
    return {"correction_requested": request.requested}

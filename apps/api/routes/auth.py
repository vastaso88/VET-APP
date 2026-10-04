from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from apps.api.schemas.auth import AuthCredentialsRequest

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup")
def sign_up(request: AuthCredentialsRequest) -> dict[str, object]:
    result = get_container().auth_provider.sign_up(request.email, request.password)
    if result is None:
        return {"detail": "Signup completed. Confirm email if required by Supabase."}
    return result.model_dump()


@router.post("/login")
def sign_in(request: AuthCredentialsRequest) -> dict[str, object]:
    result = get_container().auth_provider.sign_in_with_password(request.email, request.password)
    return result.model_dump()


@router.get("/me")
def get_me() -> dict[str, str]:
    user = get_container().auth_provider.get_current_user()
    # Same body as before the user gained an optional display name.
    return user.model_dump(include={"id", "email"})

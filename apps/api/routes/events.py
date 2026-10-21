from datetime import date
from typing import Annotated

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from packages.core.application.services.submit_event import (
    SubmissionLimitReachedError,
    SubmitEventInput,
)

router = APIRouter(prefix="/events", tags=["events"])


class SubmitEventRequest(BaseModel):
    title: Annotated[str, Field(max_length=200)]
    event_type: Annotated[str, Field(max_length=40)]
    starts_on: date
    ends_on: date
    city: Annotated[str, Field(max_length=200)]
    source_url: Annotated[str, Field(max_length=500)]
    province_code: Annotated[str | None, Field(max_length=4)] = None
    region: Annotated[str | None, Field(max_length=60)] = None
    venue_name: Annotated[str | None, Field(max_length=200)] = None


@router.post("/submissions", status_code=201, response_model=None)
def submit_event(request: SubmitEventRequest) -> JSONResponse | dict[str, str]:
    """ "Segnala un evento": the suggestion waits for the team's check and is
    not public until then. Needs a signed-in user (limits abuse); the author is
    never shown. Invalid input answers 400 with a message for the user."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        submission = container.submit_event_service().execute(
            SubmitEventInput(owner_id=user.id, **request.model_dump())
        )
    except SubmissionLimitReachedError as exc:
        return JSONResponse(
            status_code=429, content={"detail": str(exc), "code": "submission_limit_reached"}
        )
    return {"submission_id": submission.id, "status": submission.status}

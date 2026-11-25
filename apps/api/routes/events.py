from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.dependencies.subscription import require_active_subscription
from apps.api.request_language import request_language
from packages.core.application.services.list_events import ListEventsInput
from packages.core.application.services.submit_event import (
    SubmissionLimitReachedError,
    SubmitEventInput,
)
from packages.core.domain.events.abroad import ABROAD_RADIUS_KM

router = APIRouter(prefix="/events", tags=["events"])


@router.get("", dependencies=[Depends(require_active_subscription)])
def list_events(
    country: Annotated[str, Query(min_length=2, max_length=2)],
    from_day: Annotated[date, Query(alias="from")],
    to_day: Annotated[date, Query(alias="to")],
    abroad: bool = False,
) -> dict[str, object]:
    """The public events of [country] that touch the window. Part of what a
    plan includes: after the trial an owner without a plan gets 402.

    `country_has_events` tells an empty month from a country the catalogue does not cover.

    With [abroad] (the app sends it; without it nothing changes) also the international events
    of other countries and those within `abroad_radius_km` of the signed-in owner's saved
    Località. The position is read here from the owner's own row: it is never a parameter,
    and neither it nor a distance is in the answer."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_events_service().execute(
        ListEventsInput(
            country=country,
            from_day=from_day,
            to_day=to_day,
            abroad_for_owner=user.id if abroad else None,
        )
    )
    answer: dict[str, object] = {
        "events": result.events,
        "country_has_events": result.country_has_events,
    }
    if abroad:
        answer["abroad_radius_km"] = ABROAD_RADIUS_KM
    return answer


class SubmitEventRequest(BaseModel):
    title: Annotated[str, Field(max_length=200)]
    event_type: Annotated[str, Field(max_length=40)]
    starts_on: date
    ends_on: date
    city: Annotated[str, Field(max_length=200)]
    source_url: Annotated[str, Field(max_length=500)]
    country: Annotated[str | None, Field(max_length=2)] = None
    province_code: Annotated[str | None, Field(max_length=4)] = None
    region: Annotated[str | None, Field(max_length=60)] = None
    venue_name: Annotated[str | None, Field(max_length=200)] = None


@router.post(
    "/submissions",
    status_code=201,
    response_model=None,
    dependencies=[Depends(require_active_subscription)],
)
def submit_event(
    request: SubmitEventRequest, http_request: Request
) -> JSONResponse | dict[str, str]:
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
            status_code=429,
            content={
                "detail": str(exc),
                "code": "submission_limit_reached",
                "message": exc.message(request_language(http_request)),
            },
        )
    return {"submission_id": submission.id, "status": submission.status}

from typing import Annotated

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from packages.core.application.services.geocoding import GeocodingRateLimitedError
from packages.shared.errors.base import ProviderError

# POST with a JSON body, not GET with query parameters: request URLs end
# up in the hosting provider's access logs, and these are home addresses
# and positions (security audit APP-6).
router = APIRouter(prefix="/geocoding", tags=["geocoding"])

_LANGUAGE = r"^[a-zA-Z]{2}(-[a-zA-Z]{2})?$"


class SearchRequest(BaseModel):
    query: Annotated[str, Field(min_length=2, max_length=300)]
    country_code: Annotated[str | None, Field(pattern=r"^[a-zA-Z]{2}$")] = None
    language: Annotated[str | None, Field(pattern=_LANGUAGE)] = None


class ReverseRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    # 18 = building, 14 = neighbourhood; no coarser or finer levels needed.
    zoom: int = Field(default=18, ge=10, le=18)
    language: Annotated[str | None, Field(pattern=_LANGUAGE)] = None


def _refused(status_code: int, code: str, detail: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"detail": detail, "code": code})


@router.post("/search", response_model=None)
def search_address(body: SearchRequest) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        results = container.geocoding_service.search(
            user.id, body.query, country_code=body.country_code, language=body.language
        )
    except GeocodingRateLimitedError as exc:
        return _refused(429, "geocoding_rate_limited", str(exc))
    except ProviderError as exc:
        return _refused(503, "geocoding_unavailable", str(exc))
    return {"results": [place.model_dump() for place in results]}


@router.post("/reverse", response_model=None)
def reverse_geocode(body: ReverseRequest) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        place = container.geocoding_service.reverse(
            user.id, body.latitude, body.longitude, zoom=body.zoom, language=body.language
        )
    except GeocodingRateLimitedError as exc:
        return _refused(429, "geocoding_rate_limited", str(exc))
    except ProviderError as exc:
        return _refused(503, "geocoding_unavailable", str(exc))
    return {"result": place.model_dump() if place is not None else None}

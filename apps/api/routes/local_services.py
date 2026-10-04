from typing import Annotated, Literal

from fastapi import APIRouter, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from packages.core.application.services.list_nearby_radar_places import (
    ListNearbyRadarPlacesInput,
)
from packages.core.application.services.radar_reports import (
    ContributionRulesRequiredError,
    RateDogParkInput,
    ReportLimitReachedError,
    SubmitRadarReportInput,
    VoteRadarReportInput,
)
from packages.core.domain.radar_places.models import (
    RADAR_PLACE_API_EXCLUDED_FIELDS,
    RadarDataSource,
    RadarPlaceType,
)
from packages.core.domain.radar_reports.models import RadarUserReport, ReportKind
from packages.shared.errors.base import ValidationError

router = APIRouter(prefix="/local-services", tags=["local-services"])


class SubmitReportRequest(BaseModel):
    kind: ReportKind
    place_type: RadarPlaceType
    name: str | None = Field(default=None, max_length=120)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    address_label: str | None = Field(default=None, max_length=160)
    target_source: str | None = Field(default=None, max_length=60)
    target_source_id: str | None = Field(default=None, max_length=120)


class VoteReportRequest(BaseModel):
    vote: Literal["confirm", "deny"]


class RatePlaceRequest(BaseModel):
    source: str = Field(max_length=60)
    source_id: str = Field(max_length=120)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    stars: int = Field(ge=1, le=5)


def _source_payload(source: RadarDataSource) -> dict[str, object]:
    return source.model_dump(
        mode="json",
        include={"source", "release", "license", "attribution", "url", "imported_at"},
    )


def _report_payload(report: RadarUserReport, *, required: int) -> dict[str, object]:
    # Never the reporter: not even as a pseudonym.
    return {
        "report_id": report.id,
        "kind": report.kind,
        "status": report.status,
        "confirmations": max(0, report.confirmations - report.denials),
        "required": required,
    }


def _contributions_off() -> JSONResponse:
    return JSONResponse(
        status_code=503,
        content={
            "detail": "Segnalazioni e voti non sono ancora attivi.",
            "code": "contributions_disabled",
        },
    )


def _rules_required(exc: ContributionRulesRequiredError) -> JSONResponse:
    return JSONResponse(
        status_code=403, content={"detail": str(exc), "code": "contribution_rules_required"}
    )


# Deliberately no bulk/export variant of this route: the data comes from
# open datasets (OpenStreetMap is ODbL), and serving it only as bounded,
# distance-filtered results keeps the app a "produced work" rather than a
# redistributed derivative database (docs/features/radar_places_overpass.md).
@router.get("/places")
def list_nearby_places(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    radius_km: Annotated[float | None, Query(gt=0)] = None,
    place_type: Annotated[list[RadarPlaceType] | None, Query()] = None,
    per_type_limit: Annotated[int, Query(ge=1, le=400)] = 60,
) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_nearby_radar_places_service().execute(
        ListNearbyRadarPlacesInput(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            place_types=list(place_type or []),
            per_type_limit=per_type_limit,
            viewer_id=user.id,
        )
    )
    return {
        "places": [
            {
                **item.place.model_dump(mode="json", exclude=set(RADAR_PLACE_API_EXCLUDED_FIELDS)),
                "distance_km": round(item.distance_km, 3),
                **result.extras.get(item.place.id, {}),
            }
            for item in result.places
        ],
        "coverage": {
            "coverage_key": result.coverage_key,
            "status": result.coverage_status,
            "refreshed_at": result.refreshed_at,
        },
        "context": {
            "search_radius_km": result.search_radius_km,
        },
        "sources": [_source_payload(source) for source in result.sources],
    }


@router.get("/sources")
def list_data_sources() -> dict[str, object]:
    """Datasets behind the radar, for the app's "Fonti dati" page."""
    container = get_container()
    container.auth_provider.get_current_user()
    return {
        "sources": [
            _source_payload(source) for source in container.radar_catalog_repository.list_sources()
        ],
        # Where to ask for a correction or removal; null when not configured.
        "support_contact_email": container.settings.support_contact_email.strip() or None,
    }


@router.get("/reports/options")
def report_options() -> dict[str, object]:
    """What "Segnala!" currently accepts, so the app's form follows the
    server's configuration without a new build."""
    container = get_container()
    container.auth_provider.get_current_user()
    settings = container.radar_report_settings()
    return {
        "enabled": settings is not None,
        "missing_place_types": sorted(settings.missing_place_types) if settings else [],
        "confirmations_required": settings.confirmations_required if settings else None,
    }


@router.post("/reports", response_model=None)
def submit_report(request: SubmitReportRequest) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    service = container.submit_radar_report_service()
    settings = container.radar_report_settings()
    if service is None or settings is None:
        return _contributions_off()
    try:
        result = service.execute(SubmitRadarReportInput(user_id=user.id, **request.model_dump()))
    except ContributionRulesRequiredError as exc:
        return _rules_required(exc)
    except ReportLimitReachedError as exc:
        return JSONResponse(
            status_code=429, content={"detail": str(exc), "code": "report_limit_reached"}
        )
    return {
        **_report_payload(result.report, required=settings.required_for(result.report.kind)),
        "counted_as_confirmation": result.counted_as_confirmation,
    }


@router.post("/reports/{report_id}/vote", response_model=None)
def vote_report(report_id: str, request: VoteReportRequest) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    service = container.vote_radar_report_service()
    settings = container.radar_report_settings()
    if service is None or settings is None:
        return _contributions_off()
    try:
        report = service.execute(
            VoteRadarReportInput(
                user_id=user.id, report_id=report_id, confirm=request.vote == "confirm"
            )
        )
    except ContributionRulesRequiredError as exc:
        return _rules_required(exc)
    return _report_payload(report, required=settings.required_for(report.kind))


@router.put("/ratings", response_model=None)
def rate_place(request: RatePlaceRequest) -> dict[str, object] | JSONResponse:
    """Stars for a public dog park. The place is looked up in our own data
    rather than trusted from the request: only a dog park that exists
    there can be rated."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    service = container.rate_dog_park_service()
    if service is None:
        return _contributions_off()
    nearby = container.list_nearby_radar_places_service().execute(
        ListNearbyRadarPlacesInput(
            latitude=request.latitude,
            longitude=request.longitude,
            radius_km=0.3,
            place_types=["dog_park"],
            per_type_limit=400,
        )
    )
    place = next(
        (
            item.place
            for item in nearby.places
            if item.place.source_name == request.source
            and item.place.source_external_id == request.source_id
        ),
        None,
    )
    if place is None:
        raise ValidationError("Area cani non trovata.")
    try:
        service.execute(RateDogParkInput(user_id=user.id, place=place, stars=request.stars))
    except ContributionRulesRequiredError as exc:
        return _rules_required(exc)
    return {"stars": request.stars}

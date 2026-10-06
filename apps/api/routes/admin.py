import hashlib
from collections import Counter
from datetime import UTC, datetime
from typing import Any, Literal
from urllib.parse import urlsplit
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status
from postgrest.types import CountMethod
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container

router = APIRouter(prefix="/admin", tags=["admin"])


class GeographicIngestionRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius_km: float = Field(gt=0, le=50)


class ChatModerationRequest(BaseModel):
    status: Literal["under_review", "resolved", "wont_fix"]
    resolution_note: str | None = Field(default=None, max_length=1000)


class ScientificDiscoveryRequest(BaseModel):
    query: str = Field(min_length=2, max_length=500)
    species: Literal[
        "dog",
        "cat",
        "small_mammal",
        "bird",
        "reptile_amphibian",
        "fish",
        "other",
    ] = "dog"
    intent: Literal[
        "clinical_question",
        "nutrition_question",
        "behavior_question",
        "preventive_care",
    ] = "clinical_question"
    max_results: int = Field(default=10, ge=1, le=20)


def _configured_admin_emails() -> frozenset[str]:
    settings = get_container().settings
    configured = settings.admin_emails or settings.developer_emails
    return frozenset(email.strip().lower() for email in configured if email.strip())


def _require_admin() -> Any:
    emails = _configured_admin_emails()
    if not emails:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin access is not configured",
        )

    user = get_container().auth_provider.get_current_user()
    if not user.email or user.email.strip().lower() not in emails:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def _admin_client() -> Any:
    container = get_container()
    if container.settings.persistence_backend != "supabase":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin operations require PERSISTENCE_BACKEND=supabase",
        )

    # Lazy import keeps the API bootstrap usable in the in-memory runtime.
    from packages.infrastructure.persistence.supabase.client import build_supabase_client

    return build_supabase_client(container.settings)


def _count_rows(query: Any) -> int:
    response = query.range(0, 0).execute()
    count = getattr(response, "count", None)
    return int(count or 0)


def _count_auth_users(client: Any) -> int:
    total = 0
    page = 1
    per_page = 1000

    while page <= 100:
        response = client.auth.admin.list_users(page=page, per_page=per_page)
        if isinstance(response, list):
            users = response
        else:
            users = getattr(response, "users", None) or []
        total += len(users)
        if len(users) < per_page:
            break
        page += 1

    return total


def _geographic_input(request: GeographicIngestionRequest) -> tuple[Any, float, float]:
    from packages.core.application.services.list_nearby_radar_places import (
        SHARED_RADAR_OWNER_ID,
    )
    from packages.core.application.services.request_radar_places_ingestion import (
        RequestRadarPlacesIngestionInput,
    )
    from packages.core.domain.coverage.models import ingestion_radius_km, tier_for_radius

    container = get_container()
    max_radius = container.settings.radar_search_radius_km
    if request.radius_km > max_radius:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"radius_km exceeds configured maximum ({max_radius:g} km)",
        )

    tier = tier_for_radius(request.radius_km, max_search_radius_km=max_radius)
    ingestion_radius = ingestion_radius_km(
        tier,
        latitude=request.latitude,
        longitude=request.longitude,
    )
    located = RequestRadarPlacesIngestionInput(
        owner_id=SHARED_RADAR_OWNER_ID,
        center_latitude=request.latitude,
        center_longitude=request.longitude,
        radius_km=ingestion_radius,
        freshness_ttl_hours=container.settings.radar_freshness_ttl_hours,
        cell_size_degrees=tier.cell_size_degrees,
    )
    center = located.coverage_window().cell_center
    ingestion = located.model_copy(
        update={
            "center_latitude": center.latitude,
            "center_longitude": center.longitude,
        }
    )
    return ingestion, request.radius_km, ingestion_radius


def _geographic_result_payload(
    *,
    ingestion: Any,
    search_radius_km: float,
    ingestion_radius_km: float,
    places: list[Any],
    existing: Any | None,
) -> dict[str, object]:
    counts = Counter(place.place_type for place in places)
    window = ingestion.coverage_window()
    return {
        "source": get_container().radar_places_source.name,
        "coverage_key": window.coverage_key,
        "center": {
            "latitude": ingestion.center_latitude,
            "longitude": ingestion.center_longitude,
        },
        "search_radius_km": search_radius_km,
        "ingestion_radius_km": ingestion_radius_km,
        "place_count": len(places),
        "by_type": dict(sorted(counts.items())),
        "existing_coverage": (
            {
                "place_count": existing.place_count,
                "refreshed_at": existing.refreshed_at.isoformat(),
                "expires_at": existing.expires_at.isoformat(),
            }
            if existing is not None
            else None
        ),
        "sample": [
            {
                "name": place.name,
                "place_type": place.place_type,
                "subtype": place.subtype,
                "city": place.city,
                "address_label": place.address_label,
                "latitude": place.latitude,
                "longitude": place.longitude,
                "source_external_id": place.source_external_id,
            }
            for place in places[:20]
        ],
    }


_SCIENTIFIC_DISCOVERY_HOSTS = frozenset(
    {
        "doi.org",
        "europepmc.org",
        "openalex.org",
        "pmc.ncbi.nlm.nih.gov",
        "pubmed.ncbi.nlm.nih.gov",
    }
)


def _retrieve_scientific_evidence(request: ScientificDiscoveryRequest) -> tuple[Any, list[Any]]:
    from packages.core.application.ports.evidence_retriever import (
        EvidenceRetrievalRequest,
    )

    container = get_container()
    evidence = container.evidence_retriever.retrieve(
        EvidenceRetrievalRequest(
            query=request.query,
            species=request.species,
            intent=request.intent,
            max_results=request.max_results,
        )
    )
    return container, evidence


def _scientific_domain_host(source_url: str | None, doi: str | None, pmid: str | None) -> str | None:
    host = ""
    if source_url:
        try:
            host = (urlsplit(source_url).hostname or "").lower()
        except ValueError:
            host = ""
    if host in _SCIENTIFIC_DISCOVERY_HOSTS:
        return host
    if pmid:
        return "pubmed.ncbi.nlm.nih.gov"
    if doi:
        return "doi.org"
    return None


def _scientific_canonical_url(source_url: str | None, doi: str | None, pmid: str | None) -> str | None:
    if doi:
        normalized = doi.strip().lower()
        for prefix in ("https://doi.org/", "http://doi.org/", "doi:"):
            if normalized.startswith(prefix):
                normalized = normalized.removeprefix(prefix)
        if normalized:
            return f"https://doi.org/{normalized}"
    if pmid and pmid.strip():
        return f"https://pubmed.ncbi.nlm.nih.gov/{pmid.strip()}/"
    return source_url.strip() if source_url and source_url.strip() else None


def _scientific_catalog_payload(client: Any, limit_count: int = 50) -> dict[str, object]:
    response = client.rpc("admin_scientific_catalog", {"limit_count": limit_count}).execute()
    data = getattr(response, "data", None)
    if isinstance(data, dict):
        return data
    if isinstance(data, list) and data and isinstance(data[0], dict):
        # Defensive compatibility for PostgREST/client versions that wrap a scalar JSON result.
        return data[0]
    return {
        "metrics": {
            "trusted_domains": 0,
            "documents": 0,
            "eligible_for_rag": 0,
            "embedded": 0,
            "chunks": 0,
        },
        "recent_documents": [],
    }


@router.get("/me")
def admin_me() -> dict[str, str]:
    user = _require_admin()
    return {"id": user.id, "email": user.email}


@router.get("/overview")
def admin_overview() -> dict[str, object]:
    _require_admin()
    client = _admin_client()

    users = _count_auth_users(client)
    pets = _count_rows(client.table("pet_profiles").select("id", count=CountMethod.exact))
    conversations = _count_rows(client.table("conversations").select("id", count=CountMethod.exact))
    radar_osm = _count_rows(client.table("radar_places_osm").select("id", count=CountMethod.exact))
    radar_open = _count_rows(
        client.table("radar_places_open").select("id", count=CountMethod.exact)
    )
    radar_reports = _count_rows(
        client.table("radar_user_reports")
        .select("id", count=CountMethod.exact)
        .eq("status", "pending")
    )
    chat_reports = _count_rows(
        client.table("chat_response_reports")
        .select("id", count=CountMethod.exact)
        .in_("status", ["reported", "under_review"])
    )
    marketplace_reports = _count_rows(
        client.table("marketplace_listing_reports").select("id", count=CountMethod.exact)
    )
    scrape_runs = _count_rows(client.table("scrape_runs").select("id", count=CountMethod.exact))

    sources_response = (
        client.table("data_sources")
        .select("source,release,place_count,imported_at")
        .order("source")
        .execute()
    )
    recent_runs_response = (
        client.table("scrape_runs")
        .select(
            "id,engine,status,coverage_key,source_names,place_count,error_message,"
            "requested_at,started_at,finished_at"
        )
        .order("created_at", desc=True)
        .limit(5)
        .execute()
    )

    return {
        "metrics": {
            "users": users,
            "pets": pets,
            "conversations": conversations,
            "radar_places": radar_osm + radar_open,
            "radar_osm": radar_osm,
            "radar_open": radar_open,
            "open_moderation": radar_reports + chat_reports + marketplace_reports,
            "scrape_runs": scrape_runs,
        },
        "moderation": {
            "radar_reports": radar_reports,
            "chat_reports": chat_reports,
            "marketplace_reports": marketplace_reports,
        },
        "data_sources": getattr(sources_response, "data", None) or [],
        "recent_runs": getattr(recent_runs_response, "data", None) or [],
    }


@router.get("/moderation")
def admin_moderation() -> dict[str, object]:
    _require_admin()
    client = _admin_client()

    radar_response = (
        client.table("radar_user_reports")
        .select(
            "id,kind,status,place_type,name,latitude,longitude,address_label,"
            "target_source,target_source_id,confirmations,denials,created_at,resolved_at"
        )
        .order("created_at", desc=True)
        .limit(100)
        .execute()
    )
    chat_response = (
        client.table("chat_response_reports")
        .select(
            "id,conversation_id,message_id,pet_id,reason,details,reported_answer,"
            "status,created_at,resolved_at,resolution_note,credited_bug_ref"
        )
        .order("created_at", desc=True)
        .limit(100)
        .execute()
    )
    marketplace_response = (
        client.table("marketplace_listing_reports")
        .select("id,listing_id,reason,created_at")
        .order("created_at", desc=True)
        .limit(100)
        .execute()
    )

    marketplace_reports = list(getattr(marketplace_response, "data", None) or [])
    listing_ids = sorted(
        {
            str(item["listing_id"])
            for item in marketplace_reports
            if item.get("listing_id") is not None
        }
    )
    listings_by_id: dict[str, dict[str, object]] = {}
    if listing_ids:
        listings_response = (
            client.table("marketplace_listings")
            .select("id,title,status,report_count,category,city_label,created_at")
            .in_("id", listing_ids)
            .execute()
        )
        listings_by_id = {
            str(item["id"]): item for item in (getattr(listings_response, "data", None) or [])
        }

    for report in marketplace_reports:
        report["listing"] = listings_by_id.get(str(report.get("listing_id")))

    return {
        "radar": getattr(radar_response, "data", None) or [],
        "chat": getattr(chat_response, "data", None) or [],
        "marketplace": marketplace_reports,
    }


@router.post("/moderation/chat/{report_id}")
def admin_resolve_chat_report(
    report_id: str,
    request: ChatModerationRequest,
) -> dict[str, object]:
    _require_admin()

    from packages.core.application.services.resolve_chat_response_report import (
        ResolveChatResponseReportInput,
    )

    result = get_container().resolve_chat_response_report_service().execute(
        ResolveChatResponseReportInput(
            report_id=report_id,
            status=request.status,
            resolution_note=request.resolution_note,
        )
    )
    return {
        "report": result.report.model_dump(
            mode="json",
            exclude={"reporter_ref", "reporter_owner_id"},
        )
    }


@router.get("/geographic")
def admin_geographic() -> dict[str, object]:
    _require_admin()
    client = _admin_client()

    sources_response = (
        client.table("data_sources")
        .select(
            "source,release,license,attribution,url,place_count,imported_at,"
            "min_latitude,max_latitude,min_longitude,max_longitude"
        )
        .order("source")
        .execute()
    )
    coverage_response = (
        client.table("radar_coverage_cells")
        .select(
            "coverage_key,center_latitude,center_longitude,radius_km,source_name,"
            "place_count,refreshed_at,expires_at"
        )
        .order("refreshed_at", desc=True)
        .limit(50)
        .execute()
    )

    return {
        "counts": {
            "osm": _count_rows(
                client.table("radar_places_osm").select("id", count=CountMethod.exact)
            ),
            "open": _count_rows(
                client.table("radar_places_open").select("id", count=CountMethod.exact)
            ),
            "cache": _count_rows(
                client.table("radar_places_cache").select("id", count=CountMethod.exact)
            ),
        },
        "sources": getattr(sources_response, "data", None) or [],
        "coverage": getattr(coverage_response, "data", None) or [],
    }


@router.post("/geographic/preview")
def admin_geographic_preview(
    request: GeographicIngestionRequest,
) -> dict[str, object]:
    _require_admin()
    container = get_container()
    ingestion, search_radius, ingestion_radius = _geographic_input(request)
    existing = container.radar_places_repository.get_coverage(
        ingestion.coverage_window().coverage_key
    )

    try:
        places = container.radar_places_source.fetch_places(ingestion)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Geographic preview failed: {str(exc)[:500]}",
        ) from exc

    return _geographic_result_payload(
        ingestion=ingestion,
        search_radius_km=search_radius,
        ingestion_radius_km=ingestion_radius,
        places=places,
        existing=existing,
    )


@router.post("/geographic/execute")
def admin_geographic_execute(
    request: GeographicIngestionRequest,
) -> dict[str, object]:
    admin = _require_admin()
    container = get_container()
    client = _admin_client()
    ingestion, search_radius, ingestion_radius = _geographic_input(request)
    coverage_key = ingestion.coverage_window().coverage_key
    existing = container.radar_places_repository.get_coverage(coverage_key)

    from packages.core.application.services.request_radar_places_ingestion import (
        RequestRadarPlacesIngestionService,
    )

    job_id = str(uuid4())
    now = datetime.now(UTC).isoformat()
    source_name = container.radar_places_source.name
    client.table("scrape_runs").insert(
        {
            "id": job_id,
            "job_id": job_id,
            "engine": "admin_places",
            "owner_id": admin.id,
            "coverage_key": coverage_key,
            "status": "running",
            "search_radius_km": search_radius,
            "ingestion_radius_km": ingestion_radius,
            "freshness_ttl_hours": container.settings.radar_freshness_ttl_hours,
            "source_names": [source_name],
            "place_count": 0,
            "requested_at": now,
            "started_at": now,
            "created_at": now,
            "updated_at": now,
        }
    ).execute()

    try:
        result = RequestRadarPlacesIngestionService(
            container.radar_places_repository,
            container.radar_places_source,
        ).execute(ingestion)
    except Exception as exc:
        finished = datetime.now(UTC).isoformat()
        client.table("scrape_runs").update(
            {
                "status": "failed",
                "error_message": str(exc)[:2000],
                "finished_at": finished,
                "updated_at": finished,
            }
        ).eq("id", job_id).execute()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Geographic ingestion failed: {str(exc)[:500]}",
        ) from exc

    finished = datetime.now(UTC).isoformat()
    client.table("scrape_runs").update(
        {
            "status": "completed",
            "place_count": len(result.places),
            "error_message": None,
            "finished_at": finished,
            "updated_at": finished,
        }
    ).eq("id", job_id).execute()

    payload = _geographic_result_payload(
        ingestion=ingestion,
        search_radius_km=search_radius,
        ingestion_radius_km=ingestion_radius,
        places=result.places,
        existing=existing,
    )
    payload["job_id"] = job_id
    payload["refreshed_at"] = result.coverage.refreshed_at.isoformat()
    payload["expires_at"] = result.coverage.expires_at.isoformat()
    return payload


@router.get("/jobs")
def admin_jobs() -> dict[str, object]:
    _require_admin()
    client = _admin_client()
    response = (
        client.table("scrape_runs")
        .select(
            "id,job_id,engine,owner_id,coverage_key,status,search_radius_km,"
            "ingestion_radius_km,freshness_ttl_hours,source_names,place_count,"
            "error_message,requested_at,started_at,finished_at,created_at,updated_at"
        )
        .order("created_at", desc=True)
        .limit(100)
        .execute()
    )
    return {"jobs": getattr(response, "data", None) or []}


@router.get("/scientific")
def admin_scientific_catalog() -> dict[str, object]:
    _require_admin()
    return _scientific_catalog_payload(_admin_client())


@router.post("/scientific/discover")
def admin_scientific_discover(
    request: ScientificDiscoveryRequest,
) -> dict[str, object]:
    _require_admin()
    container, evidence = _retrieve_scientific_evidence(request)
    return {
        "backend": container.settings.evidence_backend,
        "results": [item.model_dump(mode="json") for item in evidence],
    }


@router.post("/scientific/ingest")
def admin_scientific_ingest(
    request: ScientificDiscoveryRequest,
) -> dict[str, object]:
    admin = _require_admin()
    client = _admin_client()
    container, evidence = _retrieve_scientific_evidence(request)

    job_id = str(uuid4())
    now = datetime.now(UTC).isoformat()
    query_key = hashlib.sha256(
        f"{request.species}|{request.intent}|{request.query.strip().lower()}".encode("utf-8")
    ).hexdigest()[:16]
    coverage_key = f"scientific:{request.species}:{query_key}"
    backend = container.settings.evidence_backend

    client.table("scrape_runs").insert(
        {
            "id": job_id,
            "job_id": job_id,
            "engine": "scientific_papers",
            "owner_id": admin.id,
            "coverage_key": coverage_key,
            "status": "running",
            "source_names": [backend],
            "place_count": 0,
            "requested_at": now,
            "started_at": now,
            "created_at": now,
            "updated_at": now,
        }
    ).execute()

    rows: list[dict[str, object]] = []
    for item in evidence:
        canonical_url = _scientific_canonical_url(item.source_url, item.doi, item.pmid)
        domain_host = _scientific_domain_host(item.source_url, item.doi, item.pmid)
        if canonical_url is None or domain_host is None:
            continue
        rows.append(
            {
                "canonical_url": canonical_url,
                "domain_host": domain_host,
                "title": item.title,
                "journal": item.journal,
                "doi": item.doi,
                "pmid": item.pmid,
                "publication_year": item.year,
                "species": item.species,
                "clinical_domain": item.clinical_domain,
                "reliability_tier": item.tier,
                "summary": item.snippet,
                "metadata": {
                    "retrieval_backend": backend,
                    "original_source_url": item.source_url,
                    "access_depth": item.access_depth,
                    "discovery_query": request.query,
                    "discovery_intent": request.intent,
                    "discovered_by_admin_id": admin.id,
                },
            }
        )

    try:
        response = client.rpc(
            "admin_ingest_scientific_documents",
            {"payload": rows},
        ).execute()
        ingestion = getattr(response, "data", None)
        if isinstance(ingestion, list) and ingestion and isinstance(ingestion[0], dict):
            ingestion = ingestion[0]
        if not isinstance(ingestion, dict):
            ingestion = {
                "inserted": 0,
                "updated": 0,
                "skipped": len(rows),
                "documents": 0,
            }
    except Exception as exc:
        finished = datetime.now(UTC).isoformat()
        client.table("scrape_runs").update(
            {
                "status": "failed",
                "error_message": str(exc)[:2000],
                "finished_at": finished,
                "updated_at": finished,
            }
        ).eq("id", job_id).execute()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Scientific ingestion failed: {str(exc)[:500]}",
        ) from exc

    finished = datetime.now(UTC).isoformat()
    client.table("scrape_runs").update(
        {
            "status": "completed",
            "place_count": int(ingestion.get("inserted", 0)) + int(ingestion.get("updated", 0)),
            "error_message": None,
            "finished_at": finished,
            "updated_at": finished,
        }
    ).eq("id", job_id).execute()

    return {
        "backend": backend,
        "job_id": job_id,
        "discovered": len(evidence),
        "submitted": len(rows),
        "ingestion": ingestion,
        "results": [item.model_dump(mode="json") for item in evidence],
        "catalog": _scientific_catalog_payload(client),
    }

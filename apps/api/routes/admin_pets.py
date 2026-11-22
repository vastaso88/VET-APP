"""Read-only administrative pet directory; owner pet endpoints remain private."""

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from apps.api.routes.admin import _admin_client, _require_admin
from apps.api.routes.admin_directories_legacy import legacy_pets_directory
from packages.infrastructure.admin.user_reports import pets_directory

router = APIRouter(prefix="/admin/pets", tags=["admin"])


@router.get("")
def list_admin_pets(
    q: str = Query(default="", max_length=200),
    page: int = Query(default=1, ge=1, le=2000),
    page_size: int = Query(default=50, ge=1, le=100),
    species: str = Query(default="", max_length=50),
    status: str = Query(default="", pattern=r"^(|active|inactive|exotic|memorial)$"),
    country: str = Query(default="", max_length=2),
    region: str = Query(default="", max_length=200),
) -> dict[str, Any]:
    _require_admin()
    try:
        client = _admin_client()
        # Search, filters, order and page run in the database (QK-07): the directory
        # fields of one page come back, never medical notes or the whole pet table.
        directory = pets_directory(
            client,
            q=q,
            species=species,
            status=status,
            country=country,
            region=region,
            page=page,
            page_size=page_size,
            # TEMPORARY: the old logic while the database function does not exist yet.
            fallback=lambda: legacy_pets_directory(
                client,
                q=q,
                species=species,
                status=status,
                country=country,
                region=region,
                page=page,
                page_size=page_size,
            ),
        )
        return {
            "pets": directory["rows"],
            "total": directory["total"],
            "page": directory["page"],
            "page_size": page_size,
        }
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=503, detail="Pet directory is not available") from None

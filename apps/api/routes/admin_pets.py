"""Read-only administrative pet directory; owner pet endpoints remain private."""

from typing import Any

from fastapi import APIRouter, HTTPException, Query

from apps.api.routes.admin import _admin_client, _require_admin, _species_bucket

router = APIRouter(prefix="/admin/pets", tags=["admin"])


@router.get("")
def list_admin_pets(
    q: str = Query(default="", max_length=200),
    page: int = Query(default=1, ge=1, le=2000),
    page_size: int = Query(default=50, ge=1, le=100),
    species: str = Query(default="", max_length=50),
    status: str = Query(default="", pattern=r"^(|active|inactive|exotic|memorial)$"),
) -> dict[str, Any]:
    _require_admin()
    try:
        client = _admin_client()
        # Fetch only administrative directory fields, never medical notes or records.
        response = (
            client.table("pet_profiles")
            .select("id,owner_id,name,species,species_group,breed,is_active,is_exotic,is_memorial")
            .execute()
        )
        rows = list(getattr(response, "data", None) or [])
        needle = q.strip().casefold()
        if needle:
            rows = [
                row for row in rows
                if any(needle in str(row.get(field) or "").casefold()
                       for field in ("name", "id", "owner_id", "breed"))
            ]
        if species:
            rows = [row for row in rows if _species_bucket(row) == species]
        if status:
            flag = {
                "active": "is_active",
                "inactive": "is_active",
                "exotic": "is_exotic",
                "memorial": "is_memorial",
            }[status]
            expected = status != "inactive"
            rows = [row for row in rows if row.get(flag) is expected]
        rows.sort(key=lambda row: (str(row.get("name") or "").casefold(), str(row.get("id") or "")))
        total = len(rows)
        page = min(page, max(1, (total + page_size - 1) // page_size))
        selected = rows[(page - 1) * page_size:page * page_size]
        return {"pets": selected, "total": total, "page": page, "page_size": page_size}
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=503, detail="Pet directory is not available") from None

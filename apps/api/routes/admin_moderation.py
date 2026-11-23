"""Admin moderation: chat, radar, marketplace reports and marketplace restrictions."""

from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any, Literal, get_args

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.routes.admin_common import (
    _admin_client,
    _require_admin,
)
from packages.core.application.services.listing_review import (
    ListingReviewConflictError,
    ListingReviewNotFoundError,
    ListingReviewService,
)
from packages.core.domain.marketplace.content_review import RemovalReason
from packages.core.domain.marketplace.models import ListingReportReason
from packages.core.domain.marketplace.photos import owner_links

router = APIRouter(prefix="/admin", tags=["admin"])


class ChatModerationRequest(BaseModel):
    status: Literal["under_review", "resolved", "wont_fix"]
    resolution_note: str | None = Field(default=None, max_length=1000)


class RadarModerationRequest(BaseModel):
    action: Literal["confirm", "reject", "reopen"]
    resolution_note: str | None = Field(default=None, max_length=1000)


class MarketplaceModerationRequest(BaseModel):
    action: Literal["remove_listing", "dismiss_report", "restore_listing", "reopen_report"]
    # What the seller is told when the ad is taken down; the report's own reason when
    # the team does not choose another.
    removal_reason: RemovalReason | None = None
    resolution_note: str | None = Field(default=None, max_length=1000)


class ListingReviewDecisionRequest(BaseModel):
    outcome: Literal["checked", "removed", "restored"]
    reason: Literal["food", "supplement", "medicine", "other"] | None = None
    note: str | None = Field(default=None, max_length=1000)


class MarketplaceMessageModerationRequest(BaseModel):
    action: Literal["close_conversation", "dismiss_report", "reopen_report"]
    resolution_note: str | None = Field(default=None, max_length=1000)


class MarketplaceRestrictionRequest(BaseModel):
    owner_id: str = Field(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_-]+$")
    reason: Literal["spam", "scam", "harassment", "prohibited_items", "other"]
    note: str | None = Field(default=None, min_length=3, max_length=1000)


@router.get("/moderation")
def admin_moderation() -> dict[str, object]:
    _require_admin()
    client = _admin_client()

    radar_response = (
        client.table("radar_user_reports")
        .select(
            "id,kind,status,place_type,name,latitude,longitude,address_label,"
            "target_source,target_source_id,confirmations,denials,created_at,resolved_at,"
            "admin_resolution_note,resolved_by_admin_id"
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
        .select(
            "id,listing_id,reporter_owner_id,reason,created_at,status,resolution_action,"
            "resolution_note,resolved_at,resolved_by_admin_id"
        )
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
            .select(
                "id,owner_id,title,description,category,condition,price_cents,photo_urls,"
                "latitude,longitude,city_label,status,report_count,created_at,updated_at"
            )
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


@router.get("/moderation/marketplace_messages")
def admin_marketplace_message_reports() -> dict[str, object]:
    _require_admin()
    return {"reports": get_container().marketplace_messaging_moderation_service().queue()}


# Published ads whose seller confirmed they sell no food, supplements or treatments, to be
# checked by the team (content_review.py).
@router.get("/moderation/listing_reviews")
def admin_listing_reviews() -> dict[str, object]:
    _require_admin()
    return {"reviews": get_container().listing_review_service().queue()}


@router.get("/moderation/listing_reviews/{review_id}")
def admin_listing_review_detail(review_id: str) -> dict[str, object]:
    _require_admin()
    detail = get_container().listing_review_service().detail(review_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="Listing review not found")
    return {"item": detail}


@router.post("/moderation/listing_reviews/{review_id}")
def admin_decide_listing_review(
    review_id: str, request: ListingReviewDecisionRequest
) -> dict[str, object]:
    admin = _require_admin()
    if request.outcome == "removed" and request.reason is None:
        raise HTTPException(status_code=422, detail="A removal needs a reason")
    try:
        listing = (
            get_container()
            .listing_review_service()
            .decide(
                review_id,
                request.outcome,
                admin_id=admin.id,
                reason=request.reason,
                note=request.note,
            )
        )
    except ListingReviewNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Listing review not found") from exc
    except ListingReviewConflictError as exc:
        raise HTTPException(
            status_code=409, detail="The ad changed or was already decided: reload it"
        ) from exc
    return {"listing_id": listing.id, "listing_status": listing.status}


@router.get("/moderation/{queue}/{item_id}")
def admin_moderation_detail(queue: str, item_id: str) -> dict[str, object]:
    admin = _require_admin()

    if queue == "marketplace_messages":
        # The team reads a thread only here, and only because it was reported;
        # every look is written down (marketplace_moderation_access_log).
        detail = (
            get_container().marketplace_messaging_moderation_service().detail(item_id, admin.id)
        )
        if detail is None:
            raise HTTPException(status_code=404, detail="Marketplace message report not found")
        return {"queue": queue, "item": detail}

    client = _admin_client()

    if queue == "radar":
        response = (
            client.table("radar_user_reports").select("*").eq("id", item_id).limit(1).execute()
        )
        rows = getattr(response, "data", None) or []
        if not rows:
            raise HTTPException(status_code=404, detail="Radar report not found")
        votes = (
            client.table("radar_report_votes")
            .select("vote,created_at")
            .eq("report_id", item_id)
            .order("created_at", desc=True)
            .execute()
        )
        return {"queue": queue, "item": rows[0], "votes": getattr(votes, "data", None) or []}

    if queue == "chat":
        response = (
            client.table("chat_response_reports").select("*").eq("id", item_id).limit(1).execute()
        )
        rows = getattr(response, "data", None) or []
        if not rows:
            raise HTTPException(status_code=404, detail="Chat report not found")
        # The reporter's pseudonym (and the legacy clear id) stay server-side:
        # a reviewer needs the reported answer, not who reported it.
        item = {
            key: value
            for key, value in rows[0].items()
            if key not in {"reporter_ref", "reporter_owner_id"}
        }
        return {"queue": queue, "item": item}

    if queue == "marketplace":
        response = (
            client.table("marketplace_listing_reports")
            .select("*")
            .eq("id", item_id)
            .limit(1)
            .execute()
        )
        rows = getattr(response, "data", None) or []
        if not rows:
            raise HTTPException(status_code=404, detail="Marketplace report not found")
        report = rows[0]
        listing_response = (
            client.table("marketplace_listings")
            .select("*")
            .eq("id", report["listing_id"])
            .limit(1)
            .execute()
        )
        listing_rows = getattr(listing_response, "data", None) or []
        report["listing"] = _with_own_photos(listing_rows[0]) if listing_rows else None
        return {"queue": queue, "item": report}

    raise HTTPException(status_code=404, detail="Unknown moderation queue")


@router.post("/moderation/chat/{report_id}")
def admin_resolve_chat_report(
    report_id: str,
    request: ChatModerationRequest,
) -> dict[str, object]:
    _require_admin()

    from packages.core.application.services.resolve_chat_response_report import (
        ResolveChatResponseReportInput,
    )

    result = (
        get_container()
        .resolve_chat_response_report_service()
        .execute(
            ResolveChatResponseReportInput(
                report_id=report_id,
                status=request.status,
                resolution_note=request.resolution_note,
            )
        )
    )
    return {
        "report": result.report.model_dump(
            mode="json",
            exclude={"reporter_ref", "reporter_owner_id"},
        )
    }


@router.post("/moderation/radar/{report_id}")
def admin_resolve_radar_report(
    report_id: str,
    request: RadarModerationRequest,
) -> dict[str, object]:
    admin = _require_admin()
    client = _admin_client()
    response = client.table("radar_user_reports").select("*").eq("id", report_id).limit(1).execute()
    rows = getattr(response, "data", None) or []
    if not rows:
        raise HTTPException(status_code=404, detail="Radar report not found")
    report = rows[0]
    now = datetime.now(UTC).isoformat()
    override_reason = f"admin-report:{report_id}"

    if request.action == "reopen":
        client.table("radar_user_reports").update(
            {
                "status": "pending",
                "resolved_at": None,
                "admin_resolution_note": request.resolution_note,
                "resolved_by_admin_id": admin.id,
            }
        ).eq("id", report_id).execute()
        if report.get("target_source") and report.get("target_source_id"):
            client.table("radar_place_overrides").delete().eq("source", report["target_source"]).eq(
                "source_id", report["target_source_id"]
            ).eq("reason", override_reason).execute()
    else:
        new_status = "confirmed" if request.action == "confirm" else "rejected"
        client.table("radar_user_reports").update(
            {
                "status": new_status,
                "resolved_at": now,
                "admin_resolution_note": request.resolution_note,
                "resolved_by_admin_id": admin.id,
            }
        ).eq("id", report_id).execute()
        if request.action == "confirm" and report.get("kind") in {"closed", "duplicate"}:
            if report.get("target_source") and report.get("target_source_id"):
                client.table("radar_place_overrides").upsert(
                    {
                        "source": report["target_source"],
                        "source_id": report["target_source_id"],
                        "action": "exclude",
                        "reason": override_reason,
                        "place_type": report.get("place_type"),
                        "latitude": report.get("latitude"),
                        "longitude": report.get("longitude"),
                    }
                ).execute()

    updated = client.table("radar_user_reports").select("*").eq("id", report_id).limit(1).execute()
    return {"report": (getattr(updated, "data", None) or [report])[0]}


def _with_own_photos(listing: dict[str, Any]) -> dict[str, Any]:
    """Only the files of the ad."""
    links = listing.get("photo_urls")
    return {
        **listing,
        "photo_urls": owner_links(
            [link for link in links if isinstance(link, str)] if isinstance(links, list) else [],
            str(listing.get("id") or ""),
            str(listing.get("owner_id") or ""),
            get_container().marketplace_photo_base,
        ),
    }


def _report_reason(reason: object) -> RemovalReason:
    known: tuple[RemovalReason, ...] = get_args(ListingReportReason)
    return next((item for item in known if item == reason), "other")


def _decide_reported(decide: Callable[[ListingReviewService], object]) -> None:
    try:
        decide(get_container().listing_review_service())
    except ListingReviewNotFoundError as exc:
        raise HTTPException(status_code=404, detail="The listing is gone") from exc


@router.post("/moderation/marketplace/{report_id}")
def admin_resolve_marketplace_report(
    report_id: str,
    request: MarketplaceModerationRequest,
) -> dict[str, object]:
    admin = _require_admin()
    client = _admin_client()
    response = (
        client.table("marketplace_listing_reports")
        .select("*")
        .eq("id", report_id)
        .limit(1)
        .execute()
    )
    rows = getattr(response, "data", None) or []
    if not rows:
        raise HTTPException(status_code=404, detail="Marketplace report not found")
    report = rows[0]
    listing_id = str(report["listing_id"])
    now = datetime.now(UTC).isoformat()

    if request.action == "remove_listing":
        _decide_reported(
            lambda service: service.remove_reported(
                listing_id,
                request.removal_reason or _report_reason(report.get("reason")),
                admin_id=admin.id,
                note=request.resolution_note,
            )
        )
        report_update = {
            "status": "resolved",
            "resolution_action": "remove_listing",
            "resolution_note": request.resolution_note,
            "resolved_at": now,
            "resolved_by_admin_id": admin.id,
        }
    elif request.action == "dismiss_report":
        report_update = {
            "status": "dismissed",
            "resolution_action": "keep_listing",
            "resolution_note": request.resolution_note,
            "resolved_at": now,
            "resolved_by_admin_id": admin.id,
        }
    elif request.action == "restore_listing":
        _decide_reported(lambda service: service.restore_reported(listing_id, admin_id=admin.id))
        report_update = {
            "status": "resolved",
            "resolution_action": "restore_listing",
            "resolution_note": request.resolution_note,
            "resolved_at": now,
            "resolved_by_admin_id": admin.id,
        }
    else:
        report_update = {
            "status": "open",
            "resolution_action": None,
            "resolution_note": request.resolution_note,
            "resolved_at": None,
            "resolved_by_admin_id": admin.id,
        }

    client.table("marketplace_listing_reports").update(report_update).eq("id", report_id).execute()

    open_reports_response = (
        client.table("marketplace_listing_reports")
        .select("reporter_owner_id")
        .eq("listing_id", listing_id)
        .eq("status", "open")
        .execute()
    )
    open_reporters = {
        str(row["reporter_owner_id"])
        for row in (getattr(open_reports_response, "data", None) or [])
        if row.get("reporter_owner_id") is not None
    }
    client.table("marketplace_listings").update(
        {"report_count": len(open_reporters), "updated_at": now}
    ).eq("id", listing_id).execute()

    updated = (
        client.table("marketplace_listing_reports")
        .select("*")
        .eq("id", report_id)
        .limit(1)
        .execute()
    )
    return {"report": (getattr(updated, "data", None) or [report])[0]}


@router.get("/moderation/marketplace_restrictions")
def admin_marketplace_restrictions() -> dict[str, object]:
    _require_admin()
    return {
        "restrictions": get_container().marketplace_messaging_moderation_service().restrictions()
    }


@router.post("/moderation/marketplace_restrictions")
def admin_restrict_marketplace_user(request: MarketplaceRestrictionRequest) -> dict[str, object]:
    """Keeps one person out of the Mercatino: no new ads, no edits, no messages."""
    admin = _require_admin()
    if get_container().settings.persistence_backend == "supabase":
        from apps.api.routes.admin_user_actions import (
            ExecuteRequest,
            PreviewRequest,
            execute,
            preview,
        )

        prepared = preview(
            PreviewRequest(
                owner_ids=[request.owner_id.strip()],
                action="restrict_marketplace",
                reason=request.reason,
                note=(request.note or "").strip() or f"Moderation: {request.reason}",
                duration_days=7,
            )
        )
        outcome = execute(ExecuteRequest(token=prepared["token"], confirmed=True))
        if outcome["results"][0]["status"] not in {"applied", "already_applied"}:
            raise HTTPException(status_code=409, detail="Prepare the user action again")
        rows = (
            _admin_client()
            .table("marketplace_user_restrictions")
            .select("*")
            .eq("owner_id", request.owner_id.strip())
            .limit(1)
            .execute()
            .data
        )
        return {"restriction": rows[0] if rows else None}
    restriction = (
        get_container()
        .marketplace_messaging_moderation_service()
        .restrict(request.owner_id.strip(), request.reason, request.note, admin.id)
    )
    return {"restriction": restriction.model_dump(mode="json")}


@router.post("/moderation/marketplace_restrictions/{owner_id}/lift")
def admin_lift_marketplace_restriction(owner_id: str) -> dict[str, object]:
    admin = _require_admin()
    if get_container().settings.persistence_backend == "supabase":
        from apps.api.routes.admin_user_actions import (
            ExecuteRequest,
            PreviewRequest,
            execute,
            preview,
        )

        prepared = preview(
            PreviewRequest(
                owner_ids=[owner_id],
                action="lift_marketplace",
                reason="other",
                note="Manual release from the moderation queue",
            )
        )
        outcome = execute(ExecuteRequest(token=prepared["token"], confirmed=True))
        if outcome["results"][0]["status"] not in {"applied", "already_applied"}:
            raise HTTPException(status_code=409, detail="Prepare the user action again")
        rows = (
            _admin_client()
            .table("marketplace_user_restrictions")
            .select("*")
            .eq("owner_id", owner_id)
            .limit(1)
            .execute()
            .data
        )
        return {"restriction": rows[0] if rows else None}
    restriction = (
        get_container().marketplace_messaging_moderation_service().lift(owner_id, admin.id)
    )
    if restriction is None:
        raise HTTPException(status_code=404, detail="Marketplace restriction not found")
    return {"restriction": restriction.model_dump(mode="json")}


@router.post("/moderation/marketplace_messages/{report_id}")
def admin_resolve_marketplace_message_report(
    report_id: str,
    request: MarketplaceMessageModerationRequest,
) -> dict[str, object]:
    admin = _require_admin()
    report = (
        get_container()
        .marketplace_messaging_moderation_service()
        .resolve(report_id, request.action, request.resolution_note, admin.id)
    )
    if report is None:
        raise HTTPException(status_code=404, detail="Marketplace message report not found")
    return {"report": report.model_dump(mode="json")}

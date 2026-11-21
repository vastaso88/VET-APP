"""Explicit, signed previews; one transaction and immutable receipt per target."""

import base64
import hashlib
import hmac
import json
import time
from typing import Annotated, Any, Literal
from uuid import uuid4

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, model_validator

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import (
    _admin_client,
    _configured_admin_emails,
    _list_auth_users,
    _require_admin,
)
from apps.api.routes.admin_users import auth_user
from packages.infrastructure.admin.user_reports import case_is_about, countries

router = APIRouter(prefix="/admin/user-actions", tags=["admin"])
Action = Literal["restrict_marketplace", "lift_marketplace", "revoke_devices"]
Reason = Literal["spam", "scam", "harassment", "prohibited_items", "other"]
OwnerId = Annotated[str, Field(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_-]+$")]


class CaseRef(BaseModel):
    owner_id: str = Field(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_-]+$")
    queue: Literal["marketplace", "marketplace_messages"]
    id: str = Field(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_-]+$")


class PreviewRequest(BaseModel):
    action: Action
    reason: Reason
    note: str = Field(min_length=3, max_length=1000)
    duration_days: int = Field(default=7, ge=1, le=90)
    owner_ids: list[OwnerId] = Field(default_factory=list, max_length=100)
    cases: list[CaseRef] = Field(default_factory=list, max_length=100)
    all_results: bool = False
    q: str = Field(default="", max_length=200)
    country: str = Field(default="", pattern=r"^(|unknown|[A-Z]{2})$")

    @model_validator(mode="after")
    def selection(self) -> "PreviewRequest":
        if len(self.note.strip()) < 3:
            raise ValueError("A meaningful reason is required")
        if self.all_results and (self.owner_ids or self.cases):
            raise ValueError("Choose explicit accounts or all filtered results")
        if any(not owner or len(owner) > 100 for owner in self.owner_ids):
            raise ValueError("Invalid account id")
        return self


class ExecuteRequest(BaseModel):
    token: str = Field(min_length=10, max_length=100_000)
    confirmed: Literal[True]


def _signature(raw: str) -> str:
    secret = get_container().settings.reporter_pseudonym_secret()
    return hmac.new(
        f"admin-user-actions:{secret}".encode(), raw.encode(), hashlib.sha256
    ).hexdigest()


def _protected(user: Any, admin_id: str) -> bool:
    email = str(getattr(user, "email", "") or "").strip().lower()
    return str(user.id) == admin_id or email in (
        _configured_admin_emails() | get_container().developer_emails
    )


@router.post("/preview")
def preview(request: PreviewRequest) -> dict[str, Any]:
    admin = _require_admin()
    try:
        client = _admin_client()
        if request.all_results:
            users = _list_auth_users(client)
            locations = countries(client)
            needle = request.q.strip().casefold()
            users = [
                user
                for user in users
                if (
                    not needle
                    or needle in str(user.id).casefold()
                    or needle in str(getattr(user, "email", "") or "").casefold()
                )
                and (
                    not request.country
                    or (locations.get(str(user.id), {}).get("country_code") or "unknown")
                    == request.country
                )
            ]
            if len(users) > 100:
                raise HTTPException(
                    status_code=422, detail="Narrow the selection to at most 100 accounts"
                )
        else:
            ids = sorted(set(request.owner_ids) | {case.owner_id for case in request.cases})
            if not ids or len(ids) > 100:
                raise HTTPException(status_code=422, detail="Select between 1 and 100 accounts")
            users = [auth_user(client, owner_id) for owner_id in ids]
        if not users:
            raise HTTPException(status_code=422, detail="No accounts selected")
        case_map = {case.owner_id: case for case in request.cases}
        if len(case_map) != len(request.cases):
            raise HTTPException(status_code=422, detail="Select one case per account")
        targets, display = [], []
        for user in users:
            owner_id = str(user.id)
            if _protected(user, admin.id):
                raise HTTPException(
                    status_code=422, detail="The selection contains a protected team account"
                )
            case = case_map.get(owner_id)
            if case and not case_is_about(client, owner_id, case.queue, case.id):
                raise HTTPException(
                    status_code=422, detail="A selected case does not concern its target"
                )
            state = (
                client.table("marketplace_user_restrictions")
                .select("created_at,lifted_at,expires_at")
                .eq("owner_id", owner_id)
                .limit(1)
                .execute()
                .data
                or []
            )
            targets.append(
                {
                    "owner_id": owner_id,
                    "case": case.model_dump() if case else None,
                    "restriction": state[0] if state else {},
                }
            )
            display.append(
                {
                    "id": owner_id,
                    "email": getattr(user, "email", None),
                    "case": case.model_dump() if case else None,
                }
            )
        payload = {
            "admin_id": admin.id,
            "expires": int(time.time()) + 600,
            "request_id": str(uuid4()),
            "targets": targets,
            "action": request.action,
            "reason": request.reason,
            "note": request.note.strip(),
            "duration_days": request.duration_days,
        }
        raw = base64.urlsafe_b64encode(json.dumps(payload, separators=(",", ":")).encode()).decode()
        return {
            "token": f"{raw}.{_signature(raw)}",
            "users": display,
            "action": request.action,
            "reason": request.reason,
            "note": payload["note"],
            "duration_days": request.duration_days,
            "expires_at": payload["expires"],
        }
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=503, detail="The action preview is not available") from None


@router.post("/execute")
def execute(request: ExecuteRequest) -> dict[str, Any]:
    admin = _require_admin()
    try:
        raw, signature = request.token.rsplit(".", 1)
        if not hmac.compare_digest(signature, _signature(raw)):
            raise ValueError("signature")
        payload = json.loads(base64.urlsafe_b64decode(raw))
        if payload["admin_id"] != admin.id or payload["expires"] <= time.time():
            raise ValueError("expired or different admin")
    except (ValueError, KeyError, TypeError):
        raise HTTPException(
            status_code=409, detail="Preview expired or invalid; prepare it again"
        ) from None
    client = _admin_client()
    results = []
    for target in payload["targets"]:
        owner_id = target["owner_id"]
        try:
            user = auth_user(client, owner_id)
            if _protected(user, admin.id):
                results.append({"id": owner_id, "status": "protected", "changed": False})
                continue
            case = target["case"]
            if case and not case_is_about(client, owner_id, case["queue"], case["id"]):
                results.append({"id": owner_id, "status": "case_changed", "changed": False})
                continue
            outcome = (
                client.rpc(
                    "admin_apply_user_action",
                    {
                        "p_request_id": payload["request_id"],
                        "p_owner_id": owner_id,
                        "p_admin_id": admin.id,
                        "p_action": payload["action"],
                        "p_reason": payload["reason"],
                        "p_note": payload["note"],
                        "p_duration_days": payload["duration_days"],
                        "p_case_queue": case["queue"] if case else None,
                        "p_case_id": case["id"] if case else None,
                        "p_expected_restriction": target["restriction"],
                    },
                )
                .execute()
                .data
            )
            results.append({"id": owner_id, **outcome})
        except Exception:
            results.append({"id": owner_id, "status": "failed", "changed": False})
    return {"results": results}

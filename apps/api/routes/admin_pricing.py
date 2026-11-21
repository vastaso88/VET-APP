"""Admin pricing drafts and effective plan features; every write is TOTP-gated."""

from __future__ import annotations

from typing import Any, Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from apps.api.routes.admin import _admin_client, _require_admin
from apps.api.routes.admin_users import _verify_plan_totp

router = APIRouter(prefix="/admin/pricing", tags=["admin"])

Plan = Literal["plus", "pro", "ultra"]
Feature = Literal[
    "max_pets", "max_chats_per_pet", "daily_questions",
    "max_devices", "daily_sonnet_answers",
]
Store = Literal["apple", "google"]
Period = Literal["monthly", "yearly"]


class FeatureUpdate(BaseModel):
    plan: Plan
    feature: Feature
    enabled: bool
    quota: int = Field(ge=0, le=2000)
    totp_code: str = Field(pattern=r"^\d{6}$", min_length=6, max_length=6)


class PriceUpdate(BaseModel):
    country_code: str = Field(pattern=r"^[A-Z]{2}$", min_length=2, max_length=2)
    store: Store
    plan: Plan
    period: Period
    currency: str = Field(pattern=r"^[A-Z]{3}$", min_length=3, max_length=3)
    amount_minor: int | None = Field(default=None, ge=1, le=100_000_000)
    totp_code: str = Field(pattern=r"^\d{6}$", min_length=6, max_length=6)


def _proof(admin_id: str, code: str, client: Any) -> str:
    # Shared persistent rate limiting across every Vercel worker and across
    # the user-plan and pricing admin actions.
    try:
        allowed = client.rpc(
            "admin_plan_totp_register_attempt", {"p_admin_id": admin_id}
        ).execute().data
    except Exception:
        raise HTTPException(status_code=503, detail="MFA rate limit unavailable") from None
    if allowed is not True:
        raise HTTPException(status_code=429, detail="Too many TOTP attempts")
    return _verify_plan_totp(admin_id, code)


@router.get("")
def get_pricing() -> dict[str, object]:
    _require_admin()
    client = _admin_client()
    try:
        features = (
            client.table("pricing_plan_features")
            .select("plan,feature,enabled,quota,updated_at")
            .order("plan").order("feature").execute().data or []
        )
        prices = (
            client.table("pricing_store_prices")
            .select("country_code,store,plan,period,currency,amount_minor,updated_at")
            .order("country_code").order("store").order("plan").order("period")
            .execute().data or []
        )
        audit = (
            client.table("pricing_admin_audit")
            .select("id,admin_id,entity_type,entity_key,before_value,after_value,changed_at")
            .order("changed_at", desc=True).limit(30).execute().data or []
        )
    except Exception:
        raise HTTPException(status_code=503, detail="Pricing migration is not available") from None
    return {"features": features, "prices": prices, "audit": audit,
            "store_sync": "manual", "prices_are_store_drafts": True}


@router.post("/features")
def save_feature(request: FeatureUpdate) -> dict[str, object]:
    admin = _require_admin()
    client = _admin_client()
    digest = _proof(admin.id, request.totp_code, client)
    try:
        client.rpc("admin_pricing_save_feature", {
            "p_admin_id": admin.id,
            "p_plan": request.plan,
            "p_feature": request.feature,
            "p_enabled": request.enabled,
            "p_quota": request.quota,
            "p_code_digest": digest,
        }).execute()
    except Exception:
        raise HTTPException(status_code=409, detail="Save failed or TOTP already used") from None
    return {"saved": True}


@router.post("/prices")
def save_price(request: PriceUpdate) -> dict[str, object]:
    admin = _require_admin()
    client = _admin_client()
    digest = _proof(admin.id, request.totp_code, client)
    try:
        client.rpc("admin_pricing_save_price", {
            "p_admin_id": admin.id,
            "p_country_code": request.country_code,
            "p_store": request.store,
            "p_plan": request.plan,
            "p_period": request.period,
            "p_currency": request.currency,
            "p_amount_minor": request.amount_minor,
            "p_code_digest": digest,
        }).execute()
    except Exception:
        raise HTTPException(status_code=409, detail="Save failed or TOTP already used") from None
    return {"saved": True}

"""App Store / Google Play subscriptions: verification, restore, store
notifications, reconciliation. The backend alone decides the rights."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import JSONResponse

from apps.api.dependencies.container import get_container
from apps.api.request_language import request_language
from apps.api.schemas.subscription import (
    AppleNotificationRequest,
    RestorePurchasesRequest,
    VerifyPurchaseRequest,
)
from packages.core.application.ports.store_billing import (
    StoreRejectedError,
    StoreTemporaryError,
)
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
)
from packages.core.application.services.store_billing import (
    PurchaseOwnershipError,
    StoreBillingService,
    UnknownProductError,
)
from packages.core.domain.localization import translate
from packages.core.domain.subscription.store import Store

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/billing", tags=["billing"])


def _service() -> StoreBillingService:
    container = get_container()
    service = container.store_billing_service()
    if service is None or not container.settings.billing_enabled:
        raise HTTPException(503, detail="billing_not_configured")
    return service


def _error(status: int, code: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"detail": code, "code": code})


def _status_body(user: Any) -> dict[str, object]:
    result = (
        get_container()
        .get_or_create_subscription_service()
        .execute(
            GetOrCreateSubscriptionInput(
                owner_id=user.id,
                email=user.email,
                email_verified=getattr(user, "email_verified", None),
            )
        )
    )
    return result.model_dump(mode="json")


@router.get("/catalog")
def catalog() -> dict[str, object]:
    """Product ids the app asks the store for; prices come from the store."""
    container = get_container()
    service = container.store_billing_service()
    from packages.core.domain.subscription.store import ProductCatalog

    products = ProductCatalog.from_json(container.settings.billing_catalog_json).products
    return {
        "enabled": bool(container.settings.billing_enabled and service is not None),
        "products": [p.model_dump(mode="json") for p in products],
    }


@router.get("/account-token")
def account_token() -> dict[str, str]:
    user = get_container().auth_provider.get_current_user()
    return {"account_token": _service().account_token(user.id)}


@router.post("/purchases/verify", response_model=None)
def verify_purchase(
    request: VerifyPurchaseRequest, http_request: Request
) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    service = _service()
    container.age_gate_service().require_paid_plan(user.id)
    try:
        outcome = service.verify_purchase(
            owner_id=user.id,
            store=Store(request.store),
            store_subscription_id=request.store_subscription_id,
            product_id=request.product_id,
        )
    except PurchaseOwnershipError as exc:
        return _error(409, exc.code)
    except UnknownProductError:
        return _error(422, "unknown_product")
    except StoreRejectedError:
        logger.warning("store rejected a purchase verification")
        return _error(422, "purchase_not_verified")
    except StoreTemporaryError:
        return _error(503, "store_unavailable")
    body: dict[str, object] = {
        "complete_transaction": outcome.complete_transaction,
        "state": outcome.entitlement.state,
        "status": _status_body(user),
        "pets_over_limit": None,
    }
    # The new plan may have fewer places than the owner has pets: nothing is
    # deleted or moved (Terms it/03 section 4), the owner is told.
    over = (
        container.select_plan_service().pets_over_limit(user.id, outcome.plan)
        if outcome.plan
        else None
    )
    if over is not None:
        body["pets_over_limit"] = over.model_dump()
        body["code"] = "pets_over_plan_limit"
        body["message"] = translate(
            "plan_over_pet_limit",
            request_language(http_request),
            count=over.count,
            limit=over.limit,
            plan=over.plan.capitalize(),
        )
    return body


@router.post("/purchases/restore", response_model=None)
def restore_purchases(request: RestorePurchasesRequest) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        restored = _service().restore(
            owner_id=user.id, store=Store(request.store), ids=request.store_subscription_ids
        )
    except StoreTemporaryError:
        return _error(503, "store_unavailable")
    return {"restored": len(restored), "status": _status_body(user)}


@router.post("/apple/notifications", response_model=None)
def apple_notification(request: AppleNotificationRequest) -> dict[str, str] | JSONResponse:
    """App Store Server Notifications V2. Non-2xx makes Apple retry."""
    service = _service()
    decoder = get_container().apple_signed_data_decoder()
    if decoder is None:
        return _error(503, "billing_not_configured")
    try:
        notification = decoder.notification(request.signedPayload)
        return {"outcome": service.handle_notification(notification)}
    except StoreRejectedError:
        logger.warning("rejected an App Store notification with an invalid signature")
        return _error(400, "invalid_notification")
    except StoreTemporaryError:
        return _error(503, "store_unavailable")


@router.post("/google/notifications", response_model=None)
async def google_notification(
    request: Request, authorization: str | None = Header(default=None)
) -> dict[str, str] | JSONResponse:
    """Real-time developer notifications (Pub/Sub push, OIDC-authenticated)."""
    from packages.infrastructure.billing.google_play import (
        PubSubPushAuthenticator,
        parse_rtdn,
    )

    container = get_container()
    settings = container.settings
    service = _service()
    if not (settings.google_pubsub_audience and settings.google_pubsub_service_account):
        return _error(503, "billing_not_configured")
    body = await request.body()
    if len(body) > 65536:
        return _error(413, "too_large")
    try:
        PubSubPushAuthenticator(
            audience=settings.google_pubsub_audience,
            service_account_email=settings.google_pubsub_service_account,
        ).verify(authorization)
        envelope: dict[str, Any] = await request.json()
        notification = parse_rtdn(envelope, settings.google_play_package_name)
        if notification is None:
            return {"outcome": "test"}
        return {"outcome": service.handle_notification(notification)}
    except StoreRejectedError:
        logger.warning("rejected a Google Play notification")
        return _error(403, "invalid_notification")
    except StoreTemporaryError:
        return _error(503, "store_unavailable")


@router.post("/reconcile")
def reconcile(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, int]:
    """Periodic re-check with the stores (same scheduler secret as /admin)."""
    from apps.api.routes.admin import _require_scheduler_token

    _require_scheduler_token(x_vetapp_scheduler)
    return _service().reconcile()

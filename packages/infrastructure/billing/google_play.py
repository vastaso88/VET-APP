"""Google Play Developer API (subscriptionsv2) + Real-time Developer Notifications."""

from __future__ import annotations

import base64
import json
import threading
import time
from datetime import UTC, datetime
from typing import Any

import httpx

from packages.core.application.ports.store_billing import (
    StoreNotification,
    StoreRejectedError,
    StoreTemporaryError,
)
from packages.core.domain.subscription.store import Store, StoreState, VerifiedStorePurchase
from packages.infrastructure.billing.jose import (
    USER_AGENT,
    JoseError,
    sign_rs256,
    verify_rs256_with_jwks,
)

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
GOOGLE_CERTS = "https://www.googleapis.com/oauth2/v3/certs"

_STATE = {
    "SUBSCRIPTION_STATE_PENDING": StoreState.PENDING,
    "SUBSCRIPTION_STATE_ACTIVE": StoreState.ACTIVE,
    "SUBSCRIPTION_STATE_PAUSED": StoreState.PAUSED,
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": StoreState.IN_GRACE_PERIOD,
    "SUBSCRIPTION_STATE_ON_HOLD": StoreState.ON_HOLD,
    "SUBSCRIPTION_STATE_CANCELED": StoreState.CANCELED,
    "SUBSCRIPTION_STATE_EXPIRED": StoreState.EXPIRED,
    "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED": StoreState.EXPIRED,
}
# subscriptionNotification.notificationType 12 = SUBSCRIPTION_REVOKED.
_REVOKED = 12


def _rfc3339(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def parse_subscription_v2(token: str, body: dict[str, Any]) -> VerifiedStorePurchase:
    items = body.get("lineItems") or []
    if not items:
        raise StoreRejectedError("no line items")
    item = max(items, key=lambda i: i.get("expiryTime", ""))
    state = _STATE.get(body.get("subscriptionState", ""), StoreState.EXPIRED)
    auto_renew = bool((item.get("autoRenewingPlan") or {}).get("autoRenewEnabled"))
    if state == StoreState.ACTIVE and not auto_renew:
        state = StoreState.CANCELED
    account = (body.get("externalAccountIdentifiers") or {}).get("obfuscatedExternalAccountId")
    expires = _rfc3339(item.get("expiryTime"))
    return VerifiedStorePurchase(
        store=Store.GOOGLE,
        store_subscription_id=token,
        latest_transaction_id=body.get("latestOrderId"),
        product_id=str(item.get("productId")),
        base_plan_id=(item.get("offerDetails") or {}).get("basePlanId"),
        state=state,
        expires_at=expires,
        auto_renew=auto_renew,
        grace_expires_at=expires if state == StoreState.IN_GRACE_PERIOD else None,
        environment="sandbox" if body.get("testPurchase") is not None else "production",
        account_token=account.lower() if account else None,
        linked_previous_id=body.get("linkedPurchaseToken"),
        needs_acknowledgement=body.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_PENDING",
    )


class GooglePlayVerifier:
    def __init__(
        self,
        *,
        package_name: str,
        service_account_json: str,
        client: httpx.Client | None = None,
    ) -> None:
        self._package = package_name
        self._account = json.loads(service_account_json)
        self._client = client or httpx.Client(timeout=10, headers={"User-Agent": USER_AGENT})
        self._access: tuple[str, float] | None = None
        self._lock = threading.Lock()

    def _bearer(self) -> str:
        with self._lock:
            if self._access and self._access[1] > time.time() + 60:
                return self._access[0]
            now = int(time.time())
            assertion = sign_rs256(
                {
                    "iss": self._account["client_email"],
                    "scope": SCOPE,
                    "aud": self._account.get("token_uri", "https://oauth2.googleapis.com/token"),
                    "iat": now,
                    "exp": now + 3600,
                },
                self._account["private_key"],
                self._account.get("private_key_id"),
            )
            try:
                response = self._client.post(
                    self._account.get("token_uri", "https://oauth2.googleapis.com/token"),
                    data={
                        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                        "assertion": assertion,
                    },
                )
            except httpx.HTTPError as exc:
                raise StoreTemporaryError("google oauth unreachable") from exc
            if response.status_code != 200:
                raise StoreTemporaryError(f"google oauth {response.status_code}")
            data = response.json()
            self._access = (data["access_token"], time.time() + int(data.get("expires_in", 3600)))
            return self._access[0]

    def _call(self, method: str, url: str) -> httpx.Response:
        try:
            response = self._client.request(
                method, url, headers={"Authorization": f"Bearer {self._bearer()}"}
            )
        except httpx.HTTPError as exc:
            raise StoreTemporaryError("google play unreachable") from exc
        if response.status_code == 429 or response.status_code >= 500:
            raise StoreTemporaryError(f"google play {response.status_code}")
        if response.status_code >= 400:
            raise StoreRejectedError(f"google play {response.status_code}")
        return response

    def verify(
        self, *, store_subscription_id: str, product_id: str | None = None
    ) -> VerifiedStorePurchase:
        response = self._call(
            "GET", f"{API}/{self._package}/purchases/subscriptionsv2/tokens/{store_subscription_id}"
        )
        return parse_subscription_v2(store_subscription_id, response.json())

    def acknowledge(self, purchase: VerifiedStorePurchase) -> None:
        self._call(
            "POST",
            f"{API}/{self._package}/purchases/subscriptions/{purchase.product_id}"
            f"/tokens/{purchase.store_subscription_id}:acknowledge",
        )


class PubSubPushAuthenticator:
    """Verifies the OIDC token Pub/Sub puts on push requests: Google
    signature, issuer, audience and the configured service account."""

    def __init__(
        self, *, audience: str, service_account_email: str, client: httpx.Client | None = None
    ) -> None:
        self._audience = audience
        self._email = service_account_email
        self._client = client or httpx.Client(timeout=10, headers={"User-Agent": USER_AGENT})
        self._jwks: tuple[dict[str, Any], float] | None = None

    def _keys(self) -> dict[str, Any]:
        if self._jwks and self._jwks[1] > time.time():
            return self._jwks[0]
        try:
            response = self._client.get(GOOGLE_CERTS)
        except httpx.HTTPError as exc:
            raise StoreTemporaryError("google certs unreachable") from exc
        if response.status_code != 200:
            raise StoreTemporaryError("google certs unavailable")
        self._jwks = (response.json(), time.time() + 3600)
        return self._jwks[0]

    def verify(self, authorization: str | None) -> None:
        if not authorization or not authorization.startswith("Bearer "):
            raise StoreRejectedError("missing push token")
        try:
            claims = verify_rs256_with_jwks(authorization[7:], self._keys())
        except JoseError as exc:
            raise StoreRejectedError(f"push token: {exc}") from exc
        if claims.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
            raise StoreRejectedError("issuer")
        if claims.get("aud") != self._audience:
            raise StoreRejectedError("audience")
        if claims.get("email") != self._email or not claims.get("email_verified"):
            raise StoreRejectedError("sender")
        if int(claims.get("exp", 0)) < time.time():
            raise StoreRejectedError("expired")


def parse_rtdn(envelope: dict[str, Any], package_name: str) -> StoreNotification | None:
    """Pub/Sub push envelope -> notification. None for test messages."""
    message = envelope.get("message") or {}
    try:
        data = json.loads(base64.b64decode(message.get("data", "")))
    except (ValueError, json.JSONDecodeError) as exc:
        raise StoreRejectedError("bad pubsub data") from exc
    if data.get("packageName") != package_name:
        raise StoreRejectedError("wrong package")
    signed_at = datetime.fromtimestamp(int(data.get("eventTimeMillis", 0)) / 1000, tz=UTC)
    event_id = str(message.get("messageId") or message.get("message_id") or "")
    if not event_id:
        raise StoreRejectedError("no message id")
    if sub := data.get("subscriptionNotification"):
        kind = int(sub.get("notificationType", 0))
        return StoreNotification(
            event_id=event_id,
            store=Store.GOOGLE,
            notification_type=f"SUBSCRIPTION_{kind}",
            signed_at=signed_at,
            store_subscription_id=sub.get("purchaseToken"),
            revoke=kind == _REVOKED,
            environment="any",
        )
    if voided := data.get("voidedPurchaseNotification"):
        return StoreNotification(
            event_id=event_id,
            store=Store.GOOGLE,
            notification_type="VOIDED_PURCHASE",
            signed_at=signed_at,
            store_subscription_id=voided.get("purchaseToken"),
            refund=True,
            environment="any",
        )
    return None

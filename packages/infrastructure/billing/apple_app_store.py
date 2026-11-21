"""App Store Server API (StoreKit 2) + App Store Server Notifications V2."""

from __future__ import annotations

import base64
import time
from datetime import UTC, datetime
from typing import Any

import httpx
from cryptography import x509

from packages.core.application.ports.store_billing import (
    StoreNotification,
    StoreRejectedError,
    StoreTemporaryError,
)
from packages.core.domain.subscription.store import Store, StoreState, VerifiedStorePurchase
from packages.infrastructure.billing.jose import (
    USER_AGENT,
    JoseError,
    sign_es256,
    verify_apple_jws,
)

PRODUCTION_URL = "https://api.storekit.itunes.apple.com"
SANDBOX_URL = "https://api.storekit-sandbox.itunes.apple.com"

# lastTransactions[].status of "Get All Subscription Statuses".
_STATUS = {
    1: StoreState.ACTIVE,
    2: StoreState.EXPIRED,
    3: StoreState.BILLING_RETRY,
    4: StoreState.IN_GRACE_PERIOD,
    5: StoreState.REVOKED,
}


def _ms(value: object) -> datetime | None:
    return datetime.fromtimestamp(int(value) / 1000, tz=UTC) if value else None  # type: ignore[call-overload]


def load_root_certificates(pem_or_b64: str) -> list[x509.Certificate]:
    """APPLE_ROOT_CERTIFICATES: PEM text, or base64 of PEM/DER (Apple Root CA
    G3, downloaded from https://www.apple.com/certificateauthority/)."""
    raw = pem_or_b64.strip()
    if not raw:
        return []
    if "BEGIN CERTIFICATE" not in raw:
        decoded = base64.b64decode(raw)
        if b"BEGIN CERTIFICATE" not in decoded:
            return [x509.load_der_x509_certificate(decoded)]
        raw = decoded.decode()
    return x509.load_pem_x509_certificates(raw.encode())


class AppleSignedDataDecoder:
    def __init__(self, *, bundle_id: str, roots: list[x509.Certificate]) -> None:
        self._bundle_id = bundle_id
        self._roots = roots

    def decode(self, jws: str) -> dict[str, Any]:
        try:
            payload = verify_apple_jws(jws, self._roots)
        except JoseError as exc:
            raise StoreRejectedError(f"apple signature: {exc}") from exc
        bundle = payload.get("bundleId") or (payload.get("data") or {}).get("bundleId")
        if bundle is not None and bundle != self._bundle_id:
            raise StoreRejectedError("wrong bundle id")
        return payload

    def purchase(
        self, transaction_jws: str, renewal_jws: str | None, status: int | None = None
    ) -> VerifiedStorePurchase:
        tx = self.decode(transaction_jws)
        renewal = self.decode(renewal_jws) if renewal_jws else {}
        expires = _ms(tx.get("expiresDate"))
        revoked = _ms(tx.get("revocationDate"))
        auto_renew = renewal.get("autoRenewStatus") == 1
        grace = _ms(renewal.get("gracePeriodExpiresDate"))
        if revoked is not None:
            state = (
                StoreState.REFUNDED
                if tx.get("revocationReason") is not None
                else StoreState.REVOKED
            )
        elif status is not None:
            state = _STATUS.get(status, StoreState.EXPIRED)
        elif expires is not None and expires > datetime.now(UTC):
            state = StoreState.ACTIVE
        elif grace is not None and grace > datetime.now(UTC):
            state = StoreState.IN_GRACE_PERIOD
        else:
            state = StoreState.EXPIRED
        if state == StoreState.ACTIVE and not auto_renew:
            state = StoreState.CANCELED
        return VerifiedStorePurchase(
            store=Store.APPLE,
            store_subscription_id=str(tx["originalTransactionId"]),
            latest_transaction_id=str(tx.get("transactionId")),
            product_id=str(tx["productId"]),
            state=state,
            expires_at=expires,
            auto_renew=auto_renew,
            grace_expires_at=grace,
            revoked_at=revoked,
            environment=str(tx.get("environment", "Production")).lower(),
            account_token=(
                str(tx["appAccountToken"]).lower() if tx.get("appAccountToken") else None
            ),
            event_time=_ms(tx.get("signedDate")) or datetime.now(UTC),
        )

    def notification(self, signed_payload: str) -> StoreNotification:
        payload = self.decode(signed_payload)
        data = payload.get("data") or {}
        purchase = None
        if data.get("signedTransactionInfo"):
            purchase = self.purchase(
                data["signedTransactionInfo"], data.get("signedRenewalInfo"), data.get("status")
            )
        kind = str(payload.get("notificationType", ""))
        return StoreNotification(
            event_id=str(payload["notificationUUID"]),
            store=Store.APPLE,
            notification_type=kind,
            subtype=payload.get("subtype"),
            signed_at=_ms(payload.get("signedDate")) or datetime.now(UTC),
            store_subscription_id=purchase.store_subscription_id if purchase else None,
            purchase=purchase,
            refund=kind == "REFUND",
            revoke=kind == "REVOKE",
            environment=str(data.get("environment", "Production")).lower(),
        )


class AppleAppStoreVerifier:
    def __init__(
        self,
        *,
        issuer_id: str,
        key_id: str,
        private_key_pem: str,
        bundle_id: str,
        decoder: AppleSignedDataDecoder,
        use_sandbox: bool,
        client: httpx.Client | None = None,
    ) -> None:
        self._issuer = issuer_id
        self._kid = key_id
        self._key = private_key_pem
        self._bundle = bundle_id
        self._decoder = decoder
        self._bases = [SANDBOX_URL] if use_sandbox else [PRODUCTION_URL, SANDBOX_URL]
        self._sandbox_allowed = use_sandbox
        self._client = client or httpx.Client(timeout=10, headers={"User-Agent": USER_AGENT})

    def _token(self) -> str:
        now = int(time.time())
        return sign_es256(
            {
                "iss": self._issuer,
                "iat": now,
                "exp": now + 600,
                "aud": "appstoreconnect-v1",
                "bid": self._bundle,
            },
            self._key,
            self._kid,
        )

    def verify(
        self, *, store_subscription_id: str, product_id: str | None = None
    ) -> VerifiedStorePurchase:
        for base in self._bases:
            if base == SANDBOX_URL and not self._sandbox_allowed:
                break
            try:
                response = self._client.get(
                    f"{base}/inApps/v1/subscriptions/{store_subscription_id}",
                    headers={"Authorization": f"Bearer {self._token()}"},
                )
            except httpx.HTTPError as exc:
                raise StoreTemporaryError("app store unreachable") from exc
            if response.status_code == 404:
                continue
            if response.status_code == 429 or response.status_code >= 500:
                raise StoreTemporaryError(f"app store {response.status_code}")
            if response.status_code != 200:
                raise StoreRejectedError(f"app store {response.status_code}")
            for group in response.json().get("data", []):
                for item in group.get("lastTransactions", []):
                    return self._decoder.purchase(
                        item["signedTransactionInfo"],
                        item.get("signedRenewalInfo"),
                        item.get("status"),
                    )
            raise StoreRejectedError("no subscription in answer")
        raise StoreRejectedError("transaction not found")

    def acknowledge(self, purchase: VerifiedStorePurchase) -> None:
        """StoreKit 2: the app finishes the transaction; nothing server-side."""
        return None

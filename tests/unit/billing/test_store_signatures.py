"""Signed data from the stores: genuine chains pass, forgeries fail. Keys and
certificates are generated in the test; nothing real is used."""

from __future__ import annotations

import base64
import json
import time
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import NameOID

from packages.core.application.ports.store_billing import StoreRejectedError
from packages.core.domain.subscription.store import StoreState
from packages.infrastructure.billing.apple_app_store import AppleSignedDataDecoder
from packages.infrastructure.billing.google_play import (
    PubSubPushAuthenticator,
    parse_rtdn,
    parse_subscription_v2,
)
from packages.infrastructure.billing.jose import (
    JoseError,
    b64url_encode,
    sign_es256,
    sign_rs256,
    verify_apple_jws,
)


def _cert(
    subject: str,
    key: ec.EllipticCurvePrivateKey,
    issuer: str,
    issuer_key: ec.EllipticCurvePrivateKey,
    oid: str | None,
    ca: bool,
) -> x509.Certificate:
    now = datetime.now(UTC)
    builder = (
        x509.CertificateBuilder()
        .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, subject)]))
        .issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, issuer)]))
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=1))
        .not_valid_after(now + timedelta(days=30))
        .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True)
    )
    if oid:
        builder = builder.add_extension(
            x509.UnrecognizedExtension(x509.ObjectIdentifier(oid), b"\x05\x00"), critical=False
        )
    return builder.sign(issuer_key, hashes.SHA256())


class FakeApple:
    def __init__(self) -> None:
        self.root_key = ec.generate_private_key(ec.SECP256R1())
        self.int_key = ec.generate_private_key(ec.SECP256R1())
        self.leaf_key = ec.generate_private_key(ec.SECP256R1())
        self.root = _cert("Root", self.root_key, "Root", self.root_key, None, True)
        self.intermediate = _cert(
            "WWDR", self.int_key, "Root", self.root_key, "1.2.840.113635.100.6.2.1", True
        )
        self.leaf = _cert(
            "Leaf", self.leaf_key, "WWDR", self.int_key, "1.2.840.113635.100.6.11.1", False
        )

    def sign(self, payload: dict[str, object]) -> str:
        pem = self.leaf_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        ).decode()
        token = sign_es256(payload, pem, "unused")
        header = {
            "alg": "ES256",
            "x5c": [
                base64.b64encode(c.public_bytes(serialization.Encoding.DER)).decode()
                for c in (self.leaf, self.intermediate, self.root)
            ],
        }
        _, body, sig = token.split(".")
        # Re-sign with the x5c header.
        signing_input = f"{b64url_encode(json.dumps(header).encode())}.{body}"
        from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

        r, s = decode_dss_signature(
            self.leaf_key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
        )
        del sig
        return f"{signing_input}.{b64url_encode(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


@pytest.fixture(scope="module")
def apple() -> FakeApple:
    return FakeApple()


def _tx(**extra: object) -> dict[str, object]:
    return {
        "originalTransactionId": "1000",
        "transactionId": "1001",
        "productId": "net.quokkapet.pro.monthly",
        "bundleId": "net.quokkapet.app",
        "expiresDate": int((time.time() + 86400) * 1000),
        "environment": "Sandbox",
        "appAccountToken": "6F9619FF-8B86-4011-B42D-00C04FC964FF",
        "signedDate": int(time.time() * 1000),
        **extra,
    }


def test_genuine_apple_jws_is_accepted(apple: FakeApple) -> None:
    assert verify_apple_jws(apple.sign({"a": 1}), [apple.root]) == {"a": 1}


def test_apple_jws_from_an_untrusted_root_is_rejected(apple: FakeApple) -> None:
    other = FakeApple()
    with pytest.raises(JoseError):
        verify_apple_jws(other.sign({"a": 1}), [apple.root])


def test_tampered_apple_payload_is_rejected(apple: FakeApple) -> None:
    header, _, sig = apple.sign({"plan": "plus"}).split(".")
    forged = f"{header}.{b64url_encode(json.dumps({'plan': 'ultra'}).encode())}.{sig}"
    with pytest.raises(JoseError):
        verify_apple_jws(forged, [apple.root])


def test_unsigned_alg_none_is_rejected(apple: FakeApple) -> None:
    token = f"{b64url_encode(b'{"alg":"none"}')}.{b64url_encode(b'{}')}."
    with pytest.raises(JoseError):
        verify_apple_jws(token, [apple.root])


def test_apple_transaction_decodes_to_purchase(apple: FakeApple) -> None:
    decoder = AppleSignedDataDecoder(bundle_id="net.quokkapet.app", roots=[apple.root])
    renewal = apple.sign({"autoRenewStatus": 1})
    purchase = decoder.purchase(apple.sign(_tx()), renewal, status=1)
    assert purchase.state == StoreState.ACTIVE and purchase.environment == "sandbox"
    assert purchase.account_token == "6f9619ff-8b86-4011-b42d-00c04fc964ff"


def test_apple_refund_and_wrong_bundle(apple: FakeApple) -> None:
    decoder = AppleSignedDataDecoder(bundle_id="net.quokkapet.app", roots=[apple.root])
    refunded = decoder.purchase(
        apple.sign(_tx(revocationDate=int(time.time() * 1000), revocationReason=0)), None
    )
    assert refunded.state == StoreState.REFUNDED
    with pytest.raises(StoreRejectedError):
        decoder.purchase(apple.sign(_tx(bundleId="com.evil")), None)


def test_apple_notification_v2(apple: FakeApple) -> None:
    decoder = AppleSignedDataDecoder(bundle_id="net.quokkapet.app", roots=[apple.root])
    payload = apple.sign(
        {
            "notificationType": "REFUND",
            "notificationUUID": "uuid-1",
            "signedDate": int(time.time() * 1000),
            "data": {
                "bundleId": "net.quokkapet.app",
                "environment": "Sandbox",
                "signedTransactionInfo": apple.sign(_tx()),
            },
        }
    )
    notification = decoder.notification(payload)
    assert notification.refund is True and notification.event_id == "uuid-1"
    assert notification.store_subscription_id == "1000"


def test_google_subscription_v2_parsing() -> None:
    purchase = parse_subscription_v2(
        "tok",
        {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "acknowledgementState": "ACKNOWLEDGEMENT_STATE_PENDING",
            "latestOrderId": "GPA.1",
            "testPurchase": {},
            "linkedPurchaseToken": "old",
            "externalAccountIdentifiers": {"obfuscatedExternalAccountId": "ABC"},
            "lineItems": [
                {
                    "productId": "quokka_pro",
                    "expiryTime": "2030-01-01T00:00:00Z",
                    "autoRenewingPlan": {"autoRenewEnabled": True},
                    "offerDetails": {"basePlanId": "yearly"},
                }
            ],
        },
    )
    assert purchase.state == StoreState.ACTIVE and purchase.needs_acknowledgement
    assert purchase.environment == "sandbox" and purchase.base_plan_id == "yearly"
    assert purchase.linked_previous_id == "old" and purchase.account_token == "abc"
    pending = parse_subscription_v2(
        "t",
        {
            "subscriptionState": "SUBSCRIPTION_STATE_PENDING",
            "lineItems": [{"productId": "quokka_pro"}],
        },
    )
    assert pending.state == StoreState.PENDING


def _google_line(**extra: object) -> dict[str, object]:
    plan = {
        "autoRenewEnabled": True,
        "recurringPrice": {"currencyCode": "EUR", "units": "85", "nanos": 990000000},
        **extra.pop("plan", {}),  # type: ignore[dict-item]
    }
    return {
        "productId": "quokka_pro",
        "expiryTime": "2030-01-01T00:00:00Z",
        "autoRenewingPlan": plan,
        "offerDetails": {"basePlanId": "yearly"},
        **extra,
    }


def _google_price(line: dict[str, object]) -> object:
    return parse_subscription_v2(
        "tok", {"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE", "lineItems": [line]}
    ).renewal_price


def test_google_states_the_amount_of_the_next_renewal() -> None:
    price = _google_price(_google_line())
    assert price is not None
    assert (price.micros, price.currency) == (85_990_000, "EUR")  # type: ignore[attr-defined]
    whole = _google_price(
        _google_line(plan={"recurringPrice": {"currencyCode": "JPY", "units": "12500"}})
    )
    assert whole is not None and whole.micros == 12_500_000_000  # type: ignore[attr-defined]
    # A price change that has already been applied is the price.
    applied = _google_line(plan={"priceChangeDetails": {"priceChangeState": "APPLIED"}})
    assert _google_price(applied) is not None


@pytest.mark.parametrize(
    "line",
    [
        _google_line(plan={"recurringPrice": None}),
        _google_line(plan={"recurringPrice": {}}),
        _google_line(plan={"recurringPrice": {"currencyCode": "EUR"}}),
        _google_line(plan={"recurringPrice": {"currencyCode": "", "units": "85"}}),
        _google_line(plan={"recurringPrice": {"currencyCode": "EUR", "units": "a lot"}}),
        _google_line(plan={"recurringPrice": "85.99"}),
        # The next charge may be another one.
        _google_line(plan={"priceChangeDetails": {"priceChangeState": "OUTSTANDING"}}),
        _google_line(plan={"priceChangeDetails": {"priceChangeState": "CONFIRMED"}}),
        _google_line(plan={"installmentDetails": {"initialCommittedPaymentsCount": 12}}),
        _google_line(deferredItemReplacement={"productId": "quokka_plus"}),
        _google_line(offerDetails={"basePlanId": "yearly", "offerId": "trial"}),
        _google_line(autoRenewingPlan="unexpected"),
    ],
)
def test_google_s_amount_is_unknown_rather_than_invented(line: dict[str, object]) -> None:
    if line["autoRenewingPlan"] == "unexpected":
        # Not a plan at all: the verification itself keeps its old behaviour.
        from packages.infrastructure.billing.google_play import _renewal_price

        assert _renewal_price(line) is None
        return
    assert _google_price(line) is None


def test_apple_s_amount_is_not_read_yet(apple: FakeApple) -> None:
    """Until the field is checked on Apple's own reference the reminder does not go for Apple."""
    decoder = AppleSignedDataDecoder(bundle_id="net.quokkapet.app", roots=[apple.root])
    purchase = decoder.purchase(apple.sign(_tx()), apple.sign({"autoRenewStatus": 1}), 1)
    assert purchase.renewal_price is None


def test_rtdn_parsing_and_wrong_package() -> None:
    def envelope(data: dict[str, object]) -> dict[str, object]:
        return {
            "message": {
                "messageId": "m1",
                "data": base64.b64encode(json.dumps(data).encode()).decode(),
            }
        }

    note = parse_rtdn(
        envelope(
            {
                "packageName": "net.quokkapet.app",
                "eventTimeMillis": "1",
                "voidedPurchaseNotification": {"purchaseToken": "t"},
            }
        ),
        "net.quokkapet.app",
    )
    assert note is not None and note.refund is True
    assert (
        parse_rtdn(
            envelope({"packageName": "net.quokkapet.app", "testNotification": {}}),
            "net.quokkapet.app",
        )
        is None
    )
    with pytest.raises(StoreRejectedError):
        parse_rtdn(envelope({"packageName": "com.evil"}), "net.quokkapet.app")


class _Certs:
    def __init__(self, jwks: Any) -> None:
        self.jwks = jwks

    def get(self, url: str) -> object:
        jwks = self.jwks

        class R:
            status_code = 200

            def json(self) -> Any:
                return jwks

        return R()


def _pubsub(claims: dict[str, object]) -> tuple[PubSubPushAuthenticator, str]:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    numbers = key.public_key().public_numbers()
    jwks = {
        "keys": [
            {
                "kid": "k1",
                "n": b64url_encode(numbers.n.to_bytes(256, "big")),
                "e": b64url_encode(numbers.e.to_bytes(3, "big")),
            }
        ]
    }
    pem = key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    ).decode()
    auth = PubSubPushAuthenticator(
        audience="https://api.example.com/billing/google/notifications",
        service_account_email="push@example.com",
        client=_Certs(jwks),  # type: ignore[arg-type]
    )
    return auth, "Bearer " + sign_rs256(claims, pem, "k1")


_GOOD = {
    "iss": "https://accounts.google.com",
    "email": "push@example.com",
    "email_verified": True,
    "aud": "https://api.example.com/billing/google/notifications",
}


def test_pubsub_push_token_is_verified() -> None:
    auth, header = _pubsub({**_GOOD, "exp": int(time.time()) + 300})
    auth.verify(header)


@pytest.mark.parametrize("bad", [{"aud": "x"}, {"email": "evil@example.com"}, {"exp": 1}])
def test_pubsub_push_with_wrong_claims_is_rejected(bad: dict[str, object]) -> None:
    auth, header = _pubsub({**_GOOD, "exp": int(time.time()) + 300, **bad})
    with pytest.raises(StoreRejectedError):
        auth.verify(header)


def test_pubsub_push_without_token_is_rejected() -> None:
    auth, _ = _pubsub(_GOOD)
    with pytest.raises(StoreRejectedError):
        auth.verify(None)

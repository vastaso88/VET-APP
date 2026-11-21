"""Minimal JWS/JWT helpers on `cryptography` (ES256 for Apple, RS256 for Google).
No third-party JWT library: a few lines we can read and test."""

from __future__ import annotations

import base64
import json
import time
from typing import Any

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.asymmetric.utils import (
    decode_dss_signature,
    encode_dss_signature,
)

USER_AGENT = "QuokkaBilling/0.1"

# Apple marker OIDs: leaf (Mac App Store receipt signing) and WWDR intermediate.
_APPLE_LEAF_OID = x509.ObjectIdentifier("1.2.840.113635.100.6.11.1")
_APPLE_INTERMEDIATE_OID = x509.ObjectIdentifier("1.2.840.113635.100.6.2.1")


class JoseError(Exception):
    pass


def b64url_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def b64url_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def _split(token: str) -> tuple[dict[str, Any], dict[str, Any], bytes, bytes]:
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
        header = json.loads(b64url_decode(header_b64))
        payload = json.loads(b64url_decode(payload_b64))
    except (ValueError, json.JSONDecodeError) as exc:
        raise JoseError("malformed token") from exc
    return header, payload, f"{header_b64}.{payload_b64}".encode(), b64url_decode(sig_b64)


def sign_es256(payload: dict[str, Any], private_key_pem: str, kid: str) -> str:
    key = serialization.load_pem_private_key(private_key_pem.encode(), password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise JoseError("App Store key must be an EC P-256 key (.p8)")
    header = {"alg": "ES256", "kid": kid, "typ": "JWT"}
    signing_input = ".".join(
        b64url_encode(json.dumps(part, separators=(",", ":")).encode())
        for part in (header, payload)
    )
    r, s = decode_dss_signature(key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256())))
    return f"{signing_input}.{b64url_encode(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def sign_rs256(payload: dict[str, Any], private_key_pem: str, kid: str | None = None) -> str:
    key = serialization.load_pem_private_key(private_key_pem.encode(), password=None)
    if not isinstance(key, rsa.RSAPrivateKey):
        raise JoseError("Google service account key must be RSA")
    header: dict[str, Any] = {"alg": "RS256", "typ": "JWT"}
    if kid:
        header["kid"] = kid
    signing_input = ".".join(
        b64url_encode(json.dumps(part, separators=(",", ":")).encode())
        for part in (header, payload)
    )
    signature = key.sign(signing_input.encode(), padding.PKCS1v15(), hashes.SHA256())
    return f"{signing_input}.{b64url_encode(signature)}"


def verify_apple_jws(token: str, root_certificates: list[x509.Certificate]) -> dict[str, Any]:
    """Verifies an Apple-signed JWS (x5c chain up to a configured Apple root,
    Apple marker OIDs, ES256 signature) and returns its payload."""
    if not root_certificates:
        raise JoseError("no Apple root certificate configured")
    header, payload, signing_input, signature = _split(token)
    if header.get("alg") != "ES256":
        raise JoseError("unexpected alg")
    chain = header.get("x5c")
    if not isinstance(chain, list) or len(chain) < 3:
        raise JoseError("missing x5c chain")
    try:
        leaf, intermediate, root = (
            x509.load_der_x509_certificate(base64.b64decode(c)) for c in chain[:3]
        )
    except ValueError as exc:
        raise JoseError("bad certificate") from exc
    trusted = {c.fingerprint(hashes.SHA256()) for c in root_certificates}
    if root.fingerprint(hashes.SHA256()) not in trusted:
        raise JoseError("untrusted root")
    try:
        intermediate.verify_directly_issued_by(root)
        leaf.verify_directly_issued_by(intermediate)
    except (ValueError, TypeError, InvalidSignature) as exc:
        raise JoseError("broken certificate chain") from exc
    _require_extension(intermediate, _APPLE_INTERMEDIATE_OID)
    _require_extension(leaf, _APPLE_LEAF_OID)
    now = time.time()
    for cert in (leaf, intermediate, root):
        if not (
            cert.not_valid_before_utc.timestamp() <= now <= cert.not_valid_after_utc.timestamp()
        ):
            raise JoseError("certificate outside validity")
    public_key = leaf.public_key()
    if not isinstance(public_key, ec.EllipticCurvePublicKey) or len(signature) != 64:
        raise JoseError("bad signature")
    der = encode_dss_signature(
        int.from_bytes(signature[:32], "big"), int.from_bytes(signature[32:], "big")
    )
    try:
        public_key.verify(der, signing_input, ec.ECDSA(hashes.SHA256()))
    except InvalidSignature as exc:
        raise JoseError("invalid signature") from exc
    return payload


def _require_extension(cert: x509.Certificate, oid: x509.ObjectIdentifier) -> None:
    try:
        cert.extensions.get_extension_for_oid(oid)
    except x509.ExtensionNotFound as exc:
        raise JoseError("not an Apple certificate") from exc


def verify_rs256_with_jwks(token: str, jwks: dict[str, Any]) -> dict[str, Any]:
    header, payload, signing_input, signature = _split(token)
    if header.get("alg") != "RS256":
        raise JoseError("unexpected alg")
    key_data = next((k for k in jwks.get("keys", []) if k.get("kid") == header.get("kid")), None)
    if key_data is None:
        raise JoseError("unknown key id")
    public_key = rsa.RSAPublicNumbers(
        int.from_bytes(b64url_decode(key_data["e"]), "big"),
        int.from_bytes(b64url_decode(key_data["n"]), "big"),
    ).public_key()
    try:
        public_key.verify(signature, signing_input, padding.PKCS1v15(), hashes.SHA256())
    except InvalidSignature as exc:
        raise JoseError("invalid signature") from exc
    return payload

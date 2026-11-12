import hashlib
import hmac


def reporter_ref(owner_id: str, salt: str) -> str:
    """Stable pseudonym for a reporter: HMAC-SHA256 of the owner id under a
    server-side secret. The same owner always maps to the same value (so
    reports can be deduplicated and found again for an erasure request),
    but the value cannot be turned back into the owner id without the
    secret, which lives only in the backend's environment.
    """
    digest = hmac.new(salt.encode("utf-8"), owner_id.encode("utf-8"), hashlib.sha256)
    return digest.hexdigest()[:32]

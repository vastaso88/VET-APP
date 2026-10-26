class VetAppError(Exception):
    """Base application error."""


class AuthenticationError(VetAppError):
    """Raised when authentication is missing or invalid."""


class ValidationError(VetAppError):
    """Raised when a domain invariant is violated."""


class ProviderError(VetAppError):
    """Raised when an external provider fails."""


class QuotaExceededError(VetAppError):
    """A per-owner daily allowance is used up (vision, dictation, vet
    summary): the API answers 429 with [message], written for the owner
    in their language, and the seconds until the counter resets."""

    def __init__(self, kind: str, *, limit: int, retry_after_seconds: int, message: str) -> None:
        super().__init__(message)
        self.kind = kind
        self.limit = limit
        self.retry_after_seconds = retry_after_seconds
        self.message = message

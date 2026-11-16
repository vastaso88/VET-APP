class VetAppError(Exception):
    """Base application error."""


class AuthenticationError(VetAppError):
    """Raised when authentication is missing or invalid."""


class ValidationError(VetAppError):
    """Raised when a domain invariant is violated."""


class RequirementMissingError(ValidationError):
    """Refused because the owner has not given something yet (round 2 of the
    synthetic users, 2026-11-16: nobody could publish and the answer did not
    say why). The API answers 400 with `detail` and `code` = [code] (what the
    app already compares), [message] in the owner's language, and [fix]: the
    field to send, for anyone calling the API directly."""

    def __init__(self, code: str, *, message: str, fix: dict[str, object]) -> None:
        super().__init__(code)
        self.code = code
        self.message = message
        self.fix = fix


class ProviderError(VetAppError):
    """Raised when an external provider fails."""


class SubscriptionRequiredError(VetAppError):
    """The trial is over and the owner has no plan: the API answers 402
    `subscription_required` and the app shows the paywall."""


class AgeRestrictedError(VetAppError):
    """The owner's declared age (or the lack of one) does not allow this: the
    API answers 403 with the code as `code`: `age_required` (declare the date
    of birth first), `marketplace_adults_only`, `guardian_required` (a
    declared minor must confirm a parent's authorisation before a paid plan),
    `under_minimum_age` (account closed) or `age_already_declared`."""

    @property
    def code(self) -> str:
        return str(self)


class PlanLimitError(VetAppError):
    """The owner's plan does not allow more of [kind] ("pets",
    "chats_per_pet"): the API answers 403 `plan_limit_reached` with the
    limit, so the app can offer a higher plan."""

    def __init__(self, kind: str, *, limit: int, message: str) -> None:
        super().__init__(message)
        self.kind = kind
        self.limit = limit
        self.message = message


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


class MarketplaceRestrictedError(VetAppError):
    """The moderation team kept this owner out of the Mercatino: the API answers
    403 `marketplace_restricted` with the reason code and the date, and the app
    says it in the owner's language."""

    def __init__(self, *, reason: str, since: str) -> None:
        super().__init__("marketplace_restricted")
        self.reason = reason
        self.since = since

from typing import NamedTuple


class PaidCall(NamedTuple):
    """A model call the provider was paid for although nothing came of it."""

    model: str
    prompt_tokens: int
    completion_tokens: int
    cached_prompt_tokens: int = 0
    cache_write_tokens: int = 0


class VetAppError(Exception):
    """Base application error."""


class AuthenticationError(VetAppError):
    """Raised when authentication is missing or invalid."""


class ValidationError(VetAppError):
    """Raised when a domain invariant is violated."""


class ContentRefusedError(ValidationError):
    """The text of an ad is refused: `detail` is the sentence the app already compares,
    `terms` the words the automatic check found, so the seller reads them (DSA art. 17)."""

    def __init__(self, message: str, *, terms: list[str], code: str = "content_refused") -> None:
        super().__init__(message)
        self.terms = terms
        self.code = code


class RequirementMissingError(ValidationError):
    """Refused because the owner has not given something yet (round 2 of the
    synthetic users, 2026-11-16: nobody could publish and the answer did not
    say why). The API answers 400 with `detail` and `code` = [code] (what the
    app already compares), [message] in the owner's language, and [fix]: the
    field to send, for anyone calling the API directly. [detail]: what an app too old
    to know the code shows as it comes, when the bare code would not do."""

    def __init__(
        self, code: str, *, message: str, fix: dict[str, object], detail: str | None = None
    ) -> None:
        super().__init__(code)
        self.detail = detail or code
        self.code = code
        self.message = message
        self.fix = fix


class ConversationLimitError(ValidationError):
    """The owner already has as many chats open for this pet as the plan allows:
    the API answers 400 with `detail` "conversation_limit_reached: <text>" (the
    app reads the prefix as its signal), and also the bare `code` and the `text`
    written for the owner in their language, so a client that is not the app
    never has to show the technical prefix."""

    code = "conversation_limit_reached"

    def __init__(self, message: str, *, limit: int) -> None:
        super().__init__(f"{self.code}: {message}")
        self.message = message
        self.limit = limit


class ProviderError(VetAppError):
    """Raised when an external provider fails."""

    # The calls already paid when it failed: the spending guard counts them too.
    paid_calls: tuple[PaidCall, ...] = ()


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


class PetInMemoriesError(VetAppError):
    """The pet is in Ricordi (docs/product/17_ricordi_animali.md): its data
    can be read, exported and deleted, never added to or changed. The API
    answers 409 `pet_in_memories`; the owner brings the pet back to Animali
    first."""

    def __init__(self) -> None:
        super().__init__("pet_in_memories")


class ConsentRequiredError(VetAppError):
    """The Terms and the Privacy notice are not accepted at the current version:
    the API answers 403 `consent_required` and the app shows the acceptance
    screen, then retries."""

    @property
    def code(self) -> str:
        return str(self)


class MarketplaceRulesRequiredError(VetAppError):
    """The owner has not accepted the current Mercatino rules: the API answers
    403 `marketplace_rules_required` and the app shows the rules with their checkbox."""

    def __init__(self) -> None:
        super().__init__("marketplace_rules_required")


class PlanLimitError(VetAppError):
    """The owner's plan does not allow more of [kind] ("pets",
    "chats_per_pet"): the API answers 403 `plan_limit_reached` with the
    limit, so the app can offer a higher plan."""

    def __init__(
        self, kind: str, *, limit: int, message: str, upgrade_to: str | None = None
    ) -> None:
        super().__init__(message)
        self.kind = kind
        self.limit = limit
        self.message = message
        # The plan one step above ("pro", "ultra"), when there is one to suggest.
        self.upgrade_to = upgrade_to


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

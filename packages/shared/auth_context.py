from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar, Token
from typing import Any, NamedTuple

_access_token: ContextVar[str | None] = ContextVar("access_token", default=None)


class RequestIdentityMemo:
    """What was already established for the request being served: who the caller is (the
    identity provider's answer) and the outcome of the subscription lookup.

    One instance is created together with the access token of a request and lives only as
    long as it. Both parts are bound to the token they were filled for, so a lookup made
    with any other token finds nothing: nothing can be handed to a different caller, and a
    new request (new token context, new memo) always starts empty. Failures are never stored,
    so a rejected or revoked token is checked again every time."""

    def __init__(self) -> None:
        self._entry: tuple[str, Any] | None = None
        self._subscriptions: dict[tuple[str, str, str, bool | None], Any] = {}
        self._quota_uses: list[Any] = []

    # --- identity -------------------------------------------------------------------

    def get(self, token: str) -> Any | None:
        entry = self._entry
        if entry is not None and entry[0] == token:
            return entry[1]
        return None

    def put(self, token: str, identity: Any) -> None:
        self._entry = (token, identity)

    def clear(self) -> None:
        self._entry = None

    # --- subscription outcome ---------------------------------------------------------

    def get_subscription(
        self, token: str, owner_id: str, email: str, email_verified: bool | None
    ) -> Any | None:
        """The outcome already computed in this request for this token, this owner and this
        address. A caller that cannot tell whether the address is confirmed (None) may reuse
        the outcome of a confirmed one, never of an unconfirmed one: the confirmed lookup
        already saved whatever the address earns, so repeating it would answer the same."""
        found = self._subscriptions.get((token, owner_id, email, email_verified))
        if found is None and email_verified is None:
            found = self._subscriptions.get((token, owner_id, email, True))
        return found

    def put_subscription(
        self, token: str, owner_id: str, email: str, email_verified: bool | None, outcome: Any
    ) -> None:
        self._subscriptions[(token, owner_id, email, email_verified)] = outcome

    # --- daily allowances counted in this request -----------------------------------

    def note_quota_use(self, use: Any) -> None:
        """An allowance (a question, a photo reading, a dictation...) was counted for this
        request. If the request then fails through no fault of the owner, the use is given
        back (`take_quota_uses` + the budget's refund): only what the owner received counts."""
        self._quota_uses.append(use)

    def take_quota_uses(self) -> list[Any]:
        """The uses counted so far in this request, removed from the list: whoever takes them
        gives them back, so a use can never be returned twice."""
        taken, self._quota_uses = self._quota_uses, []
        return taken

    def forget_subscriptions(self, owner_id: str) -> None:
        """Drops every remembered outcome of one owner: their plan or state just changed."""
        for key in [key for key in self._subscriptions if key[1] == owner_id]:
            del self._subscriptions[key]


# A ContextVar holding a mutable object, not the values themselves: sync routes and
# dependencies run in worker threads that receive a copy of the context, and only a shared
# object lets what one dependency established be seen by the next one of the same request.
_identity_memo: ContextVar[RequestIdentityMemo | None] = ContextVar("identity_memo", default=None)


class AccessTokenState(NamedTuple):
    """What `set_access_token` changed, so `reset_access_token` can put each back as it was."""

    access_token: Token[str | None]
    memo: Token[RequestIdentityMemo | None]


def get_access_token() -> str | None:
    return _access_token.get()


def get_identity_memo() -> RequestIdentityMemo | None:
    """The memo of the current request, or None outside a request (scripts, jobs)."""
    return _identity_memo.get()


def forget_request_subscription(owner_id: str) -> None:
    """Call after a plan or an account state of [owner_id] changed: the subscription outcome
    remembered for this request (if any) is no longer true."""
    memo = _identity_memo.get()
    if memo is not None:
        memo.forget_subscriptions(owner_id)


def set_access_token(token: str | None) -> AccessTokenState:
    memo_state = _identity_memo.set(RequestIdentityMemo())
    return AccessTokenState(_access_token.set(token), memo_state)


def reset_access_token(state: AccessTokenState) -> None:
    """Puts back the token and the memo that were in place before `set_access_token`
    (nested contexts: the outer one keeps what it had already remembered)."""
    _identity_memo.reset(state.memo)
    _access_token.reset(state.access_token)


@contextmanager
def access_token_context(token: str | None) -> Iterator[None]:
    state = set_access_token(token)
    try:
        yield
    finally:
        reset_access_token(state)

from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar, Token
from typing import Any

_access_token: ContextVar[str | None] = ContextVar("access_token", default=None)


class RequestIdentityMemo:
    """What the identity provider already verified for the request being served.

    One instance is created together with the access token of a request and lives only
    as long as it. It is bound to the token it was filled for: a lookup with any other
    token finds nothing, so an identity can never be handed to a different caller, and a
    new request (new token context, new memo) always starts empty. Failures are never
    stored, so a rejected or revoked token is checked again every time."""

    def __init__(self) -> None:
        self._entry: tuple[str, Any] | None = None

    def get(self, token: str) -> Any | None:
        entry = self._entry
        if entry is not None and entry[0] == token:
            return entry[1]
        return None

    def put(self, token: str, identity: Any) -> None:
        self._entry = (token, identity)

    def clear(self) -> None:
        self._entry = None


# A ContextVar holding a mutable object, not the identity itself: sync routes and
# dependencies run in worker threads that receive a copy of the context, and only a shared
# object lets what one dependency verified be seen by the next one of the same request.
_identity_memo: ContextVar[RequestIdentityMemo | None] = ContextVar("identity_memo", default=None)


def get_access_token() -> str | None:
    return _access_token.get()


def get_identity_memo() -> RequestIdentityMemo | None:
    """The memo of the current request, or None outside a request (scripts, jobs)."""
    return _identity_memo.get()


def set_access_token(token: str | None) -> Token[str | None]:
    _identity_memo.set(RequestIdentityMemo())
    return _access_token.set(token)


def reset_access_token(token: Token[str | None]) -> None:
    _identity_memo.set(None)
    _access_token.reset(token)


@contextmanager
def access_token_context(token: str | None) -> Iterator[None]:
    state = set_access_token(token)
    try:
        yield
    finally:
        reset_access_token(state)

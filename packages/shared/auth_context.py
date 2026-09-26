from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar, Token

_access_token: ContextVar[str | None] = ContextVar("access_token", default=None)


def get_access_token() -> str | None:
    return _access_token.get()


def set_access_token(token: str | None) -> Token[str | None]:
    return _access_token.set(token)


def reset_access_token(token: Token[str | None]) -> None:
    _access_token.reset(token)


@contextmanager
def access_token_context(token: str | None) -> Iterator[None]:
    state = set_access_token(token)
    try:
        yield
    finally:
        reset_access_token(state)

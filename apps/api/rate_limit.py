"""Best-effort request throttling for the few routes that cost money or
guard credentials.

Why "best effort": the API runs as serverless functions, so this counter
lives in each instance's memory and is not shared across instances or
cold starts. It still stops the cheap attacks (a loop from one client
hammering /auth/login or /speech-to-text through a single warm
instance) and documents the intended ceilings; a shared store (the
`chat_user_daily_usage` table, or Supabase's own auth rate limits) is the
place for hard guarantees.

Keys: the bearer token's hash when present (one user), otherwise the
client address. Vercel puts the real client in `X-Forwarded-For`
(first hop); the header is only trusted when the app runs behind it.
"""

from __future__ import annotations

import hashlib
import threading
import time
from collections import deque
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from fastapi import Request, Response
from fastapi.responses import JSONResponse


@dataclass(frozen=True)
class RateLimitRule:
    """`limit` requests per `window_seconds` for paths starting with `prefix`."""

    prefix: str
    limit: int
    window_seconds: float
    methods: frozenset[str] = frozenset({"POST"})


DEFAULT_RULES: tuple[RateLimitRule, ...] = (
    # Credential endpoints: slow down guessing (Supabase has its own limits
    # too, but they count the backend's egress IP for everyone).
    RateLimitRule(prefix="/auth/login", limit=10, window_seconds=60.0),
    RateLimitRule(prefix="/auth/signup", limit=5, window_seconds=60.0),
    # Model calls outside the per-user daily chat quota.
    RateLimitRule(prefix="/speech-to-text", limit=20, window_seconds=600.0),
    RateLimitRule(prefix="/chat-attachments", limit=20, window_seconds=600.0),
)


class SlidingWindowLimiter:
    def __init__(
        self,
        rules: tuple[RateLimitRule, ...] = DEFAULT_RULES,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._rules = rules
        self._clock = clock
        self._hits: dict[tuple[str, str], deque[float]] = {}
        self._lock = threading.Lock()

    def rule_for(self, method: str, path: str) -> RateLimitRule | None:
        for rule in self._rules:
            if method.upper() in rule.methods and path.startswith(rule.prefix):
                return rule
        return None

    def allow(self, rule: RateLimitRule, key: str) -> bool:
        now = self._clock()
        with self._lock:
            bucket = self._hits.setdefault((rule.prefix, key), deque())
            while bucket and now - bucket[0] > rule.window_seconds:
                bucket.popleft()
            if len(bucket) >= rule.limit:
                return False
            bucket.append(now)
            # Keep the table from growing with one-off callers.
            if len(self._hits) > 10_000:
                stale = [k for k, v in self._hits.items() if not v or now - v[-1] > 3600]
                for k in stale:
                    del self._hits[k]
            return True


def client_key(request: Request) -> str:
    auth_header = request.headers.get("Authorization", "")
    if auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1].strip()
        if token:
            return "tok:" + hashlib.sha256(token.encode()).hexdigest()[:32]
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return "ip:" + forwarded.split(",")[0].strip()
    client = request.client
    return "ip:" + (client.host if client else "unknown")


def build_middleware(
    limiter: SlidingWindowLimiter,
) -> Callable[[Request, Callable[[Request], Awaitable[Response]]], Awaitable[Response]]:
    async def middleware(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        rule = limiter.rule_for(request.method, request.url.path)
        if rule is not None and not limiter.allow(rule, client_key(request)):
            return JSONResponse(
                status_code=429,
                content={"detail": "Troppe richieste: riprova tra poco."},
                headers={"Retry-After": str(int(rule.window_seconds))},
            )
        return await call_next(request)

    return middleware

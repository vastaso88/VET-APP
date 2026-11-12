from __future__ import annotations

from functools import lru_cache
from typing import TYPE_CHECKING

from packages.shared.config.settings import Settings

if TYPE_CHECKING:
    from supabase import Client


def build_supabase_client(settings: Settings) -> Client:
    """The service-role client, one per process. Every repository used to
    create its own: on a cold serverless instance each of them then paid
    its own TLS handshake with the database the first time it was used.
    Sharing is safe because nothing signs a user in on this client (the
    auth provider does that on the public one), so its credentials never
    change."""
    return _service_client(settings.supabase_url, settings.supabase_service_role_key)


@lru_cache(maxsize=4)
def _service_client(url: str, key: str) -> Client:
    from supabase import create_client

    return create_client(url, key)


def build_supabase_public_client(settings: Settings) -> Client:
    from supabase import create_client

    return create_client(settings.supabase_url, settings.supabase_anon_key)

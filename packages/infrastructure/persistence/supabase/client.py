from __future__ import annotations

from typing import TYPE_CHECKING

from packages.shared.config.settings import Settings

if TYPE_CHECKING:
    from supabase import Client


def build_supabase_client(settings: Settings) -> Client:
    from supabase import create_client

    return create_client(settings.supabase_url, settings.supabase_service_role_key)


def build_supabase_public_client(settings: Settings) -> Client:
    from supabase import create_client

    return create_client(settings.supabase_url, settings.supabase_anon_key)

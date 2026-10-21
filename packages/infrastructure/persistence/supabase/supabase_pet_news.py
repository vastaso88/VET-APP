from __future__ import annotations

from typing import TYPE_CHECKING

from packages.core.application.ports.pet_news import PetNewsCacheRepository
from packages.core.domain.pet_news.models import PetNewsSnapshot

if TYPE_CHECKING:
    from supabase import Client


class SupabasePetNewsCacheRepository(PetNewsCacheRepository):
    """One row per audience in `pet_news_snapshots`, written only by the
    backend (service role): the app never reads the table directly."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "pet_news_snapshots"

    def get(self, key: str) -> PetNewsSnapshot | None:
        response = self._client.table(self._table).select("*").eq("key", key).limit(1).execute()
        if not response.data:
            return None
        return PetNewsSnapshot.model_validate(response.data[0])

    def put(self, snapshot: PetNewsSnapshot) -> None:
        self._client.table(self._table).upsert(snapshot.model_dump(mode="json")).execute()

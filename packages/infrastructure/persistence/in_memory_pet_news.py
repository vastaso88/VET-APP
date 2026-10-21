from packages.core.application.ports.pet_news import PetNewsCacheRepository
from packages.core.domain.pet_news.models import PetNewsSnapshot


class InMemoryPetNewsCacheRepository(PetNewsCacheRepository):
    def __init__(self) -> None:
        self._snapshots: dict[str, PetNewsSnapshot] = {}

    def get(self, key: str) -> PetNewsSnapshot | None:
        return self._snapshots.get(key)

    def put(self, snapshot: PetNewsSnapshot) -> None:
        self._snapshots[snapshot.key] = snapshot

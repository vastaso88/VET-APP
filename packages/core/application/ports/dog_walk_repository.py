from typing import Protocol

from packages.core.domain.dog_walk.models import WalkSession


class DogWalkRepository(Protocol):
    def save(self, walk: WalkSession) -> WalkSession: ...

    def get(self, walk_id: str) -> WalkSession | None: ...

    def list_by_owner(self, owner_id: str) -> list[WalkSession]: ...

from pydantic import BaseModel

from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.domain.dog_walk.models import WalkSession


class ListWalksInput(BaseModel):
    owner_id: str


class ListWalksOutput(BaseModel):
    walks: list[WalkSession]


class ListWalksService:
    def __init__(self, repository: DogWalkRepository) -> None:
        self._repository = repository

    def execute(self, data: ListWalksInput) -> ListWalksOutput:
        return ListWalksOutput(walks=self._repository.list_by_owner(data.owner_id))

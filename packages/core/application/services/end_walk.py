from pydantic import BaseModel

from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.domain.common.entity import utc_now
from packages.core.domain.dog_walk.models import WalkSession, estimate_steps
from packages.shared.errors.base import ValidationError


class EndWalkInput(BaseModel):
    walk_id: str
    owner_id: str


class EndWalkOutput(BaseModel):
    walk: WalkSession


class EndWalkService:
    def __init__(self, repository: DogWalkRepository) -> None:
        self._repository = repository

    def execute(self, data: EndWalkInput) -> EndWalkOutput:
        walk = self._repository.get(data.walk_id)
        if walk is None:
            raise ValidationError("walk not found")
        if walk.owner_id != data.owner_id:
            raise ValidationError("walk does not belong to owner")
        if walk.status != "in_progress":
            raise ValidationError("walk is already finished")

        ended_at = utc_now()
        duration_seconds = int((ended_at - walk.started_at).total_seconds())
        updated = walk.model_copy(
            update={
                "status": "completed",
                "ended_at": ended_at,
                "duration_seconds": duration_seconds,
                "step_count_estimate": estimate_steps(walk.distance_meters),
            }
        )
        return EndWalkOutput(walk=self._repository.save(updated))

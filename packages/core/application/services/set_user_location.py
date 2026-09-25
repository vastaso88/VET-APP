from pydantic import BaseModel

from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates, LocationMode, LocationSource, UserLocation


class SetUserLocationInput(BaseModel):
    owner_id: str
    mode: LocationMode | None = None
    home: Coordinates | None = None
    home_label: str | None = None
    current: Coordinates | None = None
    current_label: str | None = None
    current_source: LocationSource | None = None


class SetUserLocationOutput(BaseModel):
    user_location: UserLocation


class SetUserLocationService:
    """Updates whichever fields the caller explicitly set, leaving the rest
    of the owner's existing record untouched - e.g. refreshing `current`
    from a new GPS fix shouldn't erase a previously saved `home`. A field
    left out of the input keeps its existing value; a field explicitly
    passed as `None` (e.g. `home=None`) clears it - `model_fields_set`
    distinguishes the two, since an omitted field never enters that set."""

    def __init__(self, repository: UserLocationRepository) -> None:
        self._repository = repository

    def execute(self, data: SetUserLocationInput) -> SetUserLocationOutput:
        existing = self._repository.get(data.owner_id) or UserLocation(owner_id=data.owner_id)
        fields = ("mode", "home", "home_label", "current", "current_label", "current_source")
        updates = {
            field: getattr(data, field) for field in fields if field in data.model_fields_set
        }
        if "current" in updates:
            updates["current_captured_at"] = utc_now() if updates["current"] is not None else None
        updated = existing.model_copy(update={**updates, "updated_at": utc_now()})
        return SetUserLocationOutput(user_location=self._repository.save(updated))

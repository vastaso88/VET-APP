from typing import Protocol

from packages.core.domain.pet_profile.weight_measurement import WeightMeasurement


class WeightMeasurementRepository(Protocol):
    def latest_for_pet(self, owner_id: str, pet_id: str) -> WeightMeasurement | None:
        """The most recent weighing of this owner's pet, or None."""
        ...

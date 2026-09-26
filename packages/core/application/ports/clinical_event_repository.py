from typing import Protocol

from packages.core.domain.medical_record.models import ClinicalEvent


class ClinicalEventRepository(Protocol):
    def list_by_pet(self, pet_id: str) -> list[ClinicalEvent]: ...

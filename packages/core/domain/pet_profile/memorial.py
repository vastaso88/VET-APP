"""Ricordi: a pet that passed away (docs/product/17_ricordi_animali.md).

Its profile, photos, walks, records and past chats stay readable and
exportable, and can be deleted; nothing is added to them or changed while the
pet is in Ricordi. The app writes most of these tables directly, where
scripts/setup/ricordi_animali.sql applies the same rule; the backend routes
that take a pet check it here.
"""

from packages.core.domain.pet_profile.models import PetProfile
from packages.shared.errors.base import PetInMemoriesError


def ensure_not_in_memories(pet_profile: PetProfile) -> None:
    if pet_profile.is_memorial:
        raise PetInMemoriesError()

"""Collaudo F41: the API did not say whether a pet is in Ricordi (the field is never written by
the backend, so it was never dumped). The list and the single pet now carry `is_memorial`, in the
answer only: saving a pet still cannot bring it back."""

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.pet_profile.models import PetProfile


def test_the_list_and_the_single_pet_say_if_a_pet_is_in_ricordi() -> None:
    client = TestClient(app)
    alive = client.post("/pets", json={"name": "Vivo", "species": "Gatto"}).json()["pet_profile"]
    memorial = PetProfile(
        id="pet-ricordo", owner_id="demo-user", name="Nocciola", species="Gatto", is_memorial=True
    )
    get_container().pet_profile_repository.save(memorial)

    listed = {p["id"]: p for p in client.get("/pets").json()["pet_profiles"]}

    assert listed[alive["id"]]["is_memorial"] is False
    assert listed["pet-ricordo"]["is_memorial"] is True
    assert client.get("/pets/pet-ricordo").json()["pet_profile"]["is_memorial"] is True
    assert client.get(f"/pets/{alive['id']}").json()["pet_profile"]["is_memorial"] is False


def test_the_field_is_never_taken_from_a_save() -> None:
    dumped = PetProfile(owner_id="o", name="N", species="Cane", is_memorial=True).model_dump()

    assert "is_memorial" not in dumped  # what the repositories write

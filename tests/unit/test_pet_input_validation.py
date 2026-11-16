import re
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.application.services.update_pet_profile import (
    UpdatePetProfileInput,
    UpdatePetProfileService,
)
from packages.core.domain.pet_profile.models import FishStock, PetProfile
from packages.core.domain.pet_profile.validation import (
    PetInputError,
    parse_weight_kg,
    validate_pet_fields,
)
from packages.infrastructure.persistence.in_memory_repositories import InMemoryPetProfileRepository
from packages.shared.errors.base import ValidationError

OWNER = "owner-a"
STRANGER = "owner-b"


def _repository() -> InMemoryPetProfileRepository:
    repository = InMemoryPetProfileRepository()
    repository.save(
        PetProfile(
            id="pet-1",
            owner_id=OWNER,
            name="Milo",
            species="Cane",
            breed="Beagle",
            notes="Allergico al pollo",
            sex="Maschio",
            dog_size_category="Medio",
            weight_label="12 kg",
            aquarium_stock=[FishStock(species="Guppy", male_count=1, female_count=2)],
        )
    )
    return repository


@pytest.mark.parametrize(
    ("label", "kilograms"),
    [("23 kg", 23.0), ("17,8 kg", 17.8), ("450 g", 0.45), ("12", 12.0), ("10 lb", 4.5359237)],
)
def test_a_weight_label_is_read_in_kilograms(label: str, kilograms: float) -> None:
    assert parse_weight_kg(label) == pytest.approx(kilograms)


@pytest.mark.parametrize("label", ["-19 kg", "-5 g", "tanto", "kg", "", "1e3 kg"])
def test_a_weight_label_that_is_negative_or_unreadable_is_not_read(label: str) -> None:
    assert parse_weight_kg(label) is None


@pytest.mark.parametrize(
    ("values", "touched", "code"),
    [
        ({"name": "  "}, {"name"}, "name_required"),
        ({"name": ""}, {"name"}, "name_required"),
        ({"name": "Smaug", "species": "Drago"}, {"species"}, "species_unknown"),
        ({"species": "Cane", "age_years": 200}, {"age_years"}, "age_out_of_range"),
        ({"species": "Cane", "age_years": 40}, {"age_years"}, "age_out_of_range"),
        ({"species": "Cane", "age_years": -1}, {"age_years"}, "age_out_of_range"),
        ({"species": "Cane", "weight_label": "-19 kg"}, {"weight_label"}, "weight_unreadable"),
        ({"species": "Cane", "weight_label": "-5 g"}, {"weight_label"}, "weight_unreadable"),
        ({"species": "Cane", "weight_label": "9999 kg"}, {"weight_label"}, "weight_out_of_range"),
        ({"species": "Gatto", "weight_label": "0 kg"}, {"weight_label"}, "weight_out_of_range"),
        ({"species": "Gatto", "weight_label": "60 kg"}, {"weight_label"}, "weight_out_of_range"),
        (
            {"species": "Cane", "activity_level": "frenetic"},
            {"activity_level"},
            "activity_level_invalid",
        ),
        (
            {"species": "Cane", "body_condition": "huge"},
            {"body_condition"},
            "body_condition_invalid",
        ),
        ({"species": "Cane", "microchip_number": "123"}, {"microchip_number"}, "microchip_invalid"),
    ],
)
def test_absurd_values_are_refused_with_a_code(
    values: dict[str, object], touched: set[str], code: str
) -> None:
    with pytest.raises(PetInputError) as error:
        validate_pet_fields(values, touched)

    assert error.value.code == code


@pytest.mark.parametrize(
    "values",
    [
        {"name": "Rex", "species": "Cane", "age_years": 16, "weight_label": "32 kg"},
        {"name": "Kiwi", "species": "Uccello", "age_years": 40, "weight_label": "90 g"},
        {"name": "Tito", "species": "Rettili e anfibi", "age_years": 80, "weight_label": "150 kg"},
        {"name": "Dolly", "species": "dog", "age_years": 3, "weight_label": "8,5 kg"},
    ],
)
def test_ordinary_and_unusual_but_real_values_pass(values: dict[str, object]) -> None:
    validate_pet_fields(values, set(values))


def test_what_nobody_touched_is_not_judged() -> None:
    # A row saved long ago with an odd weight: changing the name must not fail.
    validate_pet_fields({"name": "Nuovo", "species": "Cane", "weight_label": "boh"}, {"name"})


def test_every_message_exists_in_the_five_languages() -> None:
    error = PetInputError("age_out_of_range", "age_years", max=35)
    texts = {language: error.message(language) for language in ("it", "en", "es", "de", "fr")}

    assert len(set(texts.values())) == 5
    assert all("35" in text for text in texts.values())
    assert error.message(None) == texts["it"]
    assert error.message("ja") == texts["it"]


def test_the_message_catalogue_is_complete_for_every_language() -> None:
    from packages.core.domain.pet_profile import validation

    codes = {code for catalogue in validation._MESSAGES.values() for code in catalogue}
    for language, catalogue in validation._MESSAGES.items():
        assert set(catalogue) == codes, language


# --- partial update -------------------------------------------------------------------


def test_updating_only_the_weight_keeps_everything_else() -> None:
    service = UpdatePetProfileService(_repository())

    result = service.execute(
        UpdatePetProfileInput(pet_id="pet-1", owner_id=OWNER, weight_label="13 kg")
    )

    pet = result.pet_profile
    assert pet.weight_label == "13 kg"
    assert (pet.name, pet.species, pet.breed) == ("Milo", "Cane", "Beagle")
    assert (pet.notes, pet.sex, pet.dog_size_category) == ("Allergico al pollo", "Maschio", "Medio")
    assert [stock.species for stock in pet.aquarium_stock] == ["Guppy"]


def test_an_explicit_null_clears_an_optional_field_only() -> None:
    service = UpdatePetProfileService(_repository())

    pet = service.execute(
        UpdatePetProfileInput(pet_id="pet-1", owner_id=OWNER, notes=None)
    ).pet_profile

    assert pet.notes is None
    assert pet.breed == "Beagle"


def test_a_name_or_species_cannot_be_blanked_or_invented_by_an_update() -> None:
    service = UpdatePetProfileService(_repository())

    with pytest.raises(PetInputError) as blank:
        service.execute(UpdatePetProfileInput(pet_id="pet-1", owner_id=OWNER, name=" "))
    with pytest.raises(PetInputError) as null_species:
        service.execute(UpdatePetProfileInput(pet_id="pet-1", owner_id=OWNER, species=None))
    with pytest.raises(PetInputError) as invented:
        service.execute(UpdatePetProfileInput(pet_id="pet-1", owner_id=OWNER, species="Drago"))

    assert (blank.value.code, null_species.value.code, invented.value.code) == (
        "name_required",
        "species_unknown",
        "species_unknown",
    )


def test_a_species_change_rechecks_the_weight_already_saved() -> None:
    service = UpdatePetProfileService(_repository())

    # The saved 12 kg is judged again against the new species (a cat tops out at 25 kg).
    with pytest.raises(PetInputError) as error:
        service.execute(
            UpdatePetProfileInput(
                pet_id="pet-1", owner_id=OWNER, species="Gatto", weight_label="40 kg"
            )
        )

    assert error.value.code == "weight_out_of_range"


def test_a_refused_update_changes_nothing() -> None:
    repository = _repository()
    service = UpdatePetProfileService(repository)

    with pytest.raises(PetInputError):
        service.execute(
            UpdatePetProfileInput(pet_id="pet-1", owner_id=OWNER, weight_label="-19 kg")
        )

    assert repository.get("pet-1").weight_label == "12 kg"  # type: ignore[union-attr]


def test_user_b_cannot_update_user_as_pet_even_partially() -> None:
    repository = _repository()
    service = UpdatePetProfileService(repository)

    with pytest.raises(ValidationError, match="pet_profile not found"):
        service.execute(
            UpdatePetProfileInput(pet_id="pet-1", owner_id=STRANGER, weight_label="1 kg")
        )

    assert repository.get("pet-1").weight_label == "12 kg"  # type: ignore[union-attr]


def test_create_refuses_the_same_absurd_values() -> None:
    service = CreatePetProfileService(InMemoryPetProfileRepository())

    cases: list[tuple[dict[str, Any], str]] = [
        ({"name": ""}, "name_required"),
        ({"species": "Drago"}, "species_unknown"),
        ({"age_years": 200}, "age_out_of_range"),
        ({"weight_label": "-19 kg"}, "weight_unreadable"),
        ({"weight_label": "9999 kg"}, "weight_out_of_range"),
        ({"activity_level": "frenetic"}, "activity_level_invalid"),
    ]
    for extra, code in cases:
        payload: dict[str, Any] = {"owner_id": OWNER, "name": "Milo", "species": "Cane", **extra}
        with pytest.raises(PetInputError) as error:
            service.execute(CreatePetProfileInput(**payload))
        assert error.value.code == code, extra


# --- through the API ------------------------------------------------------------------


def _new_pet(client: TestClient) -> str:
    response = client.post(
        "/pets",
        json={
            "name": "Milo",
            "species": "Cane",
            "breed": "Beagle",
            "notes": "nota",
            "sex": "Maschio",
        },
    )
    assert response.status_code == 200
    return str(response.json()["pet_profile"]["id"])


def test_api_put_with_only_the_weight_keeps_the_rest() -> None:
    client = TestClient(app)
    pet_id = _new_pet(client)

    response = client.put(f"/pets/{pet_id}", json={"weight_label": "14 kg"})

    assert response.status_code == 200
    pet = response.json()["pet_profile"]
    assert (pet["weight_label"], pet["breed"], pet["notes"], pet["sex"]) == (
        "14 kg",
        "Beagle",
        "nota",
        "Maschio",
    )


def test_api_refuses_absurd_values_with_422_and_a_message_in_the_language() -> None:
    client = TestClient(app)
    pet_id = _new_pet(client)

    invented = client.post("/pets", json={"name": "Smaug", "species": "Drago"})
    heavy = client.put(
        f"/pets/{pet_id}", json={"weight_label": "9999 kg"}, headers={"Accept-Language": "de-DE"}
    )
    activity = client.put(f"/pets/{pet_id}", json={"activity_level": "frenetic"})

    assert invented.status_code == 422
    assert invented.json()["code"] == "species_unknown"
    assert invented.json()["field"] == "species"
    assert heavy.status_code == 422
    assert heavy.json()["code"] == "weight_out_of_range"
    assert "Gewicht" in heavy.json()["detail"]
    assert activity.status_code == 422, "an invalid level is a refusal, not an internal error"
    assert activity.json()["code"] == "activity_level_invalid"
    assert client.get(f"/pets/{pet_id}").json()["pet_profile"]["weight_label"] is None


def test_deleting_a_pet_is_done_by_the_app_on_supabase_and_only_for_its_owner() -> None:
    # No API route deletes a pet: the app does it on the table, where this policy
    # keeps it to the owner's own rows (the same "user B" rule as the other tables).
    schema = (Path(__file__).resolve().parents[2] / "scripts/setup/supabase_schema.sql").read_text(
        encoding="utf-8"
    )
    policy = re.search(
        r"create policy pet_profiles_delete_own\s+on public\.pet_profiles\s+for delete\s+"
        r"using \(owner_id = auth\.uid\(\)::text\);",
        schema,
    )

    assert policy is not None


def test_every_species_the_app_offers_is_accepted_by_the_api() -> None:
    # The chat creates a backend pet from the local one (POST /pets): a species
    # the app offers but the API refuses would break the chat for that pet. Add
    # a new app species to species.py in the same change.
    store = (
        Path(__file__).resolve().parents[2]
        / "apps/mobile_app/lib/features/pets/data/pet_demo_store.dart"
    ).read_text(encoding="utf-8")
    offered = re.findall(r"label: '([^']+)'", store)

    assert {"Cane", "Gatto", "Piccoli mammiferi", "Uccello", "Altro"} <= set(offered)
    for label in offered:
        validate_pet_fields({"name": "Pet", "species": label}, {"name", "species"})


@pytest.mark.parametrize(
    "label", ["Coniglio", "Rettile", "Piccolo mammifero", "piccoli mammiferi", " Cane "]
)
def test_species_saved_by_older_builds_are_still_accepted(label: str) -> None:
    validate_pet_fields({"name": "Pet", "species": label}, {"name", "species"})

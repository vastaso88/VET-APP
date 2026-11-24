"""Collaudo F40: «cane » was stored with its space, «Pesci» was accepted while the error listed
«Pesce». The server matches the species to the app's list (spaces, capitals, accents, singular
or plural, the app's five languages) on the routes that receive it and when a row is read."""

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.pet_profile.species import (
    APP_SPECIES_LABELS,
    is_known_species,
    normalize_species,
    tidy_species,
)


@pytest.mark.parametrize(
    ("written", "label"),
    [
        ("cane ", "Cane"),
        ("  CANE", "Cane"),
        ("Cani", "Cane"),
        ("Pesci", "Pesce"),
        ("pesce", "Pesce"),
        ("gatti", "Gatto"),
        ("Uccelli", "Uccello"),
        ("Rettili", "Rettili e anfibi"),
        ("rettili  e   anfibi", "Rettili e anfibi"),
        ("Piccolo mammifero", "Piccoli mammiferi"),
        ("Altro", "Altro"),
        ("Hunde", "Cane"),
        ("Katzen", "Gatto"),
        ("Poissons", "Pesce"),
        ("pequeños mamíferos", "Piccoli mammiferi"),
        ("Pájaros", "Uccello"),
        ("Kleinsäuger", "Piccoli mammiferi"),
        ("dogs", "Cane"),
    ],
)
def test_a_species_written_another_way_becomes_the_apps_label(written: str, label: str) -> None:
    assert tidy_species(written) == label
    assert is_known_species(written)
    assert label in APP_SPECIES_LABELS


@pytest.mark.parametrize("code", ["dog", "cat", "bird", "fish", "other", "small_mammal", "rabbit"])
def test_the_internal_codes_are_left_alone(code: str) -> None:
    assert tidy_species(code) == code
    assert tidy_species(f"  {code} ") == code


def test_an_unknown_species_is_trimmed_never_matched_by_guessing() -> None:
    assert tidy_species(" Drago ") == "Drago"
    assert not is_known_species("Drago")


def test_the_family_of_a_species_written_another_way_is_still_found() -> None:
    assert normalize_species("Hunde") == "dog"
    assert normalize_species("Poissons") == "fish"
    assert normalize_species("Drago") == "other"


def test_a_row_saved_dirty_reads_clean() -> None:
    pet = PetProfile.model_validate({"owner_id": "u", "name": "Nemo", "species": "Pesci "})

    assert pet.species == "Pesce"


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


def test_the_routes_store_the_apps_label(client: TestClient) -> None:
    created = client.post("/pets", json={"name": "Nemo", "species": "Pesci "})
    assert created.status_code == 200
    pet = created.json()["pet_profile"]
    assert pet["species"] == "Pesce"

    updated = client.put(f"/pets/{pet['id']}", json={"species": " cane"})
    assert updated.status_code == 200
    assert updated.json()["pet_profile"]["species"] == "Cane"
    assert client.get(f"/pets/{pet['id']}").json()["pet_profile"]["species"] == "Cane"


def test_an_invented_species_is_still_refused(client: TestClient) -> None:
    response = client.post("/pets", json={"name": "Smaug", "species": "Drago"})

    assert response.status_code in {400, 422}
    assert "Pesce" in response.text, "the refusal lists the app's species"

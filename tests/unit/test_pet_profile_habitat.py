from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile


def test_habitat_with_no_fields_set_is_empty() -> None:
    assert HabitatDetails().is_empty()


def test_habitat_with_any_single_field_set_is_not_empty() -> None:
    assert not HabitatDetails(dimensions="60x30x36 cm").is_empty()
    assert not HabitatDetails(volume_liters=54).is_empty()
    assert not HabitatDetails(temperature_label="24-26°C").is_empty()
    assert not HabitatDetails(substrate="ghiaia fine").is_empty()
    assert not HabitatDetails(notes="filtro esterno 800L/h").is_empty()


def test_pet_profile_defaults_have_no_habitat_and_empty_aquarium_stock() -> None:
    profile = PetProfile(owner_id="owner-1", name="Milo", species="dog")

    assert profile.habitat is None
    assert profile.aquarium_stock == []


def test_pet_profile_accepts_habitat_and_aquarium_stock() -> None:
    profile = PetProfile(
        owner_id="owner-1",
        name="Acquario del salotto",
        species="Pesce",
        habitat=HabitatDetails(dimensions="60x30x36 cm", volume_liters=54),
        aquarium_stock=[
            FishStock(species="Guppy", male_count=2, female_count=4),
            FishStock(species="Neon Tetra", male_count=3, female_count=3),
        ],
    )

    assert profile.habitat is not None
    assert profile.habitat.volume_liters == 54
    assert len(profile.aquarium_stock) == 2
    assert profile.aquarium_stock[0].species == "Guppy"

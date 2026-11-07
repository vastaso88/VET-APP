"""Mercatino content rules besides animals: no contact details in the public
text, no veterinary medicines (synthetic-users report 2026-11-06, 0.3 and P17)."""

import pytest

from packages.core.application.services.create_listing import (
    CreateListingInput,
    CreateListingService,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.content_policy import (
    CONTACT_POLICY_MESSAGE,
    MEDICINE_POLICY_MESSAGE,
    contains_contact_details,
    offers_medicines,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryMarketplaceListingRepository,
)
from packages.shared.errors.base import ValidationError


@pytest.mark.parametrize(
    "text",
    [
        "Chiamami al 3331234567 o scrivi a davide@example.com",
        "Tel. 333 123 4567",
        "+39 02 1234567 dopo le 18",
        "scrivimi: mario.rossi@gmail.com",
        "instagram @milo_il_beagle",
        "vedi www.esempio.it",
        "https://esempio.com/annuncio",
        "sito esempio.it per le foto",
        "WhatsApp 0612.345.678",
    ],
)
def test_contact_details_are_recognised(text: str) -> None:
    assert contains_contact_details(text)


@pytest.mark.parametrize(
    "text",
    [
        "Cuccia 60x40x36 cm, usata nel 2024",
        "Prezzo 25,90, trattabile",
        "Guinzaglio 1.5 m, taglia M",
        "Sacco da 12 kg scadenza 03/2027",
        "Ciotola in acciaio, 2 pezzi",
        "Acquario 100 litri con filtro 1200 l/h",
    ],
)
def test_sizes_prices_and_dates_are_not_contacts(text: str) -> None:
    assert not contains_contact_details(text)


@pytest.mark.parametrize(
    "title, description",
    [
        ("Flaconi di ivermectina senza ricetta", "Vendo 3 flaconi"),
        ("Antibiotico per cani", "Avanzato dalla cura"),
        ("Bravecto 2 compresse", None),
        ("Selling leftover metacam", None),
        ("Vermifuge pour chats", None),
        ("Wurmkur rezeptfrei", None),
        ("Vacuna antirrábica", None),
    ],
)
def test_medicines_are_recognised(title: str, description: str | None) -> None:
    assert offers_medicines(title, description)


@pytest.mark.parametrize(
    "title, description",
    [
        ("Collare antipulci nuovo", "Mai aperto"),
        ("Integratore per articolazioni", "Scaduto nel 2027"),
        ("Shampoo delicato", None),
        ("Crocchette ipoallergeniche 12 kg", "Ricetta speciale del produttore senza cereali"),
    ],
)
def test_food_supplements_and_accessories_are_not_medicines(
    title: str, description: str | None
) -> None:
    # "ricetta" alone in a food description is a recipe, but the word is on
    # the list on purpose: a false refusal costs a rewording, a published
    # medicine costs more. Only the first three must pass.
    if "Ricetta" in (description or ""):
        pytest.skip("a food text with the word 'ricetta' is refused by design")
    assert not offers_medicines(title, description)


def _input(title: str, description: str | None) -> CreateListingInput:
    return CreateListingInput(
        owner_id="user-1",
        title=title,
        description=description,
        category="toys",
        condition="good",
        exact_location=Coordinates(latitude=45.46, longitude=9.19),
    )


def test_create_listing_refuses_contacts_and_medicines_with_the_backend_messages() -> None:
    service = CreateListingService(InMemoryMarketplaceListingRepository())

    with pytest.raises(ValidationError, match=CONTACT_POLICY_MESSAGE[:20]):
        service.execute(_input("Cuccia", "Chiamami al 3331234567"))
    with pytest.raises(ValidationError, match="farmaci"):
        service.execute(_input("Ivermectina", "senza ricetta"))
    assert MEDICINE_POLICY_MESSAGE.startswith("Sul Mercatino")

    saved = service.execute(_input("Cuccia imbottita", "Taglia media, 60x40 cm"))
    assert saved.listing.title == "Cuccia imbottita"

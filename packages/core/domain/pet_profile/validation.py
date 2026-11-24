"""What the API accepts for a pet's fields, with a message in the owner's language.

The app writes pets straight to Supabase after its own form checks; these rules
are for the API, which tests, other clients and the chat go through. Only the
fields a request actually sets are judged, so a row saved long ago with an odd
value is never refused for something nobody touched.
"""

import re
from collections.abc import Iterable, Mapping
from typing import Any

from packages.core.domain.common.language import normalize_language
from packages.core.domain.pet_profile.body_condition import BODY_CONDITIONS
from packages.core.domain.pet_profile.details import ACTIVITY_LEVELS, is_valid_microchip
from packages.core.domain.pet_profile.species import is_known_species, normalize_species
from packages.shared.errors.base import ValidationError

# Generous upper bounds by species family: they refuse the absurd (200 years,
# 9999 kg), not the unusual (a 30-year-old parrot, a 90 kg dog).
_MAX_AGE_YEARS = {
    "dog": 35,
    "cat": 35,
    "small_mammal": 25,
    "bird": 90,
    "reptile_amphibian": 150,
    "fish": 60,
    "other": 150,
}
_MAX_WEIGHT_KG = {
    "dog": 120,
    "cat": 25,
    "small_mammal": 20,
    "bird": 15,
    "reptile_amphibian": 300,
    "fish": 50,
    "other": 2000,
}

_KG = 1.0
_GRAM = 0.001
_POUND = 0.45359237
# The units as people write them, in the app's languages ("4 chili", "450 grammi", "9 pounds"):
# a weight said in words used to be refused and blocked the whole update (collaudo F39).
_UNIT_TO_KG = {
    **dict.fromkeys(
        ("kg", "kgs", "kilo", "kilos", "kili", "chilo", "chili", "chilogrammo", "chilogrammi"), _KG
    ),
    **dict.fromkeys(("kilogram", "kilograms", "kilogramme", "kilogrammes", "kilogramm"), _KG),
    **dict.fromkeys(("g", "gr", "grammo", "grammi", "gram", "grams", "gramme", "grammes"), _GRAM),
    **dict.fromkeys(("lb", "lbs", "libbra", "libbre", "pound", "pounds"), _POUND),
    **dict.fromkeys(("oz", "ounce", "ounces", "oncia", "once"), 0.0283495231),
}
_UNITS = "|".join(sorted(_UNIT_TO_KG, key=len, reverse=True))
# "circa 4 chili", "ca. 4 kg", "~4 kg": the approximation is dropped, the number is kept.
_APPROXIMATELY = r"(?:circa|ca\.?|about|approx\.?|environ|etwa|~)"
_WEIGHT_RE = re.compile(
    rf"^\s*(?:{_APPROXIMATELY}\s*)?(\d+(?:[.,]\d+)?)\s*({_UNITS})?(?:\s*(?:circa|ca\.?))?\s*$",
    re.IGNORECASE,
)


def max_age_years(species: str) -> int:
    return _MAX_AGE_YEARS[normalize_species(species)]


def max_weight_kg(species: str) -> int:
    return _MAX_WEIGHT_KG[normalize_species(species)]


def parse_weight_kg(label: str) -> float | None:
    """The weight in kilograms of a label like "23 kg", "17,8 kg", "450 g", "12 lb", "4 chili"
    or "circa 4 kg" (no unit means kg); None when it cannot be read (including any negative
    number)."""
    match = _WEIGHT_RE.match(label)
    if match is None:
        return None
    number = float(match.group(1).replace(",", "."))
    return number * _UNIT_TO_KG[(match.group(2) or "kg").lower()]


# The values the API accepts are the Italian labels the app stores (or the English
# codes), so each language lists those, with the app's own name for the species.
_SPECIES_CHOICES = {
    "it": "Cane, Gatto, Piccoli mammiferi, Uccello, Rettili e anfibi, Pesce, Altro",
    "en": (
        "Cane (dog), Gatto (cat), Piccoli mammiferi (small mammals), Uccello (bird), "
        "Rettili e anfibi (reptiles and amphibians), Pesce (fish), Altro (other)"
    ),
    "es": (
        "Cane (perro), Gatto (gato), Piccoli mammiferi (pequeños mamíferos), Uccello (ave), "
        "Rettili e anfibi (reptiles y anfibios), Pesce (pez), Altro (otro)"
    ),
    "de": (
        "Cane (Hund), Gatto (Katze), Piccoli mammiferi (Kleinsäuger), Uccello (Vogel), "
        "Rettili e anfibi (Reptilien und Amphibien), Pesce (Fisch), Altro (Sonstiges)"
    ),
    "fr": (
        "Cane (chien), Gatto (chat), Piccoli mammiferi (petits mammifères), Uccello (oiseau), "
        "Rettili e anfibi (reptiles et amphibiens), Pesce (poisson), Altro (autre)"
    ),
}

_MESSAGES: dict[str, dict[str, str]] = {
    "it": {
        "name_required": "Il nome dell'animale è obbligatorio.",
        "species_unknown": f"Specie non riconosciuta. Scegli tra: {_SPECIES_CHOICES['it']}.",
        "age_out_of_range": "L'età deve essere tra 0 e {max} anni per questa specie.",
        "weight_unreadable": "Il peso non è leggibile. Scrivilo come «23 kg» o «450 g».",
        "weight_out_of_range": (
            "Il peso deve essere maggiore di zero e al massimo {max} kg per questa specie."
        ),
        "activity_level_invalid": "Livello di attività non valido. Valori ammessi: {values}.",
        "body_condition_invalid": "Corporatura non valida. Valori ammessi: {values}.",
        "microchip_invalid": "Il microchip deve avere 15 cifre.",
    },
    "en": {
        "name_required": "The pet's name is required.",
        "species_unknown": f"Species not recognized. Choose one of: {_SPECIES_CHOICES['en']}.",
        "age_out_of_range": "The age must be between 0 and {max} years for this species.",
        "weight_unreadable": "The weight cannot be read. Write it like “23 kg” or “450 g”.",
        "weight_out_of_range": (
            "The weight must be above zero and at most {max} kg for this species."
        ),
        "activity_level_invalid": "Invalid activity level. Allowed values: {values}.",
        "body_condition_invalid": "Invalid body condition. Allowed values: {values}.",
        "microchip_invalid": "The microchip number must have 15 digits.",
    },
    "es": {
        "name_required": "El nombre del animal es obligatorio.",
        "species_unknown": f"Especie no reconocida. Elige entre: {_SPECIES_CHOICES['es']}.",
        "age_out_of_range": "La edad debe estar entre 0 y {max} años para esta especie.",
        "weight_unreadable": "No se puede leer el peso. Escríbelo como «23 kg» o «450 g».",
        "weight_out_of_range": (
            "El peso debe ser mayor que cero y como máximo {max} kg para esta especie."
        ),
        "activity_level_invalid": "Nivel de actividad no válido. Valores admitidos: {values}.",
        "body_condition_invalid": "Condición corporal no válida. Valores admitidos: {values}.",
        "microchip_invalid": "El microchip debe tener 15 dígitos.",
    },
    "de": {
        "name_required": "Der Name des Tieres ist ein Pflichtfeld.",
        "species_unknown": f"Tierart nicht erkannt. Wählen Sie eine von: {_SPECIES_CHOICES['de']}.",
        "age_out_of_range": "Das Alter muss für diese Tierart zwischen 0 und {max} Jahren liegen.",
        "weight_unreadable": (
            "Das Gewicht ist nicht lesbar. Schreiben Sie es wie „23 kg“ oder „450 g“."
        ),
        "weight_out_of_range": (
            "Das Gewicht muss größer als null sein und darf für diese Tierart höchstens "
            "{max} kg betragen."
        ),
        "activity_level_invalid": "Ungültiges Aktivitätsniveau. Erlaubte Werte: {values}.",
        "body_condition_invalid": "Ungültiger Körperbau. Erlaubte Werte: {values}.",
        "microchip_invalid": "Die Mikrochip-Nummer muss 15 Ziffern haben.",
    },
    "fr": {
        "name_required": "Le nom de l'animal est obligatoire.",
        "species_unknown": (
            f"Espèce non reconnue. Choisissez parmi\u00a0: {_SPECIES_CHOICES['fr']}."
        ),
        "age_out_of_range": "L'âge doit être compris entre 0 et {max} ans pour cette espèce.",
        "weight_unreadable": (
            "Le poids est illisible. Écrivez-le comme «\u00a023\u00a0kg\u00a0»"
            "ou «\u00a0450\u00a0g\u00a0»."
        ),
        "weight_out_of_range": (
            "Le poids doit être supérieur à zéro et ne pas dépasser {max} kg pour cette espèce."
        ),
        "activity_level_invalid": "Niveau d'activité non valide. Valeurs admises\u00a0: {values}.",
        "body_condition_invalid": "Corpulence non valide. Valeurs admises\u00a0: {values}.",
        "microchip_invalid": "Le numéro de puce électronique doit comporter 15 chiffres.",
    },
}


class PetInputError(ValidationError):
    """A pet field the API refuses. [code] is stable (the app can key on it);
    [message] is written for the owner, in their language."""

    def __init__(self, code: str, field: str, **params: object) -> None:
        super().__init__(code)
        self.code = code
        self.field = field
        self.params = params

    def message(self, language: str | None = None) -> str:
        catalogue = _MESSAGES[normalize_language(language)]
        return catalogue[self.code].format(**self.params)


def _joined(values: Iterable[str]) -> str:
    return ", ".join(values)


def validate_pet_fields(values: Mapping[str, Any], touched: Iterable[str]) -> None:
    """Raises PetInputError for the first refused field among [touched]; [values]
    is the pet as it will be saved (so the age and weight are judged against the
    species the pet will have)."""
    fields = set(touched)

    if "name" in fields:
        name = values.get("name")
        if not isinstance(name, str) or not name.strip():
            raise PetInputError("name_required", "name")

    species = values.get("species")
    if "species" in fields and (not isinstance(species, str) or not is_known_species(species)):
        raise PetInputError("species_unknown", "species")
    species_text = species if isinstance(species, str) else ""

    if fields & {"age_years", "species"}:
        age = values.get("age_years")
        if age is not None and not 0 <= age <= max_age_years(species_text):
            raise PetInputError("age_out_of_range", "age_years", max=max_age_years(species_text))

    if fields & {"weight_label", "species"}:
        label = values.get("weight_label")
        if label is not None and str(label).strip():
            kilograms = parse_weight_kg(str(label))
            if kilograms is None:
                raise PetInputError("weight_unreadable", "weight_label")
            limit = max_weight_kg(species_text)
            if not 0 < kilograms <= limit:
                raise PetInputError("weight_out_of_range", "weight_label", max=limit)

    activity = values.get("activity_level")
    if "activity_level" in fields and activity is not None and activity not in ACTIVITY_LEVELS:
        raise PetInputError(
            "activity_level_invalid", "activity_level", values=_joined(ACTIVITY_LEVELS)
        )

    condition = values.get("body_condition")
    if "body_condition" in fields and condition is not None and condition not in BODY_CONDITIONS:
        raise PetInputError(
            "body_condition_invalid", "body_condition", values=_joined(BODY_CONDITIONS)
        )

    if "microchip_number" in fields and not is_valid_microchip(values.get("microchip_number")):
        raise PetInputError("microchip_invalid", "microchip_number")

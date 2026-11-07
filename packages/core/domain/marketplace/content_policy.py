"""What a Mercatino ad may not contain besides animals (see animal_policy.py).

Two rules, both decided by the backend whatever the app did:

* **No contact details** in the public text: phone numbers, e-mail addresses,
  web sites, social handles. The text of an ad is public to every signed-in
  owner nearby; a phone number in it is a personal datum published to
  strangers with no way back (synthetic-users report 2026-11-06, finding
  0.3). The places feature already refuses them in a venue's name; this is
  the same rule for ads.
* **No veterinary medicines**, with or without a prescription: in the EU
  medicinal products for animals are sold at retail only by authorised
  pharmacies and outlets (Reg. (EU) 2019/6, art. 103-104; in Italy d.lgs.
  193/2006), never between private individuals. Food, supplements, flea
  collars and other accessories are not medicines and pass.

Messages are in Italian like every other backend validation message; the app
maps them to the owner's language (marketplace_repository.dart).
"""

from __future__ import annotations

import re

from packages.core.domain.marketplace.animal_policy import normalize_text

CONTACT_POLICY_MESSAGE = "Nell'annuncio non inserire telefoni, email, siti web o profili social."
MEDICINE_POLICY_MESSAGE = (
    "Sul Mercatino non si possono vendere farmaci o medicinali veterinari, nemmeno senza ricetta."
)

# Seven or more digits, with spaces, dots, slashes or dashes in between:
# "333 1234567", "+39 02 1234567", "0612.345.678". Sizes ("60x40x36"),
# years ("2024") and prices ("25,90") stay under the threshold.
_PHONE = re.compile(r"(?:\d[\s./-]*){7,}")
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")
_HANDLE = re.compile(r"(?<![\w.])@[A-Za-z0-9_.]{2,}")
_WEB = re.compile(
    r"https?://|www\.|"
    r"\b[a-z0-9-]+\.(?:it|com|net|org|eu|info|de|fr|es|uk|us|au|ch|at|be|ie|io|app)\b",
    re.IGNORECASE,
)


def contains_contact_details(*texts: str | None) -> bool:
    """True when any text carries a phone number, an e-mail, a web address or
    a social handle."""
    for text in texts:
        if not text:
            continue
        if _EMAIL.search(text) or _HANDLE.search(text) or _WEB.search(text):
            return True
        if _PHONE.search(text):
            return True
    return False


# Normalised whole words (lowercase, no accents), it/en/es/de/fr. Generic
# nouns for medicines, the prescription itself, and the molecules and brands
# most often resold between owners. Deliberately NOT here: antiparassitario,
# antipulci, integratore, mangime, shampoo (accessories and food).
MEDICINE_TERMS = (
    # it
    "farmaco farmaci medicinale medicinali antibiotico antibiotici antinfiammatorio "
    "antinfiammatori cortisone cortisonico cortisonici vaccino vaccini vermifugo vermifughi "
    "sverminante sverminanti antidolorifico antidolorifici ricetta prescrizione "
    # en
    "medicine medicines medication medications drug drugs antibiotic antibiotics vaccine "
    "vaccines dewormer dewormers wormer wormers painkiller painkillers prescription "
    # es
    "medicamento medicamentos farmacos antibioticos vacuna vacunas desparasitante "
    "desparasitantes receta "
    # de
    "medikament medikamente arznei arzneimittel antibiotikum antibiotika impfstoff "
    "impfstoffe wurmkur wurmkuren entwurmung rezept rezeptfrei rezeptpflichtig "
    # fr
    "medicament medicaments antibiotique antibiotiques vaccin vaccins vermifuge vermifuges "
    "ordonnance "
    # molecules and brands (same spelling in every language, or close)
    "ivermectina ivermectin ivermectine amoxicillina amoxicillin amoxicilina amoxicilline "
    "metronidazolo metronidazole metronidazol prednisolone prednisone prednisolon prednisona "
    "meloxicam metacam tramadolo tramadol gabapentin gabapentina gabapentine fenobarbitale "
    "phenobarbital fenobarbital insulina insulin insuline levotiroxina levothyroxine "
    "levothyroxin apoquel cytopoint bravecto nexgard simparica advocate stronghold milbemax "
    "drontal panacur baytril synulox rimadyl previcox onsior librela solensia"
).split()

_MEDICINE = re.compile(
    r"\b(?:" + "|".join(sorted(set(MEDICINE_TERMS), key=len, reverse=True)) + r")\b"
)


def offers_medicines(*texts: str | None) -> bool:
    """True when any text names a medicine, a prescription or one of the
    listed active substances or brands."""
    return any(_MEDICINE.search(normalize_text(text)) for text in texts if text)

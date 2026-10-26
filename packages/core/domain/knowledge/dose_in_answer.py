"""Does a reply from the model hand the owner a dose? (security audit LLM-5)

The prompt forbids medicines and doses, and the dosage guard stops the
owner's explicit requests before the model; but an insistent owner could
still get "10 mg/kg di meloxicam ogni 24 ore" out of the model. This is the
deterministic net behind the prompt, in the five languages of the chat:
a reply is refused (and replaced by the fixed dosage text) when it
contains

* a per-kilogram dose ("5 mg/kg", "0,1 ml per kg") anywhere, or
* an amount with a medicine unit ("20 mg", "2 compresse", "3 gocce",
  "1 Tablette", "2 comprimés") in the same sentence as a medicine word, or
* a medicine word with a posology ("ogni 8 ore", "twice a day", "alle 12
  Stunden", "trois fois par jour", "cada 12 horas").

Naming a medicine without a dose stays allowed (the prompt lets the chat
explain a therapy the vet prescribed), and so do laboratory values
("creatinina 2,4 mg/dl"), body weights ("pesa 20 kg") and amounts of food
or water. A dose that already appears in the owner's own document (the
vet's prescription, handed to the model as data) is not the model's and
is allowed through `allowed_text`.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.dosage_request import MEDICINE_WORDS
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# English and Spanish medicine words (the Italian, German and French ones
# come from dosage_request.MEDICINE_WORDS).
_MEDICINE_WORDS_EN_ES = (
    r"tablets?|pills?|capsules?|drops?|syrup|ointment|medication|medicine|medicines|"
    r"antibiotics?|painkillers?|anti-inflammatory|antiinflammatory|steroids?|cortisone|"
    r"dewormer|antihistamine|sedative|ibuprofen|paracetamol|acetaminophen|aspirin|"
    r"meloxicam|carprofen|prednisone|prednisolone|gabapentin|tramadol|amoxicillin|"
    r"metronidazole|famotidine|omeprazole|"
    r"pastillas?|comprimidos?|capsulas?|gotas?|jarabe|pomada|medicamentos?|medicinas?|"
    r"antibioticos?|analgesicos?|antiinflamatorios?|corticoides?|antiparasitarios?|"
    r"ibuprofeno|aspirina|carprofeno|prednisona|gabapentina|amoxicilina|metronidazol|"
    r"omeprazol"
)
_MEDICINE = re.compile(rf"\b(?:{MEDICINE_WORDS}|{_MEDICINE_WORDS_EN_ES})\b")

_NUMBER = r"(?:\d+(?:[.,]\d+)?|½|¼|mezz[ao]|meta|half|halbe|demi|media|medio|un quarto|a quarter)"
_MASS_UNITS = (
    r"mg|mcg|µg|ug|g|grammi|grams?|gramos?|gramm|grammes?|ui|iu|ie|mg\.|ml|cc|millilitri|"
    r"milliliters?|mililitros?|milliliter|millilitres?"
)
_COUNT_UNITS = (
    r"compress[ae]|pastigli[ae]|pillol[ae]|capsul[ae]|gocc[ea]|fial[ae]|bustin[ae]|"
    r"tablets?|pills?|capsules?|drops?|tabletten?|kapseln?|tropfen|comprimes?|cachets?|"
    r"gelules?|gouttes?|pastillas?|comprimidos?|capsulas?|gotas?"
)
# "mg/kg", "mg per kg", "mg al kg", "mg pro kg", "mg par kg", "mg por kg".
_PER_KG = re.compile(
    rf"\b{_NUMBER}\s*(?:{_MASS_UNITS})\s*(?:/|per|al|a|pro|par|por|je|every|ogni)\s*(?:kg|kilo\w*|chilo\w*)\b"
)
# An amount with a mass unit NOT followed by a laboratory denominator.
_AMOUNT = re.compile(
    rf"\b{_NUMBER}\s*(?:{_MASS_UNITS})\b(?!\s*/\s*(?:dl|l|100\s*ml|mmol|min|h|ora|hour|kg))"
    rf"|\b{_NUMBER}\s*(?:{_COUNT_UNITS})\b"
)
_POSOLOGY = re.compile(
    r"\b(?:ogni|every|alle|toutes? les|cada|jede|jeden|tous les)\s+\d+\s*"
    r"(?:ore|ora|hours?|hrs?|h|stunden|heures?|horas?)\b"
    r"|\b(?:\d+|una|due|tre|one|two|three|twice|einmal|zweimal|dreimal|une|deux|trois|una|dos|tres)"
    r"\s*(?:volte?|times?|mal|fois|veces|vez)\s+(?:al|a|per|a day|täglich|taglich|am tag|"
    r"par jour|al dia|al día|por dia|por día)"
    r"|\b(?:twice|once|three times) (?:a|per) day\b|\b(?:bid|tid|sid)\b"
)
_SENTENCE_SPLIT = re.compile(r"(?<=[.!?;:\n])\s+")
# A bare unit ("200 ml di acqua") is not a medicine word on its own: the
# sentence needs a medicine name, kind or pharmaceutical form.
_BARE_UNIT = re.compile(
    r"^(?:mg|ml|cc|milligramm\w*|millilitr\w*|milliliter\w*|millilitre\w*|milligramme\w*|"
    r"mililitros?)$"
)


def _names_a_medicine(sentence: str) -> bool:
    return any(not _BARE_UNIT.match(found.group(0)) for found in _MEDICINE.finditer(sentence))


def find_dosage(answer: str, *, allowed_text: str = "") -> str | None:
    """The first dosage expression the model wrote on its own, or None.
    Comparisons run on normalised text (case, accents); an expression also
    present in [allowed_text] (the owner's document) is skipped."""
    text = normalize_for_matching(answer)
    allowed = normalize_for_matching(allowed_text) if allowed_text else ""

    def is_models_own(expression: str) -> bool:
        return not allowed or expression not in allowed

    for match in _PER_KG.finditer(text):
        if is_models_own(match.group(0)):
            return match.group(0)
    for sentence in _SENTENCE_SPLIT.split(text):
        if not _names_a_medicine(sentence):
            continue
        amount = _AMOUNT.search(sentence)
        if amount is not None and is_models_own(amount.group(0)):
            return amount.group(0)
        posology = _POSOLOGY.search(sentence)
        if posology is not None and is_models_own(posology.group(0)):
            return posology.group(0)
    return None

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

from packages.core.domain.safety.dosage_request import MEDICINE_WORDS, PREVENTION_CLASSES
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


_NEGATED_GENERIC = re.compile(
    r"\b(?:nemmeno|neanche|neppure|non|mai|senza|not even|never|no|nunca|ni siquiera|nicht|"
    r"nie|kein\w*|jamais|pas)\b"
)
_NAMED_DRUG = re.compile(
    r"\b(?:metacam|meloxicam|rimadyl|carprofen\w*|previcox|firocoxib|onsior|robenacoxib|"
    r"novalgina|metamizolo|tachipirina|paracetamol\w*|aspirin\w*|oki|ketoprofen\w*|brufen|"
    r"nurofen|ibuprofen\w*|amoxicillin\w*|synulox|clavaseptin|baytril|enrofloxacin\w*|"
    r"metronidazol\w*|prednisolon\w*|prednison\w*|deltacortene|gabapentin\w*|tramadol\w*|"
    r"cerenia|maropitant|apoquel|frontline|advantix|milbemax|drontal|stronghold|bravecto|"
    r"nexgard|simparica|seresto|antibiotic\w*|antinfiammatori\w*|cortison\w*|farmac\w*|"
    r"medicin\w*|antidolorific\w*)\b"
)


# Food and water (synthetic users round 2, 2026-11-16): "una bustina da 85 g due
# volte al giorno", "40-50 grammi per kg", "pellets twice a day and a few drops
# of water" were refused as doses and replaced by the fixed text on medicines.
_FOOD = re.compile(
    r"\b(?:mangi\w*|cibo|umido|crocchett\w*|pappa|pasto|pasti|razion\w*|alimento|alimentazione|"
    r"eats?|eating|feed\w*|come|comer|fressen|frisst|manger|mange|"
    r"mangime|acqua|fieno|verdur\w*|frutta|semi|pellet\w*|carne|pesce|"
    r"beve|bere|beva|drinks?|drinking|bebe|beber|trinkt|trinken|boit|boire|"
    r"food|kibble|meals?|portions?|water|hay|seeds?|vegetables?|treats?|"
    r"comida|pienso|raciones|racion|agua|heno|verduras?|"
    r"futter|nassfutter|trockenfutter|mahlzeit\w*|wasser|heu|gemuse|"
    r"nourriture|croquettes?|patee|repas|ration\w*|eau|foin|legumes)\b"
)
# Units and forms a food portion shares with a medicine.
_SHARED_WITH_FOOD = re.compile(
    r"^(?:bustin\w*|gocc\w*|drops?|gotas?|tropfen|gouttes?|mg|ml|cc|milligramm\w*|"
    r"millilitr\w*|milliliter\w*|millilitre\w*|milligramme\w*|mililitros?)$"
)
# Drinking and misting are water too (synthetic users round 3: "60 millilitri per
# chilo" a dog drinks, a chameleon's enclosure misted "three times a day").
_WATER = re.compile(
    r"\b(?:acqua|water|agua|wasser|eau|beve|bere|beva|drinks?|drinking|bebe|beber|trinkt|"
    r"trinken|boit|boire|nebulizz\w*|vaporizz\w*|spruzz\w*|mist\w*|spray\w*|pulveriz\w*|"
    r"spruh\w*|bespruh\w*|pulveris\w*)\b"
)
# A body weight ("pesa 85 g", "her weight is 85 g"): the animal, not a dose.
_BODY_WEIGHT = re.compile(
    r"\b(?:pesa|peso|pesava|weighs?|weight|weighed|wiegt|gewicht|pese|poids|pesaba)\b"
    r"[^.;:!?]{0,30}$"
)
# Drops are food only when they are drops of water ("a few drops of water on the
# leaves"); "2 gocce nel cibo" is a medicine or a supplement.
_DROPS = re.compile(r"^(?:gocc\w*|drops?|gotas?|tropfen|gouttes?)$")
_VOLUME = re.compile(r"\b(?:ml|cc|millilitr\w*|milliliter\w*|millilitre\w*|mililitros?)\b")
# Units only a medicine has.
_DRUG_UNIT = re.compile(r"\b\d+(?:[.,]\d+)?\s*(?:mg|mcg|µg|ug|ui|iu|ie)\b")


def _is_a_food_amount(sentence: str) -> bool:
    """A portion of food or water: food words, no named drug, no unit only a
    medicine has, and every medicine-like word one a food portion shares."""
    if not _FOOD.search(sentence) or _NAMED_DRUG.search(sentence) or _DRUG_UNIT.search(sentence):
        return False
    water = bool(_WATER.search(sentence))
    return all(
        _SHARED_WITH_FOOD.match(word) and (water or not _DROPS.match(word))
        for word in (found.group(0) for found in _MEDICINE.finditer(sentence))
    )


def _names_a_medicine(sentence: str) -> bool:
    return any(not _BARE_UNIT.match(found.group(0)) for found in _MEDICINE.finditer(sentence))


def _only_prevention_classes(sentence: str) -> bool:
    """Every medicine word of the sentence is a preventive-treatment class
    (vermifugo, antiparassitario, vaccino...), not a named drug."""
    words = [
        found.group(0)
        for found in _MEDICINE.finditer(sentence)
        if not _BARE_UNIT.match(found.group(0))
    ]
    return bool(words) and all(PREVENTION_CLASSES.fullmatch(word) for word in words)


def find_dosage(answer: str, *, allowed_text: str = "") -> str | None:
    """The first dosage expression the model wrote on its own, or None.
    Comparisons run on normalised text (case, accents); an expression also
    present in [allowed_text] (the owner's document) is skipped."""
    text = normalize_for_matching(answer)
    allowed = normalize_for_matching(allowed_text) if allowed_text else ""

    def is_models_own(expression: str) -> bool:
        return not allowed or expression not in allowed

    sentences = _SENTENCE_SPLIT.split(text)
    for sentence in sentences:
        for match in _PER_KG.finditer(sentence):
            # Grams of food per kilo of body weight, or water per kilo, are
            # rations; a volume per kilo of anything else may be a liquid drug.
            ration = _is_a_food_amount(sentence) and (
                not _VOLUME.search(match.group(0)) or bool(_WATER.search(sentence))
            )
            if is_models_own(match.group(0)) and not ration:
                return match.group(0)
    for sentence in sentences:
        if not _names_a_medicine(sentence) or _is_a_food_amount(sentence):
            continue
        amount = next(
            (
                found
                for found in _AMOUNT.finditer(sentence)
                if not _BODY_WEIGHT.search(sentence[: found.start()])
            ),
            None,
        )
        if amount is not None and is_models_own(amount.group(0)):
            if _NEGATED_GENERIC.search(sentence) and not _NAMED_DRUG.search(sentence):
                # "nemmeno una goccia di grappa", "non una compressa": a refusal
                # of a generic amount, not a dose (synthetic users 2026-11-07).
                continue
            return amount.group(0)
        if _only_prevention_classes(sentence):
            # "il vermifugo di solito si fa ogni tre mesi, lo decide il
            # veterinario": a principle about a preventive treatment, not
            # a dose of a drug (an amount above is still caught).
            continue
        posology = _POSOLOGY.search(sentence)
        if posology is not None and is_models_own(posology.group(0)):
            return posology.group(0)
    return None


_LINE_SENTENCES = re.compile(r"(?<=[.!?;])\s+")


def without_dose_sentences(answer: str, *, allowed_text: str = "") -> str:
    """The answer without the sentences that hand over a dose, layout kept.
    For a reply to a question that asked no dose (synthetic users round 3: the
    weight of a cockatiel taken for a dose replaced four different answers with
    the same refusal): the rest of the answer stays, the dose never does."""
    kept_lines: list[str] = []
    for line in answer.split("\n"):
        sentences = _LINE_SENTENCES.split(line)
        kept = [s for s in sentences if find_dosage(s, allowed_text=allowed_text) is None]
        if len(kept) == len(sentences):
            kept_lines.append(line)
        elif kept:
            kept_lines.append(" ".join(kept))
    return re.sub(r"\n{3,}", "\n\n", "\n".join(kept_lines)).strip()

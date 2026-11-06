"""Is the owner asking how much of a medicine to give?

The guard that refuses to give a dose (ChatOrchestrator._dosage_guard_result)
used to recognise only a handful of fixed phrases ("quanti mg", "che dose"…):
6 of 15 realistic requests were stopped in the 2026-10-14 stress test, and
the rest reached the model. A request is now recognised as
  (a way of asking an amount, or a dose word, or a fraction of a tablet)
  AND (a medicine, a pharmaceutical form, or a unit of a medicine)
matched as whole words on normalised text. Both halves are needed, so
"quanto deve mangiare?" or "quante dosi di vaccino?" are not stopped.

2026-10-26: German and French forms of both halves ("wie viel Metacam darf
ich geben", "combien de gouttes de Doliprane"), on the same rule.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching


def _words(pattern: str) -> re.Pattern[str]:
    return re.compile(rf"\b(?:{pattern})\b")


_MEDICINE_WORDS_IT = (
    # units and pharmaceutical forms
    r"mg|ml|milligramm\w*|millilitr\w*|gocce|goccia|compress\w*|pastigli\w*|pillol\w*|"
    r"capsul\w*|cpr|fial\w*|bustin\w*|supposte?|supposit\w*|pipett\w*|sciropp\w*|"
    r"iniezion\w*|puntur\w*|"
    # kinds of medicine
    r"farmac\w*|medicin\w*|antibiotic\w*|antidolorific\w*|antinfiammatori\w*|"
    r"antiinfiammatori\w*|cortison\w*|antiparassitari\w*|vermifug\w*|antistaminic\w*|"
    r"sedativ\w*|calmant\w*|tranquillant\w*|antiemetic\w*|antiacid\w*|"
    # common names (veterinary and from the family medicine cabinet)
    r"metacam|meloxicam|rimadyl|carprofen\w*|previcox|firocoxib|onsior|robenacoxib|"
    r"novalgina|metamizolo|tachipirina|paracetamolo|aspirina|oki|ketoprofene|brufen|"
    r"nurofen|ibuprofene|amoxicillina|synulox|clavaseptin|baytril|enrofloxacina|"
    r"metronidazolo|prednisolone|prednisone|deltacortene|gabapentin\w*|tramadolo?|"
    r"cerenia|maropitant|apoquel|frontline|advantix|milbemax|drontal|stronghold|"
    r"bravecto|nexgard|simparica|seresto"
)
_MEDICINE_WORDS_DE = (
    # Formen und Einheiten (Umlaute kommen als a/o/u oder ae/oe/ue an)
    r"tablette\w*|tabl|tropfen|kapsel\w*|zapfchen|zaepfchen|spritze\w*|saft|sirup|salbe|"
    r"paste|milligramm\w*|milliliter\w*|"
    # Arten von Medikamenten
    r"medikament\w*|arznei\w*|mittel|praparat\w*|praeparat\w*|antibiotikum|antibiotika|"
    r"schmerzmittel|schmerztablette\w*|entzundungshemmer\w*|entzuendungshemmer\w*|"
    r"kortison\w*|cortison\w*|wurmkur\w*|wurmmittel|entwurmung\w*|antihistaminikum|"
    r"antihistaminika|beruhigungsmittel|beruhigungstablette\w*|"
    # Namen (Tierarzt und Hausapotheke)
    r"novalgin|metamizol|ben-u-ron|benuron|dolormin|thomapyrin|aspirin|ibuprofen|"
    r"paracetamol|diclofenac|carprofen|prednisolon|tramadol|amoxicillin|enrofloxacin|"
    r"metronidazol|clavaseptin|cerenia"
)
_MEDICINE_WORDS_FR = (
    # formes et unités
    r"comprime\w*|cachet\w*|gelule\w*|goutte\w*|sirop|pipette\w*|suppositoire\w*|"
    r"injection\w*|piqure\w*|sachet\w*|milligramme\w*|millilitre\w*|pommade|"
    # types de médicaments
    r"medicament\w*|antibiotique\w*|anti-inflammatoire\w*|antiinflammatoire\w*|"
    r"antidouleur\w*|analgesique\w*|antalgique\w*|cortisone|corticoide\w*|vermifuge\w*|"
    r"antiparasitaire\w*|antihistaminique\w*|calmant\w*|sedatif\w*|tranquillisant\w*|"
    r"antiemetique\w*|"
    # noms (vétérinaire et armoire à pharmacie)
    r"doliprane|dafalgan|efferalgan|advil|aspirine|ibuprofene|carprofene|previcox|"
    r"cortancyl|gabapentine|amoxicilline|clamoxyl|augmentin|enrofloxacine|"
    r"metronidazole|flagyl"
)
_MEDICINE_WORDS = f"{_MEDICINE_WORDS_IT}|{_MEDICINE_WORDS_DE}|{_MEDICINE_WORDS_FR}"
# Shared with dose_in_answer.py (the net on the model's replies).
MEDICINE_WORDS = _MEDICINE_WORDS
_MEDICINE = _words(_MEDICINE_WORDS)

_GIVE_IT = r"dare|dargli|darle|darne|do|dovrei dare|somministr\w*"
_GIVE_DE = r"geben|gebe|verabreichen|verabreiche|eingeben|reingeben"
_GIVE_FR = r"donner|donne|donnerais|administrer|administre|lui en donner|mettre"
_GIVE = f"(?:{_GIVE_IT}|{_GIVE_DE}|{_GIVE_FR})"

# How much: "quanti mg", "quanta tachipirina", "quante gocce di…" (the
# medicine right after the question word), or "quanto/ogni quanto … dare".
# A question word alone is not enough: "quanto costa il metacam?", "quanto
# dura l'antibiotico?" are not requests for a dose.
_HOW_MUCH_WORDS = (
    r"quant[oaie]|wie ?viel|wieviel|wie viele|welche menge|welche dosis|combien de|combien d'|"
    r"combien|quelle quantite de|quelle quantite d'|quelle quantite|quelle dose de|"
    r"quelle dose d'|quelle dose"
)
_HOW_OFTEN_WORDS = r"ogni quanto|wie oft|a quelle frequence|tous les combien|combien de fois"
_DOSE_WORDS = r"dos[ei]|dosaggi\w*|posologi\w*|dosis|dosierung\w*|dosieren|dosage\w*|posologie\w*"
_CHANGE_DOSE_WORDS = (
    r"raddoppi\w*|dimezz\w*|verdoppel\w*|doppelte dosis|halbier\w*|halbe dosis|doubler|double|"
    r"reduire de moitie|diviser par deux|demi-dose|demi dose"
)
_FRACTION_WORDS = (
    r"mezz[ao]|meta|un quarto|un terzo|halbe|eine halbe|halb|viertel|eine viertel|drittel|"
    r"demi|un demi|une demie|un quart|un tiers|une moitie"
)
_SOLID_FORMS = (
    r"compress\w*|pastigli\w*|pillol\w*|capsul\w*|fial\w*|bustin\w*|tablette\w*|kapsel\w*|"
    r"comprime\w*|cachet\w*|gelule\w*"
)
_ARTICLES = r"di |del |della |dello |dei |delle |degli |von |vom |des |der |de |d'|du |de la |de l'"

_ASKS_AN_AMOUNT = re.compile(
    rf"\b(?:{_HOW_MUCH_WORDS}) (?:{_ARTICLES})?(?:{_MEDICINE_WORDS})\b"
    rf"|\b(?:{_HOW_MUCH_WORDS}|{_HOW_OFTEN_WORDS})(?: \w+){{0,4}} {_GIVE}\b"
    rf"|\b(?:{_DOSE_WORDS})\b"
    rf"|\b(?:{_CHANGE_DOSE_WORDS})\b"
    rf"|\b(?:{_FRACTION_WORDS})(?:-| )(?:\w+ ){{0,2}}(?:de |d')?(?:{_SOLID_FORMS})\b"
)

_VACCINE = _words(r"vaccin\w*|richiam\w*|impf\w*|auffrischung\w*|rappel")
_VACCINE_EXCEPTION = _words(
    r"farmac\w*|medikament\w*|medicament\w*|mg|ml|compress\w*|tablette\w*|comprime\w*"
)


# Preventive treatments the owner asks the schedule of (repositioning,
# docs/product/11 §4, 2.3): "ogni quanto il vermifugo?" is a question of
# principles, answered with "product and frequency are the vet's call",
# not refused as a dose request. Five languages, accents removed.
PREVENTION_CLASSES = _words(
    r"vermifug\w*|sverminazion\w*|antiparassitar\w*|antipulci|antizecch\w*|spot-on|spot on|"
    r"pipett\w* antiparassitar\w*|vaccin\w*|richiam\w*|filaria|filariosi|"
    r"deworm\w*|worming|wormer|flea|fleas|tick|ticks|antiparasitic\w*|vaccination\w*|"
    r"vaccine\w*|booster|heartworm|"
    r"desparasit\w*|antiparasitari\w*|antipulgas|garrapat\w*|vacun\w*|"
    r"entwurm\w*|wurmkur\w*|zeckenschutz|flohschutz|floh\w*|zecken\w*|\w*impf\w*|"
    r"vermifuge\w*|antiparasitaire\w*|antipuce\w*|tique\w*|vaccin\w*|rappel\w*"
)
_SCHEDULE_WORDS = re.compile(
    r"\b(?:ogni quanto|quante volte|con che frequenza|con quale frequenza|quando (?:va|si|devo|"
    r"bisogna|serve)|a che eta|da che eta|how often|how frequently|when should|when do|"
    r"cada cuanto|con que frecuencia|cuando (?:hay que|debo|se)|wie oft|wie haufig|wann (?:muss|"
    r"soll|sollte)|tous les combien|a quelle frequence|quand (?:faut-il|dois-je|doit-on))\b"
)
# What makes it a dose request after all: an amount of the product.
_SCHEDULE_AMOUNT = re.compile(
    r"\b(?:mg|ml|cc|compress\w*|pastigli\w*|pillol\w*|gocce|tablets?|pills?|drops?|"
    r"comprimidos?|pastillas?|gotas?|tabletten?|tropfen|comprimes?|cachets?|gouttes?|"
    r"quant[oaie] ne|quanto gliene|how much|how many|cuant[oa]s?|wie ?viel|combien de)\b"
)


def asks_an_amount(message: str) -> bool:
    """The message asks how much / which dose, whether or not it names the
    medicine ("dimmi solo la dose per 4 kg")."""
    text = normalize_for_matching(message)
    return bool(_ASKS_AN_AMOUNT.search(text) or _SCHEDULE_AMOUNT.search(text))


def names_a_medicine(message: str) -> bool:
    return bool(_MEDICINE.search(normalize_for_matching(message)))


def is_prevention_schedule_question(message: str) -> bool:
    """ "Ogni quanto va fatto il vermifugo?", "how often should he be
    dewormed?": the schedule of a preventive treatment, with no amount in
    the question."""
    text = normalize_for_matching(message)
    return bool(
        PREVENTION_CLASSES.search(text)
        and _SCHEDULE_WORDS.search(text)
        and not _asks_an_amount_of_a_preventive(text)
    )


_MG_PER_KG = re.compile(r"\bmg\s*/\s*kg\b")


def _asks_an_amount_of_a_preventive(text: str) -> bool:
    # "cada cuanto" and "ogni quanto" are schedule words, not amounts:
    # removed before looking for "cuantos comprimidos", "quanto ne do".
    without_schedule = _SCHEDULE_WORDS.sub(" ", text)
    return bool(_SCHEDULE_AMOUNT.search(without_schedule) or _MG_PER_KG.search(text))


def is_dosage_request(message: str) -> bool:
    text = normalize_for_matching(message)
    if _VACCINE.search(text) and not _VACCINE_EXCEPTION.search(text):
        # "quante dosi di vaccino deve fare?" is a schedule question.
        return False
    if is_prevention_schedule_question(message):
        return False
    if PREVENTION_CLASSES.search(text) and _asks_an_amount_of_a_preventive(text):
        # "quante compresse di vermifugo gli do?", "how many tablets of
        # wormer": an amount of a preventive is a dose like any other.
        return True
    if _MG_PER_KG.search(text) and _MEDICINE.search(text):
        return True
    return bool(_ASKS_AN_AMOUNT.search(text) and _MEDICINE.search(text))

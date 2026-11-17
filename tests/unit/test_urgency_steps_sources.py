"""The fixed urgency steps say only what a published source supports (doc 20 §9).

Owner decision 17/11/2026: no veterinary review; a species gesture without a source is
removed or reduced to the universal steps. These phrases were removed on 17/11/2026 and
must not come back in any language without a source in docs/product/20.
"""

from __future__ import annotations

import re

import pytest

from packages.core.domain.localization import _MESSAGES, SupportedLocale

# key -> phrases that must not appear, per language
REMOVED: dict[str, dict[SupportedLocale, tuple[str, ...]]] = {
    # A, C: "acqua in eccesso" contradicts Defra on heat
    "triage_steps": {
        "it": ("acqua in eccesso",),
        "en": ("excessive water",),
        "es": ("agua en exceso",),
        "de": ("übermäßig Wasser",),
        "fr": ("trop d'eau",),
    },
    "triage_steps_female": {
        "it": ("acqua in eccesso",),
        "en": ("excessive water",),
        "es": ("agua en exceso",),
        "de": ("übermäßig Wasser",),
        "fr": ("trop d'eau",),
    },
    "triage_steps_cool": {
        "it": ("acqua in eccesso",),
        "en": ("excessive water",),
        "es": ("agua en exceso",),
        "de": ("übermäßig Wasser",),
        "fr": ("trop d'eau",),
    },
    # B: neither "al caldo" nor "non scaldarlo"
    "triage_steps_exotic": {
        "it": ("scaldar", "temperatura"),
        "en": ("warm", "temperature"),
        "es": ("calentar", "temperatura"),
        "de": ("wärmen", "Temperatur"),
        "fr": ("réchauffer", "température"),
    },
    "triage_steps_exotic_female": {
        "it": ("scaldar", "temperatura"),
        "en": ("warm", "temperature"),
        "es": ("calentar", "temperatura"),
        "de": ("wärmen", "Temperatur"),
        "fr": ("réchauffer", "température"),
    },
    # D: "al caldo", "dopo poche ore"
    "triage_steps_small_mammal_stasis": {
        "it": ("al caldo", "poche ore"),
        "en": ("warm", "hours"),
        "es": ("abrigad", "horas"),
        "de": ("warm", "Stunden"),
        "fr": ("chaud", "heures"),
    },
    # E: no order "first shade, then leave"
    "triage_steps_heatstroke": {
        "it": ("e parti verso",),
        "en": ("set off",),
        "es": ("sal hacia",),
        "de": ("fahren Sie los",),
        "fr": ("et partez",),
    },
    # F: ice, rinsing, collar
    "triage_steps_snakebite": {
        "it": ("ghiaccio", "lava", "collare"),
        "en": ("ice", "rinse", "collar"),
        "es": ("hielo", "lava", "collar"),
        "de": ("Eis", "spülen", "Halsband"),
        "fr": ("glace", "rincez", "collier"),
    },
    # G: mouth rinse
    "triage_steps_processionary": {
        "it": ("sciacqua", "fisiologica"),
        "en": ("rinse", "saline"),
        "es": ("enjuaga", "suero"),
        "de": ("spülen", "Kochsalz"),
        "fr": ("rincez", "sérum"),
    },
    # L: filter outlet, lid, 30-40 %, "in a few hours"
    "triage_steps_fish": {
        "it": ("filtro", "coperchio", "30-40", "poche ore"),
        "en": ("filter", "lid", "30-40", "few hours"),
        "es": ("filtro", "tapa", "30-40", "pocas horas"),
        "de": ("Filter", "Deckel", "30-40", "Stunden"),
        "fr": ("filtre", "couvercle", "30-40", "heures"),
    },
    # N: "in poche ore", "non premere sulla pancia"
    "triage_steps_urinary": {
        "it": ("poche ore", "pancia"),
        "en": ("hours", "belly"),
        "es": ("horas", "barriga"),
        "de": ("Stunden", "Bauch"),
        "fr": ("heures", "ventre"),
    },
    # Q: hours, bottles, ice, "no salt"
    "triage_steps_axolotl": {
        "it": ("ore", "bottiglie", "ghiaccio", "sale"),
        "en": ("hours", "bottles", "ice", "salt"),
        "es": ("horas", "botellas", "hielo", "sal,"),
        "de": ("Stunden", "Flaschen", "Eis", "Salz"),
        "fr": ("heures", "bouteilles", "glace", "sel"),
    },
    # R: gauze/pressure, styptic powder, chest wrap
    "triage_steps_bird_bleeding": {
        "it": ("premi", "garza", "polvere", "petto"),
        "en": ("press", "gauze", "powder", "chest"),
        "es": ("aprieta", "gasa", "polvo", "pecho"),
        "de": ("Drücken", "Mull", "Puder", "Brust"),
        "fr": ("appuyez", "compresse", "poudre", "poitrine"),
    },
    # S: gauze/pressure (wrong for amphibians)
    "triage_steps_exotic_bleeding": {
        "it": ("premi", "garza"),
        "en": ("press", "gauze"),
        "es": ("aprieta", "gasa"),
        "de": ("Drücken", "Mull"),
        "fr": ("appuyez", "compresse"),
    },
}

# I, O, P (17/11, second pass): cloth on the carrier, drafts, loose collar, covers, ice
REMOVED.update(
    {
        "triage_steps_bird_respiratory": {
            "it": ("panno", "correnti"),
            "en": ("cloth", "draft"),
            "es": ("paño", "corrientes"),
            "de": ("Tuch", "Zugluft"),
            "fr": ("linge", "courant"),
        },
        "triage_steps_respiratory": {
            "it": ("collare",),
            "en": ("collar",),
            "es": ("collar",),
            "de": ("Halsband",),
            "fr": ("collier",),
        },
        "triage_steps_exotic_cool": {
            "it": ("correnti", "coperture", "ghiaccio"),
            "en": ("draft", "covers", "ice"),
            "es": ("corrientes", "mantas", "hielo"),
            "de": ("Zugluft", "Abdeckungen", "Eis"),
            "fr": ("courant", "couvertures", "glace"),
        },
    }
)

CASES = [
    (key, lang, phrase)
    for key, langs in REMOVED.items()
    for lang, phrases in langs.items()
    for phrase in phrases
]


@pytest.mark.parametrize(("key", "lang", "phrase"), CASES)
def test_unsourced_phrase_stays_out_of_the_urgency_steps(
    key: str, lang: SupportedLocale, phrase: str
) -> None:
    # match at a word start, so "ore" does not hit "calore"
    pattern = r"\b" + re.escape(phrase)
    assert not re.search(pattern, _MESSAGES[key][lang], re.IGNORECASE), (key, lang, phrase)


@pytest.mark.parametrize("lang", ["it", "en", "es", "de", "fr"])
def test_two_seizures_in_24_hours_is_an_emergency(lang: SupportedLocale) -> None:
    # Doc 20 §2 (convulsioni): two or more seizures in 24 hours = emergency.
    assert "24" in _MESSAGES["triage_steps_seizure"][lang]


def test_the_axolotl_is_still_never_warmed() -> None:
    # Confirmed by doc 20 §5: the one temperature gesture that stays.
    assert "non scaldare la vasca" in _MESSAGES["triage_steps_axolotl"]["it"]

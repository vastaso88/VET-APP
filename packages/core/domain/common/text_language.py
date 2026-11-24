"""Which of the chat's languages a text is written in (collaudo, wave 1: five answers of eleven
for an English account came out in Italian).

Counts the function words of each language; a text too short or too mixed says nothing. Tuned on
1125 questions of owners labelled by language (24/11/2026): 94% right, 6% undecided, 1 in 1125
wrong. Deterministic, no model, no library.
"""

from __future__ import annotations

import re

_WORDS = re.compile(r"[a-zà-ÿœß]+")

_FUNCTION_WORDS: dict[str, frozenset[str]] = {
    "it": frozenset(
        (
            "il lo la i gli le un uno una di del dello della dei degli delle da dal dalla nel "
            "nella nelle sul sulla con per tra che chi è e ed o ma se non si mi ti ci ho ha "
            "hanno sono era può devo deve vorrei posso come quando quanto perché più anche "
            "questo questa quello cosa dove adesso ora già ancora molto così mio mia suo sua "
            "ieri oggi domani sempre mai bene senza dopo prima ogni fa va sta"
        ).split()
    ),
    "en": frozenset(
        (
            "the a an and or but is are was were to of in on at for with from by as it its "
            "this that these those i my me you your he she they we his her their have has had "
            "do does did can could should would will not no what how when where why which if "
            "so very there be been about just like get go"
        ).split()
    ),
    "es": frozenset(
        (
            "el la los las un una unos unas de del al a en con por para que qué y o pero si "
            "no se me te le lo mi tu su es está están son ha he hace hay tiene tengo puedo "
            "puede debo debe como cómo cuando cuándo dónde más muy también ya así sin porque "
            "este esta eso algo hoy ayer mañana"
        ).split()
    ),
    "de": frozenset(
        (
            "der die das den dem des ein eine einen einem einer und oder aber ist sind war "
            "nicht kein keine mit auf in im an am zu zum zur von vom für bei nach aus über "
            "unter wenn dass ob wie was wo wann warum ich mein meine mich mir du er sie es "
            "wir ihr ihn sein seine ihre kann muss soll darf habe hat haben wird noch schon "
            "sehr auch nur immer heute"
        ).split()
    ),
    "fr": frozenset(
        (
            "le la les un une des du de d au aux en dans sur pour avec sans et ou mais est "
            "sont était ne pas plus je tu il elle on nous vous ils me te se mon ma mes ton ta "
            "sa son ses notre votre leur ce cette ces qui que quoi quand comment où pourquoi "
            "j c qu n s l y a ai as ont fait peut dois doit très bien aussi depuis encore"
        ).split()
    ),
}
_MIN_HITS = 3
_LEAD = 1.35  # over the second best


def language_of(text: str, *, min_words: int = 4) -> str | None:
    """The language code, or None when the text is too short or too mixed to say."""
    words = _WORDS.findall(text.lower())
    if len(words) < min_words:
        return None
    hits = {code: sum(w in only for w in words) for code, only in _FUNCTION_WORDS.items()}
    ranked = sorted(hits.items(), key=lambda item: -item[1])
    best, second = ranked[0], ranked[1]
    if best[1] < _MIN_HITS or best[1] < _LEAD * second[1]:
        return None
    return best[0]


def is_in_another_language(text: str, expected: str) -> bool:
    """A reply is long enough to be sure: at least a dozen words."""
    found = language_of(text, min_words=12)
    return found is not None and found != expected

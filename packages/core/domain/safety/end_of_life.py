"""The owner asks what the vet does at the end of an animal's life, or whether it hurts.

Collaudo F07, owner's decision of 25/11/2026: "la domanda va risposta in modo empatico. Ci sono
documenti ufficiali... Non è una risposta veterinaria, ma spiega cosa fa il veterinario".
Deterministic, five languages. It looks at the message and at the owner's last two messages: the
subject is often already on the table ("come si capisce che è il momento?").

`asks_about_the_vets_act` separates this question from a request to do it at home, which stays the
business of harmful_requests.py: there the fixed refusal comes first. The vet must be the one who
acts; anything the owner would do or give keeps the refusal.
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# Shown UNDER the answer, never in it: the measures of 25/11/2026 say that a law named in the
# text makes it cold (today's answer preferred 13 to 0). Official acts read by Cercafonti on
# 21-22/11/2026, with Normativa's limits (25/11/2026): the Regulation binds breeders, shops and
# shelters, from 31 August 2029, dogs and cats only, and the BOE copy is informative; the Spanish
# law is a definition for Spain, the German one is on killing vertebrates. None of them speaks of
# a sedative. Titles in the language of the act. Article 11 of the European Convention (law
# 201/2010) could not be read: it is not here.
_REGULATION_2026_1818 = EvidenceSource(
    title="Reglamento (UE) 2026/1818, art. 3 w) (bienestar de perros y gatos)",
    journal="BOE, texto original del DOUE n. 1818 del 10.8.2026 (copia informativa)",
    year=2026,
    tier="A",
    access_depth="A",
    species="other",
    snippet=(
        "Defines euthanasia: a method that brings a rapid and irreversible loss of consciousness "
        "with the least pain and distress. It binds operators, not owners."
    ),
    source_url="https://www.boe.es/buscar/doc.php?id=DOUE-L-2026-81291",
)
_LEY_7_2023 = EvidenceSource(
    title="Ley 7/2023, art. 3 z) (bienestar de los animales, España)",
    journal="BOE, texto consolidado, carácter informativo",
    year=2023,
    tier="A",
    access_depth="A",
    species="other",
    snippet=(
        "Euthanasia: assessed and done by a vet, with clinical methods that are painless and not "
        "cruel, to spare a useless suffering from a severe, lasting illness with no cure, "
        "certified by vets."
    ),
    source_url="https://www.boe.es/buscar/act.php?id=BOE-A-2023-7936",
)
_TIERSCHG_4 = EvidenceSource(
    title="Tierschutzgesetz § 4 (Deutschland)",
    journal="gesetze-im-internet.de, nicht amtliche Fassung",
    tier="A",
    access_depth="A",
    species="other",
    snippet=(
        "A vertebrate may be killed only with the pain switched off (anaesthesia), perceiving "
        "nothing, or otherwise, as far as is reasonable, avoiding pain, by someone skilled."
    ),
    source_url="https://www.gesetze-im-internet.de/tierschg/__4.html",
)


def official_sources(species_family: str) -> list[EvidenceSource]:
    if species_family in ("dog", "cat"):
        return [_REGULATION_2026_1818, _LEY_7_2023]
    return [_LEY_7_2023, _TIERSCHG_4]


_END_OF_LIFE = re.compile(
    r"\b(?:eutanasi\w*|fine vita|lasciarl[oa] andare|addorment\w+|"
    r"sopprim\w*|soppression\w*|quando (?:sara|e) (?:il )?momento|(?:che|quando) e il momento|"
    r"non ce la (?:fa|fara)(?! a\b)(?: piu)?|se un giorno non|"
    r"euthan\w*|end of life|put(?:s|ting)? (?:him|her|it|my \w+|our \w+|the \w+|an? \w+) "
    r"(?:down|to sleep)|put (?:down|to sleep)|let (?:him|her|it) go|when (?:it is|it's) time|"
    r"final de (?:la )?vida|dejarl[oa] ir|dormirl[oa]|duerman|duerme a|sacrificarl[oa]|"
    r"einschlafern|einschlafen lassen|eingeschlafert|gehen lassen|lebensende|erlosen|"
    r"fin de vie|le laisser partir|la laisser partir|endorm\w+)"
)
# What happens, whether it hurts, whether one may stay.
_WHAT_HAPPENS = re.compile(
    r"\b(?:fa male|soffr\w*|dolor\w*|cosa fa\b|cosa succede|che succede|come (?:avviene|funziona|"
    r"si svolge)|sente (?:qualcosa|male|dolore)|(?:posso|si puo) (?:restare|stare|rimanere)|"
    r"(?:gli|le) (?:fanno|fa|danno|da) (?:prima )?(?:un|una)\b|"
    r"(?:does|will|would) (?:it|that|he|she|the \w+) hurt|hurts?|pain\w*|suffer\w*|"
    r"what (?:exactly )?(?:happens|does the vet do|do they do)|how (?:does it|is it) (?:work|done)|"
    r"(?:can|may) i (?:stay|be (?:there|with))|"
    r"duele|sufre|sufrir|que (?:pasa|hace|ocurre)|como (?:es|funciona)|"
    r"puedo (?:estar|quedarme)|"
    r"tut (?:es|das|ihm|ihr) weh|weh tun|tut .{0,20}weh|schmerz\w*|leidet|was passiert|was macht|"
    r"wie lauft|darf ich (?:dabei|bleiben)|"
    r"fait[- ]ca mal|(?:est-ce que ca )?fait mal|douleur\w*|souffr\w*|"
    r"que (?:se passe|fait)|comment (?:ca )?se passe|je peux rester|puis-je rester)"
)
_VET_ACTS = re.compile(
    r"(?:\b(?:il|la|dal|dalla|col|con il|con la|un|una) (?:dottor\w+ |mi[oa] )?veterinari[oa]\b|"
    r"\bin (?:clinica|ambulatorio)\b|"
    r"\b(?:the|a|my|our|at the) vet(?:erinarian)?\b|"
    r"\b(?:el|al|la|del) veterinari[oa]\b|"
    r"\b(?:der|beim|zum|vom|die) tierarzt(?:in)?\b|"
    r"\b(?:le|la|chez le|par le) veterinaire\b|"
    r"\b(?:chi (?:lo|la) fa|who does it|quien lo hace|wer macht das|qui le fait)\b)"
)
_WITHOUT_VET = re.compile(
    r"\b(?:senza|without|sin|ohne|sans) (?:(?:il|la|a|the|el|un|una|le|mio|my|einen|den) )?"
    r"(?:veterinar\w+|vet\b|tierarzt\w*)"
)
# The owner would do it, give something, or wants a substance, an amount, a place to get it.
_OWNER_ACTS = re.compile(
    r"\b(?:da sol[oa]|io stess[oa]|"
    r"(?:farl[oa]|addormentarl[oa]|sopprimerl[oa]) (?:io|a casa|da)|"
    r"lo faccio|la faccio|posso (?:far|dar|addorment|sopprim|usar|compr|mett)\w*|(?:gli|le) do\b|"
    r"dargli|darle|dosi?|dosagg\w*|quant[oaie]|che farmac\w*|quali farmac\w*|compr\w+|procurar\w*|"
    r"costa (?:troppo|tanto)|non posso permett\w*|permettermel\w*|"
    r"myself|on my own|(?:can|could|do|should) i (?:give|put|do|use|buy|get|end)|"
    r"how (?:much|many)|dos(?:e|es|age)|which drugs?|what drugs?|buy|too expensive|can't afford|"
    r"yo mism[oa]|puedo (?:dar|hacer|dormir|usar|compr)\w*|cuant[oa]s?|que farmaco|"
    r"selbst|kann ich (?:ihm|ihr|ihn|sie|das|es)|wie ?viel\w*|welches mittel|kaufen|"
    r"moi-meme|puis-je (?:lui|le|la|l')|je peux (?:lui|le|la|l')|combien|quel medicament|achet\w*)"
)
_AT_HOME = re.compile(r"\b(?:a casa|at home|en casa|zu hause|a la maison|a domicilio)\b")
_VET_AT_HOME = re.compile(
    r"(?:chi (?:lo|la) fa\b|who does it|quien lo hace|wer macht das|qui le fait|"
    r"veterinari[oa]\w* (?:\w+ ){0,4}a (?:casa|domicilio)|a (?:casa|domicilio) (?:con|dal) "
    r"(?:(?:il|la|un|una|mio|mia) ?)*veterinari|"
    r"vet (?:\w+ ){0,4}(?:at home|home)|at home (?:with|by) (?:the|a|my|our) vet|"
    r"veterinari[oa] (?:\w+ ){0,4}(?:en|a) casa|"
    r"tierarzt\w* (?:\w+ ){0,4}(?:zu|nach) hause|"
    r"veterinaire (?:\w+ ){0,4}(?:a la maison|a domicile))"
)


_PRICE = re.compile(
    r"\b(?:quanto costa|how much (?:does it cost|is it)|cuanto cuesta|was kostet|wie ?viel kostet|"
    r"combien (?:ca )?coute)\b"
)


def asks_about_the_vets_act(message: str) -> bool:
    """The vet acts and the owner asks what happens, whether it hurts, whether the vet comes home.
    False as soon as the owner would do or give something, or asks for a substance or an amount."""
    text = _PRICE.sub(" ", normalize_for_matching(message))
    if not _VET_ACTS.search(text) or _WITHOUT_VET.search(text) or _OWNER_ACTS.search(text):
        return False
    if _AT_HOME.search(text):
        return _VET_AT_HOME.search(text) is not None
    return _WHAT_HAPPENS.search(text) is not None


def asks_what_happens_at_the_end(message: str, earlier_owner_messages: Iterable[str] = ()) -> bool:
    text = normalize_for_matching(message)
    if not (_WHAT_HAPPENS.search(text) or _VET_AT_HOME.search(text)):
        return False
    if _END_OF_LIFE.search(text):
        return _is_the_end(text)
    recent = [normalize_for_matching(m) for m in list(earlier_owner_messages)[-2:]]
    return any(_END_OF_LIFE.search(m) and _is_the_end(m) for m in recent)


# "addormentare" is also sleep and the anaesthesia of an operation.
_SLEEP_ONLY = re.compile(
    r"\b(?:addorment\w+|endorm\w+|duerman|duerme a|dormirl[oa]|einschlafen lassen)\b"
)
_NOT_THE_END = re.compile(
    r"\b(?:opera\w*|interven\w*|anestesi\w*|steriliz\w*|denti|detartrasi|radiograf\w*|"
    r"notte|sera|cuccia|si addorment\w*|mi addorment\w*|surgery|operation|operacion|narkose|"
    r"anesthesie|chirurg\w*|castra\w*|kastr\w*)\b"
)
_SURE = re.compile(
    r"\b(?:eutanasi\w*|euthan\w*|fine vita|per sempre|lasciarl[oa] andare|sopprim\w*|"
    r"soppression\w*|momento|end of life|to sleep|put down|einschlafern|eingeschlafert|"
    r"lebensende|fin de vie|non ce la fa\w*|final de (?:la )?vida|sacrificarl[oa]|"
    r"dejarl[oa] ir|erlosen)\b"
)


def _is_the_end(text: str) -> bool:
    if _SURE.search(text) or not _SLEEP_ONLY.search(text):
        return True
    return not _NOT_THE_END.search(text)

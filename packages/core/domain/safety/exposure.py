"""Question or exposure? (repositioning, docs/product/11 §4 2.2)

The fixed lists flag a toxic food or a human medicine whenever it is
named: "il gatto ha mangiato cioccolato" and "perché il cioccolato fa male
ai gatti?" both reach the triage reply. The first is an exposure and must
stay a triage; the second is an owner trying to understand, and deserves
the explanation with the safety list. The difference is deterministic:

* exposure markers: the animal ate, licked, drank, was given something,
  a time or an amount ("ieri", "mezza tavoletta", "adesso");
* intent to give: "vorrei dargli", "posso dargli", "pensavo di dare" — a
  dangerous medicine about to be given is escalated as before;
* question markers: "perché", "è vero che", "quali", a question mark.

A message is an educational question only when it carries a question
marker and neither an exposure nor an intent to give. Everything else
keeps today's behaviour (fail closed).
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching


def _words(pattern: str) -> re.Pattern[str]:
    return re.compile(rf"\b(?:{pattern})\b")


# The animal got it (five languages; accents already removed).
EXPOSURE_MARKERS = _words(
    # it
    r"ha mangiat\w*|mangiat\w*|ha leccat\w*|leccat\w*|ha bevut\w*|bevut\w*|ha ingoiat\w*|"
    r"ingoiat\w*|ingerit\w*|inghiottit\w*|masticat\w*|morsicat\w*|rosicchiat\w*|rubat\w*|"
    r"ho dato|gli ho dato|le ho dato|ho messo|gli ho messo|le ho messo|ha preso|ha trovato|"
    r"ieri|stamattina|stanotte|poco fa|un'ora fa|adesso|proprio ora|appena|"
    r"mezza tavoletta|una tavoletta|un pezzo|un pezzetto|qualche|un po' di|ne manca\w*|"
    # en
    r"ate|eaten|has eaten|swallowed|licked|chewed|drank|drunk|got into|i gave|gave him|"
    r"gave her|took|just now|an hour ago|yesterday|this morning|a piece|half a bar|a bar|"
    # es
    r"ha comido|comio|se comio|se trago|trago|lamio|ha lamido|bebio|ha bebido|le di|"
    r"le he dado|le puse|tomo|ayer|esta manana|hace un rato|ahora mismo|un trozo|"
    r"media tableta|"
    # de
    r"gefressen|gegessen|geleckt|abgeleckt|verschluckt|geschluckt|getrunken|gekaut|"
    r"habe ihm|habe ihr|ich habe .{0,20}gegeben|gegeben|gestern|heute morgen|gerade|"
    r"vor einer stunde|ein stuck|eine halbe tafel|eine tafel|"
    # fr
    r"a mange|mange|a avale|avale|a leche|leche|a bu|bu|a mache|mache|je lui ai donne|"
    r"lui ai donne|hier|ce matin|tout a l'heure|a l'instant|un morceau|une demi-tablette|"
    r"une tablette"
)

# About to give it: escalated like an exposure (the original finding).
# An amount, a dose or a pharmaceutical form in the question counts as an
# intent to give too ("quanto rimadyl devo dare?", "welche Dosis"): a
# dose question is never educational.
INTENT_TO_GIVE_MARKERS = _words(
    r"vorrei dar\w*|voglio dar\w*|pensavo di dar\w*|posso dar\w*|potrei dar\w*|"
    r"gli do|le do|gli dar\w*|le dar\w*|dovrei dar\w*|devo dar\w*|"
    r"l[oa] metto|gliel[oa] metto|metterl[oa]|posso metter\w*|potrei metter\w*|"
    r"l[oa] applico|applicarl[oa]|gliel[oa] applico|"
    r"can i put|could i put|put it on|apply it|se l[oa] pongo|le pongo|ponerl[oa]|"
    r"darf ich .{0,20}auftragen|kann ich .{0,20}auftragen|puis-je .{0,20}mettre|"
    r"je lui mets|l'appliquer|"
    r"quant\w*(?: \w+){0,4} (?:dare|do|dargli|darle|darne|dai|dia)|"
    r"can i give|could i give|should i give|i want to give|thinking of giving|i'll give|"
    r"do i give|how much|how many|"
    r"puedo darle|quiero darle|pensaba darle|le doy|debo darle|cuant\w+|"
    r"(?:darf|kann|soll|sollte|muss|mochte|durfte|konnte) ich(?: \w+){0,6} geben|"
    r"gebe ich|wie ?viel\w*|"
    r"puis-je(?: \w+){0,4} donner|je peux(?: \w+){0,4} donner|je voudrais(?: \w+){0,4} donner|"
    r"je pense(?: \w+){0,4} donner|je dois(?: \w+){0,4} donner|je lui donne|combien|"
    # a dose, a change of dose, a pharmaceutical form or a unit
    r"dos[ei]|dosaggi\w*|posologi\w*|dosis|dosierung\w*|dosage\w*|posologie\w*|"
    r"raddoppi\w*|dimezz\w*|verdoppel\w*|halbier\w*|doubler|double|"
    r"compress\w*|pastigli\w*|pillol\w*|capsul\w*|gocce|tablets?|pills?|drops?|"
    r"comprimidos?|pastillas?|gotas?|tabletten?|tropfen|comprimes?|cachets?|gouttes?|"
    r"mg|ml|cc"
)

# The owner is asking to understand.
QUESTION_MARKERS = _words(
    r"perche|perche'|come mai|e vero che|davvero|quali|quale|cosa succede se|cosa fa|"
    r"quanto e pericolos\w*|quanto e tossic\w*|fa male|fanno male|e tossic\w*|e pericolos\w*|"
    r"e velenos\w*|sono tossic\w*|sono pericolos\w*|sono velenos\w*|"
    r"why|is it true|how dangerous|how toxic|what happens if|which|what foods|is .{0,20} toxic|"
    r"is .{0,20} dangerous|are .{0,20} toxic|are .{0,20} dangerous|"
    r"por que|es verdad|es cierto|cuales|que pasa si|es toxic\w*|es peligros\w*|"
    r"son toxic\w*|son peligros\w*|"
    r"warum|wieso|stimmt es|ist es wahr|welche|was passiert wenn|ist .{0,20} giftig|"
    r"sind .{0,20} giftig|gefahrlich|"
    r"pourquoi|est-ce vrai|est ce vrai|quels|quelles|que se passe-t-il|est-il dangereux|"
    r"est-ce que .{0,20} dangereux|est-ce que .{0,20} toxique|est .{0,20} toxique|"
    r"sont .{0,20} toxiques|sont .{0,20} dangereux"
)


def is_educational_toxin_question(message: str) -> bool:
    """True for "perché il cioccolato fa male ai cani?"; False for "ha
    mangiato cioccolato", "vorrei dargli la tachipirina" and for anything
    unclear."""
    text = normalize_for_matching(message)
    if EXPOSURE_MARKERS.search(text) or INTENT_TO_GIVE_MARKERS.search(text):
        return False
    return "?" in text or bool(QUESTION_MARKERS.search(text))


def is_exposure(message: str) -> bool:
    """The animal already got the substance (ate, licked, was given it)."""
    return bool(EXPOSURE_MARKERS.search(normalize_for_matching(message)))

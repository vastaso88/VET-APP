"""Ritual "ask your vet" closings, removed after the model has written.

Build 28 feedback (2026-10-12): the chat still ended too many answers with a
generic "consulta il veterinario", which reads as alarmist and defensive.
The instructions now say when a visit is warranted (natural_answer_prompt);
this is the deterministic net for the habit the model keeps anyway — a
closing sentence that sends the owner to the vet "per sicurezza" or "in
caso di dubbio" without saying anything specific.

Only TRAILING sentences are touched, and only when they carry a ritual
hedge and nothing concrete: a sentence that names a warning sign or a time
threshold ("se tra 3 giorni…", "se vomita sangue…") is always kept, whatever
words surround it. Never applied to the rule-based safety templates.
"""

from __future__ import annotations

import re

_SENTENCE_END = re.compile(r"(?<=[.!?…])\s+")

# The sentence sends the owner to a professional.
_REFERRAL = re.compile(
    r"veterinar|\bvet\b|una visita|un controllo|al prossimo controllo|uno specialista|"
    r"farl[oa] (vedere|visitare|controllare)|portarl[oa] (dal|da un)",
    re.IGNORECASE,
)

# ...for no stated reason: hedges that make it a ritual.
_RITUAL = re.compile(
    r"in caso di dubbi|per qualsiasi dubbio|per ogni dubbio|se hai (dei |qualche )?dubbi|"
    r"se hai domande|per sicurezza|per (maggiore )?tranquillit|per una valutazione "
    r"(personalizzata|più precisa|approfondita)|non sostituisc|non sono un veterinario|"
    r"consult\w* sempre|(è|e') sempre (meglio|bene|consigliabil|opportun)|"
    r"ti consiglio comunque|meglio comunque|comunque (sempre )?(meglio|bene)|"
    r"senza esitare|non esitare",
    re.IGNORECASE,
)

# Concrete content that must never be dropped: a warning sign or a threshold.
_CONCRETE = re.compile(
    r"\d|sangue|respir|convuls|crisi|sviene|svenut|collass|avvelen|tossic|ingoiat|"
    r"ingerit|mangiato (un|una|del|dei)|non urina|non fa (la )?pip|non fa (le )?feci|"
    r"gonfi|dolore forte|non mangia|smette di mangiare|vomit|diarre|zopp|occhio|"
    r"letarg|apatic|febbre|peggior\w* (molto|rapidamente)|un giorno|due giorni|"
    r"tre giorni|una settimana|24|48",
    re.IGNORECASE,
)


def strip_ritual_referral(text: str) -> str:
    """[text] without trailing sentences that send the owner to the vet
    only as a reflex. Returns [text] unchanged when there is nothing to
    remove, or when removing would leave nothing."""
    stripped = text.rstrip()
    if not stripped:
        return text
    # Work on the last paragraph only: that is where ritual closings sit.
    head, separator, last_paragraph = stripped.rpartition("\n\n")
    sentences = _SENTENCE_END.split(last_paragraph)
    removed = False
    while sentences and _is_ritual(sentences[-1]):
        sentences.pop()
        removed = True
    if not removed:
        return text
    remainder = " ".join(sentences).strip()
    result = f"{head}{separator}{remainder}".strip() if remainder else head.strip()
    return result or text


def _is_ritual(sentence: str) -> bool:
    return bool(
        _REFERRAL.search(sentence) and _RITUAL.search(sentence) and not _CONCRETE.search(sentence)
    )

# ruff: noqa: E501
"""The e-mails sent when an account is deleted or restored: Italian texts, apart from the code.

Source: docs/compliance/18 §4-§6 (Normativa). The texts are copied from there word for
word; the few that doc 18 does not give are marked PROPOSTA below and go to Normativa and the
owner before sending is switched on. Translations: after the owner's yes (doc 18 header).

Rules the texts keep (doc 18): service messages only, never commercial; no name, address or
number of any person or company in this file (the company, the contact and the links come from
the environment); links lead to the sign-in, never to an action; plain text only.

A text is a template with {names}; [render_notice] fills them and refuses to go on if one is
missing or left over.
"""

from __future__ import annotations

import re
import string
from dataclasses import dataclass
from datetime import datetime

LANGUAGE = "it"

# Shared blocks (doc 18 §4 and §6): one model in the code, used by every e-mail.
_BLOCCO_COSA_RESTA = (
    "Dopo la cancellazione restano solo alcuni dati, elencati per intero nell'informativa "
    "{link_informativa}. I principali: (1) un codice, senza il tuo nome né la tua e-mail, con "
    "la data e il motivo della cancellazione: serve a dimostrare che l'abbiamo fatta e a rifarla "
    "se un giorno ripristinassimo una copia di sicurezza, e lo teniamo al massimo {anni_registro} "
    "anni; (2) le fatture, se ne hai, che per legge restano 10 anni nei registri contabili di "
    "chi le emette. Eventuali copie di sicurezza si cancellano entro 30 giorni."
)
_BLOCKS = {
    "blocco_cosa_resta": _BLOCCO_COSA_RESTA,
}

# "Ciao {nome}," becomes {saluto}: with no name the greeting is "Ciao," (never "Ciao ,").


@dataclass(frozen=True)
class NoticeText:
    subject: str
    body: str
    # Where the text comes from: "doc 18 §5" or "PROPOSTA" (not in doc 18: to be approved).
    source: str


TEXTS: dict[str, NoticeText] = {
    # ---- «Elimina» (doc 18 §5) ------------------------------------------------------------
    "D1": NoticeText(
        "Abbiamo ricevuto la tua richiesta: eliminiamo il tuo account Quokka",
        "{saluto} abbiamo ricevuto la tua richiesta: il {data} ci hai chiesto di eliminare il tuo account Quokka e l'abbiamo disattivato subito. Lo cancelliamo definitivamente, insieme ai tuoi dati, il {data_fine}. Se un guasto nostro ritarda l'avviso finale, la cancellazione definitiva può slittare di qualche giorno (al massimo 7) e ti scriviamo la nuova data. Hai cambiato idea? Fino a quel giorno basta accedere con questa e-mail {link_recupera} (se serve, reimposta la password) e toccare «Annulla l'eliminazione»: ritrovi i tuoi animali e i tuoi dati. Dopo la cancellazione non si potrà più ripristinare. Se non sei stato tu, accedi subito e cambia la password, oppure scrivici. {blocco_cosa_resta} Questa è una comunicazione di servizio sulla tua richiesta. {titolare}, {contatto}.",
        "PROPOSTA: doc 18, D1 (riscritto dalla Normativa il 23 novembre sera; in attesa della lettura del proprietario)",
    ),
    "D2": NoticeText(
        "Tra 7 giorni cancelliamo il tuo account Quokka",
        "{saluto} mancano 7 giorni: il {data_fine} cancelliamo il tuo account Quokka e i tuoi dati, come ci hai chiesto. Hai cambiato idea? Accedi con questa e-mail {link_recupera} e tocca «Annulla l'eliminazione»: ritrovi i tuoi animali e i tuoi dati. Se invece va bene così, non devi fare nulla. {blocco_cosa_resta} Comunicazione di servizio sulla tua richiesta. {titolare}, {contatto}.",
        "PROPOSTA: doc 18, D2 (riscritto dalla Normativa il 23 novembre sera; in attesa della lettura del proprietario)",
    ),
    "D3": NoticeText(
        "Domani cancelliamo il tuo account Quokka",
        "{saluto} domani, {data_fine}, cancelliamo il tuo account Quokka e i tuoi dati, come ci hai chiesto. Questa è l'ultima e-mail prima della cancellazione. Hai cambiato idea? Accedi oggi con questa e-mail {link_recupera} e tocca «Annulla l'eliminazione»: ritrovi i tuoi animali e i tuoi dati; se invece va bene così, non devi fare nulla. {blocco_cosa_resta} Comunicazione di servizio sulla tua richiesta. {titolare}, {contatto}.",
        "PROPOSTA: doc 18, D3 (riscritto dalla Normativa il 23 novembre sera; in attesa della lettura del proprietario)",
    ),
    "D4": NoticeText(
        "Il tuo account Quokka è stato eliminato",
        "{saluto} abbiamo eliminato il tuo account Quokka e i dati che conteneva. Grazie per il tempo passato con noi. {blocco_cosa_resta} Non ti scriveremo più su questa richiesta. {titolare}, {contatto}.",
        "PROPOSTA: doc 18, D4 (riscritto dalla Normativa il 23 novembre sera; in attesa della lettura del proprietario)",
    ),
    "R1": NoticeText(
        "Hai ripristinato il tuo account Quokka",
        "{saluto} hai ripristinato il tuo account Quokka: l'eliminazione che avevi chiesto è annullata e i tuoi dati sono di nuovo disponibili. Le scelte sui consensi facoltativi ripartono da zero: te le chiederemo di nuovo quando servono. Se non sei stato tu, accedi subito e cambia la password, oppure scrivici. Comunicazione di servizio sulla tua richiesta. {titolare}, {contatto}.",
        "PROPOSTA: doc 18, R1 (riscritto dalla Normativa il 23 novembre sera; in attesa della lettura del proprietario)",
    ),
    "D_LATE": NoticeText(
        "Cancelliamo il tuo account Quokka",
        "{saluto} il {data_fine} cancelliamo il tuo account Quokka e i tuoi dati, come ci hai chiesto. Hai cambiato idea? Accedi con questa e-mail {link_recupera} e tocca «Annulla l'eliminazione»: ritrovi i tuoi animali e i tuoi dati. Se invece va bene così, non devi fare nulla. {blocco_cosa_resta} Comunicazione di servizio sulla tua richiesta. {titolare}, {contatto}.",
        "PROPOSTA: doc 18 §5, D_LATE (rivisto dalla Normativa il 23 novembre; in attesa del sì del proprietario)",
    ),
}

_ITALIAN_MONTHS = (
    "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
    "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre",
)  # fmt: skip
_YEARS_AGO = {1: "Un anno dopo", 2: "Due anni dopo", 3: "Tre anni dopo"}


def format_date(moment: datetime) -> str:
    """«16 dicembre 2026»."""
    return f"{moment.day} {_ITALIAN_MONTHS[moment.month - 1]} {moment.year}"


def years_after(years: int) -> str:
    return _YEARS_AGO.get(years, f"{years} anni dopo")


_YEARS_IN_WORDS = {1: "un anno", 2: "due anni", 3: "tre anni"}


def format_duration(months: int) -> str:
    """Whole years in words («un anno», «due anni»), months in digits («23 mesi»): doc 18."""
    if months >= 12 and months % 12 == 0:
        years = months // 12
        return _YEARS_IN_WORDS.get(years, f"{years} anni")
    return "1 mese" if months == 1 else f"{months} mesi"


def greeting(first_name: str | None) -> str:
    """«Ciao Mario,» or «Ciao,». The name is what the owner typed: the first word only, control
    characters and braces out, a short length. It never goes into a subject."""
    words = (first_name or "").split()
    word = "".join(
        ch for ch in (words[0] if words else "") if ch.isprintable() and ch not in "{}<>"
    )
    word = word[:40]
    return f"Ciao {word}," if word else "Ciao,"


class NoticeTextError(ValueError):
    """A text was asked for with a variable missing, or one is left over."""


_FIELD = re.compile(r"\{([a-z_]+)\}")


def _fill(template: str, variables: dict[str, str], blocks: dict[str, str]) -> str:
    previous = None
    # Blocks hold fields of their own, so expand until nothing changes.
    while previous != template:
        previous = template
        template = _FIELD.sub(lambda m: blocks.get(m.group(1), m.group(0)), template)
    names = {name for _, name, _, _ in string.Formatter().parse(template) if name}
    missing = names - set(variables)
    if missing:
        raise NoticeTextError(f"missing variables: {sorted(missing)}")
    return template.format(**variables)


def render_notice(template_id: str, variables: dict[str, str]) -> tuple[str, str]:
    """(subject, body) with the shared blocks expanded and every {name} filled. A name with no
    value, or any {name} still in the result, raises [NoticeTextError]: a legal sentence is
    never sent with a hole in it."""
    text = TEXTS[template_id]
    subject, body = _fill(text.subject, variables, _BLOCKS), _fill(text.body, variables, _BLOCKS)
    for part in (subject, body):
        if _FIELD.search(part):
            raise NoticeTextError("a field is left in the text")
    return subject, body


_BLOCK_MARK = "\x00B"


def render_notice_split(template_id: str, variables: dict[str, str]) -> tuple[str, str, str]:
    """(subject, body without the «what stays» block, that block): the same words as
    [render_notice], split so a layout can set the long block apart. The body and the block
    put together in order are the text of [render_notice]."""
    text = TEXTS[template_id]
    subject = _fill(text.subject, variables, _BLOCKS)
    body = _fill(text.body, variables, {**_BLOCKS, "blocco_cosa_resta": _BLOCK_MARK})
    # Only the e-mails that really say what stays after an erasure carry that paragraph (R1 does
    # not: nothing is erased there).
    block = (
        _fill(_BLOCCO_COSA_RESTA, variables, _BLOCKS) if "{blocco_cosa_resta}" in text.body else ""
    )
    body = re.sub(r"\s+", " ", body.replace(_BLOCK_MARK, " ")).strip()
    for part in (subject, body, block):
        if _FIELD.search(part):
            raise NoticeTextError("a field is left in the text")
    return subject, body, block

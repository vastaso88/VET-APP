"""The Italian texts in the code are doc 18's, word for word (docs/compliance/18 §4-§6). The ones
doc 18 does not give are marked PROPOSTA and checked for that mark, so a text nobody approved
cannot pass as approved."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from packages.core.domain.exit_notices import texts

DOC = Path("docs/compliance/18_email_di_uscita_eliminazione_e_pausa.md").read_text(encoding="utf-8")


def _paragraph(label: str) -> str:
    """The quoted text of **label.** in doc 18: the part of its line that starts at «Ciao."""
    line = next(
        (item for item in DOC.splitlines() if re.match(r"\*\*" + re.escape(label) + r"[.*]", item)),
        None,
    )
    assert line, f"{label} not found in doc 18"
    match = re.search(r"«(Ciao.*)»\s*$", line)
    assert match, f"{label}: no quoted text"
    return match.group(1)


def _doc_block(name: str) -> str:
    """A shared block as doc 18 defines it: `{name}` = «...», or the bold `{name}` paragraph."""
    token = "`{" + name + "}`"
    for line in DOC.splitlines():
        if token + " = «" in line:
            start = line.index(token + " = «") + len(token) + 4
            return line[start : line.index("»", start)]
        if line.startswith("**" + token + "**"):
            start = line.index("«")
            return line[start + 1 : line.rindex("»")]
    raise AssertionError(f"{name} not found in doc 18")


def _normalise(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("Ciao {nome},", "{saluto}")).strip()


@pytest.mark.parametrize("template_id", ["D1", "D2", "D3", "D4", "D_LATE"])
def test_the_body_is_doc_18_word_for_word(template_id: str) -> None:
    assert _normalise(texts.TEXTS[template_id].body) == _normalise(_paragraph(template_id))


def test_the_restore_text_is_doc_18s_r1() -> None:
    assert _normalise(texts.TEXTS["R1"].body) == _normalise(_paragraph("R1"))


def test_there_is_no_text_for_a_pause_any_more() -> None:
    """The pause of the account does not exist (owner, 25 November 2026): no text, no id."""
    assert set(texts.TEXTS) == {"D1", "D2", "D3", "D4", "D_LATE", "R1"}


@pytest.mark.parametrize(
    ("name", "constant"),
    [
        ("blocco_cosa_resta", texts._BLOCCO_COSA_RESTA),
    ],
)
def test_the_shared_blocks_are_doc_18s(name: str, constant: str) -> None:
    assert _normalise(constant) == _normalise(_doc_block(name))


@pytest.mark.parametrize(
    ("template_id", "subject"),
    [
        ("D1", "Abbiamo ricevuto la tua richiesta: eliminiamo il tuo account Quokka"),
        ("D2", "Tra 7 giorni cancelliamo il tuo account Quokka"),
        ("D3", "Domani cancelliamo il tuo account Quokka"),
        ("D4", "Il tuo account Quokka è stato eliminato"),
        ("D_LATE", "Cancelliamo il tuo account Quokka"),
        ("R1", "Hai ripristinato il tuo account Quokka"),
    ],
)
def test_the_subjects_doc_18_gives_are_used_as_given(template_id: str, subject: str) -> None:
    assert texts.TEXTS[template_id].subject == subject
    assert f"«{subject}»" in DOC


def test_every_rewritten_text_is_marked_as_a_proposal_until_the_owner_reads_it() -> None:
    """The 23 November evening rewrite (warmer, one thing to do) waits for the owner's reading:
    all six bodies carry the PROPOSTA mark; the owner's yes only removes the labels."""
    proposals = {key for key, text in texts.TEXTS.items() if "PROPOSTA" in text.source}
    assert proposals == {"D1", "D2", "D3", "D4", "D_LATE", "R1"}


def test_the_seven_days_in_d1_are_the_one_constant_of_the_wait() -> None:
    from packages.core.domain.account_deletion import notices

    assert "(al massimo 7)" in texts.TEXTS["D1"].body
    assert notices.MAX_WAIT_AFTER_DUE.days == 7


def test_the_button_named_in_the_texts_is_the_one_in_the_app() -> None:
    """«Annulla l'eliminazione» in D1, D2, D3 and D_LATE is `accountRestoreCancel` in the app."""
    import json

    arb = json.loads(Path("apps/mobile_app/lib/l10n/app_it.arb").read_text(encoding="utf-8"))
    button = arb["accountRestoreCancel"]
    for key in ("D1", "D2", "D3", "D_LATE"):
        assert f"«{button}»" in texts.TEXTS[key].body, key

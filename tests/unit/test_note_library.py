"""Rules of the note library (plan docs/llm/08 work B, Normativa compliance/20 §18)."""

from __future__ import annotations

import sys
from collections.abc import Sequence
from datetime import date
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts" / "eval" / "chat_quality"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import note_library as N  # type: ignore[import-not-found]  # noqa: E402

TODAY = "2026-11-20"


def src(
    dominio: str = "gov.uk",
    livello: int = 1,
    tipo: str = "guida ufficiale",
    per_chi: str = "P",
    gruppo: str = "a",
    anno: int = 2024,
    link: str = "",
) -> N.Source:
    return N.Source(
        ente=dominio,
        anno=anno,
        link=link or f"https://{dominio}/x",
        livello=livello,
        tipo=tipo,
        per_chi=per_chi,
        dominio=dominio,
        gruppo=gruppo,
    )


def note(
    text: str = "Il cioccolato è tossico per il cane, soprattutto quello fondente.",
    source: N.Source | None = None,
    specie: str = "S01",
    tema: str = "T07",
    day: str = TODAY,
) -> N.Note:
    return N.Note(
        specie=specie,
        tema=tema,
        affermazione=text,
        condizioni="",
        fonti=[source or src()],
        verificata_il=day,
    )


def always(relation: N.Relation) -> N.RelateFn:
    return lambda a, b: relation


PASSAGE = "Chocolate contains theobromine which dogs cannot metabolise quickly."


def test_new_fact_is_created() -> None:
    lib = N.NoteLibrary()
    r = lib.add(note(), always("nuovo"), passage=PASSAGE)
    assert r.outcome == "creata" and len(lib.active()) == 1


def test_same_fact_other_source_is_merged_not_duplicated() -> None:
    lib = N.NoteLibrary()
    first = lib.add(note(), always("nuovo"), passage=PASSAGE)
    r = lib.add(
        note("Il cioccolato fondente è tossico per il cane.", src("fda.gov")),
        always("uguale"),
        passage=PASSAGE,
    )
    assert r.outcome == "unita" and r.note_id == first.note_id
    assert len(lib.active()) == 1 and lib.notes[str(first.note_id)].independent_sources == 2


def test_same_fact_same_source_is_already_present() -> None:
    lib = N.NoteLibrary()
    lib.add(note(), always("nuovo"), passage=PASSAGE)
    r = lib.add(note("Il cioccolato è tossico per il cane."), always("uguale"), passage=PASSAGE)
    assert r.outcome == "gia_presente"


def test_contrast_better_level_replaces_and_archives() -> None:
    lib = N.NoteLibrary()
    weak = lib.add(
        note(
            "Il cioccolato al latte non è tossico per il cane.",
            src("journal.org", livello=3, tipo="studio"),
        ),
        always("nuovo"),
        passage=PASSAGE,
    )
    r = lib.add(
        note("Anche il cioccolato al latte è tossico per il cane."),
        always("contrasto"),
        passage=PASSAGE,
    )
    assert r.outcome == "sostituita"
    old = lib.notes[str(weak.note_id)]
    assert old.stato == "archiviata" and old.sostituita_da == r.note_id  # never deleted


def test_contrast_worse_level_is_kept_only_in_archive() -> None:
    lib = N.NoteLibrary()
    lib.add(
        note("Anche il cioccolato al latte è tossico per il cane."),
        always("nuovo"),
        passage=PASSAGE,
    )
    r = lib.add(
        note(
            "Il cioccolato al latte non è tossico per il cane.",
            src("journal.org", livello=3, tipo="studio"),
        ),
        always("contrasto"),
        passage=PASSAGE,
    )
    assert r.outcome == "scartata" and lib.notes[str(r.note_id)].stato == "archiviata"
    assert len(lib.active()) == 1


def test_contrast_same_level_keeps_both_as_discordant() -> None:
    lib = N.NoteLibrary()
    a = lib.add(
        note("Il cioccolato al latte è tossico per il cane."), always("nuovo"), passage=PASSAGE
    )
    r = lib.add(
        note("Il cioccolato al latte è poco tossico per il cane.", src("gov.scot")),
        always("contrasto"),
        passage=PASSAGE,
    )
    assert r.outcome == "discorde" and len(lib.active()) == 2
    assert lib.notes[str(a.note_id)].discorde_con == [r.note_id]


def test_score_order_level_then_sources_then_owners_then_year() -> None:
    law = note(source=src(tipo="legge", per_chi="L"))
    guide = note(source=src())
    two = note(source=src("a.org", livello=2, tipo="linea guida"))
    two.fonti.append(src("b.org", livello=2, tipo="linea guida"))
    one = note(source=src("a.org", livello=2, tipo="linea guida"))
    pro = note(source=src("a.org", livello=2, tipo="linea guida", per_chi="PR"))
    old = note(source=src("a.org", livello=2, tipo="linea guida", anno=2010))
    ordered = sorted([old, pro, one, two, guide, law], key=N.Note.score_key)
    assert ordered == [law, guide, two, one, old, pro]


def test_six_identical_words_from_the_source_are_refused() -> None:
    lib = N.NoteLibrary()
    copied = note("Chocolate contains theobromine which dogs cannot metabolise.")
    r = lib.add(copied, always("nuovo"), passage=PASSAGE)
    assert r.outcome == "scartata" and "parole identiche" in r.reason
    five = note("Chocolate contains theobromine which dogs eliminate slowly.")
    assert lib.add(five, always("nuovo"), passage=PASSAGE).outcome == "creata"


@pytest.mark.parametrize(
    "text",
    [
        "Scrivi a mario@example.com per il cioccolato del cane.",
        "Il cane con microchip 380260000123456 non deve mangiare cioccolato.",
        "Il cioccolato è tossico per Fido, il cane.",
        "Vedi https://example.com per il cioccolato e il cane.",
    ],
)
def test_user_data_is_refused(text: str) -> None:
    lib = N.NoteLibrary()
    r = lib.add(note(text), always("nuovo"), passage=PASSAGE, forbidden=["Fido"])
    assert r.outcome == "scartata" and r.reason.startswith("dati dell'utente")


def test_words_copied_from_the_question_are_refused() -> None:
    lib = N.NoteLibrary()
    question = "ieri sera il mio cane ha mangiato una tavoletta intera di cioccolato fondente"
    r = lib.add(
        note("Il mio cane ha mangiato una tavoletta intera di cioccolato: è tossico."),
        always("nuovo"),
        passage=PASSAGE,
        forbidden=[question],
    )
    assert r.outcome == "scartata"


def test_group_c_site_never_gives_notes() -> None:
    lib = N.NoteLibrary()
    r = lib.add(
        note(source=src("msdvetmanual.com", livello=4, tipo="manuale", gruppo="c")),
        always("nuovo"),
        passage=PASSAGE,
    )
    assert r.outcome == "scartata" and "(c)" in r.reason


def test_group_b_cap_unknown_size_is_20_with_alarm_at_half() -> None:
    lib = N.NoteLibrary([N.Site("rspca.org.uk", "b")])
    results = [
        lib.add(
            note(
                f"Fatto numero {i} sul cane e le sue abitudini {i * 7}.",
                src(
                    "rspca.org.uk",
                    livello=4,
                    tipo="scheda",
                    gruppo="b",
                    link=f"https://rspca.org.uk/{i}",
                ),
                tema=list(N.THEMES)[i % len(N.THEMES)],
            ),
            always("nuovo"),
            passage=PASSAGE,
        )
        for i in range(21)
    ]
    assert [r.outcome for r in results[:20]] == ["creata"] * 20
    assert results[20].outcome == "scartata" and "tetto di 20" in results[20].reason
    assert not results[8].alarm and results[9].alarm  # the 10th note reaches half of 20


def test_group_b_cap_is_one_percent_of_pages_at_most_50() -> None:
    assert N.Site("x.org", "b", pagine_stimate=1200).cap == 12
    assert N.Site("x.org", "b", pagine_stimate=900_000).cap == 50
    assert N.Site("x.org", "a").cap is None and N.Site("x.org", "c").cap == 0


def test_remove_site_deletes_its_notes_and_keeps_other_sources() -> None:
    lib = N.NoteLibrary()
    only = lib.add(note(source=src("blv.admin.ch")), always("nuovo"), passage=PASSAGE)
    shared = lib.add(
        note(
            "Il coniglio ha bisogno di fieno sempre.",
            src("gov.uk"),
            specie="S03",
            tema="T01",
        ),
        always("nuovo"),
        passage=PASSAGE,
    )
    lib.add(
        note(
            "Il coniglio deve avere fieno a volontà.",
            src("blv.admin.ch"),
            specie="S03",
            tema="T01",
        ),
        always("uguale"),
        passage=PASSAGE,
    )
    assert lib.remove_site("blv.admin.ch") == {"cancellate": 1, "fonte_tolta": 1}
    assert only.note_id not in lib.notes
    assert [s.dominio for s in lib.notes[str(shared.note_id)].fonti] == ["gov.uk"]


def test_expired_notes_are_not_sufficient() -> None:
    lib = N.NoteLibrary()
    lib.add(note(day="2025-10-01"), always("nuovo"), passage=PASSAGE)

    def match(fact: str, notes: Sequence[N.Note]) -> N.Note | None:
        return notes[0] if notes else None

    later = date(2026, 11, 20)
    assert lib.expired(later)
    s = N.sufficiency(lib, "S01", "T07", ["cioccolato tossico"], match, later)
    assert not s.enough and s.missing == ["cioccolato tossico"]


def test_sufficiency_needs_a_good_note_for_every_fact() -> None:
    lib = N.NoteLibrary()
    lib.add(note(), always("nuovo"), passage=PASSAGE)  # official guide: good
    lib.add(
        note(
            "Lo xilitolo è molto tossico per il cane.", src("journal.org", livello=3, tipo="studio")
        ),
        always("nuovo"),
        passage=PASSAGE,
    )  # single study: weak

    def match(fact: str, notes: Sequence[N.Note]) -> N.Note | None:
        return next((n for n in notes if fact.split()[0].lower() in n.text.lower()), None)

    today = date(2026, 11, 21)
    s = N.sufficiency(lib, "S01", "T07", ["cioccolato", "xilitolo"], match, today)
    assert not s.enough and s.missing == ["xilitolo"]
    s = N.sufficiency(lib, "S01", "T07", ["cioccolato"], match, today)
    assert s.enough


def test_save_and_load_round_trip(tmp_path: Path) -> None:
    lib = N.NoteLibrary([N.Site("rspca.org.uk", "b", 3000)])
    lib.add(note(), always("nuovo"), passage=PASSAGE)
    path = tmp_path / "note.json"
    lib.save(path)
    again = N.NoteLibrary.load(path)
    assert [n.affermazione for n in again.active()] == [n.affermazione for n in lib.active()]
    assert again.sites["rspca.org.uk"].cap == 30 and again.counts == {"creata": 1}


@pytest.mark.parametrize(
    ("claims", "levels", "expected"),
    [
        (3, [1, 1, 1], "verde"),
        (3, [1, 1], "giallo"),
        (2, [1, 2], "giallo"),  # a scientific society makes it yellow
        (2, [], "grigio"),
        (0, [], "grigio"),
    ],
)
def test_verification_index(claims: int, levels: list[int], expected: str) -> None:
    assert N.verification_index(claims=claims, supported_levels=levels) == expected


def test_index_words_never_promise_verification() -> None:
    assert N.INDEX_NAME == "Fonti"
    assert not any("erificat" in label for label in N.INDEX_LABEL.values())


def test_notes_expire_after_six_months() -> None:
    n = note(day="2026-05-01")
    assert not n.expired(date(2026, 10, 29)) and n.expired(date(2026, 10, 31))

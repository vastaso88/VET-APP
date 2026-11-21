"""Pre-fill of the note library from the collected questions (plan docs/llm/08 "Partire già
pieni"). PREPARED, NOT RUN: it starts only with --run, after the gates of test 2.

    uv run python scripts/eval/chat_quality/note_prefill.py questions.jsonl notes.json \
        [--library .local/chat_eval/prova2/biblioteca] [--budget-usd 20] [--run]

questions.jsonl: one {"specie": "...", "testo": "..."} per line (forum, test rounds, tests).
For every question: the facts it needs (generic words), the sufficiency check; for the
missing facts only, the kept texts are searched, the checker confirms which passage states
the fact, and confirmed facts become notes (NoteLibrary.add: 6-word check, no user data,
per-site caps, merge / replace / discordant).

Normativa docs/compliance/20 §18: reading only because a question asks, never to fill a
section of a site; caps and pauses as in the app; no source text written to disk; a site's
notes can be removed with NoteLibrary.remove_site(). Questions never enter a note (they are
passed as "forbidden" text). Model calls: local claude program (EVAL_CLAUDE_EXE) or an eval
key, never Groq nor production keys. Without --run it only prints what it would do.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path[:0] = [str(HERE), str(ROOT)]
import claude_cli  # noqa: E402
import library_chat as L  # noqa: E402
import library_verify as V  # noqa: E402
import note_library as N  # noqa: E402
import note_steps as S  # noqa: E402

PAUSE_S = 3.0  # between questions: a polite pace, also for the sites read on demand


def make_call(spent: list[float], model: str) -> S.Call:
    def call(system: str, user: str, purpose: str) -> str:
        data = claude_cli_json(system, user, model)
        spent[0] += float(data.get("total_cost_usd") or 0.0)
        return str(data.get("result") or "")

    return call


def claude_cli_json(system: str, user: str, model: str) -> dict[str, Any]:
    import os
    import subprocess

    env = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("CLAUDE_CODE_", "ANTHROPIC_", "CLAUDECODE"))
    }
    env["CLAUDE_CONFIG_DIR"] = str(claude_cli.CONFIG_DIR)
    done = subprocess.run(
        [
            claude_cli.cli_exe(),
            "-p",
            "--model",
            model,
            "--system-prompt",
            system,
            "--tools",
            "",
            "--setting-sources",
            "",
            "--strict-mcp-config",
            "--no-session-persistence",
            "--output-format",
            "json",
        ],
        input=user,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        env=env,
        timeout=300,
    )
    try:
        data: dict[str, Any] = json.loads(done.stdout)
    except json.JSONDecodeError:
        return {}
    return data


def prefill_one(
    call: S.Call,
    library: N.NoteLibrary,
    index: L.LibraryIndex,
    by_pid: dict[str, L.Passage],
    audience: dict[str, str],
    question: dict[str, Any],
    today: date,
    counter: Counter[str],
) -> None:
    text = str(question.get("testo") or "")
    pet = str(question.get("specie") or "")
    need = S.understand(call, text, pet)
    enough = N.sufficiency(
        library, need["specie"], need["tema"], need["fatti"], S.match_facts(call), today
    )
    if enough.enough:
        counter["gia_coperta"] += 1
        return
    # the missing facts, written as sentences, go through the same checker as answers
    draft = " ".join(f.rstrip(".") + "." for f in enough.missing)
    verified = V.verify(
        call, index, answer=draft, pet=pet, language="it", already_cited=[], first_reply=False
    )
    units = V._units(draft)
    _, where = V._numbered(units)
    for verdict in verified.verdicts:
        if verdict.get("esito") != "sostenuta" or verdict["n"] not in where:
            continue
        passage = by_pid.get(verdict["passo"])
        if passage is None:
            continue
        domain = N.site_of(passage.doc.link) if passage.doc.link else passage.doc.id.lower()
        site = library.sites.get(domain)
        source = S.source_of(passage.doc, audience, site.gruppo if site else "a")
        note = S.write_note(call, units[where[verdict["n"]]], passage, source, today)
        if note is None:
            counter["non_scritta"] += 1
            continue
        result = library.add(note, S.relate(call), passage=passage.text, forbidden=[text])
        counter[result.outcome] += 1
        if result.alarm:
            print(f"ALLARME {result.alarm}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("questions", type=Path)
    parser.add_argument("notes", type=Path)
    parser.add_argument(
        "--library", type=Path, default=ROOT / ".local" / "chat_eval" / "prova2" / "biblioteca"
    )
    parser.add_argument("--budget-usd", type=float, default=20.0)
    parser.add_argument("--model", default="claude-haiku-5-5")
    parser.add_argument("--run", action="store_true", help="without it: dry run only")
    args = parser.parse_args()
    questions = [json.loads(x) for x in args.questions.read_text("utf-8").splitlines() if x]
    if not args.run:
        print(
            f"prova a secco: {len(questions)} domande, tetto {args.budget_usd} USD, "
            f"biblioteca {args.library}, note in {args.notes}. Nessuna chiamata fatta."
        )
        return
    if not claude_cli.cli_exe():
        sys.exit("EVAL_CLAUDE_EXE manca")
    library = N.NoteLibrary.load(args.notes) if args.notes.exists() else N.NoteLibrary()
    listed = json.loads((args.library / "indice.json").read_text("utf-8"))
    names = {Path(str(row["file"])).name for row in listed}
    index = L.LibraryIndex(L.load_library(args.library / "testi", names))
    by_pid = {p.pid: p for p in index.passages}
    audience = S.load_audience(args.library)
    spent = [0.0]
    call = make_call(spent, args.model)
    counter: Counter[str] = Counter()
    today = date.today()
    for i, question in enumerate(questions, 1):
        if spent[0] >= args.budget_usd:
            print(f"tetto di spesa raggiunto ({spent[0]:.2f} USD): stop alla domanda {i}")
            break
        prefill_one(call, library, index, by_pid, audience, question, today, counter)
        library.save(args.notes)
        print(f"{i}/{len(questions)} {dict(counter)} {spent[0]:.2f} USD", flush=True)
        time.sleep(PAUSE_S)


if __name__ == "__main__":
    main()

"""The online twin of Quokka: schema, test accounts, check before a round.

    python -m scripts.collaudo.gemello schema-sql   # one SQL file to apply on the twin
    python -m scripts.collaudo.gemello confronta [--prod-nomi FILE]
    python -m scripts.collaudo.gemello utenti       # create (or keep) the accounts, plan Pro
    python -m scripts.collaudo.gemello azzera       # erase the test accounts' data, Pro again
    python -m scripts.collaudo.gemello build <build/web | app.apk>  # app only on the twin
    python -m scripts.collaudo.gemello controllo [--domanda]  # check before a round (1 = stop)

Never production: every command goes through `config.load_gemello`, which refuses the
production project, the normal backend's project and any API that is not local or the
`collaudo` branch. Passwords are generated here and kept only in
`.local/collaudo/utenti.json` (outside the repository); nothing secret is printed.

The schema comparison never reads production: it compares the twin with the repository and,
optionally, with a names-only file of production (tables, functions, policies) prepared by
the Orchestrator.
"""

from __future__ import annotations

import argparse
import json
import secrets
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import quote

from scripts.collaudo import persone
from scripts.collaudo.config import ROOT, Gemello, GemelloNonSicuro, load_gemello, output_root
from scripts.collaudo.rete import Risposta, chiama

# Left out on purpose: supabase_security_hardening.sql only alters the old Stripe billing
# objects that exist in production and not in the repository (it would fail on the twin).
# Order of the SQL on an empty project: the base schema first (docs/runbooks/supabase_setup.md),
# the literature layer, then the increments whose objects the base schema does not contain
# (a test checks that every other script of scripts/setup adds nothing new), then the generated
# plan rules, then the migrations in their timestamp order. Each file is idempotent.
ORDINE_SCHEMA: tuple[str, ...] = (
    "scripts/setup/supabase_schema.sql",
    "scripts/setup/supabase_llm_sources_schema.sql",
    "scripts/setup/security_2026_10_26.sql",
    "scripts/setup/events_read_via_backend.sql",
    "scripts/setup/marketplace_country.sql",
    "scripts/setup/marketplace_messages.sql",
    "scripts/setup/marketplace_private_sellers.sql",
    "scripts/setup/marketplace_reports_via_backend.sql",
    "scripts/setup/subscriptions_retention.sql",
    "scripts/setup/marketplace_no_animals.sql",
    "scripts/setup/marketplace_content_review.sql",
    "scripts/setup/marketplace_hidden_ads.sql",
    "scripts/setup/marketplace_published_photos.sql",
    "scripts/setup/ricordi_animali.sql",
    "scripts/setup/plan_access_rules.sql",
    # K13: giving back an allowance the owner did not receive. Without it the twin's refund call
    # fails (logged, harmless) and the counters stay where the failed request left them.
    "scripts/setup/chat_usage_refund.sql",
    # PESO: a weighing dated after tomorrow is refused by the database.
    "scripts/setup/weight_no_future_dates.sql",
)
MIGRATIONS_DIR = "supabase/migrations"
PIANO_COLLAUDO = "pro"
# admin_plan_changes.admin_id: who changed the plan. No real admin exists on the twin; the
# nil UUID marks the collaudo script in the audit table.
ADMIN_COLLAUDO = "00000000-0000-0000-0000-000000000000"


# --- schema -----------------------------------------------------------------------------


def file_schema(root: Path = ROOT) -> list[Path]:
    files = [root / name for name in ORDINE_SCHEMA]
    files += sorted((root / MIGRATIONS_DIR).glob("*.sql"))
    return files


# Shared helpers that a file uses before the file that defines them (2026-11-22, first run
# on an empty twin: supabase_schema.sql creates a trigger on public.set_updated_at(), which
# only supabase_llm_sources_schema.sql defines). Same body as there; `create or replace`, so
# the later definition is harmless. Found by the collaudo: an install from zero of
# supabase_schema.sql alone fails the same way.
PREAMBOLO = """-- ===== preambolo: funzioni condivise usate prima della loro definizione =====
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;
"""


def componi_schema(root: Path = ROOT, commit: str = "") -> str:
    parts = [
        "-- Schema del GEMELLO di collaudo (mai la produzione). Generato da",
        "-- scripts/collaudo/gemello.py" + (f" al commit {commit}" if commit else "") + ".",
        "-- Ogni blocco è idempotente; l'ordine è quello di ORDINE_SCHEMA + migrazioni.",
        "",
        PREAMBOLO,
    ]
    for path in file_schema(root):
        relative = path.relative_to(root).as_posix()
        parts += [f"-- ===== file: {relative} =====", path.read_text(encoding="utf-8"), ""]
    return "\n".join(parts)


def _commit() -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return ""
    return result.stdout.strip()


def nomi_dichiarati(sql: str) -> dict[str, set[str]]:
    """Tables, functions, policies and triggers the SQL creates (names only, lower case)."""
    import re

    text = re.sub(r"--[^\n]*", "", sql).lower()
    tables = {
        name.removeprefix("public.")
        for name in re.findall(r"create table if not exists ([a-z_][a-z0-9_.]*)", text)
        if "." not in name.removeprefix("public.")
    }
    functions = set(
        re.findall(r"create (?:or replace )?function (?:public\.)?([a-z_][a-z0-9_]*)\s*\(", text)
    )
    policies = set(re.findall(r'create policy "?([a-z_][a-z0-9_ ]*?)"?\s+on', text))
    triggers = set(re.findall(r"create (?:or replace )?trigger ([a-z_][a-z0-9_]*)", text))
    return {"tabelle": tables, "funzioni": functions, "policy": policies, "trigger": triggers}


def differenze_nomi(
    gemello: dict[str, set[str]], riferimento: dict[str, set[str]]
) -> dict[str, dict[str, list[str]]]:
    """Only the kinds the reference lists: a kind it does not cover is not «missing»."""
    out: dict[str, dict[str, list[str]]] = {}
    for kind in ("tabelle", "funzioni", "policy", "trigger"):
        if kind not in riferimento:
            continue
        mine, theirs = gemello.get(kind, set()), riferimento[kind]
        out[kind] = {
            "solo_gemello": sorted(mine - theirs),
            "solo_riferimento": sorted(theirs - mine),
        }
    return out


def _carica_nomi(path: Path) -> dict[str, set[str]]:
    """Names-only file of production (prepared by the Orchestrator): tables, functions and
    policies (`schema.table.policy`: compared by the policy name)."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    out: dict[str, set[str]] = {}
    for kind in ("tabelle", "funzioni", "policy", "trigger"):
        values = raw.get(kind, [])
        if isinstance(values, list) and kind in raw:
            out[kind] = {str(name).lower().rsplit(".", 1)[-1] for name in values}
    return out


# --- accounts ---------------------------------------------------------------------------


def _service_headers(gemello: Gemello) -> dict[str, str]:
    return {"apikey": gemello.service_key, "Authorization": f"Bearer {gemello.service_key}"}


def utenti_path() -> Path:
    return output_root() / "utenti.json"


def carica_utenti() -> dict[str, Any]:
    path = utenti_path()
    if not path.is_file():
        return {}
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data


def salva_utenti(data: dict[str, Any]) -> None:
    path = utenti_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def _trova_id(gemello: Gemello, email: str) -> str:
    page = 1
    while page < 50:
        answer = chiama(
            "GET",
            f"{gemello.supabase_url}/auth/v1/admin/users?page={page}&per_page=200",
            headers=_service_headers(gemello),
        )
        users = answer.body.get("users", []) if isinstance(answer.body, dict) else []
        for user in users:
            if str(user.get("email", "")).lower() == email.lower():
                return str(user["id"])
        if len(users) < 200:
            return ""
        page += 1
    return ""


def assicura_account(gemello: Gemello, email: str, password: str) -> str:
    """The account's id; created confirmed with [password], or its password reset to it."""
    if not email.endswith("@example.com"):
        raise GemelloNonSicuro("solo account @example.com")
    answer = chiama(
        "POST",
        f"{gemello.supabase_url}/auth/v1/admin/users",
        headers=_service_headers(gemello),
        body={"email": email, "password": password, "email_confirm": True},
    )
    if answer.ok and isinstance(answer.body, dict) and answer.body.get("id"):
        return str(answer.body["id"])
    user_id = _trova_id(gemello, email)
    if not user_id:
        raise RuntimeError(f"account non creato: {email} (HTTP {answer.status})")
    chiama(
        "PUT",
        f"{gemello.supabase_url}/auth/v1/admin/users/{quote(user_id)}",
        headers=_service_headers(gemello),
        body={"password": password, "email_confirm": True},
    )
    return user_id


def metti_piano(gemello: Gemello, user_id: str, plan: str = PIANO_COLLAUDO) -> Risposta:
    """The existing admin function (migration 20261121210000): plan + audit row."""
    return chiama(
        "POST",
        f"{gemello.supabase_url}/rest/v1/rpc/admin_change_user_plan",
        headers=_service_headers(gemello),
        body={"p_owner_id": user_id, "p_admin_id": ADMIN_COLLAUDO, "p_plan": plan},
    )


# The check before a round signs in and (optionally) asks one question with its OWN account,
# so no tester's quota is used and the timekeeper's cold start stays cold.
ACCOUNT_CONTROLLO = "col-controllo@example.com"


def crea_utenti(gemello: Gemello) -> dict[str, Any]:
    data = persone.carica()
    saved = carica_utenti()
    accounts = [
        (email, item["chat"]) for item in data["persone"] for email in persone.account_di(item)
    ]
    accounts.append((ACCOUNT_CONTROLLO, "controllo"))
    for email, chat in accounts:
        entry = saved.get(email) or {"chat": chat}
        entry.setdefault("password", secrets.token_urlsafe(24))
        entry["id"] = assicura_account(gemello, email, entry["password"])
        plan = metti_piano(gemello, entry["id"])
        entry["piano"] = PIANO_COLLAUDO if plan.ok else f"ERRORE HTTP {plan.status}"
        entry["aggiornato"] = datetime.now(UTC).isoformat(timespec="seconds")
        saved[email] = entry
        salva_utenti(saved)
        print(f"{email}: pronto (piano {entry['piano']})")
    return saved


def chiavi_pseudonimi(service_key: str) -> tuple[str, str]:
    """The keys the twin's server uses for the pseudonyms of chat reports and radar
    contributions, derived exactly as it does when REPORTER_PSEUDONYM_SALT and
    RADAR_PSEUDONYM_KEY are not set (as in production): `Settings.reporter_pseudonym_secret`
    and `radar_wiring.radar_report_settings`. With other keys the eraser would miss them."""
    import hashlib
    import hmac

    radar = hmac.new(
        service_key.encode("utf-8"), b"radar-contributions-v1", hashlib.sha256
    ).hexdigest()
    return service_key, radar


def azzera_utenti(gemello: Gemello) -> None:
    """Every test account keeps its identity and password; its data go (same eraser as the
    real account deletion), then the plan is set to Pro again."""
    from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
        SupabaseAccountEraser,
    )
    from supabase import create_client

    secret, radar_key = chiavi_pseudonimi(gemello.service_key)
    eraser = SupabaseAccountEraser(
        create_client(gemello.supabase_url, gemello.service_key),
        media_bucket="chat-attachments",
        chat_reporter_secret=secret,
        radar_pseudonym_key=radar_key,
    )
    for email, entry in carica_utenti().items():
        if not email.endswith("@example.com") or not entry.get("id"):
            continue
        report = eraser.erase_data(entry["id"])
        metti_piano(gemello, entry["id"])
        print(f"{email}: azzerato ({sum(report.rows_deleted.values())} righe)")


# --- check before a round ---------------------------------------------------------------


def accedi(gemello: Gemello, email: str, password: str) -> Risposta:
    """Sign in THROUGH THE SERVER: it checks the password on its own Supabase, so success
    with an account that exists only in the twin proves the server is on the twin."""
    return chiama(
        "POST",
        f"{gemello.api_url}/auth/login",
        body={"email": email, "password": password},
        bypass=gemello.bypass,
    )


LIMITE_PRO = 16
DOMANDA_DI_PROVA = "Quanta acqua dovrebbe bere al giorno un labrador adulto?"


def _usage_rows_since(gemello: Gemello, since: str) -> int | None:
    answer = chiama(
        "GET",
        f"{gemello.supabase_url}/rest/v1/llm_usage?select=id&occurred_at=gte.{quote(since)}",
        headers=_service_headers(gemello),
    )
    return len(answer.body) if answer.ok and isinstance(answer.body, list) else None


def controllo(gemello: Gemello, *, domanda: bool = False) -> list[str]:
    """Problems found; empty = the round may start.

    1. `/health` says `environment: production`: the twin runs exactly as production
       (owner/Orchestrator decision 22/11: same CORS, no /docs, no test switches); what tells
       it apart is point 2, never the name;
    2. an account that exists only in the twin signs in THROUGH THE SERVER (so the server is
       on the twin's Supabase);
    3. the server reports that account on the Pro plan (`limits.source == "pro"`: the trial
       has the same 16 questions, so the number alone proves nothing);
    4. the twin's `llm_usage` ledger is readable;
    5. with `domanda=True`: one real question (a few cents on the «prove» key) adds a row to
       that ledger. The Anthropic console of «prove» is checked by a person.
    """
    problems: list[str] = []
    health = chiama("GET", f"{gemello.api_url}/health", bypass=gemello.bypass)
    environment = health.body.get("environment") if isinstance(health.body, dict) else None
    if not health.ok:
        problems.append(f"/health non risponde (HTTP {health.status})")
    elif environment != "production":
        problems.append(
            f"/health dice environment={environment!r}: il gemello deve girare come "
            "la produzione (ENVIRONMENT=production)"
        )
    users = carica_utenti()
    probe = ACCOUNT_CONTROLLO if ACCOUNT_CONTROLLO in users else ""
    if not probe:
        problems.append("nessun account di prova: lancia prima `utenti`")
        return problems
    login = accedi(gemello, probe, users[probe]["password"])
    token = login.body.get("access_token") if isinstance(login.body, dict) else None
    if not login.ok or not token:
        problems.append(
            f"l'account del gemello non entra dal server (HTTP {login.status}): "
            "il server NON è collegato al gemello"
        )
        return problems
    status = chiama(
        "GET",
        f"{gemello.api_url}/subscription/status",
        headers={"Authorization": f"Bearer {token}"},
        bypass=gemello.bypass,
    )
    limits = status.body.get("limits") if isinstance(status.body, dict) else None
    if (
        not isinstance(limits, dict)
        or limits.get("source") != PIANO_COLLAUDO
        or limits.get("daily_questions") != LIMITE_PRO
    ):
        problems.append(f"l'account di prova non risulta Pro con {LIMITE_PRO} domande al giorno")
    elif isinstance(status.body, dict) and status.body.get("test_period"):
        problems.append("SUBSCRIPTION_TEST_PLAN è acceso sul gemello: va spento")
    started = datetime.now(UTC).isoformat(timespec="seconds")
    if _usage_rows_since(gemello, started) is None:
        problems.append("registro llm_usage del gemello non leggibile")
    elif domanda:
        auth = {"Authorization": f"Bearer {token}"}
        pet = chiama(
            "POST",
            f"{gemello.api_url}/pets",
            headers=auth,
            body={"name": "Controllo", "species": "Cane", "breed": "labrador"},
            bypass=gemello.bypass,
        )
        created = pet.body if isinstance(pet.body, dict) else {}
        pet_id = (created.get("pet_profile") or created).get("id")
        reply = chiama(
            "POST",
            f"{gemello.api_url}/chat",
            headers=auth,
            body={
                "pet_id": pet_id,
                "conversation_id": None,
                "user_message": DOMANDA_DI_PROVA,
                "language": "it",
            },
            bypass=gemello.bypass,
            timeout=180,
        )
        if not pet_id or not reply.ok:
            problems.append(f"la domanda di prova non ha risposta (HTTP {reply.status})")
        elif not _usage_rows_since(gemello, started):
            problems.append("la domanda di prova non compare nel registro llm_usage del gemello")
    return problems


# --- the app build under test ---------------------------------------------------------

# A Flutter build without --dart-define points at production by itself (since 36d188f): the
# web build and the emulator APK are checked before anyone uses them.
_BUILD_SUFFIXES = (".js", ".json", ".so", ".dex", ".txt")


def _build_blobs(path: Path) -> list[tuple[str, bytes]]:
    if path.is_file() and path.suffix == ".apk":
        import zipfile

        with zipfile.ZipFile(path) as apk:
            return [
                (name, apk.read(name))
                for name in apk.namelist()
                if name.endswith(_BUILD_SUFFIXES) and apk.getinfo(name).file_size < 80_000_000
            ]
    if path.is_dir():
        return [
            (str(f.relative_to(path)), f.read_bytes())
            for f in sorted(path.rglob("*"))
            if f.is_file() and f.suffix in _BUILD_SUFFIXES and f.stat().st_size < 80_000_000
        ]
    raise FileNotFoundError(f"build non trovata: {path}")


def controlla_build(path: Path, twin_ref: str) -> list[str]:
    """Problems of a collaudo build (web folder or APK); empty = it talks only to the twin.

    It looks for configured ADDRESSES (`https://<ref>.supabase.co`), not bare refs: the app's
    own guards name the forbidden refs and the retired hosts as plain text on purpose."""
    from scripts.collaudo.config import FORBIDDEN_SUPABASE_REFS

    def address(ref: str) -> bytes:
        return f"https://{ref}.supabase.co".encode()

    blobs = _build_blobs(path)
    problems = [
        f"{name} contiene il progetto vietato {ref[:5]}…"
        for name, data in blobs
        for ref in sorted(FORBIDDEN_SUPABASE_REFS)
        if address(ref) in data
    ]
    if not twin_ref or not any(address(twin_ref) in data for _, data in blobs):
        problems.append("la build non contiene l'indirizzo del gemello")
    return problems


# --- command line -----------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(prog="gemello", description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="comando", required=True)
    sub.add_parser("schema-sql")
    confronta = sub.add_parser("confronta")
    confronta.add_argument("--prod-nomi", type=Path, default=None)
    sub.add_parser("utenti")
    sub.add_parser("azzera")
    build = sub.add_parser("build")
    build.add_argument("percorso", type=Path, help="cartella build/web o file .apk")
    check = sub.add_parser("controllo")
    check.add_argument("--domanda", action="store_true", help="una domanda vera (pochi centesimi)")
    args = parser.parse_args(argv)

    if args.comando == "schema-sql":
        out = output_root() / "schema_gemello.sql"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(componi_schema(commit=_commit()), encoding="utf-8")
        print(f"scritto {out}")
        return 0
    if args.comando == "confronta":
        try:
            twin: Gemello | None = load_gemello(need_service_key=True, need_api=False)
        except GemelloNonSicuro as error:
            print(f"gemello non usato: {error}")
            twin = None
        return _confronta(twin, args.prod_nomi)
    try:
        gemello = load_gemello(
            need_service_key=args.comando != "build",
            need_api=args.comando == "controllo",
        )
    except GemelloNonSicuro as error:
        print(f"FERMO: {error}")
        return 2
    if args.comando == "build":
        found = controlla_build(args.percorso, gemello.supabase_ref)
        for problem in found:
            print("NO:", problem)
        print("build sul gemello" if not found else "build NON utilizzabile")
        return 1 if found else 0
    if args.comando == "utenti":
        saved = crea_utenti(gemello)
        failed = [email for email, entry in saved.items() if entry.get("piano") != PIANO_COLLAUDO]
        for email in failed:
            print(f"NO: {email} non è su Pro")
        return 1 if failed else 0
    if args.comando == "azzera":
        azzera_utenti(gemello)
        return 0
    problems = controllo(gemello, domanda=args.domanda)
    for problem in problems:
        print("NO:", problem)
    print("controllo superato" if not problems else "il giro NON parte")
    return 0 if not problems else 1


def _confronta(gemello: Gemello | None, prod_nomi: Path | None) -> int:
    """Twin vs repository (when the twin is reachable) and repository vs production names
    (when the names file exists). Production itself is never contacted."""
    from scripts.setup.check_schema import compare, parse_declared_schema, parse_live_schema

    sql = componi_schema()
    lines = [f"# Differenze di schema del gemello ({datetime.now(UTC):%Y-%m-%d %H:%M} UTC)", ""]
    lines += ["## Gemello rispetto al repository", ""]
    answer = (
        chiama("GET", f"{gemello.supabase_url}/rest/v1/", headers=_service_headers(gemello))
        if gemello is not None
        else None
    )
    if answer is None or not answer.ok or not isinstance(answer.body, dict):
        lines.append("- gemello non raggiungibile o non configurato: confronto non fatto")
    else:
        report = compare(parse_declared_schema(sql), parse_live_schema(answer.body))
        lines += [f"- DA CORREGGERE: {line}" for line in report.blocking] or ["- nulla che blocchi"]
        lines += [f"- per informazione: {line}" for line in report.informational]
    lines.append("")
    if prod_nomi is not None and prod_nomi.is_file():
        diff = differenze_nomi(nomi_dichiarati(sql), _carica_nomi(prod_nomi))
        lines += ["## Repository rispetto alla produzione (solo nomi)", ""]
        for kind, sides in diff.items():
            lines.append(
                f"- {kind}: solo nel repository {sides['solo_gemello'] or '—'}; "
                f"solo in produzione {sides['solo_riferimento'] or '—'}"
            )
    else:
        lines.append("Nessun file di nomi della produzione: confronto con la produzione non fatto.")
    out = output_root() / "schema_differenze.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"scritto {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

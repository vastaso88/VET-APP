"""The collaudo build of the app: always on the twin, never with the default values (which
are production), checked after the build.

    python -m scripts.collaudo.build_collaudo valori <chat> [--apk]     # define file for <chat>
    python -m scripts.collaudo.build_collaudo web <chat> --sorgente DIR # flutter build web

`valori` writes `.local/collaudo/build/<chat>.json` for `--dart-define-from-file` (`--apk`:
the emulator APK, built by the «APK e App nativa» session with `--profile`, the only builds
allowed plain http to 10.0.2.2); `web` builds the
web app from a CLEAN source folder at the commit under test (lesson of build 40), with
`lib/main_collaudo.dart` as entry point and local resources (no CDN), then runs the build
check (`gemello.py build`) and writes the commit in `.local/collaudo/build/registro.jsonl`.
The define file holds a synthetic password: it stays in `.local/` and is deleted after a web
build. The build itself never leaves this computer.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from scripts.collaudo import persone
from scripts.collaudo.config import Gemello, GemelloNonSicuro, load_gemello, output_root
from scripts.collaudo.gemello import carica_utenti, controlla_build
from scripts.collaudo.ponte import INDIRIZZO_EMULATORE, INDIRIZZO_WEB

# Not "production": the app's own production checks stay off, and the auto sign-in guard
# refuses a production build.
AMBIENTE_APP = "staging"


def valori(gemello: Gemello, chat: str, *, apk: bool = False) -> dict[str, Any]:
    email = persone.email_account(chat)
    account = carica_utenti().get(email)
    if not account:
        raise GemelloNonSicuro(f"nessun account per {chat}: prima `gemello utenti`")
    return {
        "SUPABASE_URL": gemello.supabase_url,
        "SUPABASE_ANON_KEY": gemello.anon_key,
        # servi_web.py bridges /api and adds the Vercel bypass code: it never enters a build
        "API_BASE_URL": INDIRIZZO_EMULATORE if apk else INDIRIZZO_WEB,
        "ENVIRONMENT": AMBIENTE_APP,
        "COLLAUDO_SUPABASE_REF": gemello.supabase_ref,
        "COLLAUDO_EMAIL": email,
        "COLLAUDO_PASSWORD": account["password"],
    }


def scrivi_valori(gemello: Gemello, chat: str, *, apk: bool = False) -> Path:
    path = output_root() / "build" / f"{chat}{'_apk' if apk else ''}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(valori(gemello, chat, apk=apk)), encoding="utf-8")
    return path


def comando_web(defines: Path) -> list[str]:
    return [
        "flutter",
        "build",
        "web",
        "--release",
        "-t",
        "lib/main_collaudo.dart",
        "--no-web-resources-cdn",
        f"--dart-define-from-file={defines}",
    ]


def _commit(source: Path) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=source, capture_output=True, text=True, check=False
    )
    dirty = subprocess.run(
        ["git", "status", "--porcelain"], cwd=source, capture_output=True, text=True, check=False
    )
    if dirty.stdout.strip():
        raise GemelloNonSicuro("la cartella sorgente non è pulita: build rifiutata")
    return result.stdout.strip()


def build_web(gemello: Gemello, chat: str, source: Path) -> Path:
    app = source / "apps" / "mobile_app"
    commit = _commit(source)
    defines = scrivi_valori(gemello, chat)
    try:
        flutter = shutil.which("flutter") or "flutter"
        command = comando_web(defines)
        command[0] = flutter
        subprocess.run(command, cwd=app, check=True)
    finally:
        defines.unlink(missing_ok=True)
    out = app / "build" / "web"
    problems = controlla_build(out, gemello.supabase_ref)
    with (output_root() / "build" / "registro.jsonl").open("a", encoding="utf-8") as log:
        log.write(
            json.dumps(
                {
                    "at": datetime.now(UTC).isoformat(timespec="seconds"),
                    "chat": chat,
                    "commit": commit,
                    "cartella": str(out),
                    "controllo": problems or "ok",
                }
            )
            + "\n"
        )
    if problems:
        shutil.rmtree(out, ignore_errors=True)
        raise GemelloNonSicuro("build non sul gemello, cancellata: " + "; ".join(problems))
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="build_collaudo")
    sub = parser.add_subparsers(dest="comando", required=True)
    values = sub.add_parser("valori")
    values.add_argument("chat")
    values.add_argument("--apk", action="store_true")
    web = sub.add_parser("web")
    web.add_argument("chat")
    web.add_argument("--sorgente", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        gemello = load_gemello(need_api=True)
        if args.comando == "valori":
            print(
                f"scritto {scrivi_valori(gemello, args.chat, apk=args.apk)} "
                "(password sintetica: resta in .local)"
            )
        else:
            print(f"build pronta in {build_web(gemello, args.chat, args.sorgente)}")
    except (GemelloNonSicuro, subprocess.CalledProcessError) as error:
        print(f"FERMO: {error}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

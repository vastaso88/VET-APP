"""What a tester uses to talk to the twin, as the app does. Successor of
`scripts/eval/synthetic_users/client.py` (local in-memory server) for the online twin.

    python -m scripts.collaudo.client <chat> accedi
    python -m scripts.collaudo.client <chat> prepara                 # Terms, Privacy, age
    python -m scripts.collaudo.client <chat> animali                 # create the persona's pets
    python -m scripts.collaudo.client <chat> allega <animale> <file>  # photo/PDF for the chat
    python -m scripts.collaudo.client <chat> detta <file audio>      # dictation
    python -m scripts.collaudo.client <chat> carica <bucket> <nome> <file>  # storage, like the app
    python -m scripts.collaudo.client <chat> chat <animale> "messaggio" [--nuova]
    python -m scripts.collaudo.client <chat> api GET /reminders
    python -m scripts.collaudo.client <chat> api POST /reminders '<json>'
    python -m scripts.collaudo.client <chat> db GET dog_walks "select=*&limit=5"
    python -m scripts.collaudo.client <chat> db POST dog_walks '' '<json>'
    python -m scripts.collaudo.client <chat> segnala --tipo funzioni --gravita grave \
        --funzione chat --titolo "..." --cosa "..." [--riproduci "passo 1" --riproduci "passo 2"]
        [--proposta "..."] [--perche "..."] [--specie ...] [--sbagliata --fonte "..."]
    python -m scripts.collaudo.client <chat> --lingua en-US --utc-offset 60 chat …  # opzioni
    python -m scripts.collaudo.client <chat> chat <animale> "…" --id-messaggio m-001
    python -m scripts.collaudo.client <chat> tempi                   # short summary of my timings

`api` goes to the server (Vercel, branch `collaudo`); `db` goes straight to the twin's
database with the user's own token, as the app does for walks, records, photos, reminders,
events, position (the RLS rules are the real ones). Every call is timed into `tempi.jsonl`;
every chat answer into `risposte.jsonl` with its words and reading time. Output:
`.local/collaudo/giro-<COLLAUDO_GIRO>/<chat>/`. Only short summaries are printed.

Sign-in is the real Supabase Auth with the account prepared by `gemello.py utenti` (password
in `.local/collaudo/utenti.json`, never printed); the token is refreshed by itself.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from statistics import median
from typing import Any

from scripts.collaudo import lettura, persone
from scripts.collaudo.config import Gemello, GemelloNonSicuro, load_gemello, output_root
from scripts.collaudo.rete import Risposta, chiama, multipart
from scripts.collaudo.segnalazioni import Segnalazione, SegnalazioneNonValida, aggiungi

_UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
_PRINT_LIMIT = 3000


def giro() -> str:
    return (os.environ.get("COLLAUDO_GIRO") or "prova").strip()


def cartella(chat: str) -> Path:
    return output_root() / f"giro-{giro()}" / chat


def stato_path(chat: str) -> Path:
    return output_root() / "stato" / f"{chat}.json"


def _load(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data


def _save(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def _append(path: Path, entry: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def percorso_generico(path: str) -> str:
    """`/pets/<uuid>/weights?x=1` -> `/pets/:id/weights`: timings grouped by route."""
    return _UUID.sub(":id", path.split("?", 1)[0])


def registra_tempo(chat: str, metodo: str, path: str, risposta: Risposta, funzione: str) -> None:
    _append(
        cartella(chat) / "tempi.jsonl",
        {
            "at": datetime.now(UTC).isoformat(timespec="seconds"),
            "chat": chat,
            "metodo": metodo.upper(),
            "percorso": percorso_generico(path),
            "funzione": funzione,
            "status": risposta.status,
            "headers_ms": risposta.headers_ms,
            "total_ms": risposta.total_ms,
        },
    )


class Sessione:
    """A signed-in tester. Tokens live in `.local/collaudo/stato/<chat>.json`."""

    def __init__(
        self, chat: str, gemello: Gemello, *, lingua: str = "", utc_offset: int | None = None
    ) -> None:
        # `chat` may name an extra account (`col-villain-chat-b`): own tokens and folder,
        # the tester's persona, the extra account's e-mail.
        self.chat = chat
        self.gemello = gemello
        self.base, self.indice = persone.risolvi_account(chat)
        self.persona = persone.persona(self.base)
        # `--lingua` (col-chloe-lingue switches language) wins over the persona's language;
        # `--utc-offset` sends X-UTC-Offset-Minutes as the app does from the phone's time zone.
        self.lingua = lingua or str(self.persona.get("lingua", "it"))
        self.utc_offset = utc_offset

    # -- auth ---------------------------------------------------------------------------
    def _token_request(self, grant: str, body: dict[str, str]) -> dict[str, Any]:
        answer = chiama(
            "POST",
            f"{self.gemello.supabase_url}/auth/v1/token?grant_type={grant}",
            headers={"apikey": self.gemello.anon_key},
            body=body,
        )
        if not answer.ok or not isinstance(answer.body, dict):
            raise RuntimeError(f"accesso non riuscito (HTTP {answer.status})")
        state = _load(stato_path(self.chat))
        state.update(
            {
                "access_token": answer.body["access_token"],
                "refresh_token": answer.body["refresh_token"],
                "expires_at": int(time.time()) + int(answer.body.get("expires_in", 3600)),
                "user_id": answer.body.get("user", {}).get("id", state.get("user_id")),
            }
        )
        _save(stato_path(self.chat), state)
        return state

    def accedi(self) -> dict[str, Any]:
        from scripts.collaudo.gemello import carica_utenti

        email = persone.email_account(self.base, self.indice)
        account = carica_utenti().get(email)
        if not account:
            raise RuntimeError(f"nessun account per {self.chat}: va creato con `gemello utenti`")
        return self._token_request("password", {"email": email, "password": account["password"]})

    def token(self, *, forza: bool = False) -> str:
        state = _load(stato_path(self.chat))
        if not state.get("access_token"):
            state = self.accedi()
        elif forza or int(state.get("expires_at", 0)) - time.time() < 120:
            try:
                state = self._token_request(
                    "refresh_token", {"refresh_token": state["refresh_token"]}
                )
            except RuntimeError:
                state = self.accedi()
        return str(state["access_token"])

    # -- calls --------------------------------------------------------------------------
    def _with_auth(self, method: str, url: str, path: str, funzione: str, **kwargs: Any) -> Any:
        headers = dict(kwargs.pop("headers", {}))
        for attempt in (0, 1):
            headers["Authorization"] = f"Bearer {self.token(forza=attempt == 1)}"
            answer = chiama(method, url, headers=headers, **kwargs)
            registra_tempo(self.chat, method, path, answer, funzione)
            if answer.status != 401:
                return answer
        return answer

    def _api_headers(self) -> dict[str, str]:
        headers = {"Accept-Language": self.lingua}
        if self.utc_offset is not None:
            headers["X-UTC-Offset-Minutes"] = str(self.utc_offset)
        return headers

    def api(
        self,
        method: str,
        path: str,
        body: Any = None,
        funzione: str = "",
        raw: tuple[bytes, str] | None = None,
    ) -> Risposta:
        path = "/" + path.lstrip("/")
        result: Risposta = self._with_auth(
            method,
            self.gemello.api_url + path,
            path,
            funzione or path.strip("/").split("/")[0],
            headers=self._api_headers(),
            body=body,
            raw=raw,
            bypass=self.gemello.bypass,
            timeout=180,
        )
        return result

    def _pet_id(self, animale: str) -> str:
        pets: dict[str, str] = _load(stato_path(self.chat)).get("animali", {})
        if animale not in pets:
            raise RuntimeError(f"animale sconosciuto: {animale}. Hai: {list(pets)}")
        return pets[animale]

    def allega(self, animale: str, file: Path) -> Risposta:
        """A photo or a PDF report for the chat, as the app uploads it (multipart)."""
        content_type = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
        raw = multipart(
            {"pet_id": self._pet_id(animale)}, "file", file.name, file.read_bytes(), content_type
        )
        return self.api("POST", "/chat-attachments", raw=raw, funzione="referti_cartella")

    def detta(self, file: Path) -> Risposta:
        """A recorded question (audio file) to the dictation, as the app sends it."""
        content_type = mimetypes.guess_type(file.name)[0] or "audio/webm"
        raw = multipart({}, "file", file.name, file.read_bytes(), content_type)
        return self.api("POST", "/speech-to-text", raw=raw, funzione="dettatura")

    def carica(self, bucket: str, nome: str, file: Path) -> Risposta:
        """A file straight into the twin's storage with the user's token, under the user's own
        folder (`<user id>/<nome>`), as the app does for pet and walk photos."""
        user_id = _load(stato_path(self.chat)).get("user_id") or ""
        if not user_id:
            self.accedi()
            user_id = _load(stato_path(self.chat)).get("user_id") or ""
        path = f"/storage/v1/object/{bucket}/{user_id}/{nome.lstrip('/')}"
        content_type = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
        result: Risposta = self._with_auth(
            "POST",
            self.gemello.supabase_url + path,
            f"/storage/v1/object/{bucket}/:utente/{nome}",
            "foto_galleria",
            headers={"apikey": self.gemello.anon_key, "x-upsert": "true"},
            raw=(file.read_bytes(), content_type),
        )
        return result

    def prepara(self) -> list[str]:
        """What the sign-up screen records in the app: Terms and Privacy accepted, then the
        declared age. Testers who test consents and age themselves are left alone."""
        if "consensi_eta" in self.persona.get("funzioni", []):
            return ["consensi ed età: li fa la persona durante il giro"]
        done: list[str] = []
        for key in ("terms_of_service", "privacy_policy"):
            answer = self.api(
                "POST", "/account/consents", {"consent_key": key, "granted": True}, "consensi_eta"
            )
            done.append(f"{key}: HTTP {answer.status}")
        age = int(self.persona.get("eta") or 40)
        today = datetime.now(UTC).date()
        birth = today.replace(year=today.year - age, month=1, day=1)
        answer = self.api("POST", "/account/age", {"birth_date": birth.isoformat()}, "consensi_eta")
        done.append(f"età: HTTP {answer.status}")
        return done

    def db(self, method: str, table: str, query: str = "", body: Any = None) -> Risposta:
        path = f"/rest/v1/{table}" + (f"?{query}" if query else "")
        headers = {"apikey": self.gemello.anon_key}
        if method.upper() in ("POST", "PATCH"):
            headers["Prefer"] = "return=representation"
        result: Risposta = self._with_auth(
            method,
            self.gemello.supabase_url + path,
            path,
            f"db:{table}",
            headers=headers,
            body=body,
        )
        return result

    # -- features -----------------------------------------------------------------------
    def crea_animali(self) -> dict[str, str]:
        state = _load(stato_path(self.chat))
        pets: dict[str, str] = state.get("animali", {})
        for pet in self.persona.get("animali", []):
            if pet["nome"] in pets:
                continue
            body = {"name": pet["nome"], "species": pet["specie_app"], "breed": pet.get("razza")}
            answer = self.api("POST", "/pets", body, funzione="profilo_animale")
            created = answer.body if isinstance(answer.body, dict) else {}
            created = created.get("pet_profile", created)
            if answer.ok and created.get("id"):
                pets[pet["nome"]] = created["id"]
                print(f"creato {pet['nome']}")
            else:
                print(f"NON creato {pet['nome']}: HTTP {answer.status} {str(answer.body)[:300]}")
        state = _load(stato_path(self.chat))
        state["animali"] = pets
        _save(stato_path(self.chat), state)
        return pets

    def chat_message(
        self, animale: str, messaggio: str, nuova: bool, id_messaggio: str = ""
    ) -> dict[str, Any]:
        state = _load(stato_path(self.chat))
        pet_id = state.get("animali", {}).get(animale)
        if not pet_id:
            raise RuntimeError(
                f"animale sconosciuto: {animale}. Hai: {list(state.get('animali', {}))}"
            )
        conversations: dict[str, str] = state.get("conversazioni", {})
        body = {
            "pet_id": pet_id,
            "conversation_id": None if nuova else conversations.get(animale),
            "user_message": messaggio,
            "language": self.lingua,
        }
        if id_messaggio:
            # the app's own id of the message: the same id twice must not answer twice
            body["client_message_id"] = id_messaggio
        answer = self.api("POST", "/chat", body, funzione="chat")
        result = answer.body if isinstance(answer.body, dict) else {}
        reply = result.get("reply") or {}
        text = str(reply.get("content") or "")
        conversation = (result.get("conversation") or {}).get("id")
        if conversation:
            state = _load(stato_path(self.chat))
            state.setdefault("conversazioni", {})[animale] = conversation
            _save(stato_path(self.chat), state)
        summary = {
            "status": answer.status,
            "risposta": text,
            "modo": result.get("mode"),
            "fonti": [s.get("title") for s in result.get("sources") or []],
            "secondi_server": round(answer.total_ms / 1000, 1),
            "parole": lettura.parole(text),
            "secondi_lettura": lettura.secondi_di_lettura(text, self.lingua),
            "conversation_id": conversation,
            "message_id": reply.get("id"),
        }
        if not answer.ok:
            summary["errore"] = str(answer.body)[:500]
        _append(
            cartella(self.chat) / "risposte.jsonl",
            {
                "at": datetime.now(UTC).isoformat(timespec="seconds"),
                "animale": animale,
                "messaggio": messaggio,
                **summary,
            },
        )
        return summary


def riassunto_tempi(chat: str) -> dict[str, dict[str, float]]:
    path = cartella(chat) / "tempi.jsonl"
    groups: dict[str, list[int]] = {}
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                entry = json.loads(line)
                key = f"{entry['metodo']} {entry['percorso']}"
                groups.setdefault(key, []).append(int(entry["total_ms"]))
    return {
        key: {
            "volte": len(values),
            "mediana_s": round(median(values) / 1000, 2),
            "massimo_s": round(max(values) / 1000, 2),
        }
        for key, values in sorted(groups.items())
    }


def _print(data: Any) -> None:
    text = data if isinstance(data, str) else json.dumps(data, ensure_ascii=False, indent=1)
    print(text[:_PRINT_LIMIT] + ("\n… (tagliato)" if len(text) > _PRINT_LIMIT else ""))


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(prog="client")
    parser.add_argument("chat")
    parser.add_argument(
        "--lingua", default="", help="es. en-US, en-AU: sostituisce quella della persona"
    )
    parser.add_argument("--utc-offset", type=int, default=None, help="minuti, es. 60 per UTC+1")
    sub = parser.add_subparsers(dest="comando", required=True)
    sub.add_parser("accedi")
    sub.add_parser("prepara")
    sub.add_parser("animali")
    attach = sub.add_parser("allega")
    attach.add_argument("animale")
    attach.add_argument("file", type=Path)
    dictate = sub.add_parser("detta")
    dictate.add_argument("file", type=Path)
    upload = sub.add_parser("carica")
    upload.add_argument("bucket")
    upload.add_argument("nome")
    upload.add_argument("file", type=Path)
    chat = sub.add_parser("chat")
    chat.add_argument("animale")
    chat.add_argument("messaggio")
    chat.add_argument("--nuova", action="store_true")
    chat.add_argument("--id-messaggio", default="", help="client_message_id, come l'app")
    api = sub.add_parser("api")
    api.add_argument("metodo")
    api.add_argument("percorso")
    api.add_argument("json", nargs="?", default=None)
    db = sub.add_parser("db")
    db.add_argument("metodo")
    db.add_argument("tabella")
    db.add_argument("query", nargs="?", default="")
    db.add_argument("json", nargs="?", default=None)
    report = sub.add_parser("segnala")
    report.add_argument("--tipo", required=True)
    report.add_argument("--gravita", required=True)
    report.add_argument("--titolo", required=True)
    report.add_argument("--cosa", required=True)
    report.add_argument("--funzione", default="")
    report.add_argument("--specie", default="")
    report.add_argument("--perche", default="")
    report.add_argument("--riproduci", action="append", default=[])
    report.add_argument("--proposta", default="")
    report.add_argument("--lavoro", default="")
    report.add_argument("--sbagliata", action="store_true")
    report.add_argument("--fonte", default="")
    report.add_argument("--prima", default="")
    report.add_argument("--dopo", default="")
    sub.add_parser("tempi")
    args = parser.parse_args(argv)

    if args.comando == "segnala":
        try:
            item = Segnalazione(
                chat=args.chat,
                giro=giro(),
                tipo=args.tipo,
                gravita=args.gravita,
                titolo=args.titolo,
                cosa_succede=args.cosa,
                funzione=args.funzione,
                specie=args.specie,
                perche_conta=args.perche,
                come_riprodurre=args.riproduci,
                proposta=args.proposta,
                lavoro=args.lavoro,
                risposta_sbagliata=args.sbagliata,
                fonte=args.fonte,
                prima=args.prima,
                dopo=args.dopo,
            )
        except SegnalazioneNonValida as error:
            print(f"segnalazione non valida: {error}")
            return 2
        aggiungi(cartella(args.chat) / "segnalazioni.jsonl", item)
        print("segnalazione registrata")
        return 0
    if args.comando == "tempi":
        _print(riassunto_tempi(args.chat))
        return 0
    try:
        session = Sessione(
            args.chat, load_gemello(), lingua=args.lingua, utc_offset=args.utc_offset
        )
    except (GemelloNonSicuro, KeyError) as error:
        print(f"FERMO: {error}")
        return 2
    if args.comando == "accedi":
        session.accedi()
        print("accesso fatto")
    elif args.comando == "prepara":
        _print(session.prepara())
    elif args.comando in ("allega", "detta", "carica"):
        if args.comando == "allega":
            answer = session.allega(args.animale, args.file)
        elif args.comando == "detta":
            answer = session.detta(args.file)
        else:
            answer = session.carica(args.bucket, args.nome, args.file)
        _print({"status": answer.status, "secondi": answer.total_ms / 1000, "body": answer.body})
    elif args.comando == "animali":
        _print(session.crea_animali())
    elif args.comando == "chat":
        _print(session.chat_message(args.animale, args.messaggio, args.nuova, args.id_messaggio))
    elif args.comando == "api":
        body = json.loads(args.json) if args.json else None
        answer = session.api(args.metodo, args.percorso, body)
        _print({"status": answer.status, "secondi": answer.total_ms / 1000, "body": answer.body})
    elif args.comando == "db":
        body = json.loads(args.json) if args.json else None
        answer = session.db(args.metodo, args.tabella, args.query, body)
        _print({"status": answer.status, "secondi": answer.total_ms / 1000, "body": answer.body})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""What a synthetic user uses: talk to the local server and file feedback.

    python client.py u03 setup
    python client.py u03 pets
    python client.py u03 chat <pet name> "messaggio" [--new]
    python client.py u03 api GET /reminders
    python client.py u03 api POST /reminders '<json>'
    python client.py u03 report <conversation_id> <message_id> <reason> "dettagli"
    python client.py u03 feedback <tipo> <gravita> <area> "testo" ["citazione"]

Only ever reaches 127.0.0.1. Results and feedback stay in .local/synthetic_users.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / ".local" / "synthetic_users"
BASE = "http://127.0.0.1:8799"
PERSONAS = json.loads(Path(__file__).with_name("personas.json").read_text(encoding="utf-8"))
TYPES = {"bug", "risposta_sbagliata", "tono", "chiarezza", "mancanza", "lodo", "idea", "privacy"}
SEVERITIES = {"bloccante", "alta", "media", "bassa"}


def persona(user_id: str) -> dict[str, Any]:
    for item in PERSONAS:
        if item["id"] == user_id:
            return item
    sys.exit(f"utente sconosciuto: {user_id}")


def state_path(user_id: str) -> Path:
    return OUTPUT / "state" / f"{user_id}.json"


def load_state(user_id: str) -> dict[str, Any]:
    path = state_path(user_id)
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save_state(user_id: str, state: dict[str, Any]) -> None:
    path = state_path(user_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")


def call(user_id: str, method: str, path: str, body: Any = None, language: str = "") -> Any:
    token = load_state(user_id).get("token", "")
    request = urllib.request.Request(BASE + path, method=method)
    request.add_header("Authorization", f"Bearer {token}")
    if language:
        request.add_header("Accept-Language", language)
    data = None
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, data, timeout=600) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else {"status": response.status}
    except urllib.error.HTTPError as error:
        return {"http_error": error.code, "body": error.read().decode("utf-8", "replace")[:800]}


def setup(user_id: str) -> None:
    me = persona(user_id)
    session = call(user_id, "POST", "/auth/signup", {"email": me["email"], "password": "synthetic"})
    state = {"token": session["access_token"], "user_id": session["user"]["id"], "pets": {}}
    save_state(user_id, state)
    print("piano:", call(user_id, "POST", "/subscription/select-plan", {"plan": me["plan"]}))
    for pet in me["pets"]:
        created = call(user_id, "POST", "/pets", pet)
        if "id" not in created:
            print("ERRORE animale", pet["name"], created)
            continue
        state["pets"][pet["name"]] = created["id"]
        print("registrato", pet["name"], created["id"])
    save_state(user_id, state)
    roster = OUTPUT / "roster.jsonl"
    with roster.open("a", encoding="utf-8") as log:
        log.write(
            json.dumps(
                {
                    "id": user_id,
                    "name": me["name"],
                    "band": me["band"],
                    "pets": list(state["pets"]),
                },
                ensure_ascii=False,
            )
            + "\n"
        )


def chat(user_id: str, pet_name: str, message: str, new: bool) -> None:
    me, state = persona(user_id), load_state(user_id)
    pet_id = state["pets"].get(pet_name)
    if pet_id is None:
        sys.exit(f"animale sconosciuto: {pet_name}. Hai: {list(state['pets'])}")
    conversations = state.setdefault("conversations", {})
    body = {
        "pet_id": pet_id,
        "conversation_id": None if new else conversations.get(pet_name),
        "user_message": message,
        "language": me["language"],
    }
    result = call(user_id, "POST", "/chat", body, me["language"])
    if "http_error" in result:
        print(json.dumps(result, ensure_ascii=False))
        return
    conversation = result.get("conversation") or {}
    reply = result.get("reply") or {}
    conversations[pet_name] = conversation.get("id")
    save_state(user_id, state)
    with (OUTPUT / "transcripts.jsonl").open("a", encoding="utf-8") as log:
        log.write(
            json.dumps(
                {
                    "user": user_id,
                    "pet": pet_name,
                    "message": message,
                    "reply": reply.get("content"),
                    "mode": result.get("mode"),
                    "sources": [s.get("title") for s in result.get("sources") or []],
                    "at": datetime.now(UTC).isoformat(),
                },
                ensure_ascii=False,
            )
            + "\n"
        )
    print(
        json.dumps(
            {
                "reply": reply.get("content"),
                "mode": result.get("mode"),
                "conversation_id": conversation.get("id"),
                "message_id": reply.get("id"),
            },
            ensure_ascii=False,
            indent=1,
        )
    )


def feedback(user_id: str, args: list[str]) -> None:
    kind, severity, area, text = args[:4]
    if kind not in TYPES or severity not in SEVERITIES:
        sys.exit(f"tipo tra {sorted(TYPES)}, gravità tra {sorted(SEVERITIES)}")
    me = persona(user_id)
    entry = {
        "user": user_id,
        "name": me["name"],
        "band": me["band"],
        "type": kind,
        "severity": severity,
        "area": area,
        "text": text,
        "quote": args[4] if len(args) > 4 else "",
        "at": datetime.now(UTC).isoformat(),
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with (OUTPUT / "feedback.jsonl").open("a", encoding="utf-8") as log:
        log.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print("feedback registrato")


def main() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    user_id, command, *args = sys.argv[1:]
    if command == "setup":
        setup(user_id)
    elif command == "pets":
        print(json.dumps(load_state(user_id).get("pets"), ensure_ascii=False, indent=1))
    elif command == "chat":
        new = "--new" in args
        args = [item for item in args if item != "--new"]
        chat(user_id, args[0], args[1], new)
    elif command == "api":
        body = json.loads(args[2]) if len(args) > 2 else None
        result = call(user_id, args[0].upper(), args[1], body, persona(user_id)["language"])
        print(json.dumps(result, ensure_ascii=False, indent=1)[:6000])
    elif command == "report":
        body = {"conversation_id": args[0], "message_id": args[1], "reason": args[2]}
        if len(args) > 3:
            body["details"] = args[3]
        print(call(user_id, "POST", "/chat-response-reports", body))
    elif command == "feedback":
        feedback(user_id, args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

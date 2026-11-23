"""The collaudo client times every call, refreshes its token and files findings in the new
format. Offline: HTTP is replaced."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from scripts.collaudo import client, lettura
from scripts.collaudo.config import Gemello
from scripts.collaudo.rete import USER_AGENT, Risposta
from scripts.collaudo.segnalazioni import SENZA_FONTE, Segnalazione, SegnalazioneNonValida

TWIN = Gemello(
    "https://abcdefghijklmnopqrst.supabase.co", "anon", "", "https://x-collaudo.vercel.app", ""
)


@pytest.fixture
def out(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    monkeypatch.setenv("COLLAUDO_GIRO", "7")
    return tmp_path


def test_routes_are_grouped_without_ids() -> None:
    path = "/pets/3f2a1b4c-0000-4000-8000-1234567890ab/weights?limit=5"
    assert client.percorso_generico(path) == "/pets/:id/weights"


def test_the_user_agent_is_a_quokka_name() -> None:
    assert USER_AGENT.startswith("Quokka")


def test_every_call_is_timed_and_a_401_refreshes_the_token(
    out: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    state = out / "stato" / "col-giulia-cucciolo.json"
    state.parent.mkdir(parents=True)
    state.write_text(
        json.dumps({"access_token": "old", "refresh_token": "r", "expires_at": 9_999_999_999}),
        encoding="utf-8",
    )
    seen: list[str] = []

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        if "grant_type=refresh_token" in url:
            return Risposta(200, {"access_token": "new", "refresh_token": "r2"}, 3, 4)
        seen.append(kwargs["headers"]["Authorization"])
        status = 401 if kwargs["headers"]["Authorization"] == "Bearer old" else 200
        return Risposta(status, {"items": []}, 10, 12)

    monkeypatch.setattr(client, "chiama", fake)
    answer = client.Sessione("col-giulia-cucciolo", TWIN).api("GET", "/reminders")

    assert answer.status == 200
    assert seen == ["Bearer old", "Bearer new"]
    lines = (out / "giro-7" / "col-giulia-cucciolo" / "tempi.jsonl").read_text("utf-8")
    entries = [json.loads(line) for line in lines.splitlines()]
    assert [e["status"] for e in entries] == [401, 200]
    assert entries[-1]["total_ms"] == 12 and entries[-1]["percorso"] == "/reminders"


def test_a_chat_answer_records_server_time_words_and_reading_time(
    out: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    state = out / "stato" / "col-sarah-esotici.json"
    state.parent.mkdir(parents=True)
    state.write_text(
        json.dumps(
            {
                "access_token": "t",
                "refresh_token": "r",
                "expires_at": 9_999_999_999,
                "animali": {"Mango": "pet-1"},
            }
        ),
        encoding="utf-8",
    )
    reply = "Leopard geckos need a warm side around thirty degrees. " * 4

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        assert kwargs["body"]["language"] == "en-GB"
        return Risposta(
            200,
            {"reply": {"content": reply, "id": "m1"}, "conversation": {"id": "c1"}, "mode": "x"},
            5000,
            5200,
        )

    monkeypatch.setattr(client, "chiama", fake)
    summary = client.Sessione("col-sarah-esotici", TWIN).chat_message("Mango", "Hi", False)

    assert summary["secondi_server"] == 5.2
    assert summary["parole"] == lettura.parole(reply)
    assert summary["secondi_lettura"] == lettura.secondi_di_lettura(reply, "en-GB")
    saved = json.loads(state.read_text("utf-8"))
    assert saved["conversazioni"] == {"Mango": "c1"}
    assert (out / "giro-7" / "col-sarah-esotici" / "risposte.jsonl").is_file()


def test_reading_speed_depends_on_the_language() -> None:
    text = "parola " * 188
    assert lettura.secondi_di_lettura(text, "it") == 60.0
    assert lettura.secondi_di_lettura(text, "en-GB") < 60.0
    assert lettura.parole("l'acqua è a 28 gradi, va bene") == 6


def test_a_wrong_answer_finding_without_source_says_so() -> None:
    item = Segnalazione(
        chat="c",
        giro="1",
        tipo="funzioni",
        gravita="grave",
        titolo="t",
        cosa_succede="x",
        risposta_sbagliata=True,
    )
    assert item.fonte == SENZA_FONTE


@pytest.mark.parametrize(
    "changes",
    [{"gravita": "alta"}, {"tipo": "bug"}, {"titolo": ""}, {"titolo": "x" * 141}],
)
def test_findings_outside_the_scale_are_refused(changes: dict[str, Any]) -> None:
    base: dict[str, Any] = {
        "chat": "c",
        "giro": "1",
        "tipo": "funzioni",
        "gravita": "fastidio",
        "titolo": "t",
        "cosa_succede": "x",
    }
    base.update(changes)
    with pytest.raises(SegnalazioneNonValida):
        Segnalazione(**base)


def test_the_command_line_files_a_finding(out: Path) -> None:
    code = client.main(
        [
            "col-luca-connettore",
            "segnala",
            "--tipo",
            "funzioni",
            "--gravita",
            "Grave",
            "--funzione",
            "peso_monitoraggio",
            "--titolo",
            "Il peso non arriva in chat",
            "--cosa",
            "La chat non vede l'ultima pesata",
            "--riproduci",
            "pesa",
            "--riproduci",
            "chiedi",
        ]
    )
    assert code == 0
    line = (out / "giro-7" / "col-luca-connettore" / "segnalazioni.jsonl").read_text("utf-8")
    saved = json.loads(line)
    assert saved["gravita"] == "grave" and saved["come_riprodurre"] == ["pesa", "chiedi"]


def _signed_in(out: Path, chat: str, **extra: Any) -> None:
    state = out / "stato" / f"{chat}.json"
    state.parent.mkdir(parents=True, exist_ok=True)
    data = {"access_token": "t", "refresh_token": "r", "expires_at": 9_999_999_999}
    data.update(extra)
    state.write_text(json.dumps(data), encoding="utf-8")


def test_a_photo_for_the_chat_is_sent_as_a_form_with_the_pet(
    out: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _signed_in(out, "col-luca-connettore", animali={"Zorro": "pet-9"})
    photo = tmp_path / "referto.pdf"
    photo.write_bytes(b"%PDF-1.4 prova")
    sent: dict[str, Any] = {}

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        sent.update(url=url, raw=kwargs["raw"])
        return Risposta(200, {"id": "a1"}, 1, 1)

    monkeypatch.setattr(client, "chiama", fake)
    client.Sessione("col-luca-connettore", TWIN).allega("Zorro", photo)

    body, content_type = sent["raw"]
    assert sent["url"].endswith("/chat-attachments")
    assert content_type.startswith("multipart/form-data; boundary=QuokkaCollaudo")
    assert b'name="pet_id"\r\n\r\npet-9' in body
    assert b'filename="referto.pdf"' in body and b"application/pdf" in body


def test_storage_uploads_go_under_the_users_own_folder(
    out: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    _signed_in(out, "col-telefono", user_id="u-77")
    picture = tmp_path / "birba.jpg"
    picture.write_bytes(b"jpg")
    urls: list[str] = []

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        urls.append(url)
        return Risposta(200, {}, 1, 1)

    monkeypatch.setattr(client, "chiama", fake)
    client.Sessione("col-telefono", TWIN).carica("pet-photos", "birba.jpg", picture)
    assert urls == [TWIN.supabase_url + "/storage/v1/object/pet-photos/u-77/birba.jpg"]
    timing = (out / "giro-7" / "col-telefono" / "tempi.jsonl").read_text("utf-8")
    assert "u-77" not in timing


def test_prepare_records_consents_and_age_unless_the_persona_tests_them(
    out: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[str, Any]] = []

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        calls.append((url.rsplit("/", 2)[-2] + "/" + url.rsplit("/", 1)[-1], kwargs.get("body")))
        return Risposta(200, {}, 1, 1)

    monkeypatch.setattr(client, "chiama", fake)
    _signed_in(out, "col-sarah-esotici")
    client.Sessione("col-sarah-esotici", TWIN).prepara()
    keys = [body.get("consent_key") for _, body in calls if body and "consent_key" in body]
    assert keys == ["terms_of_service", "privacy_policy", "emergency_notice"]
    assert any(path == "account/age" for path, _ in calls)

    calls.clear()
    _signed_in(out, "col-elena-doveri")
    client.Sessione("col-elena-doveri", TWIN).prepara()
    assert calls == []


def test_a_villain_signs_in_with_the_victim_account_under_its_own_name(
    out: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (out / "utenti.json").write_text(
        json.dumps({"col-villain-chat-b@example.com": {"password": "pw-b", "id": "u-b"}}),
        encoding="utf-8",
    )
    sent: dict[str, Any] = {}

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        sent.update(kwargs["body"])
        return Risposta(
            200, {"access_token": "t", "refresh_token": "r", "user": {"id": "u-b"}}, 1, 1
        )

    monkeypatch.setattr(client, "chiama", fake)
    session = client.Sessione("col-villain-chat-b", TWIN)
    session.accedi()
    assert sent["email"] == "col-villain-chat-b@example.com"
    assert session.persona["chat"] == "col-villain-chat"
    assert (out / "stato" / "col-villain-chat-b.json").is_file()


def test_only_declared_extra_accounts_are_resolved() -> None:
    from scripts.collaudo import persone

    assert persone.risolvi_account("col-villain-traffico-b") == ("col-villain-traffico", 1)
    assert persone.risolvi_account("col-giulia-cucciolo-b") == ("col-giulia-cucciolo-b", 0)
    assert persone.risolvi_account("col-giulia-cucciolo") == ("col-giulia-cucciolo", 0)


def test_language_offset_and_message_id_options_reach_the_server(
    out: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _signed_in(out, "col-chloe-lingue", animali={"Poule": "pet-3"})
    seen: dict[str, Any] = {}

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        seen.update(headers=kwargs["headers"], body=kwargs["body"])
        return Risposta(200, {"reply": {"content": "Hi"}, "conversation": {"id": "c"}}, 1, 1)

    monkeypatch.setattr(client, "chiama", fake)
    session = client.Sessione("col-chloe-lingue", TWIN, lingua="en-AU", utc_offset=600)
    session.chat_message("Poule", "Hello", False, "m-001")
    assert seen["headers"]["Accept-Language"] == "en-AU"
    assert seen["headers"]["X-UTC-Offset-Minutes"] == "600"
    assert seen["body"]["language"] == "en-AU" and seen["body"]["client_message_id"] == "m-001"

    session = client.Sessione("col-chloe-lingue", TWIN)
    session.chat_message("Poule", "Bonjour", False)
    # Without the option the header is still there, as in the app: this computer's own offset.
    assert seen["headers"] == {
        "Accept-Language": "fr",
        "Authorization": "Bearer t",
        "X-UTC-Offset-Minutes": str(client.fuso_locale_minuti()),
    }
    assert "client_message_id" not in seen["body"]

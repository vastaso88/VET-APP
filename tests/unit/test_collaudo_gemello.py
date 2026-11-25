"""The collaudo twin tools refuse production and give the test accounts the Pro plan.
Offline: every HTTP call is replaced."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from scripts.collaudo import config, gemello
from scripts.collaudo.config import GemelloNonSicuro, check_api_target, check_supabase_target
from scripts.collaudo.rete import Risposta

PROD = "https://ywbuzgwbkrmkukkpysbz.supabase.co"
REF = "abcdefghijklmnopqrst"
TWIN = f"https://{REF}.supabase.co"
TWIN_API = "https://vet-app-git-collaudo-team.vercel.app"


def _env(tmp_path: Path, **values: str) -> dict[str, str]:
    env_file = tmp_path / ".env"
    env_file.write_text("", encoding="utf-8")
    base = {
        "COLLAUDO_ENV_FILE": str(env_file),
        "COLLAUDO_OUTPUT": str(tmp_path / "out"),
        "COLLAUDO_SUPABASE_REF": REF,
        "COLLAUDO_SUPABASE_URL": TWIN,
        "COLLAUDO_SUPABASE_ANON_KEY": "twin-anon",
        "COLLAUDO_SUPABASE_SERVICE_ROLE_KEY": "twin-service",
        "COLLAUDO_API_URL": TWIN_API,
    }
    base.update(values)
    return base


@pytest.mark.parametrize(
    "url",
    [
        PROD,
        PROD + "/",
        "https://ywbuzgwbkrmkukkpysbz.supabase.co/rest/v1",
        "http://abcdefghijklmnopqrst.supabase.co",
        "https://dkzzcoastheciitvkiuo.supabase.co",
        "https://noulpaaonqjvprfddipn.supabase.co",
        "https://zzzzzzzzzzzzzzzzzzzz.supabase.co",
        "https://example.com",
        "",
    ],
)
def test_only_the_expected_twin_project_is_accepted(url: str) -> None:
    with pytest.raises(GemelloNonSicuro):
        check_supabase_target(url, expected_ref=REF)


def test_without_the_expected_ref_nothing_is_accepted() -> None:
    with pytest.raises(GemelloNonSicuro):
        check_supabase_target(TWIN)
    with pytest.raises(GemelloNonSicuro):
        check_supabase_target(PROD, expected_ref="ywbuzgwbkrmkukkpysbz")


def test_the_twin_must_not_be_the_normal_backend_project() -> None:
    with pytest.raises(GemelloNonSicuro):
        check_supabase_target(TWIN, normal_supabase_url=TWIN + "/", expected_ref=REF)
    assert check_supabase_target(TWIN, normal_supabase_url=PROD, expected_ref=REF) == REF


@pytest.mark.parametrize(
    "url",
    [
        "https://vet-app-psi-nine.vercel.app",
        "https://vet-app.vercel.app",
        "https://vet-app-git-main-team.vercel.app",
        "https://vet-app-34xp-git-collaudo-team.vercel.app",
        "https://collaudo-phishing.vercel.app",
        "https://api.example.com",
        "ftp://127.0.0.1",
    ],
)
def test_only_a_local_or_collaudo_api_is_accepted(url: str) -> None:
    with pytest.raises(GemelloNonSicuro):
        check_api_target(url)


@pytest.mark.parametrize("url", [TWIN_API, TWIN_API + "/", "http://127.0.0.1:8000"])
def test_the_collaudo_branch_and_local_api_are_accepted(url: str) -> None:
    assert check_api_target(url) == url.rstrip("/")


def test_the_twin_is_read_only_from_its_own_names(tmp_path: Path) -> None:
    env = _env(tmp_path, SUPABASE_URL=PROD, SUPABASE_SERVICE_ROLE_KEY="prod-service")
    loaded = config.load_gemello(env, need_service_key=True)
    assert loaded.supabase_url == TWIN
    assert loaded.service_key == "twin-service"

    without_twin = _env(tmp_path, COLLAUDO_SUPABASE_URL="")
    without_twin["SUPABASE_URL"] = TWIN
    with pytest.raises(GemelloNonSicuro):
        config.load_gemello(without_twin)


def test_a_production_key_reused_as_twin_key_is_refused(tmp_path: Path) -> None:
    env = _env(
        tmp_path, SUPABASE_SERVICE_ROLE_KEY="same", COLLAUDO_SUPABASE_SERVICE_ROLE_KEY="same"
    )
    with pytest.raises(GemelloNonSicuro):
        config.load_gemello(env)
    env = _env(tmp_path, SUPABASE_ANON_KEY="twin-anon")
    with pytest.raises(GemelloNonSicuro):
        config.load_gemello(env)


def test_the_env_file_is_read_and_the_production_url_there_still_refused(tmp_path: Path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text(f"COLLAUDO_SUPABASE_URL={PROD}\nCOLLAUDO_SUPABASE_ANON_KEY=x\n", "utf-8")
    with pytest.raises(GemelloNonSicuro):
        config.load_gemello({"COLLAUDO_ENV_FILE": str(env_file)}, need_api=False)


def test_schema_bundle_keeps_the_documented_order_and_every_migration() -> None:
    sql = gemello.componi_schema(commit="abc1234")
    positions = [sql.index(f"-- ===== file: {name} =====") for name in gemello.ORDINE_SCHEMA]
    assert positions == sorted(positions)
    assert positions[0] < sql.index("-- ===== file: supabase/migrations/")
    for path in sorted(Path("supabase/migrations").glob("*.sql")):
        assert f"-- ===== file: supabase/migrations/{path.name} =====" in sql
    assert "abc1234" in sql


def test_schema_names_and_differences() -> None:
    sql = """
    -- create table if not exists commented_out (id int);
    create table if not exists public.pets (id text);
    create or replace function public.do_it(a text) returns void as $$ $$;
    create policy "pets_own" on public.pets for select using (true);
    create trigger pets_guard before update on public.pets for each row execute function do_it();
    """
    names = gemello.nomi_dichiarati(sql)
    assert names == {
        "tabelle": {"pets"},
        "funzioni": {"do_it"},
        "policy": {"pets_own"},
        "trigger": {"pets_guard"},
    }
    diff = gemello.differenze_nomi(names, {"tabelle": {"pets", "admin_directories"}})
    assert diff["tabelle"] == {"solo_gemello": [], "solo_riferimento": ["admin_directories"]}


class _FakeServer:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, Any]] = []

    def __call__(self, method: str, url: str, **kwargs: Any) -> Risposta:
        self.calls.append((method, url, kwargs.get("body")))
        if url.endswith("/auth/v1/admin/users") and method == "POST":
            return Risposta(200, {"id": f"id-{kwargs['body']['email']}"}, 5, 5)
        if url.endswith("/rpc/admin_change_user_plan"):
            return Risposta(204, {}, 5, 5)
        return Risposta(404, {}, 5, 5)


def test_accounts_are_synthetic_get_pro_and_passwords_are_never_printed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    fake = _FakeServer()
    monkeypatch.setattr(gemello, "chiama", fake)
    twin = config.Gemello(TWIN, "anon", "service", TWIN_API, "")

    saved = gemello.crea_utenti(twin)

    assert saved and all(email.endswith("@example.com") for email in saved)
    assert all(entry["piano"] == "pro" for entry in saved.values())
    plan_calls = [body for _, url, body in fake.calls if url.endswith("admin_change_user_plan")]
    assert len(plan_calls) == len(saved)
    assert {body["p_plan"] for body in plan_calls} == {"pro"}
    stored = json.loads((tmp_path / "utenti.json").read_text(encoding="utf-8"))
    printed = capsys.readouterr().out
    assert all(entry["password"] not in printed for entry in stored.values())
    # villains have a second account for the "user B" checks
    assert "col-villain-chat-b@example.com" in saved


def test_only_example_com_accounts_can_be_created() -> None:
    twin = config.Gemello(TWIN, "anon", "service", TWIN_API, "")
    with pytest.raises(GemelloNonSicuro):
        gemello.assicura_account(twin, "someone@gmail.com", "x")


def test_the_check_before_a_round_stops_when_the_server_is_not_the_twin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    (tmp_path / "utenti.json").write_text(
        json.dumps({"col-controllo@example.com": {"password": "p", "id": "u"}}), "utf-8"
    )

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        if url.endswith("/health"):
            return Risposta(200, {"environment": "collaudo"}, 1, 1)
        if url.endswith("/auth/login"):
            return Risposta(401, {}, 1, 1)
        return Risposta(200, [], 1, 1)

    monkeypatch.setattr(gemello, "chiama", fake)
    problems = gemello.controllo(config.Gemello(TWIN, "a", "s", TWIN_API, ""))
    assert any("environment" in p for p in problems)
    assert any("NON è collegato al gemello" in p for p in problems)


def test_the_check_passes_on_a_healthy_twin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    (tmp_path / "utenti.json").write_text(
        json.dumps({"col-controllo@example.com": {"password": "p", "id": "u"}}), "utf-8"
    )

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        if url.endswith("/health"):
            return Risposta(200, {"environment": "production"}, 1, 1)
        if url.endswith("/auth/login"):
            return Risposta(200, {"access_token": "t"}, 1, 1)
        if url.endswith("/subscription/status"):
            return Risposta(
                200,
                {"limits": {"daily_questions": 40, "source": "pro"}, "test_period": False},
                1,
                1,
            )
        return Risposta(200, [], 1, 1)

    monkeypatch.setattr(gemello, "chiama", fake)
    assert gemello.controllo(config.Gemello(TWIN, "a", "s", TWIN_API, "")) == []


def test_the_command_line_stops_on_production(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    for name, value in _env(tmp_path, COLLAUDO_SUPABASE_URL=PROD).items():
        monkeypatch.setenv(name, value)
    assert gemello.main(["utenti"]) == 2
    assert "FERMO" in capsys.readouterr().out


def test_every_setup_script_left_out_of_the_bundle_adds_nothing_new() -> None:
    """A script of scripts/setup that the twin does not run must create nothing the bundle
    lacks (2026-11-22: the Mercatino animal ban and the Ricordi rules were missing, which
    would have shown false holes to the villains)."""
    bundle = gemello.nomi_dichiarati(gemello.componi_schema())
    for path in sorted(Path("scripts/setup").glob("*.sql")):
        if path.as_posix() in gemello.ORDINE_SCHEMA:
            continue
        own = gemello.nomi_dichiarati(path.read_text(encoding="utf-8"))
        missing = {
            kind: names - bundle[kind] for kind, names in own.items() if names - bundle[kind]
        }
        assert not missing, f"{path.name} crea oggetti assenti dallo schema del gemello: {missing}"


def test_the_check_stops_when_the_account_is_not_pro(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    (tmp_path / "utenti.json").write_text(
        json.dumps({"col-controllo@example.com": {"password": "p", "id": "u"}}), "utf-8"
    )

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        if url.endswith("/health"):
            return Risposta(200, {"environment": "production"}, 1, 1)
        if url.endswith("/auth/login"):
            return Risposta(200, {"access_token": "t"}, 1, 1)
        if url.endswith("/subscription/status"):
            # 16 is the old Pro count: the twin check must now refuse it.
            return Risposta(200, {"limits": {"daily_questions": 16, "source": "trial"}}, 1, 1)
        return Risposta(200, [], 1, 1)

    monkeypatch.setattr(gemello, "chiama", fake)
    problems = gemello.controllo(config.Gemello(TWIN, "a", "s", TWIN_API, ""))
    assert problems == ["l'account di prova non risulta Pro con 40 domande al giorno"]


def test_accounts_command_fails_when_a_plan_was_not_set(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    for name, value in _env(tmp_path).items():
        monkeypatch.setenv(name, value)

    def fake(method: str, url: str, **kwargs: Any) -> Risposta:
        if url.endswith("/auth/v1/admin/users"):
            return Risposta(200, {"id": "x"}, 1, 1)
        return Risposta(500, {}, 1, 1)

    monkeypatch.setattr(gemello, "chiama", fake)
    assert gemello.main(["utenti"]) == 1


def test_a_build_pointing_at_production_or_not_at_the_twin_is_refused(tmp_path: Path) -> None:
    web = tmp_path / "web"
    web.mkdir()
    (web / "main.dart.js").write_text(f'var u="https://{REF}.supabase.co";', encoding="utf-8")
    assert gemello.controlla_build(web, REF) == []

    (web / "main.dart.js").write_text('var u="https://ywbuzgwbkrmkukkpysbz.supabase.co";', "utf-8")
    problems = gemello.controlla_build(web, REF)
    assert any("vietato" in p for p in problems) and any("gemello" in p for p in problems)


def test_an_apk_is_checked_inside(tmp_path: Path) -> None:
    import zipfile

    apk = tmp_path / "app.apk"
    with zipfile.ZipFile(apk, "w") as archive:
        archive.writestr(
            "lib/x86_64/libapp.so", b"\x00https://noulpaaonqjvprfddipn.supabase.co\x00"
        )
    assert any("vietato" in p for p in gemello.controlla_build(apk, REF))
    with zipfile.ZipFile(apk, "w") as archive:
        archive.writestr("lib/x86_64/libapp.so", f"\x00https://{REF}.supabase.co".encode())
    assert gemello.controlla_build(apk, REF) == []


def test_the_eraser_keys_are_the_ones_the_server_derives() -> None:
    from types import SimpleNamespace

    from packages.bootstrap.radar_wiring import RadarWiring
    from packages.shared.config.settings import Settings

    settings = Settings(SUPABASE_SERVICE_ROLE_KEY="twin-service", _env_file=None)  # type: ignore[call-arg]
    secret, radar = gemello.chiavi_pseudonimi("twin-service")
    assert secret == settings.reporter_pseudonym_secret()
    server = RadarWiring.radar_report_settings(SimpleNamespace(settings=settings))  # type: ignore[arg-type]
    assert server is not None and server.pseudonym_key == radar


def test_a_real_build_naming_forbidden_refs_in_its_guards_is_accepted(tmp_path: Path) -> None:
    """The app's own guards list the forbidden refs as plain text: only a configured
    ADDRESS of a forbidden project makes the build unusable."""
    web = tmp_path / "web"
    web.mkdir()
    (web / "main.dart.js").write_text(
        f'["ywbuzgwbkrmkukkpysbz","noulpaaonqjvprfddipn.supabase.co"];u="https://{REF}.supabase.co"',
        encoding="utf-8",
    )
    assert gemello.controlla_build(web, REF) == []


def test_every_trigger_function_is_created_before_its_first_use() -> None:
    """On an empty project the bundle runs top to bottom: a trigger may only call a function
    already created above it (2026-11-22: set_updated_at was defined 1,300 lines too late)."""
    import re

    text = "\n".join(
        re.sub(r"--.*", "", line).lower() for line in gemello.componi_schema().splitlines()
    )
    first_definition: dict[str, int] = {}
    for match in re.finditer(r"create (?:or replace )?function (?:public\.)?(\w+)\s*\(", text):
        first_definition.setdefault(match.group(1), match.start())
    late = sorted(
        {
            match.group(1)
            for match in re.finditer(
                r"execute (?:function|procedure) (?:public\.)?(\w+)\s*\(", text
            )
            if first_definition.get(match.group(1), len(text)) > match.start()
        }
    )
    assert late == []

"""The manual "official website" check for exotic competences: candidates
are listed from our own data only, and only rows a person marked "si" with
groups and the page that says so are recorded. Invented names only."""

import importlib.util
import sys
from pathlib import Path
from types import ModuleType

ROOT_DIR = Path(__file__).resolve().parents[2]
RADAR_SCRIPTS = ROOT_DIR / "scripts" / "radar"


def _load(name: str) -> ModuleType:
    if str(RADAR_SCRIPTS) not in sys.path:
        sys.path.insert(0, str(RADAR_SCRIPTS))
    spec = importlib.util.spec_from_file_location(name, RADAR_SCRIPTS / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


candidates = _load("list_exotic_candidates")
confirm = _load("confirm_competence_claim")


def test_candidates_come_from_tags_or_name_hints() -> None:
    assert (
        candidates.candidate_reason(
            {"name": "Clinica Esempio", "details": {"veterinary:treats:rabbit": "yes"}}
        )
        == "small_mammal"
    )
    assert candidates.candidate_reason({"name": "Ambulatorio per Animali Esotici"}) == (
        "exotic_general"
    )
    assert candidates.candidate_reason({"name": "Clinica Esempio", "details": {}}) == ""


def test_only_checked_rows_with_groups_and_a_page_are_recorded(tmp_path: Path) -> None:
    sheet = tmp_path / "checked.csv"
    sheet.write_text(
        "source,source_id,nome,citta,sito,motivo,esito,gruppi,pagina\n"
        "openstreetmap_overpass,node/1,Clinica Uno,Milano,https://www.example.com,x,si,"
        '"bird,reptile_amphibian",https://www.example.com/esotici\n'
        "overture,ov-2,Clinica Due,Roma,https://www.example.org,x,no,,\n"
        "overture,ov-3,Clinica Tre,Roma,,x,nessun_sito,,\n"
        "overture,ov-4,Clinica Quattro,Roma,https://www.example.net,x,si,bird,\n"
        "overture,ov-5,Clinica Cinque,Roma,https://www.example.net,x,si,dog,https://www.example.net/a\n"
        "overture,ov-6,Clinica Sei,Roma,https://www.example.net,x,forse,,\n",
        encoding="utf-8",
    )

    records, problems = confirm.checked_rows(sheet)

    assert records == [
        {
            "source": "openstreetmap_overpass",
            "source_id": "node/1",
            "groups": ["bird", "reptile_amphibian"],
            "evidence_url": "https://www.example.com/esotici",
        }
    ]
    # "no" and "nessun_sito" leave the practice as it is; the rest are errors.
    assert [problem.split(":")[0] for problem in problems] == ["riga 5", "riga 6", "riga 7"]


def test_team_records_never_match_an_account() -> None:
    from packages.core.domain.radar_reports.models import contributor_pseudonym

    assert confirm.TEAM == "team"
    assert contributor_pseudonym("11111111-1111-4111-8111-111111111111", key="k") != "team"

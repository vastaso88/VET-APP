"""Where the twin lives, and the guard that refuses production.

The twin is read ONLY from its own names (`COLLAUDO_*`), from the environment or from the
local `.env`; the normal `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are never used as a
target, they are only compared with (never printed) so a twin set by mistake to the same
project as the normal backend is refused.

Guard (allowlist first, then denylist):
- the Supabase address must be exactly `https://<COLLAUDO_SUPABASE_REF>.supabase.co`: the
  twin's ref is fixed on its own (`azzera` erases data, so "any project but production" is
  not enough); the production project, the two retired ones and the normal `SUPABASE_URL`
  are refused anyway;
- the API address must be the local machine or the Vercel address of the `collaudo` branch
  of the API project (`vet-app-git-collaudo-…`), never a production host.

Names (values only in the environment or `.env`, never in the repository):
    COLLAUDO_SUPABASE_REF, COLLAUDO_SUPABASE_URL, COLLAUDO_SUPABASE_ANON_KEY,
    COLLAUDO_SUPABASE_SERVICE_ROLE_KEY, COLLAUDO_API_URL,
    VERCEL_BYPASS_COLLAUDO (only if the previews are protected),
    COLLAUDO_OUTPUT (default: <repository>/.local/collaudo),
    COLLAUDO_ENV_FILE (default: <repository>/.env).
"""

from __future__ import annotations

import os
import re
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]

# The production project and API: public in the repository already
# (docs/runbooks/supabase_setup.md, apps/mobile_app/.env.production.json).
PRODUCTION_SUPABASE_REFS = frozenset({"ywbuzgwbkrmkukkpysbz"})
# Retired projects that may still hold real data (apps/mobile_app runtime config loader).
RETIRED_SUPABASE_REFS = frozenset({"dkzzcoastheciitvkiuo", "noulpaaonqjvprfddipn"})
FORBIDDEN_SUPABASE_REFS = PRODUCTION_SUPABASE_REFS | RETIRED_SUPABASE_REFS
VERCEL_COLLAUDO_PREFIX = "vet-app-git-collaudo-"
PRODUCTION_API_HOSTS = frozenset({"vet-app-psi-nine.vercel.app", "vet-app.vercel.app"})
LOCAL_HOSTS = frozenset({"127.0.0.1", "localhost", "[::1]", "::1"})

_SUPABASE_HOST = re.compile(r"^([a-z0-9]{20})\.supabase\.co$")


class GemelloNonSicuro(RuntimeError):
    """The configured target is production, or not recognisably the twin."""


@dataclass(frozen=True)
class Gemello:
    supabase_url: str
    anon_key: str
    service_key: str
    api_url: str
    bypass: str

    @property
    def supabase_ref(self) -> str:
        return supabase_ref(self.supabase_url)


def supabase_ref(url: str) -> str:
    """The project ref of a Supabase address, or "" when it is not one."""
    host = (urlparse(url.strip()).hostname or "").lower()
    match = _SUPABASE_HOST.match(host)
    return match.group(1) if match else ""


def check_supabase_target(url: str, normal_supabase_url: str = "", expected_ref: str = "") -> str:
    """The twin's ref; raises unless the address is exactly the expected twin project."""
    parsed = urlparse(url.strip())
    ref = supabase_ref(url)
    if parsed.scheme != "https" or not ref:
        raise GemelloNonSicuro("COLLAUDO_SUPABASE_URL non è un indirizzo https://<ref>.supabase.co")
    if any(forbidden in url.lower() for forbidden in FORBIDDEN_SUPABASE_REFS):
        raise GemelloNonSicuro("COLLAUDO_SUPABASE_URL è la produzione o un progetto dismesso")
    expected = expected_ref.strip().lower()
    if not expected or expected in FORBIDDEN_SUPABASE_REFS:
        raise GemelloNonSicuro("manca COLLAUDO_SUPABASE_REF (il ref del progetto di prova)")
    if ref != expected:
        raise GemelloNonSicuro("COLLAUDO_SUPABASE_URL non è il progetto di prova atteso: mi fermo")
    if normal_supabase_url and supabase_ref(normal_supabase_url) == ref:
        raise GemelloNonSicuro(
            "COLLAUDO_SUPABASE_URL coincide con SUPABASE_URL del backend normale: mi fermo"
        )
    return ref


def check_api_target(url: str) -> str:
    """The API base without the final slash; raises unless it is local or the `collaudo` branch."""
    parsed = urlparse(url.strip())
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in ("http", "https") or not host:
        raise GemelloNonSicuro("COLLAUDO_API_URL non è un indirizzo valido")
    if host in PRODUCTION_API_HOSTS or any(ref in host for ref in FORBIDDEN_SUPABASE_REFS):
        raise GemelloNonSicuro("COLLAUDO_API_URL è la produzione: mi fermo")
    if host in LOCAL_HOSTS:
        return url.strip().rstrip("/")
    if (
        parsed.scheme == "https"
        and host.endswith(".vercel.app")
        and host.startswith(VERCEL_COLLAUDO_PREFIX)
    ):
        return url.strip().rstrip("/")
    raise GemelloNonSicuro(
        "COLLAUDO_API_URL deve essere locale o l'indirizzo Vercel del ramo collaudo"
    )


def read_env_file(path: Path) -> dict[str, str]:
    """NAME=value lines of a .env file; values are returned, never printed."""
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        key, separator, raw = line.partition("=")
        key = key.strip()
        if separator and key and not key.startswith("#"):
            values[key] = raw.strip().strip('"').strip("'")
    return values


def _value(name: str, environ: Mapping[str, str], env_file: Mapping[str, str]) -> str:
    return (environ.get(name) or env_file.get(name) or "").strip()


def output_root(environ: Mapping[str, str] | None = None) -> Path:
    environ = os.environ if environ is None else environ
    return Path(environ.get("COLLAUDO_OUTPUT") or ROOT / ".local" / "collaudo")


def load_gemello(
    environ: Mapping[str, str] | None = None,
    *,
    need_service_key: bool = False,
    need_api: bool = True,
) -> Gemello:
    """The twin's coordinates, checked. Raises `GemelloNonSicuro` on any doubt."""
    environ = os.environ if environ is None else environ
    env_file = read_env_file(Path(environ.get("COLLAUDO_ENV_FILE") or ROOT / ".env"))
    supabase_url = _value("COLLAUDO_SUPABASE_URL", environ, env_file)
    anon_key = _value("COLLAUDO_SUPABASE_ANON_KEY", environ, env_file)
    service_key = _value("COLLAUDO_SUPABASE_SERVICE_ROLE_KEY", environ, env_file)
    api_url = _value("COLLAUDO_API_URL", environ, env_file)
    if not supabase_url or not anon_key:
        raise GemelloNonSicuro(
            "mancano COLLAUDO_SUPABASE_URL o COLLAUDO_SUPABASE_ANON_KEY (nel .env o nell'ambiente)"
        )
    check_supabase_target(
        supabase_url,
        _value("SUPABASE_URL", environ, env_file),
        _value("COLLAUDO_SUPABASE_REF", environ, env_file),
    )
    normal_service_key = _value("SUPABASE_SERVICE_ROLE_KEY", environ, env_file)
    normal_anon_key = _value("SUPABASE_ANON_KEY", environ, env_file)
    if service_key and service_key == normal_service_key:
        raise GemelloNonSicuro("la chiave service_role del gemello è quella del backend normale")
    if anon_key == normal_anon_key:
        raise GemelloNonSicuro("la chiave publishable del gemello è quella del backend normale")
    if need_service_key and not service_key:
        raise GemelloNonSicuro("manca COLLAUDO_SUPABASE_SERVICE_ROLE_KEY")
    if need_api:
        if not api_url:
            raise GemelloNonSicuro("manca COLLAUDO_API_URL")
        api_url = check_api_target(api_url)
    return Gemello(
        supabase_url=supabase_url.rstrip("/"),
        anon_key=anon_key,
        service_key=service_key,
        api_url=api_url,
        bypass=_value("VERCEL_BYPASS_COLLAUDO", environ, env_file),
    )

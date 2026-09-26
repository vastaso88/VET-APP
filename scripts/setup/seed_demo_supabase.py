from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from packages.infrastructure.persistence.demo_seed import build_demo_seed  # noqa: E402
from packages.shared.config.settings import get_settings  # noqa: E402


def main() -> int:
    args = _parse_args()
    settings = get_settings()
    owner_id = args.owner_id or settings.bootstrap_user_id

    if not settings.supabase_url.strip() or not settings.supabase_service_role_key.strip():
        raise SystemExit(
            "Missing Supabase settings. Expected SUPABASE_URL and "
            "SUPABASE_SERVICE_ROLE_KEY in .env."
        )

    seed = build_demo_seed(owner_id)
    client = SupabaseRestClient(
        base_url=settings.supabase_url,
        api_key=settings.supabase_service_role_key,
    )

    if args.reset:
        reset_owner_seed(client, owner_id)

    client.upsert("pet_profiles", list(seed.pet_profiles))
    client.upsert("conversations", list(seed.conversations))
    client.upsert("reminders", list(seed.reminders))
    # Not owner-scoped (submitted_by_owner_id is null for seeded rows) -
    # upserted unconditionally rather than per-owner like the tables above.
    client.upsert("local_activities", list(seed.local_activities))

    pets = client.select_by_owner("pet_profiles", owner_id)
    conversations = client.select_by_owner("conversations", owner_id)
    reminders = client.select_by_owner("reminders", owner_id)

    print(
        json.dumps(
            {
                "owner_id": owner_id,
                "pet_profiles": len(pets),
                "conversations": len(conversations),
                "reminders": len(reminders),
                "local_activities": len(seed.local_activities),
                "pet_names": [row["name"] for row in pets],
            },
            indent=2,
        )
    )
    return 0


class SupabaseRestClient:
    def __init__(self, *, base_url: str, api_key: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key

    def upsert(self, table: str, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return self._request_json(
            "POST",
            f"/rest/v1/{table}?on_conflict=id",
            rows,
            extra_headers={"Prefer": "resolution=merge-duplicates,return=representation"},
        )

    def select_by_owner(self, table: str, owner_id: str) -> list[dict[str, Any]]:
        owner_filter = quote(f"eq.{owner_id}", safe=".")
        return self._request_json(
            "GET",
            f"/rest/v1/{table}?select=*&owner_id={owner_filter}",
        )

    def delete_by_owner(self, table: str, owner_id: str) -> None:
        owner_filter = quote(f"eq.{owner_id}", safe=".")
        self._request_json(
            "DELETE",
            f"/rest/v1/{table}?owner_id={owner_filter}",
            extra_headers={"Prefer": "return=minimal"},
        )

    def _request_json(
        self,
        method: str,
        path: str,
        body: Any | None = None,
        *,
        extra_headers: dict[str, str] | None = None,
    ) -> Any:
        data = None if body is None else json.dumps(body).encode("utf-8")
        headers = {
            "apikey": self._api_key,
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }
        if extra_headers:
            headers.update(extra_headers)

        request = Request(
            url=f"{self._base_url}{path}",
            data=data,
            headers=headers,
            method=method,
        )

        try:
            with urlopen(request, timeout=30) as response:
                payload = response.read().decode("utf-8")
        except HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase {method} {path} failed: {exc.code} {detail}") from exc
        except URLError as exc:
            raise RuntimeError(f"Supabase {method} {path} failed: {exc.reason}") from exc

        if not payload.strip():
            return []
        return json.loads(payload)


def reset_owner_seed(client: SupabaseRestClient, owner_id: str) -> None:
    for table in ("conversations", "reminders", "pet_profiles"):
        client.delete_by_owner(table, owner_id)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Populate Supabase core tables with stable demo data and verify readback.",
    )
    parser.add_argument(
        "--owner-id",
        help="Override the owner_id used for seeded rows. Defaults to BOOTSTRAP_USER_ID.",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Delete existing seeded rows for the selected owner before upserting.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(main())

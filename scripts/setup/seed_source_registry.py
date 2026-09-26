from __future__ import annotations

import argparse
import json
from typing import Any
from urllib import parse, request
from urllib.error import HTTPError

from packages.infrastructure.llm.sources.registry_seed import (
    build_initial_seed_catalog,
    load_registry_entry_snapshot,
)
from packages.shared.config.settings import get_settings


def _chunked(rows: list[dict[str, Any]], size: int = 200) -> list[list[dict[str, Any]]]:
    return [rows[index : index + size] for index in range(0, len(rows), size)]


def _fetch_id_map(
    client: _SeedClient,
    table_name: str,
    key_field: str,
    values: list[str],
) -> dict[str, str]:
    if not values:
        return {}
    rows = client.select_id_map(table_name, key_field, values)
    return {
        str(row[key_field]): str(row["id"])
        for row in rows
        if row.get(key_field) is not None and row.get("id") is not None
    }


def _prepare_registry_entries(
    registry_entries: list[dict[str, Any]],
    registry_ids: dict[str, str],
    domain_ids: dict[str, str],
) -> list[dict[str, Any]]:
    prepared: list[dict[str, Any]] = []
    for entry in registry_entries:
        registry_key = str(entry["registry_key"])
        host = str(entry["host"])
        registry_id = registry_ids.get(registry_key)
        source_domain_id = domain_ids.get(host)
        if registry_id is None or source_domain_id is None:
            continue
        prepared.append(
            {
                "registry_id": registry_id,
                "source_domain_id": source_domain_id,
                "host": host,
                "journal_title": entry["journal_title"],
                "raw_rank": entry.get("raw_rank"),
                "registry_size": entry.get("registry_size"),
                "raw_metric_name": entry.get("raw_metric_name"),
                "raw_metric_value": entry.get("raw_metric_value"),
                "normalized_percentile": entry.get("normalized_percentile"),
                "source_url": entry.get("source_url"),
            }
        )
    return prepared


class _SeedClient:
    def __init__(self, base_url: str, service_role_key: str) -> None:
        self._rest_base = f"{base_url.rstrip('/')}/rest/v1"
        self._functions_base = f"{base_url.rstrip('/')}/rest/v1/rpc"
        self._service_role_key = service_role_key

    @staticmethod
    def _split_table_name(table_name: str) -> tuple[str | None, str]:
        if "." not in table_name:
            return None, table_name
        schema, plain_name = table_name.split(".", 1)
        return schema, plain_name

    def upsert(self, table_name: str, rows: list[dict[str, Any]], on_conflict: str) -> None:
        if not rows:
            return
        schema, plain_table = self._split_table_name(table_name)
        query = parse.urlencode({"on_conflict": on_conflict})
        url = f"{self._rest_base}/{plain_table}?{query}"
        headers = {
            "apikey": self._service_role_key,
            "Authorization": f"Bearer {self._service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        if schema is not None:
            headers["Content-Profile"] = schema
        body = json.dumps(rows).encode("utf-8")
        req = request.Request(url, data=body, headers=headers, method="POST")
        with request.urlopen(req, timeout=60):
            return

    def select_id_map(
        self,
        table_name: str,
        key_field: str,
        values: list[str],
    ) -> list[dict[str, Any]]:
        schema, plain_table = self._split_table_name(table_name)
        encoded_values = ",".join(f'"{value}"' for value in values)
        query = parse.urlencode(
            {
                "select": f"id,{key_field}",
                key_field: f"in.({encoded_values})",
            }
        )
        url = f"{self._rest_base}/{plain_table}?{query}"
        headers = {
            "apikey": self._service_role_key,
            "Authorization": f"Bearer {self._service_role_key}",
        }
        if schema is not None:
            headers["Accept-Profile"] = schema
        req = request.Request(url, headers=headers, method="GET")
        with request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))

    def rpc(self, function_name: str, payload: dict[str, Any]) -> None:
        schema, plain_name = self._split_table_name(function_name)
        url = f"{self._functions_base}/{plain_name}"
        headers = {
            "apikey": self._service_role_key,
            "Authorization": f"Bearer {self._service_role_key}",
            "Content-Type": "application/json",
        }
        if schema is not None:
            headers["Content-Profile"] = schema
        req = request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        with request.urlopen(req, timeout=60):
            return


def seed_registry_catalog(
    *,
    apply_changes: bool,
    snapshot_path: str | None,
) -> None:
    catalog = build_initial_seed_catalog()
    extra_entries = load_registry_entry_snapshot(snapshot_path) if snapshot_path else []
    catalog["registry_entries"].extend(extra_entries)

    print(
        "Prepared seed catalog:",
        {
            "registries": len(catalog["registries"]),
            "domains": len(catalog["domains"]),
            "registry_entries": len(catalog["registry_entries"]),
            "apply": apply_changes,
        },
    )
    if not apply_changes:
        print("Dry run only. Re-run with --apply to write to Supabase.")
        return

    settings = get_settings()
    client = _SeedClient(settings.supabase_url, settings.supabase_service_role_key)

    try:
        for batch in _chunked(catalog["registries"]):
            client.upsert(
                "ai.source_registries",
                batch,
                on_conflict="registry_key",
            )

        for batch in _chunked(catalog["domains"]):
            client.upsert(
                "ai.trusted_source_domains",
                batch,
                on_conflict="host",
            )

        registry_ids = _fetch_id_map(
            client,
            "ai.source_registries",
            "registry_key",
            [str(row["registry_key"]) for row in catalog["registries"]],
        )
        domain_ids = _fetch_id_map(
            client,
            "ai.trusted_source_domains",
            "host",
            [str(row["host"]) for row in catalog["domains"]]
            + [str(row["host"]) for row in catalog["registry_entries"]],
        )
        prepared_entries = _prepare_registry_entries(
            catalog["registry_entries"],
            registry_ids,
            domain_ids,
        )
        for batch in _chunked(prepared_entries):
            client.upsert(
                "ai.source_registry_entries",
                batch,
                on_conflict="registry_id,host,journal_title",
            )

        client.rpc("ai.recompute_registry_consensus_scores", {})
    except HTTPError as exc:
        if exc.code == 406:
            raise RuntimeError(
                "The Supabase REST API is not exposing the 'ai' schema for this project. "
                "Use direct SQL seeding or expose the schema before re-running this script."
            ) from exc
        raise
    print("Seed applied successfully.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Seed the trusted source registry catalog into Supabase.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write the prepared seed catalog into Supabase.",
    )
    parser.add_argument(
        "--snapshot-json",
        default=None,
        help=(
            "Optional path to a JSON array of registry entries exported manually "
            "from OOIR, Research.com, PJIP, or other supported registries."
        ),
    )
    args = parser.parse_args()
    seed_registry_catalog(
        apply_changes=args.apply,
        snapshot_path=args.snapshot_json,
    )


if __name__ == "__main__":
    main()

"""Imports dog parks published as open data by Italian municipalities.

    uv run --with truststore python scripts/radar/import_municipal_dog_parks.py

Covers only the datasets whose license was verified (Bologna, Torino and
Milano, CC BY 4.0): see packages/infrastructure/radar_places/municipal_mapping.py.
Rows go to `radar_places_open` under one source per municipality, next to
the Overture rows and apart from OpenStreetMap.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
from typing import Any
from urllib.request import Request, urlopen

from common import (  # type: ignore[import-not-found]
    build_client,
    delete_rows_not_imported_at,
    load_excluded_ids,
    now_iso,
    save_source,
    upsert_rows,
)

from packages.infrastructure.radar_places.municipal_mapping import (  # noqa: E402
    MUNICIPAL_DATASETS,
    MunicipalDataset,
    municipal_records_to_places,
)
from packages.infrastructure.radar_places.overture_mapping import (  # noqa: E402
    place_to_open_row,
)

USER_AGENT = "VET-APP/1.0 (+https://vet-app-psi-nine.vercel.app; import periodico)"


def download(dataset: MunicipalDataset) -> list[dict[str, Any]]:
    request = Request(dataset.download_url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=60) as response:
        raw = response.read().decode("utf-8", errors="replace")
    if dataset.file_format == "csv":
        return list(csv.DictReader(io.StringIO(raw)))
    parsed = json.loads(raw)
    items = parsed.get("features", []) if dataset.file_format == "geojson" else parsed
    return [item for item in items if isinstance(item, dict)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="count only, write nothing")
    args = parser.parse_args()

    client = None if args.dry_run else build_client()
    imported_at = now_iso()
    for dataset in MUNICIPAL_DATASETS:
        records = download(dataset)
        excluded = load_excluded_ids(client, dataset.source) if client else frozenset()
        places = [
            place
            for place in municipal_records_to_places(dataset, records, release=imported_at[:10])
            if place.source_external_id not in excluded
        ]
        print(f"{dataset.city}: {len(records)} righe, {len(places)} aree cani")
        if client is None or not places:
            continue
        rows = [place_to_open_row(place, imported_at=imported_at) for place in places]
        upsert_rows(client, "radar_places_open", rows)
        # Parks the municipality no longer lists go away with this run.
        delete_rows_not_imported_at(client, "radar_places_open", imported_at, source=dataset.source)
        save_source(
            client,
            {
                "source": dataset.source,
                "release": imported_at[:10],
                "license": dataset.license,
                "attribution": dataset.attribution,
                "url": dataset.dataset_url,
                "place_count": len(rows),
                "imported_at": imported_at,
            },
        )
    if client is None:
        print("Dry run: nessuna scrittura.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

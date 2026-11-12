r"""Removes GPS and other metadata from images uploaded BEFORE the cleanup existed.

New uploads are already cleaned (app + server). This script cleans what was
stored earlier, using the very same cleaner the server uses
(packages/core/domain/conversation/media_privacy.py).

Dry run is the default and changes nothing:

    uv run --system-certs --with truststore python \
        scripts/maintenance/strip_existing_media_metadata.py

It downloads every image, applies the cleaner in memory and reports how many
files there are, how many carry metadata and how many carry a GPS position.
When the numbers look right, run it for real:

    uv run --system-certs --with truststore python \
        scripts/maintenance/strip_existing_media_metadata.py --apply

What it does with --apply, per image: cleans it, checks that the result is a
complete image of the same kind and carries no GPS, and only then overwrites
the object. A file whose cleaning cannot be verified is left exactly as it was
and counted as "non verificabile". Videos are never touched; PDFs only with
--include-pdf. It can be interrupted and rerun: finished objects are
remembered (as hashes, in .local/, which git ignores) and skipped.

Needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the local .env. Nothing is
sent anywhere but your own Supabase project; the output carries counts and
short hashes only, never names or paths.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "radar"))

from common import (  # type: ignore[import-not-found]  # noqa: E402
    ROOT_DIR,
    build_client,
    explain_certificate_error,
)

from packages.infrastructure.documents.pypdf_reader import PypdfReader  # noqa: E402
from packages.infrastructure.storage.media_metadata_cleanup import (  # noqa: E402
    DEFAULT_MAX_BYTES,
    BucketReport,
    CleanupState,
    SupabaseBucketStorage,
    process_bucket,
)

DEFAULT_STATE_FILE = ROOT_DIR / ".local" / "maintenance" / "strip_media_state.json"
PET_PHOTOS_BUCKET = "pet-photos"


def _default_buckets() -> list[str]:
    chat_bucket = os.environ.get("MEDIA_STORAGE_BUCKET", "").strip() or "chat-attachments"
    return [PET_PHOTOS_BUCKET, chat_bucket]


def _print_report(report: BucketReport, *, apply: bool) -> None:
    print(f"\n[{report.bucket}]")
    print(f"  oggetti trovati:            {report.objects}")
    if report.already_done:
        print(f"  già a posto (esecuzione precedente): {report.already_done}")
    print(f"  immagini analizzate:        {report.images}")
    print(f"  immagini con metadati:      {report.images_with_metadata}")
    print(f"  immagini con posizione GPS: {report.images_with_gps}")
    if apply:
        print(f"  immagini ripulite:          {report.images_cleaned}")
    if report.images_unsafe:
        print(f"  immagini NON verificabili (lasciate com'erano): {report.images_unsafe}")
    print(f"  PDF:                        {report.pdfs}", end="")
    if report.pdfs_with_metadata or report.pdfs_cleaned:
        print(f"  (con metadati: {report.pdfs_with_metadata}, ripuliti: {report.pdfs_cleaned})")
    else:
        print("  (non toccati)")
    print(f"  video saltati:              {report.videos_skipped}")
    if report.too_big_skipped:
        print(f"  file troppo grandi saltati: {report.too_big_skipped}")
    print(f"  altri file:                 {report.other}")
    print(f"  errori:                     {report.errors}")
    for problem in report.problems[:20]:
        print(f"    - {problem}")
    if len(report.problems) > 20:
        print(f"    ... e altri {len(report.problems) - 20}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--apply",
        action="store_true",
        help="riscrive davvero i file ripuliti (senza questa opzione: solo conteggio)",
    )
    parser.add_argument(
        "--bucket",
        action="append",
        help=f"bucket da esaminare (ripetibile); default: {', '.join(_default_buckets())}",
    )
    parser.add_argument(
        "--include-pdf",
        action="store_true",
        help="ripulisce anche autore/software dei PDF (default: i PDF non si toccano)",
    )
    parser.add_argument("--limit", type=int, help="esamina al massimo N file per bucket (prova)")
    parser.add_argument(
        "--max-mb",
        type=int,
        default=DEFAULT_MAX_BYTES // 1_000_000,
        help="salta i file più grandi di questi MB (default %(default)s)",
    )
    parser.add_argument(
        "--state-file",
        type=Path,
        default=DEFAULT_STATE_FILE,
        help="dove ricordare i file già ripuliti, per riprendere (solo con --apply)",
    )
    args = parser.parse_args()

    buckets = args.bucket or _default_buckets()
    client = build_client()
    state = CleanupState(args.state_file if args.apply else None)
    mode = "APPLY (riscrive i file)" if args.apply else "DRY RUN (non modifica nulla)"
    print(f"Modalità: {mode}")
    if args.apply and len(state):
        print(f"Ripresa: {len(state)} oggetti già a posto da un'esecuzione precedente.")

    exit_code = 0
    pdf_cleaner = PypdfReader().strip_metadata
    for bucket in buckets:
        print(f"\nEsamino il bucket '{bucket}'...", flush=True)
        try:
            report = process_bucket(
                SupabaseBucketStorage(client, bucket),
                bucket,
                apply=args.apply,
                state=state,
                include_pdf=args.include_pdf,
                pdf_cleaner=pdf_cleaner,
                max_bytes=args.max_mb * 1_000_000,
                limit=args.limit,
                progress=lambda r: print(
                    f"  ... {r.objects} oggetti, {r.images} immagini, {r.images_with_gps} con GPS",
                    flush=True,
                ),
            )
        except Exception as exc:
            explain_certificate_error(exc)
            print(f"Bucket '{bucket}' non esaminabile: {type(exc).__name__}", file=sys.stderr)
            exit_code = 1
            continue
        _print_report(report, apply=args.apply)
        if report.needs_attention:
            exit_code = 1

    if not args.apply:
        print("\nNessuna modifica fatta. Per ripulire davvero rilancia con --apply.")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

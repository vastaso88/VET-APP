r"""Copies the photos of ads published BEFORE K23 to where no account can write.

New ads are already copied by the backend. Until this has run, other people do not see the
photos of the older ones (their sellers still do).

Dry run is the default and changes nothing; it prints counts only:

    uv run --system-certs --with truststore python \
        scripts/maintenance/publish_marketplace_photos.py

When the numbers look right, run it for real:

    uv run --system-certs --with truststore python \
        scripts/maintenance/publish_marketplace_photos.py --apply

With --apply, one ad at a time: every photo is copied (JPEG checked, metadata removed) to
published/<ad>/, the row and its checks point to the copies, and only then the originals are
deleted. If a photo of an ad is missing or is not a whole JPEG that ad is left exactly as it was
and counted. Links to other sites are dropped from the rows it changes. It can be
interrupted and rerun: the next run completes what the first left half-way.

Run it AFTER marketplace_content_review.sql and marketplace_published_photos.sql, and just
BEFORE the deploy (the version in production shows the copies as well).

Needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the local .env. Nothing is sent anywhere
but your own Supabase project; the output carries counts only.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "radar"))

from common import (  # type: ignore[import-not-found]  # noqa: E402
    build_client,
    explain_certificate_error,
)

from packages.core.application.services.listing_photos import (  # noqa: E402
    ExistingPhotosOutput,
    PublishExistingPhotosService,
)
from packages.core.domain.marketplace.photos import photo_base  # noqa: E402
from packages.infrastructure.persistence.supabase.supabase_listing_reviews import (  # noqa: E402
    SupabaseListingReviewRepository,
)
from packages.infrastructure.persistence.supabase.supabase_repositories import (  # noqa: E402
    SupabaseMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import (  # noqa: E402
    SupabaseListingPhotoVault,
)


def report(output: ExistingPhotosOutput, *, applied: bool) -> str:
    lines = [
        f"Annunci esaminati: {output.listings}",
        f"Annunci con foto da copiare: {output.to_publish} ({output.photos} foto)",
        f"Collegamenti ad altri siti o di altri (mai mostrati): {output.other_links}",
    ]
    if applied:
        lines.append(f"Annunci copiati: {output.published}")
        lines.append(f"Annunci lasciati com'erano (foto mancante o non valida): {output.failed}")
    else:
        lines.append("Prova: nessuna modifica. Per copiare davvero aggiungi --apply.")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apply", action="store_true", help="copia davvero (altrimenti conta)")
    args = parser.parse_args(argv)
    client = build_client()
    service = PublishExistingPhotosService(
        SupabaseMarketplaceListingRepository(client),
        SupabaseListingReviewRepository(client),
        SupabaseListingPhotoVault(client, photo_base(os.environ["SUPABASE_URL"])),
    )
    try:
        output = service.run(apply=args.apply)
    except Exception as exc:
        explain_certificate_error(exc)
        print(f"Interrotto: {type(exc).__name__}. Si puo' rilanciare.", file=sys.stderr)
        return 1
    print(report(output, applied=args.apply))
    return 1 if output.failed else 0


if __name__ == "__main__":
    sys.exit(main())

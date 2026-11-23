"""The policies of the published photos, read as text. They are executed for real in
tests/sql/marketplace_published_photos.mjs (CI)."""

from pathlib import Path

from packages.core.domain.marketplace.photos import PHOTO_BUCKET, PUBLISHED
from packages.infrastructure.storage.listing_photo_vaults import HELD_BUCKET

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/setup/marketplace_published_photos.sql"


def _sql() -> str:
    return SCRIPT.read_text(encoding="utf-8").replace("\r\n", "\n")


def test_no_account_writes_among_the_copies_whatever_other_policy_there_is() -> None:
    for action in ("insert", "update", "delete"):
        name = f"marketplace_photos_published_{action}"
        assert f"drop policy if exists {name} on storage.objects;" in _sql()
        assert f"create policy {name} on storage.objects\nas restrictive for {action}" in _sql()
    for name in (PHOTO_BUCKET, HELD_BUCKET, PUBLISHED):
        assert f"is distinct from '{name}'" in _sql()


def test_the_schema_and_the_twin_install_the_same_script() -> None:
    schema = (ROOT / "scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    assert _sql().strip() in schema.replace("\r\n", "\n")
    twin = (ROOT / "scripts/collaudo/gemello.py").read_text(encoding="utf-8")
    assert twin.index("marketplace_hidden_ads.sql") < twin.index("marketplace_published_photos.sql")

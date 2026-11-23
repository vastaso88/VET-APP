"""The SQL of the ads hidden or taken down after reports, read as text. It is executed
for real in tests/sql/marketplace_hidden_ads.mjs (CI)."""

from pathlib import Path
from typing import get_args

from packages.core.domain.marketplace.content_review import RemovalReason, ReviewOrigin
from packages.core.domain.marketplace.models import ListingReportReason

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/setup/marketplace_hidden_ads.sql"


def _sql() -> str:
    return SCRIPT.read_text(encoding="utf-8").replace("\r\n", "\n")


def test_the_reasons_of_the_database_are_those_of_the_backend() -> None:
    for reason in get_args(RemovalReason):
        assert _sql().count(f"'{reason}'") >= 2, reason
    for origin in get_args(ReviewOrigin):
        assert f"'{origin}'" in _sql()
    assert set(get_args(ListingReportReason)) <= set(get_args(RemovalReason))


def test_reports_only_hide_a_visible_ad() -> None:
    assert "status in ('active', 'reserved') then 'removed'" in _sql()


def test_the_schema_and_the_twin_install_the_same_script_last() -> None:
    schema = (ROOT / "scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    schema = schema.replace("\r\n", "\n")
    assert _sql().strip() in schema
    # The last definition of the trigger function is the one that stays.
    last = schema.rindex("create or replace function public.handle_marketplace_listing_report")
    assert "status in ('active', 'reserved')" in schema[last:]

    twin = (ROOT / "scripts/collaudo/gemello.py").read_text(encoding="utf-8")
    assert twin.index("marketplace_content_review.sql") < twin.index("marketplace_hidden_ads.sql")

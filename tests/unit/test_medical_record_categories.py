"""The cartella clinica's categories exist twice: in the app (what the owner
picks and what is stored) and in the backend (what the chat is told). These
tests keep the two lists from drifting apart, and the schema script in step
with what both read."""

import re
from pathlib import Path

from packages.core.domain.medical_record.models import (
    CATEGORY_LABELS_IT,
    SUBTYPE_LABELS_IT,
    ClinicalEvent,
)

_ROOT = Path(__file__).resolve().parents[2]
_DART = _ROOT / "apps/mobile_app/lib/features/medical_records/domain/record_category.dart"
_SCHEMA = _ROOT / "scripts/setup/supabase_schema.sql"


def test_the_app_and_the_backend_know_the_same_categories() -> None:
    source = _DART.read_text(encoding="utf-8")
    enum_body = re.search(r"enum RecordCategory \{(.*?);", source, re.DOTALL)
    assert enum_body is not None
    app_categories = re.findall(r"\b([a-z]+)\b", enum_body.group(1))

    assert set(app_categories) == set(CATEGORY_LABELS_IT)


def test_every_type_the_app_offers_has_a_label_for_the_chat() -> None:
    source = _DART.read_text(encoding="utf-8")
    subtypes_body = source.split("List<String> get subtypes", 1)[1].split("};", 1)[0]
    app_subtypes = set(re.findall(r"'([a-z_]+)'", subtypes_body))

    assert app_subtypes
    assert app_subtypes <= set(SUBTYPE_LABELS_IT)


def test_a_row_without_a_category_is_read_as_a_row_without_one() -> None:
    event = ClinicalEvent(pet_id="pet-1", title="Vecchio referto")

    assert event.category_label is None
    assert event.subtype_label is None


def test_an_unknown_category_is_read_as_a_document() -> None:
    event = ClinicalEvent(pet_id="pet-1", category="from-the-future", subtype="new-kind")

    assert event.category_label == "documento"
    # An unknown type is passed on as written rather than dropped.
    assert event.subtype_label == "new-kind"


def test_the_schema_gives_every_existing_row_a_category_and_protects_conditions() -> None:
    schema = _SCHEMA.read_text(encoding="utf-8")

    assert "add column if not exists category text" in schema
    assert "alter column category set default 'document'" in schema
    assert "create table if not exists public.pet_conditions" in schema
    assert "alter table public.pet_conditions enable row level security" in schema
    for action in ("select", "insert", "update", "delete"):
        assert f"create policy pet_conditions_{action}_own" in schema

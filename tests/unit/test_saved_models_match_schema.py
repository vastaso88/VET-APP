"""Every model a Supabase repository saves whole has a column for each field.

A repository that upserts ``model.model_dump()`` sends every field of the
model: a field without a column in the live table fails the whole write
(PGRST204). On 2026-11-16 the chat lost every answer in production because
``Conversation.awaiting_anamnesis`` and ``escalate_next_health`` were in the
model and in no SQL script. This test reads the columns the scripts in
``scripts/setup/`` declare (``create table`` and ``alter table ... add column``,
with the parser of ``check_schema.py``) and compares them with the fields.

A new field: add its column to ``supabase_schema.sql`` (or the feature's
script) in the same change. A new repository that saves a whole model: add it
to ``SAVED_MODELS`` (the last test finds the ones missing).
"""

from __future__ import annotations

import ast
import importlib.util
import re
import sys
from pathlib import Path
from types import ModuleType

import pytest
from pydantic import BaseModel

from packages.core.application.ports.answer_cache_repository import CachedAnswer
from packages.core.domain.consent.models import AccountConsents
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.coverage.models import RadarCoverage
from packages.core.domain.device.models import UserDevice
from packages.core.domain.dog_walk.models import WalkSession
from packages.core.domain.events.submission import EventSubmission
from packages.core.domain.feedback.models import ChatResponseReport
from packages.core.domain.marketplace.messaging import (
    MarketplaceConversation,
    MarketplaceConversationReport,
    MarketplaceMessage,
    MarketplaceRestriction,
    MarketplaceUserBlock,
    ModerationAccess,
)
from packages.core.domain.marketplace.models import ListingReport
from packages.core.domain.pet_news.models import PetNewsSnapshot
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.radar_places.competences import RadarCompetenceClaim
from packages.core.domain.radar_reports.models import (
    RadarPlaceOverride,
    RadarPlaceRating,
    RadarReportVote,
    RadarUserReport,
)
from packages.core.domain.reminders.models import Reminder

ROOT = Path(__file__).resolve().parents[2]
SETUP = ROOT / "scripts" / "setup"
SUPABASE_REPOSITORIES = ROOT / "packages" / "infrastructure" / "persistence" / "supabase"


def _check_schema() -> ModuleType:
    spec = importlib.util.spec_from_file_location("check_schema", SETUP / "check_schema.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules.setdefault("check_schema", module)
    spec.loader.exec_module(module)
    return module


check_schema = _check_schema()


def declared_columns(sql: str) -> dict[str, set[str]]:
    schema = check_schema.parse_declared_schema(sql)
    return {table: set(columns) for table, columns in schema.tables.items()}


def all_setup_sql() -> str:
    return "\n".join(path.read_text(encoding="utf-8") for path in sorted(SETUP.glob("*.sql")))


# (file, "Class.method") -> (model, table, keys the repository adds itself).
SAVED_MODELS: dict[tuple[str, str], tuple[type[BaseModel], str, frozenset[str]]] = {
    ("supabase_repositories.py", "SupabasePetProfileRepository.save"): (
        PetProfile,
        "pet_profiles",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseConversationRepository.save"): (
        Conversation,
        "conversations",
        frozenset({"last_message_at"}),
    ),
    ("supabase_repositories.py", "SupabaseReminderRepository.save"): (
        Reminder,
        "reminders",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseAccountConsentsRepository.save"): (
        AccountConsents,
        "account_consents",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseUserDeviceRepository.save"): (
        UserDevice,
        "user_devices",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseRadarPlacesRepository.replace_coverage"): (
        RadarCoverage,
        "radar_coverage_cells",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseRadarReportsRepository.save_report"): (
        RadarUserReport,
        "radar_user_reports",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseRadarReportsRepository.save_vote"): (
        RadarReportVote,
        "radar_report_votes",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseRadarReportsRepository.save_rating"): (
        RadarPlaceRating,
        "radar_place_ratings",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseRadarReportsRepository.save_override"): (
        RadarPlaceOverride,
        "radar_place_overrides",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseRadarReportsRepository.save_claim"): (
        RadarCompetenceClaim,
        "radar_competence_claims",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseDogWalkRepository.save"): (
        WalkSession,
        "dog_walks",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseListingReportRepository.save"): (
        ListingReport,
        "marketplace_listing_reports",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseChatResponseReportRepository.save"): (
        ChatResponseReport,
        "chat_response_reports",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseChatAttachmentRepository.save"): (
        ChatAttachment,
        "chat_attachments",
        frozenset(),
    ),
    ("supabase_repositories.py", "SupabaseAnswerCacheRepository.put"): (
        CachedAnswer,
        "chat_answer_cache",
        frozenset(),
    ),
    ("supabase_event_submissions.py", "SupabaseEventSubmissionRepository.add"): (
        EventSubmission,
        "event_submissions",
        frozenset(),
    ),
    ("supabase_event_submissions.py", "SupabaseEventSubmissionRepository.save"): (
        EventSubmission,
        "event_submissions",
        frozenset(),
    ),
    ("supabase_pet_news.py", "SupabasePetNewsCacheRepository.put"): (
        PetNewsSnapshot,
        "pet_news_snapshots",
        frozenset(),
    ),
    (
        "supabase_marketplace_messaging.py",
        "SupabaseMarketplaceMessagingRepository.create_conversation",
    ): (MarketplaceConversation, "marketplace_conversations", frozenset()),
    ("supabase_marketplace_messaging.py", "SupabaseMarketplaceMessagingRepository.add_message"): (
        MarketplaceMessage,
        "marketplace_messages",
        frozenset(),
    ),
    ("supabase_marketplace_messaging.py", "SupabaseMarketplaceMessagingRepository.add_block"): (
        MarketplaceUserBlock,
        "marketplace_user_blocks",
        frozenset(),
    ),
    ("supabase_marketplace_messaging.py", "SupabaseMarketplaceMessagingRepository.save_report"): (
        MarketplaceConversationReport,
        "marketplace_conversation_reports",
        frozenset(),
    ),
    (
        "supabase_marketplace_messaging.py",
        "SupabaseMarketplaceMessagingRepository.save_restriction",
    ): (MarketplaceRestriction, "marketplace_user_restrictions", frozenset()),
    (
        "supabase_marketplace_messaging.py",
        "SupabaseMarketplaceMessagingRepository.log_moderation_access",
    ): (ModerationAccess, "marketplace_moderation_access_log", frozenset()),
}


def saved_keys(model: type[BaseModel]) -> set[str]:
    return set(model.model_fields) | set(model.model_computed_fields)


@pytest.mark.parametrize(
    ("model", "table", "extra"),
    list(SAVED_MODELS.values()),
    ids=[f"{name}->{spec[1]}" for (_, name), spec in SAVED_MODELS.items()],
)
def test_every_saved_field_has_a_declared_column(
    model: type[BaseModel], table: str, extra: frozenset[str]
) -> None:
    columns = declared_columns(all_setup_sql())
    assert table in columns, f"no script in scripts/setup/ creates public.{table}"
    missing = sorted((saved_keys(model) | extra) - columns[table])
    assert not missing, (
        f"{model.__name__} is saved whole into public.{table}, but no script in "
        f"scripts/setup/ declares these columns: {missing}. Add them (alter table "
        f"public.{table} add column if not exists ...) in the same change."
    )


def test_the_check_would_have_caught_the_production_failure_of_2026_11_16() -> None:
    without_the_fix = re.sub(
        r"alter table public\.conversations\s+add column if not exists "
        r"(?:awaiting_anamnesis|escalate_next_health)[^;]*;",
        "",
        (SETUP / "supabase_schema.sql").read_text(encoding="utf-8"),
    )
    columns = declared_columns(without_the_fix)["conversations"]
    assert {"awaiting_anamnesis", "escalate_next_health"} <= saved_keys(Conversation) - columns


def _whole_model_saves(path: Path) -> set[str]:
    """`Class.method` of every method that sends `x.model_dump(mode="json")`
    with nothing excluded."""
    source = path.read_text(encoding="utf-8")
    found: set[str] = set()
    for node in ast.parse(source).body:
        if not isinstance(node, ast.ClassDef):
            continue
        for method in node.body:
            if not isinstance(method, ast.FunctionDef):
                continue
            for call in ast.walk(method):
                if (
                    isinstance(call, ast.Call)
                    and isinstance(call.func, ast.Attribute)
                    and call.func.attr == "model_dump"
                    and not any(k.arg in ("exclude", "include") for k in call.keywords)
                ):
                    found.add(f"{node.name}.{method.name}")
    return found


def test_every_whole_model_save_is_in_the_list() -> None:
    found = {
        (path.name, name)
        for path in SUPABASE_REPOSITORIES.glob("*.py")
        for name in _whole_model_saves(path)
    }
    unknown = sorted(found - set(SAVED_MODELS))
    assert not unknown, (
        f"these Supabase repositories save a whole model: add them to SAVED_MODELS "
        f"with their table: {unknown}"
    )

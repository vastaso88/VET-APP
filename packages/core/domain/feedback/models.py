from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now

ChatResponseReportReason = Literal["no_answer", "wrong_answer", "incomplete_answer", "other"]
ChatResponseReportStatus = Literal["reported", "under_review", "resolved", "wont_fix"]


class ChatResponseReport(BaseModel):
    """An owner's report that a specific chat reply was missing, limited,
    or wrong ("segnala questa risposta") — feeds the same real-usage bug
    pipeline this app's own engineering already uses for stress testing,
    just sourced from real users instead.

    `reported_answer` snapshots the message content at report time rather
    than only storing `message_id`: a conversation's messages aren't
    editable today, but a snapshot is what survives if that ever changes,
    and it means a report is self-contained for review without needing to
    re-join the conversation.
    """

    id: str = Field(default_factory=new_id)
    conversation_id: str
    message_id: str
    pet_id: str
    reporter_ref: str | None = None
    """Pseudonym of who reported (see pseudonym.reporter_ref): a keyed
    hash of the owner id, never the id itself. Enough to deduplicate and
    to find a person's reports when they ask for erasure, without the
    table saying who they are (docs/compliance/07_contributi_utenti.md)."""
    reporter_owner_id: str | None = None
    """Legacy: rows written before 2026-10-03 stored the owner id in the
    clear. Never written any more; the maintenance job converts such rows
    to `reporter_ref` and blanks this."""
    reason: ChatResponseReportReason = "other"
    details: str | None = None
    reported_answer: str
    status: ChatResponseReportStatus = "reported"
    created_at: datetime = Field(default_factory=utc_now)
    resolved_at: datetime | None = None
    resolution_note: str | None = None
    credited_bug_ref: str | None = None
    """Set only once this report is confirmed linked to an actual shipped
    fix (e.g. a commit hash) — null means "not yet credited". The reward
    mechanics (a free week per resolved bug, human-reviewed, capped
    monthly per user — see docs/marketing/01_brainstorm.md) can't be
    wired to real billing yet (no subscription backend exists today, only
    a local Flutter demo store), so this field exists now precisely so
    that whenever billing does exist, crediting is just "find reports with
    this set and not yet paid out" instead of a schema change."""


class ChatResponseReportCounter(BaseModel):
    """What is left of reports past their retention: how many there were,
    per month/reason/outcome — no text, no conversation, no reporter."""

    period: str
    """Month the reports were created in, as YYYY-MM."""
    reason: str
    status: str
    total: int = 0

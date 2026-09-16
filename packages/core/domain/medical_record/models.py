from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now


class ClinicalEvent(BaseModel):
    """A single clinical document/note for a pet (spec v3 §18).

    Mirrors the fields the Flutter medical_records feature already writes to
    Supabase's `clinical_events` table — this is a summary of a document
    (a vaccination record, a blood-test report, a follow-up note), not the
    document's full content: only enough to give the chat useful context
    without ingesting an entire clinical file.
    """

    id: str = Field(default_factory=new_id)
    pet_id: str
    title: str
    subtitle: str | None = None
    meta: str | None = None
    badge: str | None = None
    detail_source: str | None = None
    created_at: datetime = Field(default_factory=utc_now)

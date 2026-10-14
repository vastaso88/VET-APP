from datetime import UTC, date, datetime

from pydantic import BaseModel, Field, field_validator

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.consent.models import ConsentRecord

# The categories of the cartella clinica (spec: "Cartella clinica per
# categorie"), as stored in `clinical_events.category`. Rows written before
# the categories existed have none and count as documents.
CATEGORY_VISIT = "visit"
CATEGORY_EXAM = "exam"
CATEGORY_VACCINE = "vaccine"
CATEGORY_THERAPY = "therapy"
CATEGORY_DOCUMENT = "document"

CATEGORY_LABELS_IT = {
    CATEGORY_VISIT: "visita",
    CATEGORY_EXAM: "esame",
    CATEGORY_VACCINE: "vaccino",
    CATEGORY_THERAPY: "terapia",
    CATEGORY_DOCUMENT: "documento",
}

# The finer type the owner can pick for a visit, an exam or a therapy. Keys
# are what the app stores (lib/features/medical_records/domain/record_category.dart);
# an unknown key is read back as written rather than dropped.
SUBTYPE_LABELS_IT = {
    "checkup": "visita di controllo",
    "specialist": "visita specialistica",
    "first_visit": "prima visita",
    "emergency": "urgenza",
    "post_surgery": "controllo post-operatorio",
    "blood": "analisi del sangue",
    "urine": "esame delle urine",
    "stool": "esame delle feci",
    "xray": "radiografia",
    "ultrasound": "ecografia",
    "antiparasitic": "antiparassitario",
    "medication": "farmaco",
    "other": "altro",
}


class ClinicalEvent(BaseModel):
    """A single clinical document/note for a pet (spec v3 §18).

    Mirrors the fields the Flutter medical_records feature already writes to
    Supabase's `clinical_events` table — this is a summary of a document
    (a vaccination record, a blood-test report, a follow-up note), not the
    document's full content: only enough to give the chat useful context
    without ingesting an entire clinical file.

    Read straight from live rows (`select *`), so it has to accept the
    table as it really is: the live `clinical_events` predates this
    project's schema script (found 2026-10-04) and carries its own columns
    (`event_type`, `event_date`, `summary`, `severity`, `source`,
    `linked_document_id`, `owner_id`) while the app's display columns
    (`subtitle`, `meta`, `badge`, `detail_source`) may be absent or null.
    Unknown columns are ignored; everything but `pet_id` is optional.
    """

    id: str = Field(default_factory=new_id)
    pet_id: str
    title: str = ""
    subtitle: str | None = None
    meta: str | None = None
    badge: str | None = None
    detail_source: str | None = None
    # Id of the uploaded file in the chat-attachments pipeline, when the
    # record has one — its cached text summary (ChatAttachment.analysis)
    # is what lets the chat know what the document actually says.
    attachment_id: str | None = None
    # When the clinical event happened (as opposed to when the row was
    # written): what "recent first" should mean when it is known.
    event_date: date | None = None
    event_type: str | None = None
    summary: str | None = None
    # visit / exam / vaccine / therapy / document; None on rows older than
    # the categories, read as "document".
    category: str | None = None
    subtype: str | None = None
    # The owner's own notes. Never sent to the chat.
    notes: str | None = None
    created_at: datetime = Field(default_factory=utc_now)

    @field_validator("title", mode="before")
    @classmethod
    def _title_or_empty(cls, value: object) -> object:
        return "" if value is None else value

    @field_validator("created_at", mode="before")
    @classmethod
    def _created_at_or_oldest(cls, value: object) -> object:
        # A row without a timestamp sorts as the oldest rather than
        # failing the whole pet's record.
        return datetime.min.replace(tzinfo=UTC) if value is None else value

    @field_validator("created_at", mode="after")
    @classmethod
    def _created_at_is_aware(cls, value: datetime) -> datetime:
        # Rows mix `timestamptz` and text timestamps: comparing an aware
        # with a naive datetime raises, so naive ones are read as UTC.
        return value if value.tzinfo else value.replace(tzinfo=UTC)

    @property
    def occurred_on(self) -> date:
        return self.event_date or self.created_at.date()

    @property
    def category_label(self) -> str | None:
        """ "esame", "visita"...; None for a row that predates the categories."""
        if not self.category:
            return None
        return CATEGORY_LABELS_IT.get(self.category, CATEGORY_LABELS_IT[CATEGORY_DOCUMENT])

    @property
    def subtype_label(self) -> str | None:
        if not self.subtype:
            return None
        return SUBTYPE_LABELS_IT.get(self.subtype, self.subtype)


CONDITION_ONGOING = "ongoing"
CONDITION_RESOLVED = "resolved"


class PetCondition(BaseModel):
    """A past or current illness of a pet ("Patologie" in the cartella).

    Only the name, the start date and the status ever reach the chat, and
    only for conditions still ongoing; the therapy and the notes are the
    owner's own and stay in the app.
    """

    id: str = Field(default_factory=new_id)
    pet_id: str
    name: str = ""
    started_on: date | None = None
    status: str = CONDITION_ONGOING
    ended_on: date | None = None
    therapy: str | None = None
    notes: str | None = None
    attachment_id: str | None = None
    created_at: datetime = Field(default_factory=utc_now)

    @field_validator("name", mode="before")
    @classmethod
    def _name_or_empty(cls, value: object) -> object:
        return "" if value is None else value

    @field_validator("status", mode="before")
    @classmethod
    def _status_or_ongoing(cls, value: object) -> object:
        return value if value in (CONDITION_ONGOING, CONDITION_RESOLVED) else CONDITION_ONGOING

    @field_validator("created_at", mode="before")
    @classmethod
    def _created_at_or_oldest(cls, value: object) -> object:
        return datetime.min.replace(tzinfo=UTC) if value is None else value

    @field_validator("created_at", mode="after")
    @classmethod
    def _created_at_is_aware(cls, value: datetime) -> datetime:
        return value if value.tzinfo else value.replace(tzinfo=UTC)

    @property
    def is_ongoing(self) -> bool:
        return self.status == CONDITION_ONGOING


class MedicalRecordConsentRecord(ConsentRecord):
    """The owner's decision on whether the chat may consult a pet's
    clinical record (spec v3 §18, §36) — persisted per pet, not per
    conversation, so it is asked once and revocable at any time (e.g.
    from account settings) rather than re-asked on every new chat.

    A `ConsentRecord` (packages/core/domain/consent/models.py) — the shared
    {granted, version, decided_at} shape also used for account-level
    consents (ToS, privacy, marketing, analytics). `version` pins the exact
    consent text the owner agreed to (or declined), so a future change to
    that text doesn't silently reinterpret a decision made under different
    wording — see packages/core/domain/medical_record/consent_text.py.
    """

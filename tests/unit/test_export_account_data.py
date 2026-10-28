"""Data export (GDPR art. 15/20): everything of the owner, nothing of anyone
else, aligned with what the account deletion erases."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from test_delete_account import (
    CHAT_SECRET,
    MEDIA_BUCKET,
    RADAR_KEY,
    FakeSupabase,
    _seed,
)

from packages.core.application.services.export_account_data import (
    ExportAccountDataInput,
    ExportAccountDataService,
)
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder
from packages.infrastructure.persistence.in_memory_account_exporter import (
    InMemoryAccountExporter,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryDogWalkRepository,
    InMemoryMarketplaceListingRepository,
    InMemoryPetConditionRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
    InMemoryUserLocationRepository,
)
from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
    CHAT_REPORT_REF,
    HANDLED_ELSEWHERE,
    OWNER_TABLES,
    RADAR_PSEUDONYM_TABLES,
)
from packages.infrastructure.persistence.supabase.supabase_account_exporter import (
    EXPORTED_TABLES,
    SIGNED_URL_SECONDS,
    SupabaseAccountExporter,
)

OWNER_A = "11111111-1111-4111-8111-111111111111"
OWNER_B = "22222222-2222-4222-8222-222222222222"


class _SigningFake(FakeSupabase):
    """The eraser's fake plus the two calls the export needs."""

    def __init__(self) -> None:
        super().__init__()
        self.signed: list[tuple[str, str, int]] = []
        storage = self.storage
        fake = self

        class _Bucket:
            def __init__(self, name: str) -> None:
                self._name = name
                self._inner = storage.from_(name)

            def list(self, prefix: str, options: dict[str, int] | None = None) -> Any:
                return self._inner.list(prefix, options)

            def create_signed_url(self, path: str, expires_in: int) -> dict[str, str]:
                fake.signed.append((self._name, path, expires_in))
                return {"signedURL": f"https://files.example/{self._name}/{path}?token=x"}

        class _Storage:
            def from_(self, name: str) -> _Bucket:
                return _Bucket(name)

        self.storage = _Storage()  # type: ignore[assignment]

        class _User:
            email = "a@example.com"
            email_confirmed_at = datetime(2026, 1, 1, tzinfo=UTC)
            created_at = datetime(2026, 1, 1, tzinfo=UTC)
            last_sign_in_at = None
            user_metadata = {"display_name": "Anna", "phone": "+39 333 0000000"}

        class _Response:
            user = _User()

        self.auth.admin.get_user_by_id = lambda _id: _Response()  # type: ignore[attr-defined]


def _exporter(client: FakeSupabase) -> SupabaseAccountExporter:
    return SupabaseAccountExporter(
        client,  # type: ignore[arg-type]
        media_bucket=MEDIA_BUCKET,
        chat_reporter_secret=CHAT_SECRET,
        radar_pseudonym_key=RADAR_KEY,
    )


def test_export_covers_every_table_the_deletion_erases() -> None:
    erased = (
        {table for table, _ in OWNER_TABLES}
        | {table for table, _ in RADAR_PSEUDONYM_TABLES}
        | {CHAT_REPORT_REF[0]}
        | set(HANDLED_ELSEWHERE)
    )
    assert EXPORTED_TABLES == erased


def test_export_returns_only_the_owners_rows_and_signed_links() -> None:
    client = _SigningFake()
    _seed(client, OWNER_A, tag="a")
    _seed(client, OWNER_B, tag="b")

    export = _exporter(client).export_data(OWNER_A)

    assert set(export.data) == EXPORTED_TABLES
    flat = [row for rows in export.data.values() for row in rows]
    assert flat, "the seeded rows were expected in the export"
    assert all(str(row.get("id", "")).startswith("a-") for row in flat)
    assert not any("b-" in str(row) for row in flat), "another owner's data leaked"
    # pseudonymous radar rows and keyed chat reports are included, their
    # internal keys stripped
    assert export.data["radar_user_reports"] and export.data["chat_response_reports"]
    assert all("reporter_pseudonym" not in row for row in export.data["radar_user_reports"])
    assert all("reporter_ref" not in row for row in export.data["chat_response_reports"])
    # clinical events hang off the owner's pets
    assert [row["id"] for row in export.data["clinical_events"]] == ["a-event"]
    # files: the attachment key, the gallery row path and the profile photo
    kinds = {(f.kind, f.bucket) for f in export.files}
    assert ("chat_attachment", MEDIA_BUCKET) in kinds
    assert ("profile_photo", "pet-photos") in kinds
    assert all(f.url and f.url_expires_at for f in export.files)
    assert all(expires == SIGNED_URL_SECONDS for _, _, expires in client.signed)
    assert not any(OWNER_B in path for _, path, _ in client.signed)
    # identity fields from the provider
    assert export.account["profile"]["phone"] == "+39 333 0000000"
    assert export.account["email"] == "a@example.com"


def test_export_refuses_a_non_uuid_owner() -> None:
    with pytest.raises(ValueError):
        _exporter(_SigningFake()).export_data("")


def test_service_merges_token_identity_without_overriding_the_provider() -> None:
    client = _SigningFake()
    _seed(client, OWNER_A, tag="a")
    service = ExportAccountDataService(_exporter(client))

    export = service.execute(
        ExportAccountDataInput(owner_id=OWNER_A, email="token@example.com", display_name="T")
    )

    assert export.account["email"] == "a@example.com"
    assert export.account["id"] == OWNER_A
    assert export.format_version == "1"


def test_in_memory_export_isolates_owners() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    pets.save(PetProfile(id="pet-b", owner_id="owner-b", name="Rex", species="Cane"))
    conversations = InMemoryConversationRepository()
    conversations.save(Conversation(owner_id="owner-b", pet_id="pet-b", title="segreto"))
    reminders = InMemoryReminderRepository()
    reminders.save(
        Reminder(
            owner_id="owner-a", pet_id="pet-a", title="Vaccino", due_date=datetime.now(UTC).date()
        )
    )
    exporter = InMemoryAccountExporter(
        pet_profiles=pets,
        conversations=conversations,
        reminders=reminders,
        clinical_events=InMemoryClinicalEventRepository(),
        pet_conditions=InMemoryPetConditionRepository(),
        account_consents=InMemoryAccountConsentsRepository(),
        user_locations=InMemoryUserLocationRepository(),
        dog_walks=InMemoryDogWalkRepository(),
        marketplace_listings=InMemoryMarketplaceListingRepository(),
    )

    export = exporter.export_data("owner-a")

    assert [row["name"] for row in export.data["pet_profiles"]] == ["Milo"]
    assert export.data["conversations"] == []
    assert [row["title"] for row in export.data["reminders"]] == ["Vaccino"]
    assert "segreto" not in str(export.model_dump())

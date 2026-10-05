from __future__ import annotations

import logging
import time
from datetime import date, datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.radar_catalog_repository import (
    BoundingBox,
    RadarCatalogRepository,
)
from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.ports.radar_reports_repository import RadarReportsRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.domain.consent.models import AccountConsents
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.coverage.models import RadarCoverage
from packages.core.domain.dog_walk.models import WalkSession
from packages.core.domain.feedback.models import ChatResponseReport, ChatResponseReportCounter
from packages.core.domain.geo.models import Coordinates, UserLocation
from packages.core.domain.local_activity.models import LocalActivity
from packages.core.domain.marketplace.models import ListingReport, MarketplaceListing
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.radar_places.models import (
    OSM_SOURCE_NAME,
    RADAR_PLACE_TRANSIENT_FIELDS,
    RadarDataSource,
    RadarPlace,
)
from packages.core.domain.radar_reports.models import (
    RadarPlaceOverride,
    RadarPlaceRating,
    RadarReportVote,
    RadarUserReport,
)
from packages.core.domain.reminders.models import Reminder
from packages.core.domain.subscription.models import Subscription

if TYPE_CHECKING:
    from supabase import Client

_logger = logging.getLogger(__name__)


def _serialize_payload(payload: dict[str, Any]) -> dict[str, Any]:
    serialized: dict[str, Any] = {}
    for key, value in payload.items():
        if isinstance(value, (datetime, date)):
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    return serialized


class SupabasePetProfileRepository(PetProfileRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "pet_profiles"

    def save(self, pet_profile: PetProfile) -> PetProfile:
        payload = _serialize_payload(pet_profile.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return pet_profile

    def get(self, pet_id: str) -> PetProfile | None:
        response = self._client.table(self._table).select("*").eq("id", pet_id).limit(1).execute()
        if not response.data:
            return None
        return PetProfile.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[PetProfile]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [PetProfile.model_validate(item) for item in response.data or []]


class SupabaseConversationRepository(ConversationRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "conversations"

    def save(self, conversation: Conversation) -> Conversation:
        payload = _serialize_payload(conversation.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return conversation

    def get(self, conversation_id: str) -> Conversation | None:
        response = (
            self._client.table(self._table).select("*").eq("id", conversation_id).limit(1).execute()
        )
        if not response.data:
            return None
        return Conversation.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[Conversation]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [Conversation.model_validate(item) for item in response.data or []]

    def list_by_pet(self, pet_id: str) -> list[Conversation]:
        response = self._client.table(self._table).select("*").eq("pet_id", pet_id).execute()
        return [Conversation.model_validate(item) for item in response.data or []]

    def delete(self, conversation_id: str) -> None:
        self._client.table(self._table).delete().eq("id", conversation_id).execute()


class SupabaseReminderRepository(ReminderRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "reminders"

    def save(self, reminder: Reminder) -> Reminder:
        payload = _serialize_payload(reminder.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return reminder

    def list_by_owner(self, owner_id: str) -> list[Reminder]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [Reminder.model_validate(item) for item in response.data or []]


class SupabaseClinicalEventRepository(ClinicalEventRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "clinical_events"

    def list_by_pet(self, pet_id: str) -> list[ClinicalEvent]:
        response = self._client.table(self._table).select("*").eq("pet_id", pet_id).execute()
        return [ClinicalEvent.model_validate(item) for item in response.data or []]


class SupabaseAccountConsentsRepository(AccountConsentsRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "account_consents"

    def get(self, owner_id: str) -> AccountConsents | None:
        response = (
            self._client.table(self._table).select("*").eq("owner_id", owner_id).limit(1).execute()
        )
        if not response.data:
            return None
        return AccountConsents.model_validate(response.data[0])

    def save(self, account_consents: AccountConsents) -> AccountConsents:
        payload = _serialize_payload(account_consents.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return account_consents


class SupabaseSubscriptionRepository(SubscriptionRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "subscriptions"

    def get(self, owner_id: str) -> Subscription | None:
        response = (
            self._client.table(self._table).select("*").eq("owner_id", owner_id).limit(1).execute()
        )
        if not response.data:
            return None
        return Subscription.model_validate(response.data[0])

    def save(self, subscription: Subscription) -> Subscription:
        payload = _serialize_payload(subscription.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return subscription


def _user_location_to_row(user_location: UserLocation) -> dict[str, Any]:
    payload = _serialize_payload(user_location.model_dump(mode="json", exclude={"home", "current"}))
    if user_location.home is not None:
        payload["home_latitude"] = user_location.home.latitude
        payload["home_longitude"] = user_location.home.longitude
    if user_location.current is not None:
        payload["current_latitude"] = user_location.current.latitude
        payload["current_longitude"] = user_location.current.longitude
    return payload


def _row_to_user_location(row: dict[str, Any]) -> UserLocation:
    home = None
    if row.get("home_latitude") is not None and row.get("home_longitude") is not None:
        home = Coordinates(latitude=row["home_latitude"], longitude=row["home_longitude"])
    current = None
    if row.get("current_latitude") is not None and row.get("current_longitude") is not None:
        current = Coordinates(latitude=row["current_latitude"], longitude=row["current_longitude"])
    return UserLocation.model_validate({**row, "home": home, "current": current})


class SupabaseUserLocationRepository(UserLocationRepository):
    """user_locations stores latitude/longitude as flat columns (see
    scripts/setup/supabase_schema.sql), not the nested `Coordinates` shape
    the domain model uses - this repository is the flattening boundary."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "user_locations"

    def get(self, owner_id: str) -> UserLocation | None:
        response = (
            self._client.table(self._table).select("*").eq("owner_id", owner_id).limit(1).execute()
        )
        if not response.data:
            return None
        return _row_to_user_location(cast(dict[str, Any], response.data[0]))

    def save(self, user_location: UserLocation) -> UserLocation:
        self._client.table(self._table).upsert(_user_location_to_row(user_location)).execute()
        return user_location


class SupabaseRadarPlacesRepository(RadarPlacesRepository):
    """Shared per-cell cache of imported places. Both tables have RLS on
    and no policies (see scripts/setup/supabase_schema.sql): only this
    service-role client reads/writes them."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._coverage_table = "radar_coverage_cells"
        self._places_table = "radar_places_cache"

    def get_coverage(self, coverage_key: str) -> RadarCoverage | None:
        response = (
            self._client.table(self._coverage_table)
            .select("*")
            .eq("coverage_key", coverage_key)
            .limit(1)
            .execute()
        )
        if not response.data:
            return None
        return RadarCoverage.model_validate(response.data[0])

    def list_places(self, coverage_key: str) -> list[RadarPlace]:
        response = (
            self._client.table(self._places_table)
            .select("*")
            .eq("coverage_key", coverage_key)
            .execute()
        )
        return [RadarPlace.model_validate(item) for item in response.data or []]

    def replace_coverage(self, coverage: RadarCoverage, places: list[RadarPlace]) -> None:
        # Upsert first, then drop rows the provider no longer returns: a
        # failure halfway leaves the previous import readable instead of
        # an empty cell.
        rows = [
            place.model_dump(mode="json", exclude=set(RADAR_PLACE_TRANSIENT_FIELDS))
            for place in places
        ]
        if rows:
            self._client.table(self._places_table).upsert(rows).execute()
        stale = (
            self._client.table(self._places_table)
            .delete()
            .eq("coverage_key", coverage.coverage_key)
        )
        if rows:
            # Rows just upserted carry this import's timestamp; anything
            # older in the cell was not returned this time.
            stale = stale.lt("source_fetched_at", coverage.refreshed_at.isoformat())
        stale.execute()
        self._client.table(self._coverage_table).upsert(coverage.model_dump(mode="json")).execute()


class SupabaseRadarCatalogRepository(RadarCatalogRepository):
    """Reads the tables scripts/radar/ fills offline. One table per source
    (radar_places_osm, radar_places_open): they are never joined or copied
    into each other, here or in the database."""

    _PAGE_SIZE = 1000
    _SOURCES_TTL_SECONDS = 300.0

    def __init__(self, client: Client) -> None:
        self._client = client
        self._sources: list[RadarDataSource] = []
        self._sources_read_at: float | None = None

    def list_sources(self) -> list[RadarDataSource]:
        now = time.monotonic()
        read_at = self._sources_read_at
        if read_at is not None and now - read_at < self._SOURCES_TTL_SECONDS:
            return list(self._sources)
        try:
            response = self._client.table("data_sources").select("*").execute()
        except Exception:
            # Tables not created yet, or a transient failure: the radar
            # still works on the live per-cell cache alone.
            _logger.warning("radar catalog unavailable: data_sources could not be read")
            return []
        self._sources = [RadarDataSource.model_validate(row) for row in response.data or []]
        self._sources_read_at = now
        return list(self._sources)

    def list_osm_places(self, box: BoundingBox) -> list[RadarPlace]:
        return [_osm_place(row) for row in self._rows_in_box("radar_places_osm", box)]

    def list_open_places(self, box: BoundingBox) -> list[RadarPlace]:
        return [_open_place(row) for row in self._rows_in_box("radar_places_open", box)]

    def get_place(self, source: str, source_id: str) -> RadarPlace | None:
        try:
            if source == OSM_SOURCE_NAME:
                query = (
                    self._client.table("radar_places_osm")
                    .select("*")
                    .eq("source_external_id", source_id)
                )
            else:
                query = (
                    self._client.table("radar_places_open")
                    .select("*")
                    .eq("source", source)
                    .eq("source_id", source_id)
                )
            rows = cast(list[dict[str, Any]], query.limit(1).execute().data or [])
        except Exception:
            _logger.warning("radar catalog unavailable: a place could not be read")
            return None
        if not rows:
            return None
        return _osm_place(rows[0]) if source == OSM_SOURCE_NAME else _open_place(rows[0])

    def _rows_in_box(self, table: str, box: BoundingBox) -> list[dict[str, Any]]:
        # PostgREST caps a response at 1000 rows; a 50 km box around a big
        # city holds more than that.
        rows: list[dict[str, Any]] = []
        while True:
            response = (
                self._client.table(table)
                .select("*")
                .gte("latitude", box.min_latitude)
                .lte("latitude", box.max_latitude)
                .gte("longitude", box.min_longitude)
                .lte("longitude", box.max_longitude)
                .order("id")
                .range(len(rows), len(rows) + self._PAGE_SIZE - 1)
                .execute()
            )
            page = cast(list[dict[str, Any]], response.data or [])
            rows.extend(page)
            if len(page) < self._PAGE_SIZE:
                return rows


def _osm_place(row: dict[str, Any]) -> RadarPlace:
    return RadarPlace.model_validate(
        {
            **row,
            "coverage_key": "catalog",
            "source_name": OSM_SOURCE_NAME,
            "source_fetched_at": row.get("imported_at"),
        }
    )


def _open_place(row: dict[str, Any]) -> RadarPlace:
    return RadarPlace.model_validate(
        {
            **row,
            "coverage_key": "catalog",
            "source_name": row["source"],
            "source_external_id": row["source_id"],
            "source_fetched_at": row.get("imported_at"),
        }
    )


class SupabaseRadarReportsRepository(RadarReportsRepository):
    """Community reports, votes and ratings. RLS on with no policies:
    every read and write goes through this service-role client, because
    rows are keyed by a pseudonym only the backend can compute.

    Reads answer "nothing" when the tables are missing or unreachable, so
    the radar keeps working without the community layer; writes fail
    loudly."""

    _MAX_IDS_PER_QUERY = 100
    _OVERRIDES_TTL_SECONDS = 60.0

    def __init__(self, client: Client) -> None:
        self._client = client
        self._overrides: list[RadarPlaceOverride] = []
        self._overrides_read_at: float | None = None

    def save_report(self, report: RadarUserReport) -> RadarUserReport:
        self._client.table("radar_user_reports").upsert(report.model_dump(mode="json")).execute()
        return report

    def get_report(self, report_id: str) -> RadarUserReport | None:
        response = (
            self._client.table("radar_user_reports")
            .select("*")
            .eq("id", report_id)
            .limit(1)
            .execute()
        )
        return RadarUserReport.model_validate(response.data[0]) if response.data else None

    def delete_report(self, report_id: str) -> None:
        # Its votes go with it (on delete cascade).
        self._client.table("radar_user_reports").delete().eq("id", report_id).execute()

    def list_reports(
        self, box: BoundingBox, *, kinds: list[str], statuses: list[str]
    ) -> list[RadarUserReport]:
        try:
            response = (
                self._client.table("radar_user_reports")
                .select("*")
                .in_("kind", kinds)
                .in_("status", statuses)
                .gte("latitude", box.min_latitude)
                .lte("latitude", box.max_latitude)
                .gte("longitude", box.min_longitude)
                .lte("longitude", box.max_longitude)
                .limit(1000)
                .execute()
            )
        except Exception:
            _logger.warning("radar reports unavailable: radar_user_reports could not be read")
            return []
        return [RadarUserReport.model_validate(row) for row in response.data or []]

    def count_reports_since(self, reporter_pseudonym: str, since: datetime) -> int:
        response = (
            self._client.table("radar_user_reports")
            .select("id")
            .eq("reporter_pseudonym", reporter_pseudonym)
            .gte("created_at", since.isoformat())
            .execute()
        )
        return len(response.data or [])

    def save_vote(self, vote: RadarReportVote) -> None:
        self._client.table("radar_report_votes").upsert(vote.model_dump(mode="json")).execute()

    def list_votes(self, report_id: str) -> list[RadarReportVote]:
        response = (
            self._client.table("radar_report_votes")
            .select("*")
            .eq("report_id", report_id)
            .execute()
        )
        return [RadarReportVote.model_validate(row) for row in response.data or []]

    def list_votes_by_voter(
        self, report_ids: list[str], voter_pseudonym: str
    ) -> list[RadarReportVote]:
        try:
            response = (
                self._client.table("radar_report_votes")
                .select("*")
                .eq("voter_pseudonym", voter_pseudonym)
                .in_("report_id", report_ids[: self._MAX_IDS_PER_QUERY])
                .execute()
            )
        except Exception:
            return []
        return [RadarReportVote.model_validate(row) for row in response.data or []]

    def save_rating(self, rating: RadarPlaceRating) -> None:
        self._client.table("radar_place_ratings").upsert(rating.model_dump(mode="json")).execute()

    def list_ratings(self, box: BoundingBox) -> list[RadarPlaceRating]:
        try:
            response = (
                self._client.table("radar_place_ratings")
                .select("*")
                .gte("latitude", box.min_latitude)
                .lte("latitude", box.max_latitude)
                .gte("longitude", box.min_longitude)
                .lte("longitude", box.max_longitude)
                .limit(1000)
                .execute()
            )
        except Exception:
            _logger.warning("radar ratings unavailable: radar_place_ratings could not be read")
            return []
        return [RadarPlaceRating.model_validate(row) for row in response.data or []]

    def save_override(self, override: RadarPlaceOverride) -> None:
        self._client.table("radar_place_overrides").upsert(
            override.model_dump(mode="json")
        ).execute()
        self._overrides_read_at = None

    def list_overrides(self) -> list[RadarPlaceOverride]:
        # The whole (small, rarely changing) table is needed by every radar
        # request: kept for a minute rather than read each time. A removal
        # made elsewhere (the script, another instance) shows within that.
        now = time.monotonic()
        read_at = self._overrides_read_at
        if read_at is not None and now - read_at < self._OVERRIDES_TTL_SECONDS:
            return list(self._overrides)
        try:
            response = self._client.table("radar_place_overrides").select("*").execute()
        except Exception:
            return []
        self._overrides = [RadarPlaceOverride.model_validate(row) for row in response.data or []]
        self._overrides_read_at = now
        return list(self._overrides)


class SupabaseDogWalkRepository(DogWalkRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "dog_walks"

    def save(self, walk: WalkSession) -> WalkSession:
        payload = _serialize_payload(walk.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return walk

    def get(self, walk_id: str) -> WalkSession | None:
        response = self._client.table(self._table).select("*").eq("id", walk_id).limit(1).execute()
        if not response.data:
            return None
        return WalkSession.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[WalkSession]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [WalkSession.model_validate(item) for item in response.data or []]


def _listing_to_row(listing: MarketplaceListing) -> dict[str, Any]:
    payload = _serialize_payload(listing.model_dump(mode="json", exclude={"location"}))
    payload["latitude"] = listing.location.latitude
    payload["longitude"] = listing.location.longitude
    return payload


def _row_to_listing(row: dict[str, Any]) -> MarketplaceListing:
    location = Coordinates(latitude=row["latitude"], longitude=row["longitude"])
    return MarketplaceListing.model_validate({**row, "location": location})


class SupabaseMarketplaceListingRepository(MarketplaceListingRepository):
    """marketplace_listings stores latitude/longitude as flat columns (see
    scripts/setup/supabase_schema.sql), like user_locations - the domain's
    nested `Coordinates` is flattened/rebuilt at this boundary."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "marketplace_listings"

    def save(self, listing: MarketplaceListing) -> MarketplaceListing:
        self._client.table(self._table).upsert(_listing_to_row(listing)).execute()
        return listing

    def get(self, listing_id: str) -> MarketplaceListing | None:
        response = (
            self._client.table(self._table).select("*").eq("id", listing_id).limit(1).execute()
        )
        if not response.data:
            return None
        return _row_to_listing(cast(dict[str, Any], response.data[0]))

    def list_active(self) -> list[MarketplaceListing]:
        response = self._client.table(self._table).select("*").eq("status", "active").execute()
        return [_row_to_listing(cast(dict[str, Any], item)) for item in response.data or []]


class SupabaseListingReportRepository(ListingReportRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "marketplace_listing_reports"

    def save(self, report: ListingReport) -> ListingReport:
        payload = _serialize_payload(report.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return report

    def list_by_listing(self, listing_id: str) -> list[ListingReport]:
        response = (
            self._client.table(self._table).select("*").eq("listing_id", listing_id).execute()
        )
        return [ListingReport.model_validate(item) for item in response.data or []]


class SupabaseChatResponseReportRepository(ChatResponseReportRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "chat_response_reports"
        self._counters_table = "chat_response_report_counters"

    def save(self, report: ChatResponseReport) -> ChatResponseReport:
        payload = _serialize_payload(report.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return report

    def get(self, report_id: str) -> ChatResponseReport | None:
        response = (
            self._client.table(self._table).select("*").eq("id", report_id).limit(1).execute()
        )
        if not response.data:
            return None
        return ChatResponseReport.model_validate(response.data[0])

    def list_by_reporter(self, reporter_ref: str) -> list[ChatResponseReport]:
        response = (
            self._client.table(self._table).select("*").eq("reporter_ref", reporter_ref).execute()
        )
        return [ChatResponseReport.model_validate(item) for item in response.data or []]

    def list_all(self) -> list[ChatResponseReport]:
        response = self._client.table(self._table).select("*").execute()
        return [ChatResponseReport.model_validate(item) for item in response.data or []]

    def delete(self, report_id: str) -> None:
        self._client.table(self._table).delete().eq("id", report_id).execute()

    def add_to_counter(self, period: str, reason: str, status: str, amount: int) -> None:
        # Read-then-upsert rather than an atomic increment: only the
        # retention job writes here, one run at a time.
        existing = (
            self._client.table(self._counters_table)
            .select("*")
            .eq("period", period)
            .eq("reason", reason)
            .eq("status", status)
            .limit(1)
            .execute()
        )
        counters = [ChatResponseReportCounter.model_validate(row) for row in existing.data or []]
        current = counters[0].total if counters else 0
        self._client.table(self._counters_table).upsert(
            {"period": period, "reason": reason, "status": status, "total": current + amount}
        ).execute()

    def list_counters(self) -> list[ChatResponseReportCounter]:
        response = self._client.table(self._counters_table).select("*").execute()
        return [ChatResponseReportCounter.model_validate(item) for item in response.data or []]


class SupabaseChatAttachmentRepository(ChatAttachmentRepository):
    """Metadata only — the image bytes themselves go through `media_storage`
    (LocalFileStorage or SupabaseMediaStorage, chosen the same way as this
    repository, see ApplicationContainer._build_media_storage).
    """

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "chat_attachments"

    def save(self, attachment: ChatAttachment) -> ChatAttachment:
        payload = _serialize_payload(attachment.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return attachment

    def get(self, attachment_id: str) -> ChatAttachment | None:
        response = (
            self._client.table(self._table).select("*").eq("id", attachment_id).limit(1).execute()
        )
        if not response.data:
            return None
        return ChatAttachment.model_validate(response.data[0])


def _activity_to_row(activity: LocalActivity) -> dict[str, Any]:
    payload = _serialize_payload(activity.model_dump(mode="json", exclude={"location"}))
    payload["latitude"] = activity.location.latitude
    payload["longitude"] = activity.location.longitude
    return payload


def _row_to_activity(row: dict[str, Any]) -> LocalActivity:
    location = Coordinates(latitude=row["latitude"], longitude=row["longitude"])
    return LocalActivity.model_validate({**row, "location": location})


class SupabaseLocalActivityRepository(LocalActivityRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "local_activities"

    def save(self, activity: LocalActivity) -> LocalActivity:
        self._client.table(self._table).upsert(_activity_to_row(activity)).execute()
        return activity

    def list_active(self) -> list[LocalActivity]:
        response = self._client.table(self._table).select("*").eq("status", "active").execute()
        return [_row_to_activity(cast(dict[str, Any], item)) for item in response.data or []]

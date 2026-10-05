from datetime import datetime

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
from packages.core.domain.geo.models import UserLocation
from packages.core.domain.local_activity.models import LocalActivity
from packages.core.domain.marketplace.models import ListingReport, MarketplaceListing
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.radar_places.models import RadarDataSource, RadarPlace
from packages.core.domain.radar_reports.models import (
    RadarPlaceOverride,
    RadarPlaceRating,
    RadarReportVote,
    RadarUserReport,
)
from packages.core.domain.reminders.models import Reminder
from packages.core.domain.subscription.models import Subscription


class InMemoryPetProfileRepository(PetProfileRepository):
    def __init__(self) -> None:
        self._items: dict[str, PetProfile] = {}

    def save(self, pet_profile: PetProfile) -> PetProfile:
        self._items[pet_profile.id] = pet_profile
        return pet_profile

    def get(self, pet_id: str) -> PetProfile | None:
        return self._items.get(pet_id)

    def list_by_owner(self, owner_id: str) -> list[PetProfile]:
        return [item for item in self._items.values() if item.owner_id == owner_id]


class InMemoryConversationRepository(ConversationRepository):
    def __init__(self) -> None:
        self._items: dict[str, Conversation] = {}

    def save(self, conversation: Conversation) -> Conversation:
        self._items[conversation.id] = conversation
        return conversation

    def get(self, conversation_id: str) -> Conversation | None:
        return self._items.get(conversation_id)

    def list_by_owner(self, owner_id: str) -> list[Conversation]:
        return [item for item in self._items.values() if item.owner_id == owner_id]

    def list_by_pet(self, pet_id: str) -> list[Conversation]:
        return [item for item in self._items.values() if item.pet_id == pet_id]

    def delete(self, conversation_id: str) -> None:
        self._items.pop(conversation_id, None)


class InMemoryReminderRepository(ReminderRepository):
    def __init__(self) -> None:
        self._items: list[Reminder] = []

    def save(self, reminder: Reminder) -> Reminder:
        self._items.append(reminder)
        return reminder

    def list_by_owner(self, owner_id: str) -> list[Reminder]:
        return [item for item in self._items if item.owner_id == owner_id]


class InMemoryClinicalEventRepository(ClinicalEventRepository):
    def __init__(self, seed: list[ClinicalEvent] | None = None) -> None:
        self._items: list[ClinicalEvent] = list(seed or [])

    def save(self, event: ClinicalEvent) -> ClinicalEvent:
        self._items.append(event)
        return event

    def list_by_pet(self, pet_id: str) -> list[ClinicalEvent]:
        return [item for item in self._items if item.pet_id == pet_id]


class InMemoryAccountConsentsRepository(AccountConsentsRepository):
    def __init__(self) -> None:
        self._items: dict[str, AccountConsents] = {}

    def get(self, owner_id: str) -> AccountConsents | None:
        return self._items.get(owner_id)

    def save(self, account_consents: AccountConsents) -> AccountConsents:
        self._items[account_consents.owner_id] = account_consents
        return account_consents


class InMemorySubscriptionRepository(SubscriptionRepository):
    def __init__(self) -> None:
        self._items: dict[str, Subscription] = {}

    def get(self, owner_id: str) -> Subscription | None:
        return self._items.get(owner_id)

    def save(self, subscription: Subscription) -> Subscription:
        self._items[subscription.owner_id] = subscription
        return subscription


class InMemoryUserLocationRepository(UserLocationRepository):
    def __init__(self) -> None:
        self._items: dict[str, UserLocation] = {}

    def get(self, owner_id: str) -> UserLocation | None:
        return self._items.get(owner_id)

    def save(self, user_location: UserLocation) -> UserLocation:
        self._items[user_location.owner_id] = user_location
        return user_location


class InMemoryRadarPlacesRepository(RadarPlacesRepository):
    def __init__(self) -> None:
        self._coverage: dict[str, RadarCoverage] = {}
        self._places: dict[str, list[RadarPlace]] = {}

    def get_coverage(self, coverage_key: str) -> RadarCoverage | None:
        return self._coverage.get(coverage_key)

    def list_places(self, coverage_key: str) -> list[RadarPlace]:
        return list(self._places.get(coverage_key, []))

    def replace_coverage(self, coverage: RadarCoverage, places: list[RadarPlace]) -> None:
        self._coverage[coverage.coverage_key] = coverage
        self._places[coverage.coverage_key] = list(places)


class InMemoryRadarCatalogRepository(RadarCatalogRepository):
    """Empty by default: without an offline import the radar behaves as
    before, on the live per-cell cache alone."""

    def __init__(self) -> None:
        self.sources: list[RadarDataSource] = []
        self.osm_places: list[RadarPlace] = []
        self.open_places: list[RadarPlace] = []

    def list_sources(self) -> list[RadarDataSource]:
        return list(self.sources)

    def list_osm_places(self, box: BoundingBox) -> list[RadarPlace]:
        return [place for place in self.osm_places if _in_box(place, box)]

    def list_open_places(self, box: BoundingBox) -> list[RadarPlace]:
        return [place for place in self.open_places if _in_box(place, box)]

    def get_place(self, source: str, source_id: str) -> RadarPlace | None:
        return next(
            (
                place
                for place in [*self.osm_places, *self.open_places]
                if place.source_name == source and place.source_external_id == source_id
            ),
            None,
        )


def _in_box(place: RadarPlace, box: BoundingBox) -> bool:
    return (
        box.min_latitude <= place.latitude <= box.max_latitude
        and box.min_longitude <= place.longitude <= box.max_longitude
    )


class InMemoryRadarReportsRepository(RadarReportsRepository):
    def __init__(self) -> None:
        self._reports: dict[str, RadarUserReport] = {}
        self._votes: dict[tuple[str, str], RadarReportVote] = {}
        self._ratings: dict[tuple[str, str, str], RadarPlaceRating] = {}
        self._overrides: dict[tuple[str, str, str], RadarPlaceOverride] = {}

    def save_report(self, report: RadarUserReport) -> RadarUserReport:
        self._reports[report.id] = report
        return report

    def get_report(self, report_id: str) -> RadarUserReport | None:
        return self._reports.get(report_id)

    def delete_report(self, report_id: str) -> None:
        self._reports.pop(report_id, None)
        self._votes = {key: vote for key, vote in self._votes.items() if key[0] != report_id}

    def list_reports(
        self, box: BoundingBox, *, kinds: list[str], statuses: list[str]
    ) -> list[RadarUserReport]:
        return [
            report
            for report in self._reports.values()
            if report.kind in kinds
            and report.status in statuses
            and box.min_latitude <= report.latitude <= box.max_latitude
            and box.min_longitude <= report.longitude <= box.max_longitude
        ]

    def count_reports_since(self, reporter_pseudonym: str, since: datetime) -> int:
        return sum(
            1
            for report in self._reports.values()
            if report.reporter_pseudonym == reporter_pseudonym and report.created_at >= since
        )

    def save_vote(self, vote: RadarReportVote) -> None:
        self._votes[(vote.report_id, vote.voter_pseudonym)] = vote

    def list_votes(self, report_id: str) -> list[RadarReportVote]:
        return [vote for vote in self._votes.values() if vote.report_id == report_id]

    def list_votes_by_voter(
        self, report_ids: list[str], voter_pseudonym: str
    ) -> list[RadarReportVote]:
        return [
            vote
            for vote in self._votes.values()
            if vote.voter_pseudonym == voter_pseudonym and vote.report_id in report_ids
        ]

    def save_rating(self, rating: RadarPlaceRating) -> None:
        self._ratings[(rating.source, rating.source_id, rating.voter_pseudonym)] = rating

    def list_ratings(self, box: BoundingBox) -> list[RadarPlaceRating]:
        return [
            rating
            for rating in self._ratings.values()
            if box.min_latitude <= rating.latitude <= box.max_latitude
            and box.min_longitude <= rating.longitude <= box.max_longitude
        ]

    def save_override(self, override: RadarPlaceOverride) -> None:
        self._overrides[(override.source, override.source_id, override.action)] = override

    def list_overrides(self) -> list[RadarPlaceOverride]:
        return list(self._overrides.values())


class InMemoryDogWalkRepository(DogWalkRepository):
    def __init__(self) -> None:
        self._items: dict[str, WalkSession] = {}

    def save(self, walk: WalkSession) -> WalkSession:
        self._items[walk.id] = walk
        return walk

    def get(self, walk_id: str) -> WalkSession | None:
        return self._items.get(walk_id)

    def list_by_owner(self, owner_id: str) -> list[WalkSession]:
        return [item for item in self._items.values() if item.owner_id == owner_id]


class InMemoryMarketplaceListingRepository(MarketplaceListingRepository):
    def __init__(self) -> None:
        self._items: dict[str, MarketplaceListing] = {}

    def save(self, listing: MarketplaceListing) -> MarketplaceListing:
        self._items[listing.id] = listing
        return listing

    def get(self, listing_id: str) -> MarketplaceListing | None:
        return self._items.get(listing_id)

    def list_active(self) -> list[MarketplaceListing]:
        return [item for item in self._items.values() if item.status == "active"]


class InMemoryListingReportRepository(ListingReportRepository):
    def __init__(self) -> None:
        self._items: list[ListingReport] = []

    def save(self, report: ListingReport) -> ListingReport:
        self._items.append(report)
        return report

    def list_by_listing(self, listing_id: str) -> list[ListingReport]:
        return [item for item in self._items if item.listing_id == listing_id]


class InMemoryChatResponseReportRepository(ChatResponseReportRepository):
    def __init__(self) -> None:
        self._items: dict[str, ChatResponseReport] = {}
        self._counters: dict[tuple[str, str, str], int] = {}

    def save(self, report: ChatResponseReport) -> ChatResponseReport:
        self._items[report.id] = report
        return report

    def get(self, report_id: str) -> ChatResponseReport | None:
        return self._items.get(report_id)

    def list_by_reporter(self, reporter_ref: str) -> list[ChatResponseReport]:
        return [item for item in self._items.values() if item.reporter_ref == reporter_ref]

    def list_all(self) -> list[ChatResponseReport]:
        return list(self._items.values())

    def delete(self, report_id: str) -> None:
        self._items.pop(report_id, None)

    def add_to_counter(self, period: str, reason: str, status: str, amount: int) -> None:
        key = (period, reason, status)
        self._counters[key] = self._counters.get(key, 0) + amount

    def list_counters(self) -> list[ChatResponseReportCounter]:
        return [
            ChatResponseReportCounter(period=period, reason=reason, status=status, total=total)
            for (period, reason, status), total in self._counters.items()
        ]


class InMemoryChatAttachmentRepository(ChatAttachmentRepository):
    def __init__(self) -> None:
        self._items: dict[str, ChatAttachment] = {}

    def save(self, attachment: ChatAttachment) -> ChatAttachment:
        self._items[attachment.id] = attachment
        return attachment

    def get(self, attachment_id: str) -> ChatAttachment | None:
        return self._items.get(attachment_id)


class InMemoryLocalActivityRepository(LocalActivityRepository):
    def __init__(self, seed: list[LocalActivity] | None = None) -> None:
        self._items: list[LocalActivity] = list(seed or [])

    def save(self, activity: LocalActivity) -> LocalActivity:
        self._items.append(activity)
        return activity

    def list_active(self) -> list[LocalActivity]:
        return [item for item in self._items if item.status == "active"]

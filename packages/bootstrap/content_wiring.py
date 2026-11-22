"""Events, pet news and travel cards (QK-20, moved verbatim)."""

from datetime import timedelta

from packages.bootstrap.container_state import ContainerState
from packages.core.application.ports.event_catalog_repository import EventCatalogRepository
from packages.core.application.ports.event_submission_repository import EventSubmissionRepository
from packages.core.application.ports.pet_news import PetNewsCacheRepository
from packages.core.application.services.get_pet_news import GetPetNewsService
from packages.core.application.services.list_events import ListEventsService
from packages.core.application.services.list_travel_cards import ListTravelCardsService
from packages.core.application.services.submit_event import SubmitEventService
from packages.core.domain.travel.cards import load_travel_cards
from packages.infrastructure.news.feed_reader import HttpPetNewsFeedReader
from packages.infrastructure.persistence.in_memory_event_catalog import (
    InMemoryEventCatalogRepository,
)
from packages.infrastructure.persistence.in_memory_event_submissions import (
    InMemoryEventSubmissionRepository,
)
from packages.infrastructure.persistence.in_memory_pet_news import InMemoryPetNewsCacheRepository


class ContentWiring(ContainerState):
    def list_events_service(self) -> ListEventsService:
        return ListEventsService(self.event_catalog_repository())

    def event_catalog_repository(self) -> EventCatalogRepository:
        """One per process (the in-memory double keeps its rows)."""
        if self._event_catalog_repository is None:
            self._event_catalog_repository = self._build_event_catalog_repository()
        return self._event_catalog_repository

    def _build_event_catalog_repository(self) -> EventCatalogRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase import supabase_event_catalog
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )

                return supabase_event_catalog.SupabaseEventCatalogRepository(
                    build_supabase_client(self.settings)
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryEventCatalogRepository()
                raise
        return InMemoryEventCatalogRepository()

    def submit_event_service(self) -> SubmitEventService:
        return SubmitEventService(self.event_submission_repository())

    def event_submission_repository(self) -> EventSubmissionRepository:
        """One per process (the in-memory double must keep its queue)."""
        if self._event_submission_repository is None:
            self._event_submission_repository = self._build_event_submission_repository()
        return self._event_submission_repository

    def _build_event_submission_repository(self) -> EventSubmissionRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase import (
                    supabase_event_submissions,
                )
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )

                return supabase_event_submissions.SupabaseEventSubmissionRepository(
                    build_supabase_client(self.settings)
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryEventSubmissionRepository()
                raise
        return InMemoryEventSubmissionRepository()

    def travel_cards_service(self) -> ListTravelCardsService:
        """Around the world: the approved travel cards (files in the repository,
        no table: they are general content without personal data)."""
        return ListTravelCardsService(
            load_travel_cards(include_drafts=self.settings.travel_cards_include_drafts)
        )

    def pet_news_service(self) -> GetPetNewsService:
        """One per process: it remembers when the feeds last failed."""
        if self._pet_news_service is None:
            self._pet_news_service = GetPetNewsService(
                self._build_pet_news_cache(),
                HttpPetNewsFeedReader(
                    disabled_feed_keys=frozenset(
                        key.strip()
                        for key in self.settings.news_disabled_feeds.split(",")
                        if key.strip()
                    )
                ),
                ttl=timedelta(minutes=self.settings.news_cache_ttl_minutes),
            )
        return self._pet_news_service

    def _build_pet_news_cache(self) -> PetNewsCacheRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_pet_news import (
                    SupabasePetNewsCacheRepository,
                )

                return SupabasePetNewsCacheRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryPetNewsCacheRepository()
                raise
        return InMemoryPetNewsCacheRepository()

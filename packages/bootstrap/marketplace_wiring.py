"""Mercatino: listings, reports and messages (QK-20, moved verbatim)."""

from packages.bootstrap.container_state import ContainerState
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.marketplace_messaging_repository import (
    MarketplaceMessagingRepository,
)
from packages.core.application.services.create_listing import CreateListingService
from packages.core.application.services.list_nearby_listings import ListNearbyListingsService
from packages.core.application.services.marketplace_messaging import (
    MarketplaceMessagingModerationService,
    MarketplaceMessagingService,
)
from packages.core.application.services.report_listing import ReportListingService
from packages.core.application.services.update_listing import UpdateListingService
from packages.infrastructure.persistence.in_memory_marketplace_messaging import (
    InMemoryMarketplaceMessagingRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryListingReportRepository,
    InMemoryMarketplaceListingRepository,
)


class MarketplaceWiring(ContainerState):
    def create_listing_service(self) -> CreateListingService:
        return CreateListingService(self.marketplace_listing_repository)

    def update_listing_service(self) -> UpdateListingService:
        return UpdateListingService(self.marketplace_listing_repository)

    def list_nearby_listings_service(self) -> ListNearbyListingsService:
        return ListNearbyListingsService(
            self.marketplace_listing_repository,
            hidden_owner_ids=self.hidden_owner_ids,
        )

    def marketplace_messaging_service(self) -> MarketplaceMessagingService:
        return MarketplaceMessagingService(
            self.marketplace_messaging_repository,
            self.marketplace_listing_repository,
            seller_can_answer=self.owner_can_write_on_marketplace,
        )

    def owner_can_write_on_marketplace(self, owner_id: str) -> bool:
        """Whether [owner_id]'s plan lets them write: the public test, a plan or an
        open trial. Read without creating anything, for someone other than the
        caller. The developer allowlist is matched by e-mail, which is not known
        here: a developer past the trial without a plan counts as without one."""
        if self.subscription_test_plan is not None:
            return True
        subscription = self.subscription_repository.get(owner_id)
        return subscription is not None and subscription.has_access(is_developer=False)

    def marketplace_messaging_moderation_service(self) -> MarketplaceMessagingModerationService:
        return MarketplaceMessagingModerationService(self.marketplace_messaging_repository)

    def report_listing_service(self) -> ReportListingService:
        return ReportListingService(
            self.marketplace_listing_repository, self.listing_report_repository
        )

    def _build_marketplace_listing_repository(self) -> MarketplaceListingRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseMarketplaceListingRepository,
                )

                return SupabaseMarketplaceListingRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryMarketplaceListingRepository()
                raise
        return InMemoryMarketplaceListingRepository()

    def _build_marketplace_messaging_repository(self) -> MarketplaceMessagingRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_marketplace_messaging import (  # noqa: E501
                    SupabaseMarketplaceMessagingRepository,
                )

                return SupabaseMarketplaceMessagingRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryMarketplaceMessagingRepository()
                raise
        return InMemoryMarketplaceMessagingRepository()

    def _build_listing_report_repository(self) -> ListingReportRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseListingReportRepository,
                )

                return SupabaseListingReportRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryListingReportRepository()
                raise
        return InMemoryListingReportRepository()

"""Radar (Servizi per animali): places, community reports, ratings (QK-20, moved verbatim)."""

import hashlib
import hmac

from packages.bootstrap.container_state import ContainerState
from packages.core.application.ports.radar_catalog_repository import RadarCatalogRepository
from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.ports.radar_reports_repository import RadarReportsRepository
from packages.core.application.services.list_nearby_radar_places import ListNearbyRadarPlacesService
from packages.core.application.services.radar_reports import (
    RadarCommunityView,
    RadarReportSettings,
    RateDogParkService,
    SubmitCompetenceClaimService,
    SubmitRadarReportService,
    VoteRadarReportService,
    WithdrawRadarReportService,
)
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionService,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryRadarCatalogRepository,
    InMemoryRadarPlacesRepository,
    InMemoryRadarReportsRepository,
)


class RadarWiring(ContainerState):
    def list_nearby_radar_places_service(self) -> ListNearbyRadarPlacesService:
        return ListNearbyRadarPlacesService(
            self.radar_places_repository,
            RequestRadarPlacesIngestionService(
                self.radar_places_repository, self.radar_places_source
            ),
            self.radar_catalog_repository,
            self.radar_community_view(),
            max_search_radius_km=self.settings.radar_search_radius_km,
            freshness_ttl_hours=self.settings.radar_freshness_ttl_hours,
            open_sources=self.radar_open_sources(),
            exotic_name_matching=self.settings.radar_exotic_name_matching,
            live_search=self.settings.radar_live_search_enabled,
        )

    def radar_report_settings(self) -> RadarReportSettings | None:
        """None when contributions are switched off: in production with no
        secret to key pseudonyms with, rather than using a known key."""
        key = self.settings.radar_pseudonym_key.strip()
        service_key = self.settings.supabase_service_role_key.strip()
        if not key and service_key:
            # Domain-separated derivation: a secret the deployment already
            # has, bound to this one purpose by the label, so it is not the
            # service key itself and is not shared with any other feature.
            # Never logged. Rotating the service key changes it.
            key = hmac.new(
                service_key.encode("utf-8"), b"radar-contributions-v1", hashlib.sha256
            ).hexdigest()
        if not key:
            if self.settings.environment == "production":
                return None
            key = "local-development-only"
        return RadarReportSettings(
            pseudonym_key=key,
            confirmations_required=self.settings.radar_report_confirmations,
            closed_confirmations_required=self.settings.radar_report_closed_confirmations,
            daily_limit=self.settings.radar_report_daily_limit,
            expiry_days=self.settings.radar_report_expiry_days,
            missing_place_types=frozenset(self.settings.radar_report_place_types),
            show_pending_closures=self.settings.radar_report_show_pending_closures,
            reports_enabled=self.settings.radar_reports_enabled,
            closed_reports_enabled=self.settings.radar_report_closed_enabled,
            ratings_enabled=self.settings.radar_ratings_enabled,
        )

    def radar_open_sources(self) -> frozenset[str] | None:
        """Sources of `radar_places_open` that are served; None is all."""
        names = {name.strip() for name in self.settings.radar_open_sources}
        return None if "*" in names else frozenset(names)

    def radar_community_view(self) -> RadarCommunityView | None:
        settings = self.radar_report_settings()
        if settings is None:
            return None
        return RadarCommunityView(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def submit_radar_report_service(self) -> SubmitRadarReportService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.reports_enabled:
            return None
        return SubmitRadarReportService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def withdraw_radar_report_service(self) -> WithdrawRadarReportService | None:
        # Also with reports switched off: taking back one's own is always allowed.
        settings = self.radar_report_settings()
        if settings is None:
            return None
        return WithdrawRadarReportService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def vote_radar_report_service(self) -> VoteRadarReportService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.reports_enabled:
            return None
        return VoteRadarReportService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def submit_competence_claim_service(self) -> SubmitCompetenceClaimService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.reports_enabled:
            return None
        return SubmitCompetenceClaimService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def rate_dog_park_service(self) -> RateDogParkService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.ratings_enabled:
            return None
        return RateDogParkService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def _build_radar_reports_repository(self) -> RadarReportsRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseRadarReportsRepository,
                )

                return SupabaseRadarReportsRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryRadarReportsRepository()
                raise
        return InMemoryRadarReportsRepository()

    def _build_radar_catalog_repository(self) -> RadarCatalogRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseRadarCatalogRepository,
                )

                return SupabaseRadarCatalogRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryRadarCatalogRepository()
                raise
        return InMemoryRadarCatalogRepository()

    def _build_radar_places_repository(self) -> RadarPlacesRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseRadarPlacesRepository,
                )

                return SupabaseRadarPlacesRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryRadarPlacesRepository()
                raise
        return InMemoryRadarPlacesRepository()

"""Account lifecycle: deletion, pause, declared age, export, eraser (QK-20, verbatim)."""

from packages.bootstrap.container_state import ContainerState
from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.account_deletion_repository import AccountDeletionRepository
from packages.core.application.ports.account_eraser import AccountEraser
from packages.core.application.ports.account_exporter import AccountExporter
from packages.core.application.ports.account_pause_repository import AccountPauseRepository
from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.account_pause import AccountPauseService
from packages.core.application.services.age_gate import AgeGateService
from packages.core.application.services.age_review_admin import AgeReviewAdminService
from packages.core.application.services.delete_account import DeleteAccountService
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.application.services.export_account_data import ExportAccountDataService
from packages.core.application.services.underage_review_dry_run import UnderageReviewDryRunService
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.in_memory_account_deletion_repository import (
    InMemoryAccountDeletionRepository,
)
from packages.infrastructure.persistence.in_memory_account_eraser import InMemoryAccountEraser
from packages.infrastructure.persistence.in_memory_account_exporter import InMemoryAccountExporter
from packages.infrastructure.persistence.in_memory_account_pause_repository import (
    InMemoryAccountPauseRepository,
)
from packages.infrastructure.persistence.in_memory_deletion_log import (
    InMemoryDeletionLogCopy,
    InMemoryDeletionLogRepository,
)


class AccountLifecycleWiring(ContainerState):
    def account_deletion_service(self) -> AccountDeletionService:
        return AccountDeletionService(
            self.account_deletion_repository,
            self._build_account_eraser(),
            self.settings.account_deletion_grace_days,
            self.account_consents_repository,
            self.pet_profile_repository,
            self.deletion_log_service,
        )

    def account_pause_service(self) -> AccountPauseService:
        return AccountPauseService(
            self.account_pause_repository,
            self.subscription_repository,
            self.settings.pause_max_months,
            self._build_account_eraser(),
            self.deletion_log_service,
        )

    def hidden_owner_ids(self) -> set[str]:
        """Sellers whose ads are hidden: asked to delete, or paused."""
        return self.account_deletion_repository.pending_owner_ids() | set(
            self.account_pause_repository.paused_owner_ids()
        )

    def _build_account_pause_repository(self) -> AccountPauseRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_pause_repository import (  # noqa: E501
                    SupabaseAccountPauseRepository,
                )

                return SupabaseAccountPauseRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountPauseRepository()
                raise
        return InMemoryAccountPauseRepository()

    def _build_deletion_log_service(self) -> DeletionLogService:
        """The register of deletions: the table and a copy in a private bucket
        outside it (docs/security/03)."""
        reapply_days = self.settings.deletion_log_reapply_days
        proof_years = self.settings.deletion_log_proof_years
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_deletion_log import (
                    SupabaseDeletionLogRepository,
                    SupabaseStorageDeletionLogCopy,
                )

                client = build_supabase_client(self.settings)
                return DeletionLogService(
                    SupabaseDeletionLogRepository(client),
                    SupabaseStorageDeletionLogCopy(client, self.settings.deletion_log_bucket),
                    reapply_days,
                    proof_years,
                )
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return DeletionLogService(
            InMemoryDeletionLogRepository(), InMemoryDeletionLogCopy(), reapply_days, proof_years
        )

    def _build_account_deletion_repository(self) -> AccountDeletionRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_deletion_repository import (  # noqa: E501
                    SupabaseAccountDeletionRepository,
                )

                return SupabaseAccountDeletionRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountDeletionRepository()
                raise
        return InMemoryAccountDeletionRepository()

    def account_eraser(self) -> AccountEraser:
        return self._build_account_eraser()

    def age_review_admin_service(self) -> AgeReviewAdminService:
        return AgeReviewAdminService(
            self.account_age_repository,
            self.owner_contact_lookup,
            self._build_account_eraser(),
            self.settings.reporter_pseudonym_secret(),
            self.deletion_log_service,
        )

    def underage_review_dry_run_service(self) -> UnderageReviewDryRunService:
        return UnderageReviewDryRunService(self.account_age_repository)

    def age_gate_service(self) -> AgeGateService:
        return AgeGateService(self.account_age_repository)

    def _build_account_age_repository(self) -> AccountAgeRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_age_repository import (  # noqa: E501
                    SupabaseAccountAgeRepository,
                )

                return SupabaseAccountAgeRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountAgeRepository()
                raise
        return InMemoryAccountAgeRepository()

    def delete_account_service(self) -> DeleteAccountService:
        return DeleteAccountService(self._build_account_eraser(), self.deletion_log_service)

    def export_account_data_service(self) -> ExportAccountDataService:
        return ExportAccountDataService(self._build_account_exporter())

    def _build_account_exporter(self) -> AccountExporter:
        # Same wiring (and same keys) as the eraser: the export must see
        # exactly what the deletion would remove.
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_exporter import (
                    SupabaseAccountExporter,
                )

                radar = self.radar_report_settings()
                return SupabaseAccountExporter(
                    build_supabase_client(self.settings),
                    media_bucket=self.settings.media_storage_bucket,
                    chat_reporter_secret=self.settings.reporter_pseudonym_secret(),
                    radar_pseudonym_key=radar.pseudonym_key if radar else None,
                )
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return InMemoryAccountExporter(
            pet_profiles=self.pet_profile_repository,
            conversations=self.conversation_repository,
            reminders=self.reminder_repository,
            clinical_events=self.clinical_event_repository,
            pet_conditions=self.pet_condition_repository,
            account_consents=self.account_consents_repository,
            user_locations=self.user_location_repository,
            dog_walks=self.dog_walk_repository,
            marketplace_listings=self.marketplace_listing_repository,
            marketplace_messaging=self.marketplace_messaging_repository,
            listing_reviews=self.listing_review_repository,
        )

    def _build_account_eraser(self) -> AccountEraser:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
                    SupabaseAccountEraser,
                )

                radar = self.radar_report_settings()
                return SupabaseAccountEraser(
                    build_supabase_client(self.settings),
                    media_bucket=self.settings.media_storage_bucket,
                    chat_reporter_secret=self.settings.reporter_pseudonym_secret(),
                    radar_pseudonym_key=radar.pseudonym_key if radar else None,
                )
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return InMemoryAccountEraser()

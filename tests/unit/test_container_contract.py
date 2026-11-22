"""QK-20: the contract of the service container, recorded BEFORE it is split into modules.

What must survive any reorganisation of `packages/bootstrap/`:
- the names on `ApplicationContainer` (public factories, `_build_*` hooks, attributes), because
  routes, jobs and tests reach them by name and several tests replace them on the instance;
- the names importable from `packages.bootstrap.container`;
- which factories hand out the same object twice and which build a new one;
- `get_container()` cached per process and `reset_container()` starting a new one;
- the concrete class of every repository for the in-memory and for the Supabase configuration
  (the Supabase one runs here with a fake client builder: nothing leaves the machine), and how
  many database clients are built (the "one client per process" rule lives in `client.py`).
"""

from __future__ import annotations

import inspect
from collections.abc import Iterator
from typing import Any
from unittest.mock import MagicMock

import pytest

import packages.infrastructure.persistence.supabase.client as supabase_client
from packages.bootstrap import container as container_module
from packages.bootstrap.container import (
    ApplicationContainer,
    get_container,
    reset_container,
)
from packages.shared.config.settings import Settings

IN_MEMORY = {
    "account_age_repository": "InMemoryAccountAgeRepository",
    "account_consents_repository": "InMemoryAccountConsentsRepository",
    "account_deletion_repository": "InMemoryAccountDeletionRepository",
    "account_pause_repository": "InMemoryAccountPauseRepository",
    "answer_cache_repository": "InMemoryAnswerCacheRepository",
    "auth_provider": "AgeGuardedAuthProvider",
    "chat_attachment_repository": "InMemoryChatAttachmentRepository",
    "chat_message_key_repository": "InMemoryMessageKeyRepository",
    "chat_orchestrator": "ChatOrchestrator",
    "chat_response_report_repository": "InMemoryChatResponseReportRepository",
    "clinical_event_repository": "InMemoryClinicalEventRepository",
    "conversation_repository": "InMemoryConversationRepository",
    "deletion_log_service": "DeletionLogService",
    "dog_walk_repository": "InMemoryDogWalkRepository",
    "email_sender": "DisabledEmailSender",
    "evidence_retriever": "InMemoryEvidenceRetriever",
    "geocoding_service": "GeocodingService",
    "image_analyzer": "EchoImageAnalyzer",
    "listing_report_repository": "InMemoryListingReportRepository",
    "llm_budget": "LlmBudget",
    "llm_client": "InstrumentedLLMClient",
    "llm_usage_repository": "InMemoryLlmUsageRepository",
    "local_activity_repository": "InMemoryLocalActivityRepository",
    "marketplace_listing_repository": "InMemoryMarketplaceListingRepository",
    "marketplace_messaging_repository": "InMemoryMarketplaceMessagingRepository",
    "media_storage": "LocalFileStorage",
    "owner_contact_lookup": "InMemoryOwnerContactLookup",
    "pet_condition_repository": "InMemoryPetConditionRepository",
    "pet_profile_repository": "InMemoryPetProfileRepository",
    "pii_anonymizer": "RuleBasedPiiAnonymizer",
    "radar_catalog_repository": "InMemoryRadarCatalogRepository",
    "radar_places_repository": "InMemoryRadarPlacesRepository",
    "radar_places_source": "OverpassRadarPlacesSource",
    "radar_reports_repository": "InMemoryRadarReportsRepository",
    "reminder_repository": "InMemoryReminderRepository",
    "speech_to_text_provider": "EchoSpeechToTextProvider",
    "store_entitlement_repository": "InMemoryStoreEntitlementRepository",
    "subscription_repository": "InMemorySubscriptionRepository",
    "user_device_repository": "InMemoryUserDeviceRepository",
    "user_location_repository": "InMemoryUserLocationRepository",
    "weight_measurement_repository": "InMemoryWeightMeasurementRepository",
}

SUPABASE = {
    "account_age_repository": "SupabaseAccountAgeRepository",
    "account_consents_repository": "SupabaseAccountConsentsRepository",
    "account_deletion_repository": "SupabaseAccountDeletionRepository",
    "account_pause_repository": "SupabaseAccountPauseRepository",
    "answer_cache_repository": "SupabaseAnswerCacheRepository",
    "auth_provider": "AgeGuardedAuthProvider",
    "chat_attachment_repository": "SupabaseChatAttachmentRepository",
    "chat_message_key_repository": "SupabaseMessageKeyRepository",
    "chat_orchestrator": "ChatOrchestrator",
    "chat_response_report_repository": "SupabaseChatResponseReportRepository",
    "clinical_event_repository": "SupabaseClinicalEventRepository",
    "conversation_repository": "SupabaseConversationRepository",
    "deletion_log_service": "DeletionLogService",
    "dog_walk_repository": "SupabaseDogWalkRepository",
    "email_sender": "DisabledEmailSender",
    "evidence_retriever": "SupabaseEvidenceRetriever",
    "geocoding_service": "GeocodingService",
    "image_analyzer": "EchoImageAnalyzer",
    "listing_report_repository": "SupabaseListingReportRepository",
    "llm_budget": "LlmBudget",
    "llm_client": "InstrumentedLLMClient",
    "llm_usage_repository": "SupabaseLlmUsageRepository",
    "local_activity_repository": "SupabaseLocalActivityRepository",
    "marketplace_listing_repository": "SupabaseMarketplaceListingRepository",
    "marketplace_messaging_repository": "SupabaseMarketplaceMessagingRepository",
    "media_storage": "SupabaseMediaStorage",
    "owner_contact_lookup": "SupabaseOwnerContactLookup",
    "pet_condition_repository": "SupabasePetConditionRepository",
    "pet_profile_repository": "SupabasePetProfileRepository",
    "pii_anonymizer": "RuleBasedPiiAnonymizer",
    "plan_access_sync": "PlanAccessSync",
    "radar_catalog_repository": "SupabaseRadarCatalogRepository",
    "radar_places_repository": "SupabaseRadarPlacesRepository",
    "radar_places_source": "OverpassRadarPlacesSource",
    "radar_reports_repository": "SupabaseRadarReportsRepository",
    "reminder_repository": "SupabaseReminderRepository",
    "speech_to_text_provider": "EchoSpeechToTextProvider",
    "store_entitlement_repository": "SupabaseStoreEntitlementRepository",
    "subscription_repository": "SupabaseSubscriptionRepository",
    "user_device_repository": "SupabaseUserDeviceRepository",
    "user_location_repository": "SupabaseUserLocationRepository",
    "weight_measurement_repository": "SupabaseWeightMeasurementRepository",
}

FACTORIES_THAT_REUSE_ONE_INSTANCE = [
    "event_catalog_repository",
    "event_submission_repository",
    "pet_news_service",
]
FACTORIES_RETURNING_NONE_WITHOUT_CONFIGURATION = [
    "apple_signed_data_decoder",
    "radar_open_sources",
    "store_billing_service",
]
FACTORIES_WITH_ARGUMENTS = ["cached_access", "owner_can_write_on_marketplace"]
PROPERTIES = ["photo_reading_enabled"]

PUBLIC_NAMES = [
    "account_deletion_service",
    "account_eraser",
    "account_pause_service",
    "age_gate_service",
    "age_review_admin_service",
    "apple_signed_data_decoder",
    "cached_access",
    "chat_response_report_maintenance_service",
    "chat_usage_maintenance_service",
    "create_listing_service",
    "create_pet_profile_service",
    "create_reminder_service",
    "delete_account_service",
    "delete_conversation_service",
    "edit_chat_message_service",
    "event_catalog_repository",
    "event_submission_repository",
    "export_account_data_service",
    "get_account_consents_service",
    "get_or_create_subscription_service",
    "get_pet_profile_service",
    "hidden_owner_ids",
    "list_chat_response_reports_service",
    "list_conversations_service",
    "list_events_service",
    "list_nearby_listings_service",
    "list_nearby_radar_places_service",
    "list_pet_profiles_service",
    "list_reminders_service",
    "llm_usage_report_service",
    "mark_not_helpful_service",
    "marketplace_messaging_moderation_service",
    "marketplace_messaging_service",
    "owner_can_write_on_marketplace",
    "owner_limits_lookup",
    "pet_news_service",
    "photo_reading_enabled",
    "radar_community_view",
    "radar_open_sources",
    "radar_report_settings",
    "rate_dog_park_service",
    "register_device_service",
    "rename_conversation_service",
    "report_chat_response_service",
    "report_listing_service",
    "resolve_chat_response_report_service",
    "retention_dry_run_service",
    "select_plan_service",
    "send_chat_message_service",
    "set_account_consent_service",
    "set_medical_record_consent_service",
    "store_billing_service",
    "submit_competence_claim_service",
    "submit_event_service",
    "submit_radar_report_service",
    "transcribe_audio_service",
    "travel_cards_service",
    "underage_review_dry_run_service",
    "update_listing_service",
    "update_pet_profile_service",
    "upload_chat_attachment_service",
    "vet_summary_service",
    "vote_radar_report_service",
    "withdraw_radar_report_service",
]

BUILD_HOOKS = [
    "_build_account_age_repository",
    "_build_account_consents_repository",
    "_build_account_deletion_repository",
    "_build_account_eraser",
    "_build_account_exporter",
    "_build_account_pause_repository",
    "_build_answer_cache_repository",
    "_build_auth_provider",
    "_build_chat_attachment_repository",
    "_build_chat_message_key_repository",
    "_build_chat_response_report_repository",
    "_build_clinical_event_repository",
    "_build_deletion_log_service",
    "_build_dog_walk_repository",
    "_build_email_sender",
    "_build_event_catalog_repository",
    "_build_event_submission_repository",
    "_build_evidence_retriever",
    "_build_image_analyzer",
    "_build_inner_auth_provider",
    "_build_listing_report_repository",
    "_build_llm_client",
    "_build_llm_usage_repository",
    "_build_local_activity_repository",
    "_build_marketplace_listing_repository",
    "_build_marketplace_messaging_repository",
    "_build_media_storage",
    "_build_owner_contact_lookup",
    "_build_pet_condition_repository",
    "_build_pet_news_cache",
    "_build_pii_anonymizer",
    "_build_plan_access_sync",
    "_build_radar_catalog_repository",
    "_build_radar_places_repository",
    "_build_radar_reports_repository",
    "_build_repositories",
    "_build_speech_to_text_provider",
    "_build_store_entitlement_repository",
    "_build_subscription_repository",
    "_build_user_device_repository",
    "_build_user_location_repository",
    "_build_weight_measurement_repository",
]

# Attributes that are not collaborators (plain values, caches, the in-memory `None`).
INSTANCE_STATE = [
    "_event_catalog_repository",
    "_event_submission_repository",
    "_pet_news_service",
    "_store_billing",
    "developer_emails",
    "last_verified_access",
    "memorial_pets_max",
    "plan_access_sync",
    "settings",
    "subscription_test_plan",
]

MODULE_NAMES = [
    "ApplicationContainer",
    "_parse_plan_overrides",
    "_resolve_subscription_test_plan",
    "answer_models",
    "get_container",
    "groq_reserve_configured",
    "reset_container",
    "resolve_memorial_pets_max",
]

SUPABASE_SETTINGS = {
    "persistence_backend": "supabase",
    "auth_backend": "supabase",
    "evidence_backend": "supabase",
    "supabase_url": "https://example.invalid",
    "supabase_service_role_key": "service-role-test-value",
    "supabase_anon_key": "anon-test-value",
}


# Choices that would otherwise follow the machine's environment variables (CI, a developer's
# shell): pinned so the recorded classes are the same everywhere.
PINNED = {
    "environment": "development",
    "persistence_backend": "in_memory",
    "auth_backend": "bootstrap",
    "evidence_backend": "in_memory",
    "llm_provider": "echo",
    "pii_anonymizer_backend": "rules",
    "vision_provider": "echo",
    "stt_provider": "echo",
    "billing_account_token_secret": "",
    "subscription_test_plan": "",
    "email_sending_enabled": False,
    "developer_emails": [],
    "billing_plan_overrides": "",
}


def _settings(**update: Any) -> Settings:
    base = Settings(_env_file=None).model_copy(update=PINNED)  # type: ignore[call-arg]
    return base.model_copy(update=update)


def _factories(cls: type = ApplicationContainer) -> list[str]:
    """Public methods that need no argument."""
    names = []
    for name, function in inspect.getmembers(cls, inspect.isfunction):
        if name.startswith("_"):
            continue
        required = [
            p
            for p in inspect.signature(function).parameters.values()
            if p.name != "self" and p.default is p.empty
        ]
        if not required:
            names.append(name)
    return names


def _classes(container: ApplicationContainer) -> dict[str, str]:
    """Concrete class of each collaborator held as a public attribute."""
    held = {}
    for key, value in vars(container).items():
        if key.startswith("_") or key == "settings":
            continue
        if isinstance(value, int | frozenset | dict) or value is None:
            continue
        held[key] = type(value).__name__
    return dict(sorted(held.items()))


class _ClientCalls:
    def __init__(self) -> None:
        self.service = 0
        self.public = 0


@pytest.fixture
def fake_supabase(monkeypatch: pytest.MonkeyPatch) -> Iterator[_ClientCalls]:
    """The database client builders replaced by fakes that count: nothing connects."""
    calls = _ClientCalls()

    def service_client(settings: Settings) -> MagicMock:
        calls.service += 1
        return MagicMock()

    def public_client(settings: Settings) -> MagicMock:
        calls.public += 1
        return MagicMock()

    monkeypatch.setattr(supabase_client, "build_supabase_client", service_client)
    monkeypatch.setattr(supabase_client, "build_supabase_public_client", public_client)
    yield calls


def _holds(obj: object, target: object) -> bool:
    """True when [obj] keeps [target] in one of its attributes (a service and its port)."""
    return any(value is target for value in vars(obj).values())


# --- names ------------------------------------------------------------------------


def test_the_public_surface_of_the_container_is_frozen() -> None:
    public = sorted(n for n in dir(ApplicationContainer) if not n.startswith("_"))
    hooks = sorted(
        n for n in dir(ApplicationContainer) if n.startswith("_") and not n.startswith("__")
    )

    assert public == PUBLIC_NAMES
    assert hooks == BUILD_HOOKS


def test_the_instance_state_after_construction_is_frozen() -> None:
    container = ApplicationContainer(_settings())
    expected = sorted({*INSTANCE_STATE, *IN_MEMORY})

    assert sorted(vars(container)) == expected


def test_the_module_keeps_exporting_the_names_other_code_imports() -> None:
    for name in MODULE_NAMES:
        assert hasattr(container_module, name), name


# --- identity and lifetime --------------------------------------------------------


def test_which_factories_reuse_their_instance_and_which_build_a_new_one() -> None:
    container = ApplicationContainer(_settings())
    same, fresh, nothing = [], [], []
    for name in _factories():
        first, second = getattr(container, name)(), getattr(container, name)()
        if first is None:
            nothing.append(name)
        elif first is second:
            same.append(name)
        else:
            fresh.append(name)

    assert same == FACTORIES_THAT_REUSE_ONE_INSTANCE
    assert nothing == FACTORIES_RETURNING_NONE_WITHOUT_CONFIGURATION
    assert sorted(set(_factories()) - set(same) - set(nothing)) == fresh
    assert (
        sorted(set(PUBLIC_NAMES) - set(_factories()) - set(PROPERTIES)) == FACTORIES_WITH_ARGUMENTS
    )
    assert isinstance(
        inspect.getattr_static(ApplicationContainer, "photo_reading_enabled"), property
    )


def test_the_store_billing_service_is_built_once_when_it_is_configured() -> None:
    container = ApplicationContainer(_settings(billing_account_token_secret="secret-for-tests"))

    first = container.store_billing_service()

    assert first is not None
    assert container.store_billing_service() is first
    assert container._store_billing is first


def test_services_share_the_container_repositories_not_copies() -> None:
    container = ApplicationContainer(_settings())

    assert _holds(container.get_pet_profile_service(), container.pet_profile_repository)
    assert _holds(container.list_reminders_service(), container.reminder_repository)
    assert _holds(container.age_gate_service(), container.account_age_repository)


def test_get_container_is_cached_per_process_and_reset_starts_a_new_one() -> None:
    reset_container()
    first = get_container()

    assert get_container() is first
    assert first.settings is get_container().settings

    reset_container()
    second = get_container()

    assert second is not first
    assert get_container() is second


# --- what tests and jobs override on the instance --------------------------------


def test_replacing_the_eraser_hook_reaches_both_services_that_erase_accounts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    container = ApplicationContainer(_settings())
    fake = object()
    monkeypatch.setattr(container, "_build_account_eraser", lambda: fake)

    assert _holds(container.account_deletion_service(), fake)
    assert _holds(container.account_pause_service(), fake)


def test_replacing_a_repository_or_the_settings_changes_what_the_next_factory_builds(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    container = ApplicationContainer(_settings())
    other_age = type(container.account_age_repository)()
    monkeypatch.setattr(container, "account_age_repository", other_age)
    assert _holds(container.age_gate_service(), other_age)

    assert container.store_billing_service() is None
    container.settings = container.settings.model_copy(update={"billing_account_token_secret": "s"})
    assert container.store_billing_service() is not None


def test_replacing_the_email_and_pii_hooks_after_construction_is_possible(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    container = ApplicationContainer(_settings())
    sentinel = object()
    monkeypatch.setattr(container, "_build_email_sender", lambda: sentinel)
    monkeypatch.setattr(container, "_build_pii_anonymizer", lambda: sentinel)

    assert container._build_email_sender() is sentinel
    assert container._build_pii_anonymizer() is sentinel
    # What was already built at construction is untouched by the later patch.
    assert container.email_sender is not sentinel


def test_the_settings_helpers_and_the_developer_allowlist_keep_their_rules() -> None:
    container = ApplicationContainer(_settings(developer_emails=["Team@Example.com", " "]))

    assert container.developer_emails == frozenset({"team@example.com"})
    assert container_module._parse_plan_overrides("a@example.com:pro,b:nope") == {
        "a@example.com": "pro"
    }
    assert container_module._resolve_subscription_test_plan("") is None
    assert container_module._resolve_subscription_test_plan("not-a-plan") is None
    assert container_module.resolve_memorial_pets_max("0") == container.memorial_pets_max


# --- the two configurations -------------------------------------------------------


def test_in_memory_configuration_wires_in_memory_collaborators() -> None:
    container = ApplicationContainer(_settings())

    assert _classes(container) == IN_MEMORY
    assert container.plan_access_sync is None
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    assert type(inner).__name__ == "BootstrapAuthProvider"


def test_supabase_configuration_wires_supabase_collaborators_with_fake_clients(
    fake_supabase: _ClientCalls,
) -> None:
    container = ApplicationContainer(_settings(**SUPABASE_SETTINGS))

    assert _classes(container) == SUPABASE
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    assert type(inner).__name__ == "SupabaseAuthProvider"
    # Construction asks for the service-role client once per collaborator and for the
    # anon client once (the auth provider); `client.py` turns the former into one per process.
    assert (fake_supabase.service, fake_supabase.public) == (31, 1)


def test_calling_every_factory_builds_only_the_lazy_collaborators_and_no_public_client(
    fake_supabase: _ClientCalls,
) -> None:
    container = ApplicationContainer(_settings(**SUPABASE_SETTINGS))
    for name in _factories():
        getattr(container, name)()

    assert (fake_supabase.service, fake_supabase.public) == (40, 1)
    assert type(container._event_catalog_repository).__name__ == "SupabaseEventCatalogRepository"
    submissions = type(container._event_submission_repository).__name__
    assert submissions == "SupabaseEventSubmissionRepository"
    assert type(container._pet_news_service).__name__ == "GetPetNewsService"
    # The cached ones build no new client when asked again.
    before = fake_supabase.service
    container.pet_news_service()
    container.event_catalog_repository()
    container.event_submission_repository()
    assert fake_supabase.service == before


def test_a_missing_supabase_package_falls_back_to_memory_outside_production(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The optional dependency is missing: development keeps working in memory,
    production refuses to start (`except ModuleNotFoundError` in the builders)."""

    def missing(settings: Settings) -> MagicMock:
        raise ModuleNotFoundError("supabase")

    monkeypatch.setattr(supabase_client, "build_supabase_client", missing)
    monkeypatch.setattr(supabase_client, "build_supabase_public_client", missing)

    container = ApplicationContainer(_settings(**SUPABASE_SETTINGS))
    assert type(container.pet_profile_repository).__name__ == "InMemoryPetProfileRepository"
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    assert type(inner).__name__ == "BootstrapAuthProvider"

    with pytest.raises(ModuleNotFoundError):
        ApplicationContainer(_settings(**SUPABASE_SETTINGS, environment="production"))

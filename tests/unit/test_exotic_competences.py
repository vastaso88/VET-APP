"""'Esperti in esotici': declared exotic-animal competence of vets."""

import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from packages.core.application.ports.radar_catalog_repository import BoundingBox
from packages.core.application.services.list_nearby_radar_places import (
    ListNearbyRadarPlacesInput,
    ListNearbyRadarPlacesService,
)
from packages.core.application.services.radar_reports import (
    ContributionRulesRequiredError,
    RadarCommunityView,
    RadarReportSettings,
    ReportLimitReachedError,
    SubmitCompetenceClaimInput,
    SubmitCompetenceClaimService,
)
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
    RequestRadarPlacesIngestionService,
)
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import (
    AccountConsents,
    AccountConsentType,
    ConsentRecord,
)
from packages.core.domain.radar_places.competences import (
    EXOTIC_GENERAL,
    ExoticCompetence,
    RadarCompetenceClaim,
    groups_from_name,
    groups_from_osm_details,
    matches_group,
)
from packages.core.domain.radar_places.models import RadarDataSource, RadarPlace
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryRadarCatalogRepository,
    InMemoryRadarPlacesRepository,
    InMemoryRadarReportsRepository,
)
from packages.infrastructure.radar_places.overpass_places_source import map_osm_element
from packages.shared.errors.base import ValidationError

LAT, LON = 45.4642, 9.19
READ_AT = datetime(2026, 11, 1, tzinfo=UTC)


def _vet(name: str = "Ambulatorio Esempio", **details: str) -> RadarPlace:
    return RadarPlace(
        coverage_key="catalog",
        place_type="veterinary",
        name=name,
        latitude=LAT,
        longitude=LON,
        source_name="openstreetmap_overpass",
        source_external_id="node/1",
        details=details,
        source_fetched_at=READ_AT,
    )


# ------------------------------------------------------------------ domain


def test_osm_treats_tags_give_groups_and_ignore_dogs_cats_and_no() -> None:
    details = {
        "veterinary:treats:rabbit": "yes",
        "veterinary:treats:ferret": "yes",
        "veterinary:treats:turtle": "yes",
        "veterinary:treats:parrot": "yes",
        "veterinary:treats:fish": "no",
        "veterinary:treats:dog": "yes",
        "veterinary:treats:exotic": "yes",
        "lit": "yes",
    }

    assert groups_from_osm_details(details) == [
        "small_mammal",
        "reptile_amphibian",
        "bird",
        EXOTIC_GENERAL,
    ]


def test_the_osm_mapper_keeps_treats_tags_in_the_details() -> None:
    place = map_osm_element(
        {
            "type": "node",
            "id": 9,
            "lat": LAT,
            "lon": LON,
            "tags": {
                "amenity": "veterinary",
                "name": "Clinica Esempio",
                "veterinary:treats:rabbit": "yes",
            },
        },
        owner_id="",
        coverage_key="catalog",
        fetched_at=READ_AT,
    )

    assert place is not None
    assert place.details == {"veterinary:treats:rabbit": "yes"}


@pytest.mark.parametrize(
    ("name", "groups"),
    [
        ("Ambulatorio Veterinario per Animali Esotici", [EXOTIC_GENERAL]),
        ("Clinica NAC Esempio", [EXOTIC_GENERAL]),
        ("Centro Rettili e Anfibi", ["reptile_amphibian"]),
        ("Studio di Medicina Aviare", ["bird"]),
        ("Clinica Conigli e Furetti", ["small_mammal"]),
        # Strict words only: place names and lookalikes do not count.
        ("Clinica Veterinaria Pescara", []),
        ("Ambulatorio Via degli Uccelli", []),
        ("Ambulatorio Esempio", []),
    ],
)
def test_name_rules_are_strict(name: str, groups: list[str]) -> None:
    assert groups_from_name(name) == groups


def test_a_general_exotic_competence_matches_every_group() -> None:
    general = [ExoticCompetence(group=EXOTIC_GENERAL, source="x", basis="name")]
    birds = [ExoticCompetence(group="bird", source="x", basis="osm_tag")]

    assert matches_group(general, "fish") and matches_group(general, None)
    assert matches_group(birds, "bird") and not matches_group(birds, "fish")
    assert not matches_group([], None)


# ------------------------------------------------------------ nearby service


class _NoSource:
    name = "none"

    def fetch_places(self, request_data: RequestRadarPlacesIngestionInput) -> list[RadarPlace]:
        return []


class _Reports(InMemoryRadarReportsRepository):
    pass


def _world(
    *, name_matching: bool = False
) -> tuple[ListNearbyRadarPlacesService, InMemoryRadarCatalogRepository, _Reports]:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [
        RadarDataSource(
            source="openstreetmap_overpass",
            release="test",
            license="ODbL",
            attribution="test",
            imported_at=READ_AT,
            min_latitude=35.0,
            max_latitude=47.5,
            min_longitude=6.0,
            max_longitude=19.0,
        )
    ]
    reports = _Reports()
    community = RadarCommunityView(
        reports, InMemoryAccountConsentsRepository(), RadarReportSettings(pseudonym_key="k")
    )
    cells = InMemoryRadarPlacesRepository()
    service = ListNearbyRadarPlacesService(
        cells,
        RequestRadarPlacesIngestionService(cells, _NoSource()),
        catalog,
        community,
        max_search_radius_km=50,
        freshness_ttl_hours=168,
        exotic_name_matching=name_matching,
    )
    return service, catalog, reports


def _competences(service: ListNearbyRadarPlacesService) -> dict[str, list[tuple[str, str]]]:
    result = service.execute(ListNearbyRadarPlacesInput(latitude=LAT, longitude=LON))
    return {
        item.place.name: [(c.group, c.basis) for c in item.place.competences]
        for item in result.places
    }


def test_osm_tags_become_competences_with_source_and_reading_date() -> None:
    service, catalog, _ = _world()
    catalog.osm_places = [_vet(**{"veterinary:treats:rabbit": "yes"})]

    place = service.execute(ListNearbyRadarPlacesInput(latitude=LAT, longitude=LON)).places[0]

    assert place.place.competences == [
        ExoticCompetence(
            group="small_mammal",
            source="openstreetmap_overpass",
            basis="osm_tag",
            read_at=READ_AT,
        )
    ]


def test_names_count_only_when_the_switch_is_on() -> None:
    off, catalog, _ = _world()
    catalog.osm_places = [_vet("Ambulatorio per Animali Esotici")]
    assert _competences(off) == {"Ambulatorio per Animali Esotici": []}

    on, catalog, _ = _world(name_matching=True)
    catalog.osm_places = [_vet("Ambulatorio per Animali Esotici")]
    assert _competences(on) == {"Ambulatorio per Animali Esotici": [(EXOTIC_GENERAL, "name")]}


def _claim(status: str, **extra: object) -> RadarCompetenceClaim:
    return RadarCompetenceClaim(
        target_source="openstreetmap_overpass",
        target_source_id="node/1",
        place_name="Ambulatorio Esempio",
        latitude=LAT,
        longitude=LON,
        groups=["bird", "fish"],
        evidence_kind="website",
        status=status,  # type: ignore[arg-type]
        reporter_pseudonym="p",
        **extra,  # type: ignore[arg-type]
    )


def test_only_confirmed_claims_add_competences_with_their_evidence() -> None:
    service, catalog, reports = _world()
    catalog.osm_places = [_vet()]
    reports.save_claim(_claim("pending"))
    assert _competences(service) == {"Ambulatorio Esempio": []}

    reports.save_claim(
        _claim(
            "confirmed",
            resolved_at=READ_AT,
            evidence_url="https://www.example.com/servizi",
        )
    )
    place = service.execute(ListNearbyRadarPlacesInput(latitude=LAT, longitude=LON)).places[0]
    assert [(c.group, c.basis, c.evidence_url) for c in place.place.competences] == [
        ("bird", "confirmed_claim", "https://www.example.com/servizi"),
        ("fish", "confirmed_claim", "https://www.example.com/servizi"),
    ]


def test_competences_are_never_stored_with_the_place() -> None:
    from packages.core.domain.radar_places.models import RADAR_PLACE_TRANSIENT_FIELDS

    assert "competences" in RADAR_PLACE_TRANSIENT_FIELDS


# ------------------------------------------------------------- claim service


def _claims_service(
    *, reports_enabled: bool = True, daily_limit: int = 5
) -> tuple[
    SubmitCompetenceClaimService, InMemoryRadarReportsRepository, InMemoryAccountConsentsRepository
]:
    reports = InMemoryRadarReportsRepository()
    consents = InMemoryAccountConsentsRepository()
    settings = RadarReportSettings(
        pseudonym_key="k", reports_enabled=reports_enabled, daily_limit=daily_limit
    )
    return SubmitCompetenceClaimService(reports, consents, settings), reports, consents


def _accept(consents: InMemoryAccountConsentsRepository, user: str) -> None:
    consents.save(
        AccountConsents(
            owner_id=user,
            consents={
                AccountConsentType.CONTRIBUTION_RULES: ConsentRecord(
                    granted=True, version=CURRENT_VERSIONS[AccountConsentType.CONTRIBUTION_RULES]
                )
            },
        )
    )


def _claim_input(user: str, place: RadarPlace | None = None, **extra: object):  # type: ignore[no-untyped-def]
    data: dict[str, object] = {"groups": ["bird"], "evidence_kind": "website"}
    data.update(extra)
    return SubmitCompetenceClaimInput(user_id=user, place=place or _vet(), **data)  # type: ignore[arg-type]


def test_a_claim_needs_the_rules_and_stays_pending_under_a_pseudonym() -> None:
    service, reports, consents = _claims_service()
    with pytest.raises(ContributionRulesRequiredError):
        service.execute(_claim_input("anna"))

    _accept(consents, "anna")
    claim = service.execute(_claim_input("anna", groups=["fish", "bird"]))

    assert claim.status == "pending"
    assert claim.groups == ["bird", "fish"]
    assert claim.reporter_pseudonym and "anna" not in claim.reporter_pseudonym
    box = BoundingBox(LAT - 1, LAT + 1, LON - 1, LON + 1)
    assert reports.list_claims(box, statuses=["confirmed"]) == []


def test_claims_are_refused_for_non_vets_unknown_groups_and_twice() -> None:
    service, _, consents = _claims_service()
    _accept(consents, "anna")
    shop = _vet().model_copy(update={"place_type": "shop"})

    with pytest.raises(ValidationError):
        service.execute(_claim_input("anna", place=shop))
    with pytest.raises(ValidationError):
        service.execute(_claim_input("anna", groups=["dog"]))
    with pytest.raises(ValidationError):
        service.execute(_claim_input("anna", groups=[]))

    service.execute(_claim_input("anna"))
    with pytest.raises(ValidationError):
        service.execute(_claim_input("anna"))


def test_claims_follow_the_daily_limit_and_the_reports_switch() -> None:
    service, reports, consents = _claims_service(daily_limit=1)
    _accept(consents, "anna")
    service.execute(_claim_input("anna"))
    other = _vet().model_copy(update={"source_external_id": "node/2"})
    with pytest.raises(ReportLimitReachedError):
        service.execute(_claim_input("anna", place=other))
    # Older claims do not count.
    for claim in list(reports._claims.values()):
        reports.save_claim(
            claim.model_copy(update={"created_at": claim.created_at - timedelta(days=2)})
        )
    service.execute(_claim_input("anna", place=other))

    off, _, consents = _claims_service(reports_enabled=False)
    _accept(consents, "anna")
    with pytest.raises(ValidationError):
        off.execute(_claim_input("anna"))


# --------------------------------------------------------------------- SQL


def test_the_sql_script_matches_the_schema_and_locks_the_table() -> None:
    script = Path("scripts/setup/radar_exotic_competences.sql").read_text(encoding="utf-8")
    schema = Path("scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    block = script[script.index("create table if not exists public.radar_competence_claims") :]

    assert block in schema
    assert "enable row level security" in block
    assert "revoke all on table public.radar_competence_claims from anon, authenticated" in block
    # No policy: only the backend reads and writes it.
    assert not re.search(r"create policy[^;]*radar_competence_claims", schema, re.IGNORECASE)

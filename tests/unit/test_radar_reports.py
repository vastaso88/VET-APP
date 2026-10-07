from datetime import timedelta
from typing import Any

import pytest

from packages.core.application.ports.radar_catalog_repository import BoundingBox
from packages.core.application.services.radar_reports import (
    ContributionRulesRequiredError,
    RadarCommunityView,
    RadarReportSettings,
    RateDogParkInput,
    RateDogParkService,
    ReportLimitReachedError,
    SubmitRadarReportInput,
    SubmitRadarReportService,
    VoteRadarReportInput,
    VoteRadarReportService,
    WithdrawRadarReportInput,
    WithdrawRadarReportService,
)
from packages.core.domain.consent.models import AccountConsents, ConsentRecord
from packages.core.domain.radar_places.models import RadarPlace
from packages.core.domain.radar_reports.models import (
    USER_SOURCE_NAME,
    RadarPlaceOverride,
    apply_overrides,
    clean_place_name,
    coarsen_position,
    contributor_pseudonym,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryRadarReportsRepository,
)
from packages.shared.errors.base import ValidationError

LAT, LON = 45.4642, 9.1900
BOX = BoundingBox(min_latitude=45.3, max_latitude=45.6, min_longitude=9.0, max_longitude=9.4)


class _World:
    """Repositories plus the three services, with a small threshold so a
    test can reach "confirmed" with a handful of users."""

    def __init__(self, **overrides: object) -> None:
        self.reports = InMemoryRadarReportsRepository()
        self.consents = InMemoryAccountConsentsRepository()
        self.settings = RadarReportSettings(
            pseudonym_key="test-key",
            confirmations_required=2,
            closed_confirmations_required=2,
            daily_limit=3,
            missing_place_types=RadarReportSettings(pseudonym_key="k").missing_place_types,
            **overrides,  # type: ignore[arg-type]
        )
        args = (self.reports, self.consents, self.settings)
        self.submit = SubmitRadarReportService(*args)
        self.vote = VoteRadarReportService(*args)
        self.rate = RateDogParkService(*args)
        self.view = RadarCommunityView(*args)
        self.withdraw = WithdrawRadarReportService(*args)

    def age(self, report_id: str, *, days: float) -> None:
        """Makes a report look as if it was made `days` ago."""
        report = self.reports.get_report(report_id)
        assert report is not None
        self.reports.save_report(
            report.model_copy(update={"created_at": report.created_at - timedelta(days=days)})
        )

    def accept_rules(self, *users: str) -> None:
        for user in users:
            self.consents.save(
                AccountConsents(
                    owner_id=user,
                    consents={"contribution_rules": ConsentRecord(granted=True, version="v2")},
                )
            )

    def report_missing(self, user: str, name: str = "Toelettatura Bau", **kwargs: object) -> str:
        data = {"place_type": "grooming", "name": name, "latitude": LAT, "longitude": LON}
        data.update(kwargs)
        return self.submit.execute(
            SubmitRadarReportInput(user_id=user, kind="missing", **data)  # type: ignore[arg-type]
        ).report.id


def _dog_park(**details: str) -> RadarPlace:
    return RadarPlace(
        coverage_key="catalog",
        place_type="dog_park",
        name="Area cani",
        latitude=LAT,
        longitude=LON,
        source_name="openstreetmap_overpass",
        source_external_id="way/1",
        details=details,
    )


def test_pseudonym_is_stable_keyed_and_not_the_user_id() -> None:
    first = contributor_pseudonym("user-1", key="k1")

    assert first == contributor_pseudonym("user-1", key="k1")
    assert first != contributor_pseudonym("user-1", key="k2")
    assert first != contributor_pseudonym("user-2", key="k1")
    assert "user-1" not in first


def test_place_name_rules() -> None:
    assert clean_place_name("  Toelettatura   Bau ", place_type="grooming") == "Toelettatura Bau"
    assert clean_place_name(None, place_type="dog_park") == "Area cani"
    for bad in (
        "",
        "Bau 02 0000 0001",
        "bau@esempio.example",
        "www.esempio.example",
        "x" * 61,
        "Merda di posto",
    ):
        with pytest.raises(ValidationError):
            clean_place_name(bad, place_type="grooming")


def test_home_based_categories_get_a_coarse_position() -> None:
    world = _World()
    world.accept_rules("anna")

    report_id = world.report_missing(
        "anna", name="Pensione Fido", place_type="hotel", latitude=45.46421, longitude=9.19037
    )

    report = world.reports.get_report(report_id)
    assert report is not None
    assert (report.latitude, report.longitude) == coarsen_position(45.46421, 9.19037)
    assert (report.latitude, report.longitude) != (45.46421, 9.19037)


def test_rules_must_be_accepted_before_contributing() -> None:
    world = _World()

    with pytest.raises(ContributionRulesRequiredError):
        world.report_missing("anna")
    with pytest.raises(ContributionRulesRequiredError):
        world.rate.execute(RateDogParkInput(user_id="anna", place=_dog_park(), stars=5))


def test_missing_place_is_pending_then_confirmed_by_other_users() -> None:
    world = _World()
    world.accept_rules("anna", "bruno", "carla")
    report_id = world.report_missing("anna")

    pending = world.view.user_places(BOX)
    assert [(place.name, place.source_name) for place in pending] == [
        ("Toelettatura Bau", USER_SOURCE_NAME)
    ]

    world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))
    assert world.reports.get_report(report_id).status == "pending"  # type: ignore[union-attr]
    world.vote.execute(VoteRadarReportInput(user_id="carla", report_id=report_id, confirm=True))

    report = world.reports.get_report(report_id)
    assert report is not None
    assert (report.status, report.confirmations) == ("confirmed", 2)
    assert report.resolved_at is not None


def test_the_reporter_cannot_confirm_and_a_vote_counts_once() -> None:
    world = _World()
    world.accept_rules("anna", "bruno")
    report_id = world.report_missing("anna")

    with pytest.raises(ValidationError):
        world.vote.execute(VoteRadarReportInput(user_id="anna", report_id=report_id, confirm=True))
    for _ in range(3):
        world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))

    report = world.reports.get_report(report_id)
    assert report is not None
    assert (report.status, report.confirmations) == ("pending", 1)


def test_denials_subtract_and_three_net_denials_reject() -> None:
    world = _World()
    world.accept_rules("anna", "bruno", "carla", "dario", "elena")
    report_id = world.report_missing("anna")

    world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))
    for user in ("carla", "dario", "elena"):
        world.vote.execute(VoteRadarReportInput(user_id=user, report_id=report_id, confirm=False))
    assert world.reports.get_report(report_id).status == "pending"  # type: ignore[union-attr]

    world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=False))

    assert world.reports.get_report(report_id).status == "rejected"  # type: ignore[union-attr]
    assert world.view.user_places(BOX) == []


def test_reporting_the_same_missing_place_again_confirms_the_first_report() -> None:
    world = _World()
    world.accept_rules("anna", "bruno")
    first = world.report_missing("anna")

    result = world.submit.execute(
        SubmitRadarReportInput(
            user_id="bruno",
            kind="missing",
            place_type="grooming",
            name="Bau toelettatura",
            latitude=LAT + 0.0002,
            longitude=LON,
        )
    )

    assert result.counted_as_confirmation
    assert result.report.id == first
    assert result.report.confirmations == 1


def test_daily_limit() -> None:
    world = _World()
    world.accept_rules("anna")
    for index in range(3):
        world.report_missing("anna", name=f"Negozio {index}", latitude=LAT + index * 0.01)

    with pytest.raises(ReportLimitReachedError):
        world.report_missing("anna", name="Negozio 9", latitude=LAT + 0.09)


def test_categories_not_enabled_are_refused() -> None:
    world = _World()
    world.accept_rules("anna")

    with pytest.raises(ValidationError):
        world.report_missing("anna", name="Sitter", place_type="pet_sitting")


def test_confirmed_closure_excludes_the_place_and_its_twin_in_another_source() -> None:
    world = _World()
    world.accept_rules("anna", "bruno", "carla")

    def report_closed(user: str) -> None:
        world.submit.execute(
            SubmitRadarReportInput(
                user_id=user,
                kind="closed",
                place_type="veterinary",
                name="Clinica Duomo",
                latitude=LAT,
                longitude=LON,
                target_source="overture",
                target_source_id="abc",
            )
        )

    report_closed("anna")
    # Independent reports of the same closure are its confirmations.
    report_closed("bruno")
    assert world.reports.list_overrides() == []
    report_closed("carla")

    def place(source: str, source_id: str, meters_north: float = 0) -> RadarPlace:
        return RadarPlace(
            coverage_key="catalog",
            place_type="veterinary",
            name="Clinica Duomo",
            latitude=LAT + meters_north / 111_320,
            longitude=LON,
            source_name=source,
            source_external_id=source_id,
        )

    remaining = world.view.without_excluded(
        [
            place("overture", "abc"),
            place("openstreetmap_overpass", "node/9", meters_north=10),
            place("openstreetmap_overpass", "node/10", meters_north=500),
        ]
    )

    assert [item.source_external_id for item in remaining] == ["node/10"]


def test_overrides_without_a_position_exclude_by_id_only() -> None:
    places = [
        RadarPlace(
            coverage_key="c",
            place_type="shop",
            name="A",
            latitude=LAT,
            longitude=LON,
            source_name="overture",
            source_external_id=identifier,
        )
        for identifier in ("x", "y")
    ]

    remaining = apply_overrides(places, [RadarPlaceOverride(source="overture", source_id="x")])

    assert [place.source_external_id for place in remaining] == ["y"]


def test_ratings_show_an_average_only_from_three_votes_and_are_replaceable() -> None:
    world = _World()
    world.accept_rules("anna", "bruno", "carla")
    park = _dog_park()

    world.rate.execute(RateDogParkInput(user_id="anna", place=park, stars=2))
    world.rate.execute(RateDogParkInput(user_id="anna", place=park, stars=5))
    world.rate.execute(RateDogParkInput(user_id="bruno", place=park, stars=4))
    rating = world.view.extras([park], BOX, viewer_id="anna")[park.id]["rating"]
    assert (rating["count"], rating["average"], rating["viewer_stars"]) == (2, None, 5)

    world.rate.execute(RateDogParkInput(user_id="carla", place=park, stars=3))
    rating = world.view.extras([park], BOX, viewer_id="carla")[park.id]["rating"]
    assert (rating["count"], rating["average"], rating["viewer_stars"]) == (3, 4.0, 3)


def test_only_public_dog_parks_can_be_rated() -> None:
    world = _World()
    world.accept_rules("anna")

    for place in (
        _dog_park(fee="yes"),
        _dog_park(access="customers"),
        _dog_park().model_copy(update={"place_type": "veterinary"}),
    ):
        with pytest.raises(ValidationError):
            world.rate.execute(RateDogParkInput(user_id="anna", place=place, stars=5))
        assert "rating" not in world.view.extras([place], BOX, viewer_id="anna").get(place.id, {})


def test_extras_tell_the_viewer_about_their_own_vote_but_never_who_reported() -> None:
    world = _World()
    world.accept_rules("anna", "bruno")
    report_id = world.report_missing("anna")
    world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))
    place = world.view.user_places(BOX)[0]

    for_reporter = world.view.extras([place], BOX, viewer_id="anna")[place.id]["community"]
    for_voter = world.view.extras([place], BOX, viewer_id="bruno")[place.id]["community"]

    assert for_reporter["viewer_is_reporter"] and for_reporter["viewer_vote"] is None
    assert not for_voter["viewer_is_reporter"] and for_voter["viewer_vote"] == 1
    assert (for_voter["confirmations"], for_voter["required"]) == (1, 2)
    assert "anna" not in str(for_voter) and "pseudonym" not in str(for_voter)


def test_pending_closures_are_shown_only_when_enabled() -> None:
    def closure_extras(world: _World) -> dict[str, object]:
        world.accept_rules("anna")
        world.submit.execute(
            SubmitRadarReportInput(
                user_id="anna",
                kind="closed",
                place_type="veterinary",
                name="Clinica Duomo",
                latitude=LAT,
                longitude=LON,
                target_source="overture",
                target_source_id="abc",
            )
        )
        place = RadarPlace(
            coverage_key="catalog",
            place_type="veterinary",
            name="Clinica Duomo",
            latitude=LAT,
            longitude=LON,
            source_name="overture",
            source_external_id="abc",
        )
        return world.view.extras([place], BOX, viewer_id="bruno").get(place.id, {})

    assert "pending_closure" not in closure_extras(_World())
    assert "pending_closure" in closure_extras(_World(show_pending_closures=True))


def test_a_reported_dog_park_cannot_be_rated_until_it_is_confirmed() -> None:
    world = _World()
    world.accept_rules("anna", "bruno", "carla")
    report_id = world.report_missing("anna", name="", place_type="dog_park")
    pending = world.view.user_places(BOX)[0]

    assert pending.name == "Area cani"
    assert "rating" not in world.view.extras([pending], BOX, viewer_id="bruno")[pending.id]
    with pytest.raises(ValidationError):
        world.rate.execute(RateDogParkInput(user_id="bruno", place=pending, stars=5))

    for user in ("bruno", "carla"):
        world.vote.execute(VoteRadarReportInput(user_id=user, report_id=report_id, confirm=True))
    confirmed = world.view.user_places(BOX)[0]

    assert world.view.extras([confirmed], BOX, viewer_id="bruno")[confirmed.id]["rating"][
        "can_rate"
    ]
    world.rate.execute(RateDogParkInput(user_id="bruno", place=confirmed, stars=5))


def test_dog_parks_are_reportable_by_default() -> None:
    assert "dog_park" in RadarReportSettings(pseudonym_key="k").missing_place_types


def test_accepting_an_older_version_of_the_rules_is_not_enough() -> None:
    world = _World()
    world.consents.save(
        AccountConsents(
            owner_id="anna",
            consents={"contribution_rules": ConsentRecord(granted=True, version="v1")},
        )
    )

    with pytest.raises(ContributionRulesRequiredError):
        world.report_missing("anna")


def _closed_report(user: str) -> SubmitRadarReportInput:
    return SubmitRadarReportInput(
        user_id=user,
        kind="closed",
        place_type="veterinary",
        name="Clinica Esempio",
        latitude=LAT,
        longitude=LON,
        target_source="overture",
        target_source_id="abc",
    )


def test_switches_are_all_on_by_default() -> None:
    settings = _World().settings

    assert settings.report_kinds() == ["missing", "closed", "duplicate", "wrong_position"]
    assert settings.ratings_enabled is True


def test_reports_switched_off_hide_user_places_and_refuse_new_ones() -> None:
    on = _World()
    on.accept_rules("anna", "bruno")
    report_id = on.report_missing("anna")
    assert [place.name for place in on.view.user_places(BOX)] == ["Toelettatura Bau"]

    # Same data, switch off: nothing is deleted, nothing is shown or accepted.
    off = _World(reports_enabled=False)
    off.reports, off.consents = on.reports, on.consents
    args = (on.reports, on.consents, off.settings)
    view = RadarCommunityView(*args)
    place = on.reports.get_report(report_id).as_place()  # type: ignore[union-attr]

    assert off.settings.report_kinds() == []
    assert view.user_places(BOX) == []
    assert "community" not in view.extras([place], BOX, viewer_id="bruno").get(place.id, {})
    with pytest.raises(ValidationError):
        SubmitRadarReportService(*args).execute(
            SubmitRadarReportInput(
                user_id="bruno",
                kind="missing",
                place_type="grooming",
                name="Toelettatura Miao",
                latitude=LAT,
                longitude=LON,
            )
        )
    with pytest.raises(ValidationError):
        VoteRadarReportService(*args).execute(
            VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True)
        )
    assert on.reports.get_report(report_id) is not None


def test_closed_reports_switched_off_leave_the_other_kinds_working() -> None:
    on = _World(show_pending_closures=True)
    on.accept_rules("anna", "bruno")
    closed_id = on.submit.execute(_closed_report("anna")).report.id

    off_settings = on.settings.model_copy(update={"closed_reports_enabled": False})
    args = (on.reports, on.consents, off_settings)
    place = RadarPlace(
        coverage_key="catalog",
        place_type="veterinary",
        name="Clinica Esempio",
        latitude=LAT,
        longitude=LON,
        source_name="overture",
        source_external_id="abc",
    )

    assert "closed" not in off_settings.report_kinds()
    assert "pending_closure" in on.view.extras([place], BOX, viewer_id="bruno")[place.id]
    assert RadarCommunityView(*args).extras([place], BOX, viewer_id="bruno") == {}
    with pytest.raises(ValidationError):
        SubmitRadarReportService(*args).execute(_closed_report("bruno"))
    with pytest.raises(ValidationError):
        VoteRadarReportService(*args).execute(
            VoteRadarReportInput(user_id="bruno", report_id=closed_id, confirm=True)
        )
    # A missing place is still accepted.
    created = SubmitRadarReportService(*args).execute(
        SubmitRadarReportInput(
            user_id="bruno",
            kind="missing",
            place_type="grooming",
            name="Toelettatura Bau",
            latitude=LAT,
            longitude=LON,
        )
    )
    assert created.report.status == "pending"


def test_ratings_switched_off_hide_stars_and_refuse_new_ones() -> None:
    on = _World()
    on.accept_rules("anna")
    park = _dog_park()
    on.rate.execute(RateDogParkInput(user_id="anna", place=park, stars=4))
    assert on.view.extras([park], BOX, viewer_id="anna")[park.id]["rating"]["viewer_stars"] == 4

    off_settings = on.settings.model_copy(update={"ratings_enabled": False})
    args = (on.reports, on.consents, off_settings)

    assert RadarCommunityView(*args).extras([park], BOX, viewer_id="anna") == {}
    with pytest.raises(ValidationError):
        RateDogParkService(*args).execute(RateDogParkInput(user_id="anna", place=park, stars=5))
    # Reports are a separate switch.
    assert off_settings.report_kinds() == ["missing", "closed", "duplicate", "wrong_position"]


def _community(world: _World, report_id: str, viewer: str) -> dict[str, Any]:
    report = world.reports.get_report(report_id)
    assert report is not None
    place = report.as_place()
    extras = world.view.extras([place], BOX, viewer_id=viewer)
    community: dict[str, Any] = extras.get(place.id, {}).get("community", {})
    return community


def test_the_reporter_can_withdraw_a_pending_report_and_its_votes_go_too() -> None:
    world = _World()
    world.accept_rules("anna", "bruno")
    report_id = world.report_missing("anna")
    world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))

    world.withdraw.execute(WithdrawRadarReportInput(user_id="anna", report_id=report_id))

    assert world.reports.get_report(report_id) is None
    assert world.reports.list_votes(report_id) == []
    assert world.view.user_places(BOX) == []


def test_only_the_reporter_can_withdraw_and_only_while_pending() -> None:
    world = _World()
    world.accept_rules("anna", "bruno", "carla")
    report_id = world.report_missing("anna")

    with pytest.raises(ValidationError):
        world.withdraw.execute(WithdrawRadarReportInput(user_id="bruno", report_id=report_id))
    with pytest.raises(ValidationError):
        world.withdraw.execute(WithdrawRadarReportInput(user_id="anna", report_id="unknown"))

    for user in ("bruno", "carla"):
        world.vote.execute(VoteRadarReportInput(user_id=user, report_id=report_id, confirm=True))
    # Confirmed by others: it is no longer the reporter's alone to remove.
    with pytest.raises(ValidationError):
        world.withdraw.execute(WithdrawRadarReportInput(user_id="anna", report_id=report_id))
    assert world.reports.get_report(report_id) is not None


def test_a_report_nobody_confirmed_tells_how_many_days_it_has_left() -> None:
    world = _World()
    world.accept_rules("anna")
    report_id = world.report_missing("anna")

    assert _community(world, report_id, "anna")["expires_in_days"] == 7
    world.age(report_id, days=5.5)
    assert _community(world, report_id, "anna")["expires_in_days"] == 2


def test_a_report_nobody_confirmed_in_seven_days_is_no_longer_served() -> None:
    world = _World()
    world.accept_rules("anna", "bruno")
    report_id = world.report_missing("anna")
    world.age(report_id, days=7.1)

    assert world.view.user_places(BOX) == []
    with pytest.raises(ValidationError):
        world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))
    # The same place reported again is a new report, not a confirmation of
    # the expired one.
    again = world.submit.execute(
        SubmitRadarReportInput(
            user_id="bruno",
            kind="missing",
            place_type="grooming",
            name="Toelettatura Bau",
            latitude=LAT,
            longitude=LON,
        )
    )
    assert again.counted_as_confirmation is False


def test_one_confirmation_keeps_a_report_waiting_past_seven_days() -> None:
    world = _World()
    world.accept_rules("anna", "bruno")
    report_id = world.report_missing("anna")
    world.vote.execute(VoteRadarReportInput(user_id="bruno", report_id=report_id, confirm=True))
    world.age(report_id, days=30)

    assert [place.name for place in world.view.user_places(BOX)] == ["Toelettatura Bau"]
    assert _community(world, report_id, "anna")["expires_in_days"] is None


def test_the_expiry_length_is_configurable() -> None:
    world = _World(expiry_days=2)
    world.accept_rules("anna")
    report_id = world.report_missing("anna")
    world.age(report_id, days=2.5)

    assert world.view.user_places(BOX) == []


def test_one_snapshot_serves_a_whole_radar_answer_with_a_single_read_of_each_table() -> None:
    world = _World()
    world.accept_rules("anna")
    report_id = world.report_missing("anna")
    calls: list[str] = []
    for name in ("list_reports", "list_overrides", "list_ratings"):
        original = getattr(world.reports, name)

        def counted(*args: Any, _name: str = name, _original: Any = original, **kwargs: Any) -> Any:
            calls.append(_name)
            return _original(*args, **kwargs)

        setattr(world.reports, name, counted)

    snapshot = world.view.snapshot(BOX)
    places = world.view.without_excluded(world.view.user_places(BOX, snapshot), snapshot)
    extras = world.view.extras(places, BOX, viewer_id="anna", snapshot=snapshot)

    assert sorted(calls) == ["list_overrides", "list_ratings", "list_reports"]
    assert extras[places[0].id]["community"]["report_id"] == report_id


def test_shelters_are_reportable_as_missing_by_default() -> None:
    from packages.shared.config.settings import Settings

    assert "shelter" in RadarReportSettings(pseudonym_key="k").missing_place_types
    assert "shelter" in Settings().radar_report_place_types

    world = _World()
    world.accept_rules("anna")
    report_id = world.report_missing("anna", name="Rifugio Esempio", place_type="shelter")

    places = world.view.user_places(BOX)
    assert [(place.place_type, place.name) for place in places] == [("shelter", "Rifugio Esempio")]
    assert places[0].source_external_id == report_id


def test_the_reportable_list_can_still_be_narrowed_from_the_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from packages.shared.config.settings import Settings

    monkeypatch.setenv("RADAR_REPORT_PLACE_TYPES", "veterinary,shop")
    assert Settings().radar_report_place_types == ["veterinary", "shop"]
    monkeypatch.setenv("RADAR_REPORT_PLACE_TYPES", '["veterinary","shelter"]')
    assert Settings().radar_report_place_types == ["veterinary", "shelter"]

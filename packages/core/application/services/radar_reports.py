from collections import defaultdict
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from typing import Any

from pydantic import BaseModel

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.radar_catalog_repository import BoundingBox
from packages.core.application.ports.radar_reports_repository import RadarReportsRepository
from packages.core.domain.common.entity import utc_now
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.radar_places.models import RadarPlace
from packages.core.domain.radar_reports.models import (
    HOME_BASED_PLACE_TYPES,
    MIN_RATINGS_TO_SHOW,
    USER_SOURCE_NAME,
    RadarPlaceOverride,
    RadarPlaceRating,
    RadarReportVote,
    RadarUserReport,
    ReportKind,
    apply_overrides,
    clean_place_name,
    coarsen_position,
    contributor_pseudonym,
    is_publicly_ratable,
)
from packages.shared.errors.base import ValidationError, VetAppError

# Two "missing place" reports of the same category this close are the same
# report: the second person is confirming the first.
_SAME_REPORT_METERS = 50.0
_KINDS_REMOVING_THE_PLACE = frozenset({"closed", "duplicate"})


class ContributionRulesRequiredError(VetAppError):
    """The user has not accepted the contribution rules yet."""


class ReportLimitReachedError(VetAppError):
    """Too many reports from this account today."""


KIND_NOT_ACTIVE_MESSAGE = "Questo tipo di segnalazione non è attivo."


class RadarReportSettings(BaseModel):
    pseudonym_key: str
    confirmations_required: int = 5
    closed_confirmations_required: int = 5
    daily_limit: int = 5
    # Categories that can be reported as missing.
    missing_place_types: frozenset[str] = frozenset(
        {"veterinary", "grooming", "shop", "hotel", "dog_park"}
    )
    # Whether a pending "closed" report is shown to everyone on the place.
    show_pending_closures: bool = False
    # Switches (see Settings): reports and votes, the "closed" kind alone,
    # dog-park stars.
    # A pending report nobody confirmed even once is dropped after this
    # many days; with one confirmation it waits for the others.
    expiry_days: int = 7
    reports_enabled: bool = True
    closed_reports_enabled: bool = True
    ratings_enabled: bool = True

    def report_kinds(self) -> list[str]:
        """Kinds of report accepted right now."""
        if not self.reports_enabled:
            return []
        return [
            kind
            for kind in ("missing", "closed", "duplicate", "wrong_position")
            if kind != "closed" or self.closed_reports_enabled
        ]

    def accepts(self, kind: str) -> bool:
        return kind in self.report_kinds()

    def required_for(self, kind: str) -> int:
        return (
            self.closed_confirmations_required if kind == "closed" else self.confirmations_required
        )


class _Contributions:
    """What the three services share: who the caller is (as a pseudonym)
    and whether they may contribute at all."""

    def __init__(
        self,
        repository: RadarReportsRepository,
        consents: AccountConsentsRepository,
        settings: RadarReportSettings,
    ) -> None:
        self._repository = repository
        self._consents = consents
        self._settings = settings

    def _pseudonym(self, user_id: str) -> str:
        return contributor_pseudonym(user_id, key=self._settings.pseudonym_key)

    def _require_rules_accepted(self, user_id: str) -> None:
        record = self._consents.get(user_id)
        consent = record.consents.get(AccountConsentType.CONTRIBUTION_RULES) if record else None
        # Accepting an older wording does not cover the current one.
        current = CURRENT_VERSIONS[AccountConsentType.CONTRIBUTION_RULES]
        if consent is None or not consent.granted or consent.version != current:
            raise ContributionRulesRequiredError(
                "Per segnalare o votare accetta prima le regole per segnalazioni e voti."
            )

    def _is_live(self, report: RadarUserReport) -> bool:
        """False for a report that expired unconfirmed. Checked wherever
        reports are read, so expiry does not depend on the cleanup job
        having run (scripts/radar/cleanup_reports.py deletes them)."""
        return not report.is_expired(expiry_days=self._settings.expiry_days)

    def _live_reports(
        self, box: BoundingBox, *, kinds: list[str], statuses: list[str]
    ) -> list[RadarUserReport]:
        return [
            report
            for report in self._repository.list_reports(box, kinds=kinds, statuses=statuses)
            if self._is_live(report)
        ]

    def _register_vote(self, report: RadarUserReport, voter: str, value: int) -> RadarUserReport:
        """Records one person's vote (replacing their previous one) and
        resolves the report if the tallies now decide it."""
        if report.status != "pending":
            raise ValidationError("Questa segnalazione è già stata chiusa.")
        if not self._is_live(report):
            raise ValidationError("Questa segnalazione è scaduta: nessuno l'ha confermata.")
        if voter == report.reporter_pseudonym:
            raise ValidationError("Non puoi confermare una tua segnalazione.")
        self._repository.save_vote(
            RadarReportVote(report_id=report.id, voter_pseudonym=voter, vote=value)
        )
        votes = self._repository.list_votes(report.id)
        tallied = report.model_copy(
            update={
                "confirmations": sum(1 for vote in votes if vote.vote > 0),
                "denials": sum(1 for vote in votes if vote.vote < 0),
            }
        )
        status = tallied.resolved_status(
            required_confirmations=self._settings.required_for(report.kind)
        )
        if status != "pending":
            tallied = tallied.model_copy(update={"status": status, "resolved_at": utc_now()})
            if status == "confirmed" and report.kind in _KINDS_REMOVING_THE_PLACE:
                self._exclude_target(tallied)
        return self._repository.save_report(tallied)

    def _exclude_target(self, report: RadarUserReport) -> None:
        if report.target_source is None or report.target_source_id is None:
            return
        self._repository.save_override(
            RadarPlaceOverride(
                source=report.target_source,
                source_id=report.target_source_id,
                reason=f"report:{report.kind}:{report.id}",
                place_type=report.place_type,
                latitude=report.latitude,
                longitude=report.longitude,
            )
        )


class SubmitRadarReportInput(BaseModel):
    user_id: str
    kind: ReportKind
    place_type: str
    name: str | None = None
    latitude: float
    longitude: float
    address_label: str | None = None
    target_source: str | None = None
    target_source_id: str | None = None


class SubmitRadarReportOutput(BaseModel):
    report: RadarUserReport
    # True when the same thing had already been reported: this submission
    # was counted as a confirmation of that report instead of a new one.
    counted_as_confirmation: bool


class SubmitRadarReportService(_Contributions):
    """ "Segnala!": a missing place, or an existing one that has closed, is
    a duplicate or is in the wrong position."""

    def execute(self, data: SubmitRadarReportInput) -> SubmitRadarReportOutput:
        if not self._settings.accepts(data.kind):
            raise ValidationError(KIND_NOT_ACTIVE_MESSAGE)
        self._require_rules_accepted(data.user_id)
        reporter = self._pseudonym(data.user_id)

        if data.kind == "missing":
            if data.place_type not in self._settings.missing_place_types:
                raise ValidationError("Questa categoria non può essere segnalata.")
            name = clean_place_name(data.name, place_type=data.place_type)
            latitude, longitude = data.latitude, data.longitude
            if data.place_type in HOME_BASED_PLACE_TYPES:
                latitude, longitude = coarsen_position(latitude, longitude)
        else:
            if not data.target_source or not data.target_source_id:
                raise ValidationError("Indica il luogo a cui si riferisce la segnalazione.")
            if data.target_source == USER_SOURCE_NAME:
                raise ValidationError(
                    'Per un luogo in attesa di conferma usa "Non è così" sulla sua scheda.'
                )
            # The name is the target's own, echoed by the app for the
            # moderation queue: not user-authored text.
            name = (data.name or "").strip()[:120] or "Luogo"
            latitude, longitude = data.latitude, data.longitude

        existing = self._find_same_pending(data, latitude, longitude)
        if existing is not None:
            if existing.reporter_pseudonym == reporter:
                raise ValidationError("Hai già fatto questa segnalazione.")
            return SubmitRadarReportOutput(
                report=self._register_vote(existing, reporter, 1), counted_as_confirmation=True
            )

        since = utc_now() - timedelta(days=1)
        if self._repository.count_reports_since(reporter, since) >= self._settings.daily_limit:
            raise ReportLimitReachedError(
                f"Puoi fare al massimo {self._settings.daily_limit} segnalazioni al giorno."
            )
        report = self._repository.save_report(
            RadarUserReport(
                kind=data.kind,
                place_type=data.place_type,
                name=name,
                latitude=latitude,
                longitude=longitude,
                address_label=(data.address_label or "").strip()[:160] or None,
                target_source=data.target_source if data.kind != "missing" else None,
                target_source_id=data.target_source_id if data.kind != "missing" else None,
                reporter_pseudonym=reporter,
            )
        )
        return SubmitRadarReportOutput(report=report, counted_as_confirmation=False)

    def _find_same_pending(
        self, data: SubmitRadarReportInput, latitude: float, longitude: float
    ) -> RadarUserReport | None:
        delta = 0.002
        box = BoundingBox(
            min_latitude=latitude - delta,
            max_latitude=latitude + delta,
            min_longitude=longitude - delta,
            max_longitude=longitude + delta,
        )
        origin = Coordinates(latitude=latitude, longitude=longitude)
        for report in self._live_reports(box, kinds=[data.kind], statuses=["pending"]):
            if data.kind == "missing":
                position = Coordinates(latitude=report.latitude, longitude=report.longitude)
                if (
                    report.place_type == data.place_type
                    and haversine_distance_km(origin, position) * 1000 <= _SAME_REPORT_METERS
                ):
                    return report
            elif (
                report.target_source == data.target_source
                and report.target_source_id == data.target_source_id
            ):
                return report
        return None


class VoteRadarReportInput(BaseModel):
    user_id: str
    report_id: str
    confirm: bool


class VoteRadarReportService(_Contributions):
    """ "Confermo" / "Non è così" on a pending report: one vote per person,
    changeable until the report is resolved."""

    def execute(self, data: VoteRadarReportInput) -> RadarUserReport:
        self._require_rules_accepted(data.user_id)
        report = self._repository.get_report(data.report_id)
        if report is None:
            raise ValidationError("Segnalazione non trovata.")
        if not self._settings.accepts(report.kind):
            raise ValidationError(KIND_NOT_ACTIVE_MESSAGE)
        return self._register_vote(report, self._pseudonym(data.user_id), 1 if data.confirm else -1)


class WithdrawRadarReportInput(BaseModel):
    user_id: str
    report_id: str


class WithdrawRadarReportService(_Contributions):
    """ "Ritira la mia segnalazione": whoever made a report can take it
    back while it is still pending (made by mistake, or as a trial). The
    report and the votes on it are deleted."""

    def execute(self, data: WithdrawRadarReportInput) -> None:
        report = self._repository.get_report(data.report_id)
        if report is None:
            raise ValidationError("Segnalazione non trovata.")
        if report.reporter_pseudonym != self._pseudonym(data.user_id):
            raise ValidationError("Puoi ritirare solo una tua segnalazione.")
        if report.status != "pending":
            raise ValidationError("Questa segnalazione è già chiusa: non si può più ritirare.")
        self._repository.delete_report(report.id)


class RateDogParkInput(BaseModel):
    user_id: str
    place: RadarPlace
    stars: int


class RateDogParkService(_Contributions):
    """One 1-5 star vote per person per public dog park, replaceable."""

    def execute(self, data: RateDogParkInput) -> None:
        if not self._settings.ratings_enabled:
            raise ValidationError("Le valutazioni non sono attive.")
        self._require_rules_accepted(data.user_id)
        if not is_publicly_ratable(data.place):
            raise ValidationError("Si possono valutare solo le aree cani pubbliche.")
        self._repository.save_rating(
            RadarPlaceRating(
                source=data.place.source_name,
                source_id=data.place.source_external_id,
                voter_pseudonym=self._pseudonym(data.user_id),
                stars=data.stars,
                latitude=data.place.latitude,
                longitude=data.place.longitude,
            )
        )


class RadarCommunitySnapshot(BaseModel):
    """What the community layer knows about one area at one moment."""

    # Live reports of the kinds that are shown, pending or confirmed.
    reports: list[RadarUserReport]
    overrides: list[RadarPlaceOverride]
    ratings: list[RadarPlaceRating]


def run_together(*reads: Callable[[], Any]) -> list[Any]:
    """Runs independent reads at the same time and returns their results
    in order. Each is a round trip to the database, so the wait is the
    slowest one instead of their sum."""
    if len(reads) < 2:
        return [read() for read in reads]
    with ThreadPoolExecutor(max_workers=len(reads)) as pool:
        return [future.result() for future in [pool.submit(read) for read in reads]]


class RadarCommunityView(_Contributions):
    """Everything the community adds to a radar answer: places reported as
    missing, places removed for good, ratings, and what the viewer has
    already voted. Returned as per-place extras, apart from the place
    data, so open-data records stay exactly as their source gave them."""

    def snapshot(self, box: BoundingBox) -> RadarCommunitySnapshot:
        """Everything the three methods below need for one area, read once
        and with the three reads running side by side: a radar answer used
        to read the reports twice and wait for each read in turn."""
        kinds = [
            kind
            for kind in self._settings.report_kinds()
            if kind == "missing" or (kind == "closed" and self._settings.show_pending_closures)
        ]
        ratings_enabled = self._settings.ratings_enabled
        reports, overrides, ratings = run_together(
            lambda: (
                self._live_reports(box, kinds=kinds, statuses=["pending", "confirmed"])
                if kinds
                else []
            ),
            self._repository.list_overrides,
            lambda: self._repository.list_ratings(box) if ratings_enabled else [],
        )
        return RadarCommunitySnapshot(reports=reports, overrides=overrides, ratings=ratings)

    def user_places(
        self, box: BoundingBox, snapshot: RadarCommunitySnapshot | None = None
    ) -> list[RadarPlace]:
        reports = (snapshot or self.snapshot(box)).reports
        return [report.as_place() for report in reports if report.kind == "missing"]

    def without_excluded(
        self, places: list[RadarPlace], snapshot: RadarCommunitySnapshot | None = None
    ) -> list[RadarPlace]:
        overrides = snapshot.overrides if snapshot else self._repository.list_overrides()
        return apply_overrides(places, overrides)

    def extras(
        self,
        places: list[RadarPlace],
        box: BoundingBox,
        *,
        viewer_id: str | None,
        snapshot: RadarCommunitySnapshot | None = None,
    ) -> dict[str, dict[str, Any]]:
        viewer = self._pseudonym(viewer_id) if viewer_id else None
        extras: dict[str, dict[str, Any]] = defaultdict(dict)

        snapshot = snapshot or self.snapshot(box)
        reports = snapshot.reports
        viewer_votes = (
            {
                vote.report_id: vote.vote
                for vote in self._repository.list_votes_by_voter(
                    [report.id for report in reports], viewer
                )
            }
            if viewer and reports
            else {}
        )

        def report_info(report: RadarUserReport) -> dict[str, Any]:
            return {
                "report_id": report.id,
                "status": report.status,
                "confirmations": max(0, report.confirmations - report.denials),
                "required": self._settings.required_for(report.kind),
                "viewer_vote": viewer_votes.get(report.id),
                "viewer_is_reporter": viewer is not None and report.reporter_pseudonym == viewer,
                # Days left before it is dropped unconfirmed; null once it
                # has a confirmation.
                "expires_in_days": report.expires_in_days(expiry_days=self._settings.expiry_days),
            }

        missing = {report.id: report for report in reports if report.kind == "missing"}
        closures = {
            (report.target_source, report.target_source_id): report
            for report in reports
            if report.kind == "closed" and report.status == "pending"
        }
        ratings: dict[tuple[str, str], list[RadarPlaceRating]] = defaultdict(list)
        ratings_enabled = self._settings.ratings_enabled
        for rating in snapshot.ratings:
            ratings[(rating.source, rating.source_id)].append(rating)

        for place in places:
            key = (place.source_name, place.source_external_id)
            if place.source_name == USER_SOURCE_NAME and place.source_external_id in missing:
                extras[place.id]["community"] = report_info(missing[place.source_external_id])
            if key in closures:
                extras[place.id]["pending_closure"] = report_info(closures[key])
            if ratings_enabled and is_publicly_ratable(place):
                votes = ratings.get(key, [])
                extras[place.id]["rating"] = {
                    "can_rate": True,
                    "count": len(votes),
                    "average": (
                        round(sum(vote.stars for vote in votes) / len(votes), 1)
                        if len(votes) >= MIN_RATINGS_TO_SHOW
                        else None
                    ),
                    "viewer_stars": next(
                        (vote.stars for vote in votes if vote.voter_pseudonym == viewer), None
                    ),
                }
        return dict(extras)

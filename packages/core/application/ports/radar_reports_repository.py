from datetime import datetime
from typing import Protocol

from packages.core.application.ports.radar_catalog_repository import BoundingBox
from packages.core.domain.radar_places.competences import RadarCompetenceClaim
from packages.core.domain.radar_reports.models import (
    RadarPlaceOverride,
    RadarPlaceRating,
    RadarReportVote,
    RadarUserReport,
)


class RadarReportsRepository(Protocol):
    def save_report(self, report: RadarUserReport) -> RadarUserReport: ...

    def get_report(self, report_id: str) -> RadarUserReport | None: ...

    def delete_report(self, report_id: str) -> None:
        """Deletes the report and the votes on it."""
        ...

    def list_reports(
        self, box: BoundingBox, *, kinds: list[str], statuses: list[str]
    ) -> list[RadarUserReport]: ...

    def count_reports_since(self, reporter_pseudonym: str, since: datetime) -> int: ...

    def save_vote(self, vote: RadarReportVote) -> None: ...

    def list_votes(self, report_id: str) -> list[RadarReportVote]: ...

    def list_votes_by_voter(
        self, report_ids: list[str], voter_pseudonym: str
    ) -> list[RadarReportVote]: ...

    def save_rating(self, rating: RadarPlaceRating) -> None: ...

    def list_ratings(self, box: BoundingBox) -> list[RadarPlaceRating]: ...

    def save_override(self, override: RadarPlaceOverride) -> None: ...

    def list_overrides(self) -> list[RadarPlaceOverride]: ...

    # Exotic-competence claims (radar_competence_claims).
    def save_claim(self, claim: RadarCompetenceClaim) -> RadarCompetenceClaim: ...

    def list_claims(
        self, box: BoundingBox, *, statuses: list[str]
    ) -> list[RadarCompetenceClaim]: ...

    def list_claims_by_reporter(
        self, reporter_pseudonym: str, *, target_source: str, target_source_id: str
    ) -> list[RadarCompetenceClaim]: ...

    def count_claims_since(self, reporter_pseudonym: str, since: datetime) -> int: ...

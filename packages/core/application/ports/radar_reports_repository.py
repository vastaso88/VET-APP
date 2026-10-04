from datetime import datetime
from typing import Protocol

from packages.core.application.ports.radar_catalog_repository import BoundingBox
from packages.core.domain.radar_reports.models import (
    RadarPlaceOverride,
    RadarPlaceRating,
    RadarReportVote,
    RadarUserReport,
)


class RadarReportsRepository(Protocol):
    def save_report(self, report: RadarUserReport) -> RadarUserReport: ...

    def get_report(self, report_id: str) -> RadarUserReport | None: ...

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

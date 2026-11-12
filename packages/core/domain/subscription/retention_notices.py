"""Which of the two e-mails an account would get, and what a commercial one
may truthfully mention (docs/compliance/12_avvisi_prima_della_cancellazione.md).

- Version S (service notice): everybody. True date, what is lost, how to
  download, how to reactivate. No offer.
- Version P (commercial): only with a commercial consent in force AND a
  declared adult, and it replaces S. An account whose age is not known is
  treated as not adult: the fail-safe is the service notice.
- No notice (variant "none"): a declared age under 14.

This module only decides. It sends nothing and has no clock of its own.
"""

from dataclasses import dataclass

from pydantic import BaseModel, Field

from packages.core.domain.age.models import AgeBand
from packages.core.domain.subscription.retention import NOTICE_DAYS

SERVICE = "service"
COMMERCIAL = "commercial"
# The account is outside the sequence: nothing is sent (declared age under 14).
NO_NOTICE = "none"

# The kinds of data an account can hold, in the order of {elenco_contenuti}
# (doc 12): animals, reminders, records of the medical record ("referti") and
# walks. The commercial text may list only the ones with a count above zero.
CONTENT_KINDS: tuple[str, ...] = ("animals", "reminders", "documents", "walks")

# The two notices whose commercial text also quotes counts ({n_animali},
# {n_documenti}, {n_promemoria}); the others quote only the names of the
# animals and, in E1, {elenco_contenuti}. A kind at zero is dropped from the
# sentence, never replaced by a number that is not true (rule 2 of the doc).
COUNT_CITES: dict[int, tuple[str, ...]] = {
    30: ("reminders", "documents"),
    106: ("animals", "documents", "reminders"),
}
assert set(COUNT_CITES) <= set(NOTICE_DAYS)


@dataclass(frozen=True)
class AccountDataCounts:
    """How much the account really holds: pets, reminders, entries of the
    medical record ("documenti"/"referti") and walks. Real counts or
    nothing."""

    animals: int
    documents: int
    reminders: int
    walks: int = 0

    def of(self, kind: str) -> int:
        return {
            "animals": self.animals,
            "reminders": self.reminders,
            "documents": self.documents,
            "walks": self.walks,
        }[kind]


class NoticePlan(BaseModel):
    """What the notice for one account would be. No text, no names, no
    numbers: the kinds of data it would quote."""

    variant: str
    # The sentence about a parent's authorisation, only for a declared minor.
    minor_note: bool = False
    # {elenco_contenuti}: what the account really holds (commercial only).
    contents: list[str] = Field(default_factory=list)
    # The counts this notice's commercial text quotes, each above zero.
    counts_cited: list[str] = Field(default_factory=list)
    # Consent and adult age were there, but the account holds nothing true to
    # quote (or the counts could not be read): rule 9, it gets the service
    # notice instead.
    nothing_to_cite: bool = False


def plan_notice(
    notice_day: int,
    *,
    marketing_consent: bool,
    age_band: str,
    counts: AccountDataCounts | None,
) -> NoticePlan:
    """[age_band] is an AgeBand from the declared date of birth. Only a
    declared adult can get the commercial notice; only a declared minor
    (14-17) gets the sentence about a parent's authorisation (an unknown age
    has no note). An account under 14 gets no notice at all: it is closed,
    cannot use or reactivate the app, and follows its own 30-day procedure
    (owner decision relayed by the Orchestrator, 2026-11-09)."""
    if age_band == AgeBand.UNDER_MINIMUM:
        return NoticePlan(variant=NO_NOTICE)
    minor_note = age_band == AgeBand.MINOR
    if not (marketing_consent and age_band == AgeBand.ADULT):
        return NoticePlan(variant=SERVICE, minor_note=minor_note)

    # Unknown counts (a failed read) also mean nothing may be quoted.
    if counts is None:
        return NoticePlan(variant=SERVICE, nothing_to_cite=True)
    contents = [kind for kind in CONTENT_KINDS if counts.of(kind) > 0]
    if not contents:
        return NoticePlan(variant=SERVICE, nothing_to_cite=True)

    return NoticePlan(
        variant=COMMERCIAL,
        contents=contents,
        counts_cited=[kind for kind in COUNT_CITES.get(notice_day, ()) if counts.of(kind) > 0],
    )

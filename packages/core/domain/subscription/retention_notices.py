"""Which of the two e-mails an account would get, and what a commercial one
may truthfully mention (docs/compliance/12_avvisi_prima_della_cancellazione.md).

- Version S (service notice): everybody. True date, what is lost, how to
  download, how to reactivate. No offer.
- Version P (commercial): only with a commercial consent in force AND a
  declared adult, and it replaces S. An account whose age is not known is
  treated as not adult: the fail-safe is the service notice.

This module only decides. It sends nothing and has no clock of its own.
"""

from dataclasses import dataclass
from datetime import date

from pydantic import BaseModel, Field

from packages.core.domain.subscription.retention import NOTICE_DAYS

SERVICE = "service"
COMMERCIAL = "commercial"

ADULT_AGE = 18

# What the commercial text of each notice quotes about the account, by the
# kind of data. "animals" = the names (or "i tuoi animali"), the others are
# counts. A kind with nothing behind it is dropped from the text, never
# replaced by a number that is not true (rule 2 of the doc).
COMMERCIAL_CITES: dict[int, tuple[str, ...]] = {
    0: ("animals",),
    30: ("animals", "reminders", "documents"),
    60: ("animals",),
    90: ("animals",),
    106: ("animals", "documents", "reminders"),
    113: ("animals",),
    117: ("animals",),
    119: ("animals",),
}
assert set(COMMERCIAL_CITES) == set(NOTICE_DAYS)


@dataclass(frozen=True)
class AccountDataCounts:
    """How much the account really holds: pets, entries of the medical
    record ("documenti") and reminders. Real counts or nothing."""

    animals: int
    documents: int
    reminders: int

    def of(self, kind: str) -> int:
        return {
            "animals": self.animals,
            "documents": self.documents,
            "reminders": self.reminders,
        }[kind]


def is_adult(birth_date: date | None, today: date) -> bool | None:
    """True/False from a date of birth; None when it is not known."""
    if birth_date is None:
        return None
    had_birthday = (today.month, today.day) >= (birth_date.month, birth_date.day)
    age = today.year - birth_date.year - (0 if had_birthday else 1)
    return age >= ADULT_AGE


class NoticePlan(BaseModel):
    """What the notice for one account would be. No text, no names, no
    numbers: the kinds of data it would quote."""

    variant: str
    # The sentence about a parent's authorisation, only for a declared minor.
    minor_note: bool = False
    cites: list[str] = Field(default_factory=list)
    # Commercial text chosen but the account holds nothing to quote.
    nothing_to_cite: bool = False


def plan_notice(
    notice_day: int,
    *,
    marketing_consent: bool,
    adult: bool | None,
    counts: AccountDataCounts | None,
) -> NoticePlan:
    minor_note = adult is False
    if not (marketing_consent and adult is True):
        return NoticePlan(variant=SERVICE, minor_note=minor_note)

    cites: list[str] = []
    if counts is not None:
        cites = [kind for kind in COMMERCIAL_CITES[notice_day] if counts.of(kind) > 0]
    return NoticePlan(
        variant=COMMERCIAL,
        cites=cites,
        # Unknown counts (a failed read) also mean nothing may be quoted.
        nothing_to_cite=not cites,
    )

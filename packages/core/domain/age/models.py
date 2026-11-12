"""Age rules (parere docs/compliance/10_pareri_dal_2026_11_06.md §3).

The date of birth is declared by the owner, never checked against a document,
kept only in the backend's `account_age` table and never shown to anyone.
Everything the rest of the code needs is the *band* computed from it.
"""

from datetime import date, datetime

from pydantic import BaseModel

# Italy's digital-consent age (Codice privacy art. 2-quinquies). One constant
# per country can replace it when other countries open.
MINIMUM_AGE = 14
ADULT_AGE = 18

# Days after which a closed account (declared age under the minimum) shows up
# in the team's dry-run count. Nothing is erased automatically (owner decision,
# 9 November 2026): the owner deletes the account or the team does it by hand.
UNDER_MINIMUM_GRACE_DAYS = 30
OLDEST_PLAUSIBLE_AGE = 120


class AgeBand:
    UNKNOWN = "unknown"
    UNDER_MINIMUM = "under_minimum"
    MINOR = "minor"  # 14 to 17
    ADULT = "adult"


class AccountAge(BaseModel):
    owner_id: str
    birth_date: date
    declared_at: datetime
    # When the owner confirmed they have a parent's authorisation for a paid
    # plan (only meaningful for a declared minor).
    guardian_ok_at: datetime | None = None
    # Set by the team when the owner wrote to say the date was a mistake: a
    # closed account with a pending correction is never erased.
    correction_requested_at: datetime | None = None


def age_on(birth_date: date, today: date) -> int:
    had_birthday = (today.month, today.day) >= (birth_date.month, birth_date.day)
    return today.year - birth_date.year - (0 if had_birthday else 1)


def band_for(birth_date: date | None, today: date) -> str:
    if birth_date is None:
        return AgeBand.UNKNOWN
    age = age_on(birth_date, today)
    if age < MINIMUM_AGE:
        return AgeBand.UNDER_MINIMUM
    if age < ADULT_AGE:
        return AgeBand.MINOR
    return AgeBand.ADULT

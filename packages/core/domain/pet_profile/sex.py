"""Sex and neutering are separate facts (2026-10-14).

Until then `pet_profiles.sex` held six combined values ("Femmina
sterilizzata", "Maschio intero", ...). It is now one of three
(`Maschio`, `Femmina`, `Sconosciuto`) and neutering lives in its own flag.
`split_legacy_sex` reads a stored value of either generation; the same
mapping is applied to the database by the `migrate-sex` statement in
scripts/setup/supabase_schema.sql (a test runs that statement).
"""

SEX_MALE = "Maschio"
SEX_FEMALE = "Femmina"
SEX_UNKNOWN = "Sconosciuto"

# legacy stored value -> (sex, neutered)
LEGACY_SEX_VALUES: dict[str, tuple[str, bool]] = {
    "Maschio castrato": (SEX_MALE, True),
    "Maschio intero": (SEX_MALE, False),
    "Femmina sterilizzata": (SEX_FEMALE, True),
    "Femmina intera": (SEX_FEMALE, False),
}


def split_legacy_sex(sex: str | None) -> tuple[str | None, bool | None]:
    """(sex, neutered) for a stored sex value; `neutered` is None when the
    value says nothing about it (current values, free text, missing)."""
    if sex is None:
        return None, None
    legacy = LEGACY_SEX_VALUES.get(sex.strip())
    if legacy is None:
        return sex, None
    return legacy

"""Recognising "this table does not exist yet" from Supabase.

A migration that was merged but not yet run on the database must not break
account deletion or the data export (it happened three times in November
2026). Only these two codes mean "no such table"; every other error still
propagates, so a real failure is never hidden.
"""

from __future__ import annotations

# 42P01: PostgreSQL undefined_table. PGRST205: PostgREST "table not found in
# the schema cache".
MISSING_TABLE_CODES = frozenset({"42P01", "PGRST205"})
# 42883: PostgreSQL undefined_function. PGRST202: PostgREST "function not found in the
# schema cache".
MISSING_FUNCTION_CODES = frozenset({"42883", "PGRST202"})


def is_missing_table(error: BaseException) -> bool:
    return getattr(error, "code", None) in MISSING_TABLE_CODES


def is_missing_function(error: BaseException) -> bool:
    return getattr(error, "code", None) in MISSING_FUNCTION_CODES


def missing_table_note(table: str) -> str:
    return f"table {table} not found on the database (migration not applied?): skipped"

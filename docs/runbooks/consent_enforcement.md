# Consent switch (`CONSENT_ENFORCEMENT_ENABLED`): what it covers and what it does not

Off by default. When on, every backend route answers 403 `consent_required` while the
Terms or the Privacy notice (or the emergency notice) are not accepted **at the current
version** (`CURRENT_VERSIONS` in `packages/core/domain/consent/account_consent_text.py`).
Checked in `AgeGuardedAuthProvider.get_current_user`, looked up at most once a minute per
account; a failed lookup lets the caller through (an outage must not lock everybody out).

## Stays open with a mandatory consent missing
Accept or decline (`/account/consents`, `/legal/*`), the cheap session check, export,
deletion (and cancelling a deletion), the age status, and **pausing the account**
(`POST /account/pause`). Whoever does not want a new version of the Terms can leave,
take their data, or put the account aside. A pause ends at the next sign-in, so it has
no route of its own to cancel.

## Covered
Everything that goes through the backend: chat, pets, marketplace, news, places, plans.

## NOT covered (known limit)
The app writes some tables **directly** to Supabase with the user's token, never through
the backend, so the switch does not see those writes: `reminders`, `pet_photos`,
`pet_weight_measurements`, `dog_walks`, `pet_conditions`, `clinical_events`,
`local_activities`, `pet_profiles`.

- Current app: stopped on the acceptance screen, it cannot reach those screens, so in
  practice the block holds.
- An **old app build** (no acceptance screen) or a hand-made client with a valid token can
  still write those rows while a consent is missing. Reading is not blocked either way
  (own rows only, RLS).
- Nothing is lost or exposed: it is a gap in "no use without accepting", not a data leak.
  Close it only when it matters (e.g. force-update old builds, or the database check below).

## Condition before turning the switch on
Set a **minimum app version** (force-update) that includes the acceptance screen, and only
then set `CONSENT_ENFORCEMENT_ENABLED=true`. This is the chosen way to close the gap above
(decision of the Orchestrator, 23 Nov 2026); the database-side check was judged not worth
its cost for now.

## Database-side check (not built, estimate)
Feasible with the pattern already used for the plan (`scripts/setup/plan_access_rules.sql`):
a small config table kept aligned by the backend at each check (as `plan_access_config` is
for the test plan) holding "enforced" and the current versions; a function
`caller_consents_ok()` reading `account_consents`; a trigger `consent_access_20_gate` on the
same eight tables (+ a restrictive policy as second defence), `service_role` untouched.
Costs: one script, eight triggers, a second copy of the versions to keep in sync, and a
rule to fail open when the config row is missing or the switch is off. Main risk: a wrong
sync locks every direct write of every user.

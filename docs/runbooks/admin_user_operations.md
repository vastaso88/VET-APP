# Users: support and moderation

Users owns account details and the closed-by-age view. `/age` redirects to
`/users/closed-by-age`; the existing age backend is unchanged. It does not become
an account-wide suspension or a bulk-erasure feature.

## Release order

1. Apply `supabase/migrations/20261121165154_admin_user_operations.sql` with the
   existing deployment credentials. The same additive SQL ends `supabase_schema.sql`.
2. Confirm both new tables have RLS and no anon/authenticated privileges, the
   public RPCs are service-role-only, and the login trigger function is private.
3. Check that `admin-user-support-retention` is scheduled daily in pg_cron. If
   pg_cron is absent, configure the existing external scheduler to call
   `admin_user_operations_cleanup()` as service_role daily before release.
4. Deploy backend, then portal, then the Flutter app. No new secret is needed.
   Do not deploy the Flutter writer before the columns exist: location sync is
   best effort and would otherwise fail. No database changes have been run by
   the local tests.

## What the data means

- Country is the geocoder's explicit country for a residence the owner actually
  saved, with city and save date. It is not nationality or verified residence.
  Existing accounts remain unknown until they save their residence again. Never
  infer country from language or coarse radar bounds, and never bulk geocode users.
- Actual successful Auth sign-ins are recorded by a trigger on last_sign_in_at,
  covering clients that authenticate directly with Supabase. No IP/token capture,
  refresh-time backfill or failed-login history. Capture is best effort and cannot
  prevent authentication. Portal shows up to 100 events in the last 90 days.
- Usage aggregates are computed in PostgreSQL, without transferring chat text to
  the portal. Totals cover retained data; quota days cover days with metered usage,
  not all app opens. Daily ledger dates are UTC. Unavailable sections show errors.
- Moderation shows up to 200 loaded Marketplace cases, received vs filed; large
  results are explicitly marked partial. A report is not an upheld violation.
  Chat/Radar reporter pseudonyms remain private. Case pages link back to Users.
- Device revocation marks app registrations revoked. The app sees it next time
  it registers; this is not immediate revocation of Auth JWTs or all API access.

## Actions

Supported: temporary Marketplace restriction (1–90 days), lift restriction, revoke
registered app devices. Plans, money and erasure are outside this surface.

Selected-page and all-filtered-results modes are distinct; max 100 unique accounts.
A signed, admin-bound preview fixes targets, filters, case references, reason and
duration for 10 minutes. Case subjects are validated; a reporter is not silently
treated as the reported person. Duplicate cases for one account are deduplicated.
Team/developer accounts and self-targeting are rejected, including on execution.

Each target runs in its own PostgreSQL transaction with an advisory lock. Audit
and mutation commit together; a unique request/account receipt makes retries
idempotent. Restriction state changes after preview return `conflict` rather than
overwriting a newer decision. An active restriction is never extended by a retry.
Partial failures stay visible and can be retried. Legacy single-account API
routes also use this ledger on Supabase; their restriction defaults to 7 days.

Both new tables are included in owner erasure/export; team-only fields are removed
from export. Cleanup runs daily (90/365 days) and also opportunistically on writes.

## Local verification

Run backend pytest, Ruff/mypy, portal typecheck/build, Flutter analyze and location
tests. From `apps/admin_portal`, run `npm run test:sql` after `npm install`.
`tests/sql/admin_user_operations.mjs` uses the pinned dev dependency `@electric-sql/pglite`
in a throwaway database and optionally accepts its module path as a CLI argument.
It checks real PostgreSQL permissions, trigger capture, transaction rollback,
retry receipts, conflicts, expiry, revocation and privacy of usage aggregates.
All browser QA uses synthetic local accounts, never live account credentials.

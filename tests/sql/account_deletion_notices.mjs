// The column that remembers the last e-mail notice of a deletion request: run with
//   node tests/sql/account_deletion_notices.mjs [<path-to-pglite-module>]
// Uses an embedded, throwaway PostgreSQL database and synthetic data. Never contacts Supabase.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth;
  create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
  grant usage on schema public, auth to service_role, anon, authenticated;
`);
// The table as scripts/setup/account_deletion_requests.sql creates it (a database that already
// has it), then the increment on top, twice: the owner may run it twice.
await db.exec(await readFile(new URL("../../scripts/setup/account_deletion_requests.sql", import.meta.url), "utf8"));
await db.exec(
  "insert into public.account_deletion_requests(owner_id, purge_after) values ('owner-a', now() + interval '30 days')",
);
const script = await readFile(new URL("../../scripts/setup/account_deletion_notices.sql", import.meta.url), "utf8");
await db.exec(script);
await db.exec(script);

const column = (
  await db.query(
    "select data_type, is_nullable from information_schema.columns where table_name = 'account_deletion_requests' and column_name = 'last_notice'",
  )
).rows[0];
assert.ok(column, "last_notice exists");
const bookedAt = (
  await db.query(
    "select data_type, is_nullable from information_schema.columns where table_name = 'account_deletion_requests' and column_name = 'last_notice_at'",
  )
).rows[0];
assert.ok(bookedAt, "last_notice_at exists");
assert.equal(bookedAt.data_type, "timestamp with time zone");
assert.equal(bookedAt.is_nullable, "YES");
assert.equal(column.data_type, "text");
assert.equal(column.is_nullable, "YES");

// A request that existed before the column reads "no notice yet".
assert.equal(
  (await db.query("select last_notice from public.account_deletion_requests where owner_id = 'owner-a'")).rows[0].last_notice,
  null,
);
await db.query("update public.account_deletion_requests set last_notice = 'confirmed' where owner_id = 'owner-a'");
assert.equal(
  (await db.query("select last_notice from public.account_deletion_requests where owner_id = 'owner-a'")).rows[0].last_notice,
  "confirmed",
);

// Row level security and the grants did not move: the user still reads only his own row and
// cannot write; anon sees nothing.
const rls = (await db.query("select relrowsecurity from pg_class where relname = 'account_deletion_requests'")).rows[0];
assert.equal(rls.relrowsecurity, true);
await db.exec("set role authenticated");
await assert.rejects(db.query("update public.account_deletion_requests set last_notice = 'x'"));
await db.exec("reset role");
await db.exec("set role anon");
await assert.rejects(db.query("select * from public.account_deletion_requests"));
await db.exec("reset role");

console.log("account_deletion_notices: ok");

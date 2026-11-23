// Confirmations and checks of Mercatino ads: run with
//   node tests/sql/marketplace_content_review.mjs [<path-to-pglite-module>]
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
  create schema storage;
  create table storage.buckets(id text primary key, name text not null, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  -- The columns of the ad this script relies on.
  create table public.marketplace_listings(
    id text primary key, owner_id text not null, status text not null default 'active',
    created_at timestamptz not null default now());
`);
const script = await readFile(
  new URL("../../scripts/setup/marketplace_content_review.sql", import.meta.url),
  "utf8",
);
await db.exec(script);
await db.exec(script); // Idempotent: the owner may run it twice.

const tables = ["marketplace_listing_reviews", "marketplace_listing_decision_log"];
for (const table of tables) {
  const { rows } = await db.query("select relrowsecurity from pg_class where relname = $1", [table]);
  assert.equal(rows[0].relrowsecurity, true, `${table}: row level security`);
  for (const role of ["anon", "authenticated"]) {
    await db.exec(`set role ${role}`);
    await assert.rejects(db.query(`select * from public.${table}`), `${role} reads ${table}`);
    await assert.rejects(db.query(`delete from public.${table}`), `${role} deletes from ${table}`);
    await db.exec("reset role");
  }
}
assert.equal(
  (await db.query("select 1 from pg_policies where policyname = 'marketplace_listing_reviews_select_own'")).rows.length,
  1,
);

const ad = (id, status) =>
  db.query("insert into public.marketplace_listings(id, owner_id, status) values ($1, 'owner-a', $2)", [id, status]);
const review = (id, listing, status, age) =>
  db.query(
    `insert into public.marketplace_listing_reviews
       (id, listing_id, owner_id, status, title, category, confirmation_version, decided_at)
     values ($1, $2, 'owner-a', $3, 'Ciotola', 'feeding', '2026-11-23', now() - $4::interval)`,
    [id, listing, status, age],
  );
const left = async (sql) => (await db.query(sql)).rows.map((row) => row.id);
await ad("removed", "removed_policy");
await review("r1", "removed", "removed", "1 month");
await review("r2", "removed", "checked", "2 months");
await db.query(
  `insert into public.marketplace_listing_decision_log(id, listing_id, outcome, reason, admin_id)
   values ('l1', 'removed', 'removed', 'food', 'admin')`,
);
// The photos of removed ads wait in a private bucket.
assert.deepEqual((await db.query("select id, public from storage.buckets")).rows, [
  { id: "marketplace-photos-held", public: false },
]);

// Only the states and reasons the backend knows.
await assert.rejects(review("bad", "removed", "pending", "1 day"));
await assert.rejects(
  db.query("update public.marketplace_listing_reviews set removal_reason = 'anything' where id = 'r2'"),
);
// The confirmation goes with the ad; the register of decisions does not depend on it.
await db.query("delete from public.marketplace_listings where id = 'removed'");
assert.deepEqual(await left("select id from public.marketplace_listing_reviews"), []);
assert.deepEqual(await left("select id from public.marketplace_listing_decision_log"), ["l1"]);
console.log("marketplace_content_review: ok");

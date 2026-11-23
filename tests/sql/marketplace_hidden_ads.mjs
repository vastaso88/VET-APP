// Ads hidden or taken down after reports: run with
//   node tests/sql/marketplace_hidden_ads.mjs [<path-to-pglite-module>]
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
  create schema storage;
  create table storage.buckets(id text primary key, name text not null, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table public.marketplace_listings(
    id text primary key, owner_id text not null, status text not null default 'active',
    report_count integer not null default 0,
    created_at timestamptz not null default now(), updated_at timestamptz not null default now());
  create table public.marketplace_listing_reports(
    id text primary key, listing_id text not null references public.marketplace_listings(id) on delete cascade,
    reporter_owner_id text not null, reason text not null, status text not null default 'open',
    created_at timestamptz not null default now());
`);
const script = async (name) => readFile(new URL(`../../scripts/setup/${name}`, import.meta.url), "utf8");
const base = await script("marketplace_content_review.sql");
const hidden = await script("marketplace_hidden_ads.sql");
await db.exec(base);
await db.exec(hidden);
await db.exec(hidden); // Idempotent: the owner may run it twice,
await db.exec(base); // and the first one again after it.
await db.exec(`
  create trigger on_marketplace_listing_report_insert
  after insert on public.marketplace_listing_reports
  for each row execute function public.handle_marketplace_listing_report();
`);

const ad = (id, status) =>
  db.query("insert into public.marketplace_listings(id, owner_id, status) values ($1, 'owner', $2)", [id, status]);
const report = (listing, reporter, status = "open") =>
  db.query(
    "insert into public.marketplace_listing_reports(id, listing_id, reporter_owner_id, reason, status) values ($1, $2, $3, 'spam', $4)",
    [`${listing}-${reporter}`, listing, reporter, status],
  );
const status = async (id) =>
  (await db.query("select status from public.marketplace_listings where id = $1", [id])).rows[0].status;

for (const state of ["active", "reserved", "sold", "removed_policy"]) {
  await ad(state, state);
  for (const reporter of ["a", "b", "c"]) await report(state, reporter);
}
assert.equal(await status("active"), "removed");
assert.equal(await status("reserved"), "removed");
assert.equal(await status("sold"), "sold");
assert.equal(await status("removed_policy"), "removed_policy"); // the team's decision stays

await ad("dismissed", "active");
for (const reporter of ["a", "b"]) await report("dismissed", reporter, "dismissed");
await report("dismissed", "c");
assert.equal(await status("dismissed"), "active"); // dismissed reports do not count

const review = (id, reason, origin) =>
  db.query(
    `insert into public.marketplace_listing_reviews
       (id, listing_id, owner_id, status, origin, title, category, confirmation_version, removal_reason)
     values ($1, 'sold', 'owner', 'removed', $2, 't', 'toys', '', $3)`,
    [id, origin, reason],
  );
for (const reason of ["food", "supplement", "medicine", "spam", "scam", "prohibited_item", "inappropriate", "sells_animals", "other"]) {
  await review(`r-${reason}`, reason, "report");
  await db.query(
    "insert into public.marketplace_listing_decision_log(id, listing_id, outcome, reason, admin_id) values ($1, 'sold', 'removed', $2, 'admin')",
    [`l-${reason}`, reason],
  );
}
await assert.rejects(review("bad-reason", "anything", "report"));
await assert.rejects(review("bad-origin", "spam", "anything"));
for (const role of ["anon", "authenticated"]) {
  await db.exec(`set role ${role}`);
  await assert.rejects(db.query("select public.handle_marketplace_listing_report()"));
  await db.exec("reset role");
}
console.log("marketplace_hidden_ads: ok");

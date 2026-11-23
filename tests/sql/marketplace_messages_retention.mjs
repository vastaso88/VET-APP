// Run with: node tests/sql/marketplace_messages_retention.mjs [<path-to-pglite-module>]
// Embedded throwaway PostgreSQL (PGlite), synthetic data, never contacts Supabase.
//
// How long a Mercatino conversation lasts (owner's decisions of 2026-11-23, reported by the
// Orchestratore): 6 months after the last message if the AD is closed (sold or deleted),
// 12 months after the last message anyway, never with an open report nor in the 6 months
// after a report was decided. An ad taken down can be restored, so it is not closed until
// it is deleted; the team closing the conversation does not count either. A team block goes
// 12 months after it ended, lifted or expired.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const db = new PGlite();
const read = async (path) => {
  const text = await readFile(new URL(`../../${path}`, import.meta.url), "utf8");
  return text.replaceAll("\r\n", "\n");
};
const script = await read("scripts/setup/marketplace_messages.sql");
const migration = await read("supabase/migrations/20261123100000_marketplace_messages_retention.sql");

await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth;
  create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
  grant usage on schema public, auth to service_role, anon, authenticated;
  create table public.marketplace_listings(
    id text primary key, status text not null default 'active',
    updated_at timestamptz not null default now());
`);
const definition = async () =>
  (await db.query("select pg_get_functiondef('public.marketplace_messages_cleanup()'::regprocedure) as d")).rows[0].d;

// The script and the migration install the same function; the migration is idempotent and
// replaces whatever was there.
await db.exec(script);
const fromScript = await definition();
await db.exec(`create or replace function public.marketplace_messages_cleanup() returns jsonb
  language plpgsql as $$ begin return '{"old": true}'::jsonb; end $$`);
await db.exec(migration);
await db.exec(migration);
assert.equal(await definition(), fromScript);

// Only the backend may run it: calling it deletes data.
for (const [role, allowed] of [["anon", false], ["authenticated", false], ["service_role", true]]) {
  const { rows } = await db.query(
    "select has_function_privilege($1, 'public.marketplace_messages_cleanup()', 'execute') as ok", [role]);
  assert.equal(rows[0].ok, allowed, role);
}

// name, last message, ad state ("deleted" = the ad is gone), extras, what must happen.
const D = { status: "dismissed" };
const U = { status: "resolved" };
const CASES = [
  // the 6 months: from the last message, only with the ad closed
  ["closed-5m", "5 months", "sold", {}, "stays"],
  ["closed-6m-less-a-day", "6 months -1 day", "sold", {}, "stays"],
  ["closed-6m-and-a-day", "6 months 1 day", "sold", {}, "goes"],
  ["closed-7m", "7 months", "sold", { listingUpdated: "7 months" }, "goes"],
  // an ad taken down can come back: closed only once it is deleted, the 12 months hold
  ["removed-7m", "7 months", "removed", {}, "stays"],
  ["removed-policy-7m", "7 months", "removed_policy", {}, "stays"],
  ["removed-13m", "13 months", "removed", {}, "goes"],
  ["removed-policy-13m", "13 months", "removed_policy", {}, "goes"],
  ["removed-long-ago-7m", "7 months", "removed_policy", { listingUpdated: "7 months" }, "stays"],
  ["open-5m", "5 months", "active", {}, "stays"],
  ["open-7m", "7 months", "active", {}, "stays"],
  ["reserved-7m", "7 months", "reserved", {}, "stays"],
  // the case where the old rule (from the closing) kept it: sold today, quiet for 7 months
  ["sold-today-quiet-7m", "7 months", "sold", { listingUpdated: "0 days" }, "goes"],
  // the 12 months, anyway
  ["open-12m-less-a-day", "12 months -1 day", "active", {}, "stays"],
  ["open-12m-and-a-day", "12 months 1 day", "active", {}, "goes"],
  ["reserved-13m", "13 months", "reserved", {}, "goes"],
  ["closed-13m", "13 months", "sold", {}, "goes"],
  // the ad was deleted
  ["deleted-ad-5m", "5 months", "deleted", {}, "stays"],
  ["deleted-ad-7m", "7 months", "deleted", {}, "goes"],
  // the team closed the conversation: the texts speak of the ad only
  ["team-closed-today-ad-open-7m", "7 months", "active", { teamClosed: "0 days" }, "stays"],
  ["team-closed-long-ago-ad-open-8m", "8 months", "active", { teamClosed: "8 months" }, "stays"],
  ["team-closed-ad-open-13m", "13 months", "active", { teamClosed: "8 months" }, "goes"],
  ["team-closed-ad-sold-7m", "7 months", "sold", { teamClosed: "0 days" }, "goes"],
  // an open report always keeps it, whatever else is true
  ["open-report-closed-7m", "7 months", "sold", { reports: [{ status: "open" }] }, "stays"],
  ["open-report-13m", "13 months", "active", { reports: [{ status: "open" }] }, "stays"],
  ["open-report-deleted-ad-13m", "13 months", "deleted", { reports: [{ status: "open" }] }, "stays"],
  ["one-open-one-decided-13m", "13 months", "sold",
    { reports: [{ status: "open" }, { status: "resolved", decided: "2 days" }] }, "stays"],
  // a decided report, upheld or dismissed, keeps it 6 months from the decision, even past
  // the 12 months; then the ordinary rule applies again
  ["upheld-yesterday-closed-7m", "7 months", "sold", { reports: [{ ...U, decided: "1 day" }] }, "stays"],
  ["dismissed-yesterday-closed-7m", "7 months", "sold", { reports: [{ ...D, decided: "1 day" }] }, "stays"],
  ["upheld-1m-13m", "13 months", "active", { reports: [{ ...U, decided: "1 month" }] }, "stays"],
  ["dismissed-1m-deleted-ad-13m", "13 months", "deleted", { reports: [{ ...D, decided: "1 month" }] }, "stays"],
  ["upheld-6m-less-a-day", "8 months", "sold", { reports: [{ ...U, decided: "6 months -1 day" }] }, "stays"],
  ["upheld-6m-and-a-day", "8 months", "sold", { reports: [{ ...U, decided: "6 months 1 day" }] }, "goes"],
  ["dismissed-6m-and-a-day", "8 months", "sold", { reports: [{ ...D, decided: "6 months 1 day" }] }, "goes"],
  ["upheld-7m-ago-open-8m", "8 months", "active", { reports: [{ ...U, decided: "7 months" }] }, "stays"],
  ["two-decided-one-recent-13m", "13 months", "sold",
    { reports: [{ ...U, decided: "8 months" }, { ...D, decided: "1 month" }] }, "stays"],
  ["two-decided-both-old-13m", "13 months", "sold",
    { reports: [{ ...U, decided: "8 months" }, { ...D, decided: "7 months" }] }, "goes"],
  // kept after an account deletion: 6 months after the decision if upheld, gone if dismissed
  ["erased-open-13m", "13 months", "deleted", { erased: true, reports: [{ status: "open" }] }, "stays"],
  ["erased-upheld-recently-13m", "13 months", "deleted",
    { erased: true, reports: [{ status: "resolved", decided: "1 month" }] }, "stays"],
  ["erased-upheld-6m-less-a-day", "13 months", "deleted",
    { erased: true, reports: [{ ...U, decided: "6 months -1 day" }] }, "stays"],
  ["erased-upheld-6m-and-a-day", "13 months", "deleted",
    { erased: true, reports: [{ ...U, decided: "6 months 1 day" }] }, "goes"],
  ["erased-one-dismissed-one-upheld", "8 months", "deleted",
    { erased: true, reports: [{ ...D, decided: "1 day" }, { ...U, decided: "1 month" }] }, "stays"],
  ["erased-upheld-13m-ago", "14 months", "deleted",
    { erased: true, reports: [{ status: "resolved", decided: "13 months" }] }, "goes"],
  ["erased-dismissed", "1 month", "deleted", { erased: true, reports: [{ ...D, decided: "1 day" }] }, "goes"],
];
assert.equal(new Set(CASES.map(([name]) => name)).size, CASES.length);

const ago = (interval) => `(now() - (interval '${interval}'))`;
// '6 months -1 day' is one interval literal for PostgreSQL: 6 months, minus one day.
async function seed(cases) {
  await db.exec("delete from public.marketplace_conversations; delete from public.marketplace_listings;");
  for (const [name, last, ad, extra] of cases) {
    await db.exec(`insert into public.marketplace_listings(id, status, updated_at)
      values ('ad-${name}', '${ad === "deleted" ? "sold" : ad}', ${ago(extra.listingUpdated ?? "1 day")})`);
    await db.exec(`insert into public.marketplace_conversations
      (id, listing_id, listing_title, buyer_id, seller_id, created_at, last_message_at, moderation_closed_at, erased_participant_at)
      values ('${name}', 'ad-${name}', 'Ciotola', 'buyer', 'seller', ${ago(last)}, ${ago(last)},
        ${extra.teamClosed ? ago(extra.teamClosed) : "null"}, ${extra.erased ? ago("1 month") : "null"})`);
    await db.exec(`insert into public.marketplace_messages(id, conversation_id, sender_id, body, created_at)
      values ('m-${name}', '${name}', 'buyer', 'Testo di prova', ${ago(last)})`);
    for (const [i, report] of (extra.reports ?? []).entries()) {
      await db.exec(`insert into public.marketplace_conversation_reports(id, conversation_id, reporter_id, reason, status, resolved_at)
        values ('r${i}-${name}', '${name}', 'reporter-${i}', 'spam', '${report.status}',
          ${report.decided ? ago(report.decided) : "null"})`);
    }
    if (ad === "deleted") await db.exec(`delete from public.marketplace_listings where id = 'ad-${name}'`);
  }
}
async function remaining() {
  const { rows } = await db.query("select id from public.marketplace_conversations order by id");
  return rows.map((row) => row.id);
}
async function clean() {
  await db.exec("set role service_role");
  try {
    return (await db.query("select public.marketplace_messages_cleanup() as out")).rows[0].out;
  } finally {
    await db.exec("reset role");
  }
}
const staying = (cases) => cases.filter((c) => c[4] === "stays").map(([name]) => name).sort();

await seed(CASES);
const result = await clean();
assert.deepEqual((await remaining()).sort(), staying(CASES));
// The count is the one of the ordinary rule; the kept-after-deletion rows are not in it.
const ordinaryGone = CASES.filter((c) => c[4] === "goes" && !c[3].erased).length;
assert.equal(result.marketplace_conversations, ordinaryGone);

// Messages and reports follow their conversation, and only theirs.
for (const table of ["marketplace_messages", "marketplace_conversation_reports"]) {
  const { rows } = await db.query(
    `select count(*)::int as n from public.${table} t
      where not exists (select 1 from public.marketplace_conversations c where c.id = t.conversation_id)`);
  assert.equal(rows[0].n, 0, table);
}
const messages = (await db.query("select count(*)::int as n from public.marketplace_messages")).rows[0].n;
assert.equal(messages, staying(CASES).length);

// A second night finds nothing more to delete.
assert.equal((await clean()).marketplace_conversations, 0);
assert.deepEqual((await remaining()).sort(), staying(CASES));

// A team block goes 12 months after it ended, whichever way it ended; one in force stays.
const BLOCKS = [
  // name, expires, lifted, what must happen
  ["no-end", null, null, "stays"],
  ["expires-tomorrow", "-1 day", null, "stays"],
  ["expired-12m-less-a-day", "12 months -1 day", null, "stays"],
  ["expired-12m-and-a-day", "12 months 1 day", null, "goes"],
  ["no-expiry-lifted-11m", null, "11 months", "stays"],
  ["no-expiry-lifted-13m", null, "13 months", "goes"],
  ["lifted-13m-would-expire-1m-ago", "1 month", "13 months", "goes"],
  ["lifted-11m-would-expire-10m-ago", "10 months", "11 months", "stays"],
];
for (const [name, expires, lifted] of BLOCKS) {
  await db.exec(`insert into public.marketplace_user_restrictions(owner_id, reason, created_at, expires_at, lifted_at)
    values ('${name}', 'spam', ${ago("14 months")}, ${expires ? ago(expires) : "null"}, ${lifted ? ago(lifted) : "null"})`);
}
const purged = await clean();
const blocksLeft = (
  await db.query("select owner_id from public.marketplace_user_restrictions order by owner_id")
).rows.map((row) => row.owner_id);
assert.deepEqual(blocksLeft.sort(), BLOCKS.filter((b) => b[3] === "stays").map((b) => b[0]).sort());
assert.equal(purged.marketplace_user_restrictions, BLOCKS.filter((b) => b[3] === "goes").length);
assert.equal(purged.marketplace_conversations, 0);

// Deleting the ad: what the team had removed takes its unreported conversations with it,
// whoever deletes it; everything else only loses the ad and keeps the ordinary times.
const WITH_AD = [
  // name, ad, extras, what must happen when the ad is deleted (last message: yesterday)
  ["team-removed", "removed_policy", {}, "goes"],
  ["team-removed-open-report", "removed_policy", { reports: [{ status: "open" }] }, "stays"],
  ["team-removed-upheld-long-ago", "removed_policy", { reports: [{ ...U, decided: "8 months" }] }, "stays"],
  ["team-removed-kept-after-deletion", "removed_policy", { erased: true, reports: [{ status: "open" }] }, "stays"],
  ["hidden-by-reports", "removed", {}, "stays"],
  ["sold", "sold", {}, "stays"],
  ["active", "active", {}, "stays"],
];
await seed(WITH_AD.map(([name, ad, extra]) => [name, "1 day", ad, extra]));
await db.exec("grant delete, select on public.marketplace_listings to authenticated");
await db.exec("set role authenticated"); // like the seller, who cannot touch conversations
await db.exec("delete from public.marketplace_listings");
await db.exec("reset role");
assert.deepEqual(
  (await remaining()).sort(),
  WITH_AD.filter((c) => c[3] === "stays").map((c) => c[0]).sort(),
);
assert.equal(
  (await db.query("select count(*)::int as n from public.marketplace_messages where conversation_id = 'team-removed'")).rows[0].n,
  0,
);
assert.equal((await clean()).marketplace_conversations, 0);

// An ad that is only edited, or restored, keeps its conversations.
await seed([["restored", "1 day", "removed_policy", {}]]);
await db.exec("update public.marketplace_listings set status = 'active'");
await db.exec("delete from public.marketplace_listings");
assert.deepEqual(await remaining(), ["restored"]);

console.log(`marketplace_messages_retention: ok (${CASES.length + BLOCKS.length + WITH_AD.length + 1} cases)`);

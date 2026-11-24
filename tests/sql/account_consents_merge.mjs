// One consent at a time, without touching the others: run with
//   node tests/sql/account_consents_merge.mjs [<path-to-pglite-module>]
// Uses an embedded, throwaway PostgreSQL database and synthetic data. Never contacts Supabase.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create table public.account_consents(
    owner_id text primary key, consents jsonb not null default '{}'::jsonb);
`);
const sql = await readFile(
  new URL("../../scripts/setup/account_consents_merge.sql", import.meta.url),
  "utf8",
);
await db.exec(sql);
await db.exec(sql); // Idempotent: the owner may run it twice.

const record = async (owner, key, granted, version = "v1") =>
  (
    await db.query("select public.account_consent_record($1, $2, $3::jsonb) as consents", [
      owner,
      key,
      JSON.stringify({ granted, version, decided_at: "2026-11-24T00:00:00Z" }),
    ])
  ).rows[0].consents;
const stored = async (owner) =>
  (await db.query("select consents from public.account_consents where owner_id = $1", [owner]))
    .rows[0]?.consents;

// The three consents of a sign-up, in any order, all stay.
await Promise.all([
  record("a", "terms_of_service", true),
  record("a", "privacy_policy", true),
  record("a", "emergency_notice", true),
]);
assert.deepEqual(Object.keys(await stored("a")).sort(), [
  "emergency_notice",
  "privacy_policy",
  "terms_of_service",
]);

// A new decision on one key changes that key only.
const after = await record("a", "privacy_policy", true, "v2");
assert.equal(after.privacy_policy.version, "v2");
assert.equal(after.terms_of_service.version, "v1");

// Another owner's row is not touched.
await record("b", "analytics", false);
assert.deepEqual(Object.keys(await stored("b")), ["analytics"]);
assert.equal(Object.keys(await stored("a")).length, 3);

// What is not a decision is refused and writes nothing.
for (const [owner, key, value] of [
  ["c", "", "{}"],
  ["", "analytics", "{}"],
  ["c", "x".repeat(65), "{}"],
  ["c", "analytics", "[]"],
  ["c", "analytics", '"yes"'],
]) {
  await assert.rejects(
    db.query("select public.account_consent_record($1, $2, $3::jsonb)", [owner, key, value]),
  );
}
assert.equal(await stored("c"), undefined);

// Only the backend may call it.
for (const [role, allowed] of [["anon", false], ["authenticated", false], ["service_role", true]]) {
  const { rows } = await db.query(
    "select has_function_privilege($1, 'public.account_consent_record(text,text,jsonb)', 'execute') as ok",
    [role],
  );
  assert.equal(rows[0].ok, allowed, role);
}
console.log("account_consents_merge: ok");

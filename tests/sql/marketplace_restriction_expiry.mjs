// Run with: node tests/sql/marketplace_restriction_expiry.mjs [<path-to-pglite-module>]
// Embedded throwaway PostgreSQL (PGlite), synthetic data, never contacts Supabase.
//
// Running scripts/setup/marketplace_messages.sql again must not make an EXPIRED team block
// count again, on a new database and on one whose table predates the expiry column.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const read = async (path) =>
  (await readFile(new URL(`../../${path}`, import.meta.url), "utf8")).replaceAll("\r\n", "\n");
const script = await read("scripts/setup/marketplace_messages.sql");
const operations = await read("supabase/migrations/20261121165154_admin_user_operations.sql");
const inMigration = operations.match(
  /create or replace function public\.marketplace_caller_is_restricted\(\)[\s\S]*?\$\$;/,
)[0];
const ME = "11111111-1111-4111-8111-111111111111";

for (const oldTable of [false, true]) {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth;
    create function auth.uid() returns uuid language sql stable
      as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
    grant usage on schema public, auth to service_role, anon, authenticated;
    create table public.marketplace_listings(
      id text primary key, status text not null default 'active',
      updated_at timestamptz not null default now());
  `);
  if (oldTable) {
    await db.exec(`create table public.marketplace_user_restrictions (
      owner_id text primary key, reason text not null, note text,
      created_at timestamptz not null default now(), created_by_admin_id text,
      lifted_at timestamptz, lifted_by_admin_id text)`);
  }
  const definition = async () =>
    (
      await db.query(
        "select pg_get_functiondef('public.marketplace_caller_is_restricted()'::regprocedure) as d",
      )
    ).rows[0].d;

  await db.exec(script);
  await db.exec(inMigration); // what production holds since 2026-11-21
  const production = await definition();
  await db.exec(script); // run again by mistake
  assert.equal(await definition(), production);

  await db.exec(`select set_config('test.uid', '${ME}', false)`);
  const restricted = async () => {
    await db.exec("set role authenticated");
    try {
      return (await db.query("select public.marketplace_caller_is_restricted() as r")).rows[0].r;
    } finally {
      await db.exec("reset role");
    }
  };
  const block = (expires, lifted = "null") =>
    db.exec(`insert into public.marketplace_user_restrictions(owner_id, reason, expires_at, lifted_at)
      values ('${ME}', 'spam', ${expires}, ${lifted})
      on conflict (owner_id) do update
        set expires_at = excluded.expires_at, lifted_at = excluded.lifted_at`);
  assert.equal(await restricted(), false);
  await block("null");
  assert.equal(await restricted(), true, "no expiry");
  await block("now() + interval '1 day'");
  assert.equal(await restricted(), true, "expires tomorrow");
  await block("now() - interval '1 second'");
  assert.equal(await restricted(), false, "expired");
  await block("now() + interval '1 day'", "now()");
  assert.equal(await restricted(), false, "lifted by the team");

  for (const [role, allowed] of [["anon", false], ["authenticated", true]]) {
    const { rows } = await db.query(
      "select has_function_privilege($1, 'public.marketplace_caller_is_restricted()', 'execute') as ok",
      [role],
    );
    assert.equal(rows[0].ok, allowed, role);
  }
}
console.log("marketplace_restriction_expiry: ok");

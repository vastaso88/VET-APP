// QK-30. Run with: node tests/sql/schema_from_scratch.mjs [<path-to-pglite-module>]
// Loads EVERY setup script on an EMPTY embedded PostgreSQL (PGlite) in the documented
// install order and stops at the first error, naming the file. Never contacts Supabase.
// Defect M001 of the collaudo (2026-11-22): supabase_schema.sql used public.set_updated_at(),
// created only by a later script, so a restore from zero stopped half way.
//
// Order = ORDINE_SCHEMA of scripts/collaudo/gemello.py (read from that file, so there is one
// list), then supabase/migrations/*.sql in name order, then the other increments of
// scripts/setup/ (idempotent: they must run cleanly after the base).
//
// What a Supabase project provides and a bare PostgreSQL does not is stubbed with the bare
// minimum: roles anon / authenticated / service_role, the schemas auth (users, uid(), role(),
// jwt()), storage (buckets, objects, foldername()) and extensions (gen_random_uuid()).
//
// Left out, on purpose, and said again at the end of the run:
//  - scripts/setup/supabase_security_hardening.sql: alters old Stripe billing objects that exist
//    only in production (the collaudo twin leaves it out for the same reason);
//  - `create extension pgcrypto`: not loaded in PGlite (extensions.gen_random_uuid() is a stub);
//  - supabase_llm_sources_schema.sql when the pgvector extension of PGlite cannot be loaded
//    (`@electric-sql/pglite/vector`): the script needs the `vector` type. Nothing else uses the
//    `ai` schema.
//  - pg_cron: the scripts only schedule when it exists (it does not here).
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { createRequire } from "node:module";

const root = new URL("../../", import.meta.url);
const require = createRequire(new URL("apps/admin_portal/package.json", root));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");

let vector = null;
try {
  ({ vector } = require("@electric-sql/pglite/vector"));
} catch {
  try {
    ({ vector } = await import("@electric-sql/pglite/vector"));
  } catch {
    vector = null;
  }
}
const db = new PGlite(vector ? { extensions: { vector } } : {});

// -- the minimum a Supabase project gives
await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema extensions;
  create function extensions.gen_random_uuid() returns uuid language sql
    as $$ select pg_catalog.gen_random_uuid() $$;
  create schema auth;
  create table auth.users(
    id uuid primary key default gen_random_uuid(), email text,
    created_at timestamptz not null default now(), last_sign_in_at timestamptz,
    email_confirmed_at timestamptz, banned_until timestamptz, raw_user_meta_data jsonb);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create function auth.role() returns text language sql stable
    as $$ select nullif(current_setting('request.jwt.claim.role', true), '')::text $$;
  create function auth.jwt() returns jsonb language sql stable
    as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
  create schema storage;
  create table storage.buckets(id text primary key, name text not null, public boolean default false,
    file_size_limit bigint, allowed_mime_types text[], created_at timestamptz default now(),
    updated_at timestamptz default now());
  create table storage.objects(id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets(id), name text, owner uuid,
    metadata jsonb, created_at timestamptz default now());
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable
    as $$ select (string_to_array(name, '/'))[1:greatest(array_length(string_to_array(name, '/'), 1) - 1, 0)] $$;
  grant usage on schema public, auth, storage, extensions to anon, authenticated, service_role;
  set search_path to public, extensions;
`);

// -- the order: ORDINE_SCHEMA of the collaudo twin, so there is one list
const gemello = await readFile(new URL("scripts/collaudo/gemello.py", root), "utf8");
const block = gemello.match(/ORDINE_SCHEMA[^=]*=\s*\(([\s\S]*?)\n\)/);
assert.ok(block, "ORDINE_SCHEMA not found in scripts/collaudo/gemello.py");
const ordered = [...block[1].matchAll(/"(scripts\/setup\/[^"]+\.sql)"/g)].map((m) => m[1]);
assert.ok(ordered.length >= 10, `only ${ordered.length} scripts in ORDINE_SCHEMA`);
assert.equal(ordered[0], "scripts/setup/supabase_schema.sql"); // the base schema comes first

const sorted = async (dir, keep = () => true) =>
  (await readdir(new URL(dir, root))).filter((f) => f.endsWith(".sql") && keep(f)).sort();
const migrations = (await sorted("supabase/migrations/")).map((f) => `supabase/migrations/${f}`);
const NOT_FROM_ZERO = new Set(["scripts/setup/supabase_security_hardening.sql"]);
const rest = (await sorted("scripts/setup/"))
  .map((f) => `scripts/setup/${f}`)
  .filter((f) => !ordered.includes(f) && !NOT_FROM_ZERO.has(f));
const everything = [...ordered, ...migrations, ...rest];

const skipped = [];
let ran = 0;
for (const file of everything) {
  let sql = await readFile(new URL(file, root), "utf8");
  if (/create extension[^;]*\bvector\b/i.test(sql) && !vector) {
    skipped.push(`${file} (needs the pgvector extension of PGlite, not loadable here)`);
    continue;
  }
  const withoutPgcrypto = sql.replace(/^\s*create extension[^;\n]*pgcrypto[^;\n]*;[ \t]*$/gim, "");
  if (withoutPgcrypto !== sql) skipped.push(`${file}: the "create extension pgcrypto" statement only`);
  sql = withoutPgcrypto;
  try {
    await db.exec(sql);
  } catch (error) {
    // The first error stops the run and names the script, like a restore from zero would.
    throw new Error(`${file} failed on an empty database: ${error.message}`, { cause: error });
  }
  ran += 1;
}

// -- what the defect was about
const has = async (query) => (await db.query(query)).rows.length === 1;
assert.ok(
  await has("select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'set_updated_at'"),
  "public.set_updated_at() was not created",
);
assert.ok(
  await has("select 1 from pg_trigger where tgname = 'trg_admin_ingestion_schedules_set_updated_at'"),
  "the trigger on admin_ingestion_schedules was not created",
);
const tables = (await db.query("select count(*)::int as n from pg_tables where schemaname = 'public'")).rows[0].n;
assert.ok(tables > 40, `only ${tables} tables in public: scripts did not install`);

console.log(`schema_from_scratch: ok (${ran} scripts, ${tables} public tables)`);
for (const line of skipped) console.log(`  skipped: ${line}`);
console.log("  not loaded on purpose: scripts/setup/supabase_security_hardening.sql, pg_cron");

// QK-07. Run with: node tests/sql/admin_directories.mjs <path-to-pglite-module>
// Embedded throwaway PostgreSQL (PGlite), synthetic data, never contacts Supabase.
// Runs the migration twice (idempotent) and checks the two admin directories on more
// rows than a provider window (2,500 accounts, 1,500 pets): last-page record, exact
// totals and country counts, no row repeated between pages, stable order, and that
// only service_role can call the functions.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth;
  create table auth.users(id uuid primary key default gen_random_uuid(), email text,
      created_at timestamptz, last_sign_in_at timestamptz, email_confirmed_at timestamptz,
      banned_until timestamptz);
  create table public.user_locations(owner_id text primary key, home_country_code text,
      home_city text, home_saved_at timestamptz);
  create table public.pet_profiles(id text primary key, owner_id text not null, name text not null,
      species text not null, breed text, notes text, is_memorial boolean not null default false);
  grant usage on schema public, auth to service_role;
  grant all on all tables in schema public to service_role;
  grant select on auth.users to service_role;
`);
const migration = await readFile(
  new URL("../../supabase/migrations/20261122100000_admin_directories.sql", import.meta.url),
  "utf8",
);
await db.exec(migration);
await db.exec(migration); // idempotent

// 2,500 accounts: created_at has ties (two per minute), countries IT/ES/FR/none in turn.
await db.exec(`
  insert into auth.users(id, email, created_at)
  select ('00000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
         'Person' || i || '@example.com',
         timestamptz '2026-01-01 00:00:00+00' + ((i / 2) || ' minutes')::interval
  from generate_series(0, 2499) i;
  insert into public.user_locations(owner_id, home_country_code, home_city)
  select ('00000000-0000-4000-8000-' || lpad(i::text, 12, '0')),
         (array['IT','ES','FR',null])[1 + i % 4], 'Example city ' || (i % 7)
  from generate_series(0, 2499) i;
  insert into public.pet_profiles(id, owner_id, name, species, breed, notes, is_memorial)
  select 'p' || lpad(i::text, 5, '0'),
         '00000000-0000-4000-8000-' || lpad((i % 2500)::text, 12, '0'),
         'Pet' || lpad(((i * 7) % 1500)::text, 5, '0'),
         (array['Cane','Gatto','Piccoli mammiferi','Uccello','Rettili e anfibi','Pesce','Altro'])[1 + i % 7],
         'Breed' || (i % 11), 'PRIVATE MEDICAL NOTE', i % 10 = 0
  from generate_series(0, 1499) i;
`);

const users = async (q, country, page, size) =>
  (await db.query("select public.admin_users_directory($1,$2,$3,$4) as r", [q, country, page, size]))
    .rows[0].r;
const pets = async (q, species, status, country, region, page, size) =>
  (
    await db.query("select public.admin_pets_directory($1,$2,$3,$4,$5,$6,$7) as r", [
      q, species, status, country, region, page, size,
    ])
  ).rows[0].r;

await db.exec("set role service_role");

// -- users: last page, totals, filters, no repeats, order
let r = await users("person0@example", "", 1, 50);
assert.equal(r.total, 1);
assert.equal(r.rows[0].email, "Person0@example.com");
r = await users("", "", 25, 100);
assert.equal(r.total, 2500);
assert.equal(r.page, 25);
assert.equal(r.rows.length, 100);
r = await users("", "", 2000, 100);
assert.equal(r.page, 25); // a page past the end is the last page
const seen = [];
for (let page = 1; page <= 25; page++) seen.push(...(await users("", "", page, 100)).rows.map((x) => x.id));
assert.equal(seen.length, 2500);
assert.equal(new Set(seen).size, 2500);
r = await users("", "FR", 1, 10);
assert.equal(r.total, 625);
assert.deepEqual(r.countries, { ES: 625, FR: 625, IT: 625, unknown: 625 }); // filter not applied to counts
assert.ok(r.rows.every((x) => x.home_country_code === "FR"));
r = await users("", "unknown", 1, 10);
assert.equal(r.total, 625);
r = await users("PERSON12", "", 1, 100);
assert.equal(r.total, 111);
assert.equal(Object.values(r.countries).reduce((a, b) => a + b, 0), 111);
// the search is a substring, not a pattern: wildcards match nothing
assert.equal((await users("%", "", 1, 10)).total, 0);
assert.equal((await users("_", "", 1, 10)).total, 0);
// ordering: newest first, id as tie-breaker
const ordered = (await users("", "", 1, 100)).rows;
for (let i = 1; i < ordered.length; i++) {
  const a = ordered[i - 1], b = ordered[i];
  assert.ok(a.created_at > b.created_at || (a.created_at === b.created_at && a.id > b.id));
}

// -- pets (QK-07d): group / exotic / active are DERIVED from species and is_memorial; the
// table has none of the columns is_active / is_exotic / species_group here, and the
// functions must not need them. 1,500 pets: species i % 7 (Cane for i % 7 = 0 ...), in
// Ricordi when i % 10 = 0.
r = await pets("pet01499", "", "", "", "", 1, 50);
assert.equal(r.total, 1);
assert.equal(r.rows[0].name, "Pet01499");
assert.ok(!("notes" in r.rows[0])); // never medical notes
assert.equal(r.rows[0].region, null);
r = await pets("", "", "", "", "", 1, 100);
assert.equal(r.total, 1500);
const names = [], ids = [];
for (let page = 1; page <= 15; page++) {
  const rows = (await pets("", "", "", "", "", page, 100)).rows;
  names.push(...rows.map((x) => x.name));
  ids.push(...rows.map((x) => x.id));
}
assert.equal(new Set(ids).size, 1500);
assert.deepEqual(names, [...names].sort());
const filters = async () => ({
  dog: (await pets("", "dog", "", "", "", 1, 100)).total,
  smallMammal: (await pets("", "small_mammal", "", "", "", 1, 100)).total,
  other: (await pets("", "other", "", "", "", 1, 100)).total,
  memorial: (await pets("", "", "memorial", "", "", 1, 100)).total,
  inactive: (await pets("", "", "inactive", "", "", 1, 100)).total,
  active: (await pets("", "", "active", "", "", 1, 100)).total,
  exotic: (await pets("", "", "exotic", "", "", 1, 100)).total,
});
const expected = { dog: 215, smallMammal: 214, other: 214, memorial: 150, inactive: 150, active: 1350, exotic: 1070 };
assert.deepEqual(await filters(), expected);
const row = (await pets("", "", "", "", "", 1, 100)).rows[0];
assert.ok("species_group" in row && "is_exotic" in row && "is_active" in row); // same names as before
assert.equal(row.is_active, !row.is_memorial);
assert.equal(row.is_exotic, row.species_group !== "dog" && row.species_group !== "cat");
assert.equal((await pets("", "", "", "es", "", 1, 100)).total > 0, true);
assert.equal((await pets("", "", "", "", "city 3", 1, 100)).total > 0, true);

// The three production columns exist there (is_active defaults to FALSE, nothing writes
// them): adding them must change nothing.
await db.exec("reset role");
await db.exec(`
  alter table public.pet_profiles add column is_active boolean not null default false;
  alter table public.pet_profiles add column is_exotic boolean;
  alter table public.pet_profiles add column species_group text;
  set role service_role;
`);
assert.deepEqual(await filters(), expected);

// -- helpers: the same species groups as `normalize_species` (Python); scope = unpaged filter
const bucket = async (value) =>
  (await db.query("select public.admin_species_bucket($1) as b", [value])).rows[0].b;
assert.equal(await bucket("Cane"), "dog");
assert.equal(await bucket("  gatto "), "cat");
assert.equal(await bucket("Piccoli mammiferi"), "small_mammal");
assert.equal(await bucket("rabbit"), "small_mammal");
assert.equal(await bucket("Uccello"), "bird");
assert.equal(await bucket("Rettili e anfibi"), "reptile_amphibian");
assert.equal(await bucket("Pesce"), "fish");
assert.equal(await bucket("Altro"), "other");
assert.equal(await bucket("Drago"), "other");
assert.equal(await bucket("  "), "unknown");
assert.equal(await bucket(null), "unknown");
assert.equal(
  (await db.query("select count(*)::int as n from public.admin_pets_scope('', 'dog', '', '', '')")).rows[0].n,
  215,
);

// -- only the API's role may call them: every function, anon and authenticated alike
const calls = [
  "select public.admin_users_directory('', '', 1, 10)",
  "select public.admin_pets_directory('', '', '', '', '', 1, 10)",
  "select public.admin_species_bucket('dog')",
  "select * from public.admin_pets_scope('', '', '', '', '')",
];
for (const role of ["anon", "authenticated"]) {
  await db.exec(`reset role; set role ${role}`);
  for (const call of calls) await assert.rejects(db.query(call), undefined, `${role} must not run: ${call}`);
}
await db.exec("reset role");
console.log("admin_directories: ok");

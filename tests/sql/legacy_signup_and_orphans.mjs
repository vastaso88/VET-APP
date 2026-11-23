// Run with: node tests/sql/legacy_signup_and_orphans.mjs [<path-to-pglite-module>]
// Embedded throwaway PostgreSQL (PGlite), synthetic data, never contacts Supabase.
//
// 1. The migration removes the two old triggers of production, also when auth.users belongs
//    to another role; it stops, changing nothing, when something else needs them.
// 2. scripts/maintenance/erase_orphan_rows.sql erases the rows of accounts that no longer
//    exist and nothing else, and does not start without the right number.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const read = async (path) =>
  (await readFile(new URL(`../../${path}`, import.meta.url), "utf8")).replaceAll("\r\n", "\n");
const migration = await read("supabase/migrations/20261123200000_remove_legacy_signup_triggers.sql");
const script = await read("scripts/maintenance/erase_orphan_rows.sql");
const cut = script.indexOf("-- ============================== PARTE 2");
assert.ok(cut > 0);
const part1 = script.slice(0, cut);
const part2 = script.slice(cut);

const ALIVE = "11111111-1111-4111-8111-111111111111";
const GONE = "22222222-2222-4222-8222-222222222222";
const DEMO_BUYER = "33333333-3333-4333-8333-333333333333";

async function database({ extraTrigger = false, newLimit = true } = {}) {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create role supabase_auth_admin;
    create schema auth;
    create table auth.users(id uuid primary key, email text);
    create table public.pet_profiles(id text primary key, owner_id text not null);
    create table public.clinical_events(id text primary key,
      pet_id text references public.pet_profiles(id) on delete cascade);
    create table public.conversations(id text primary key, owner_id text not null);
    create table public.reminders(id text primary key, owner_id text not null);
    create table public.owner_profiles(owner_id text primary key, email text, city text,
      address_label text, latitude double precision, longitude double precision);
    create table public.owner_billing_entitlements(owner_id text primary key
      references public.owner_profiles(owner_id) on delete cascade, plan_code text);
    create table public.billing_customers(id text primary key, email text, owner_id text not null
      references public.owner_profiles(owner_id) on delete cascade);
    create table public.billing_one_time_purchases(id text primary key, owner_id text not null
      references public.owner_profiles(owner_id) on delete cascade);
    create function public.billing_create_trial_for_new_auth_user() returns trigger
      language plpgsql security definer set search_path = public as $$
      begin
        insert into public.owner_profiles(owner_id, email) values (new.id::text, new.email);
        return new;
      end $$;
    create function public.billing_enforce_pet_limit() returns trigger language plpgsql as $$
      begin raise exception 'Pet limit reached'; end $$;
    create function public.plan_access_pet_limit() returns trigger language plpgsql as $$
      begin return new; end $$;
    create trigger trg_auth_users_billing_trial after insert on auth.users
      for each row execute function public.billing_create_trial_for_new_auth_user();
    create trigger trg_pet_profiles_billing_limit before insert on public.pet_profiles
      for each row execute function public.billing_enforce_pet_limit();
    ${newLimit ? `create trigger plan_access_20_pet_limit before insert on public.pet_profiles
      for each row execute function public.plan_access_pet_limit();` : ""}
    ${extraTrigger ? `create trigger somebody_else before update on public.pet_profiles
      for each row execute function public.billing_enforce_pet_limit();` : ""}
    alter schema auth owner to supabase_auth_admin;
    alter table auth.users owner to supabase_auth_admin;
  `);
  return db;
}
const triggers = async (db) =>
  (await db.query("select tgname from pg_trigger where not tgisinternal order by 1")).rows.map((r) => r.tgname);

// -- 1. the migration
{
  const db = await database();
  await db.exec(migration);
  assert.deepEqual(await triggers(db), ["plan_access_20_pet_limit"]);
  await db.exec(migration); // idempotent
  await db.exec(`insert into auth.users values ('${ALIVE}', 'a@example.com')`);
  await db.exec(`insert into public.pet_profiles values ('p', '${ALIVE}')`);
  assert.equal((await db.query("select 1 from public.owner_profiles")).rows.length, 0);
}
for (const options of [{ extraTrigger: true }, { newLimit: false }]) {
  const db = await database(options);
  const before = await triggers(db);
  await assert.rejects(db.exec(migration), /FERMO/);
  await db.exec("rollback");
  assert.deepEqual(await triggers(db), before, "a refusal leaves both triggers in place");
}

// -- 2. the orphan rows
const db = await database();
await db.exec(migration);
await db.exec(`
  insert into auth.users values ('${ALIVE}', 'a@example.com');
  insert into public.pet_profiles values ('alive', '${ALIVE}'), ('gone', '${GONE}'),
    ('upper', upper('${GONE}')), ('demo', 'demo-user'), ('shared', 'shared');
  insert into public.clinical_events values ('e-alive', 'alive'), ('e-gone', 'gone'), ('e-demo', 'demo');
  insert into public.conversations values ('c-alive', '${ALIVE}'), ('c-gone', '${GONE}');
  insert into public.reminders values ('r-gone', '${GONE}'), ('r-demo', 'demo-user');
  insert into public.owner_profiles values
    ('${ALIVE}', 'a@example.com', 'Roma', 'via di prova', 41, 12),
    ('${GONE}', 'g@example.com', 'Roma', 'via di prova', 41, 12),
    ('${DEMO_BUYER}', 'p@example.com', 'Roma', 'via di prova', 41, 12);
  insert into public.owner_billing_entitlements values ('${ALIVE}', 'trial'), ('${GONE}', 'trial'), ('${DEMO_BUYER}', 'trial');
  insert into public.billing_customers values ('b', 'p@example.com', '${DEMO_BUYER}'), ('mine', null, '${ALIVE}');
  insert into public.billing_one_time_purchases values ('o', '${DEMO_BUYER}'), ('mine', '${ALIVE}');
`);
const counts = async () => (await db.exec(part1)).at(-1).rows;
const total = (rows) => rows.find((r) => r.tabella.startsWith("TOTALE")).account;
const first = await counts();

assert.equal(total(first), 2);
assert.equal(first.find((r) => r.tabella === "pet_profiles").righe, 2);

const ids = async (table, column = "id") =>
  (await db.query(`select ${column} as v from public.${table} order by 1`)).rows.map((r) => r.v);
const everything = async () => JSON.stringify(
  await Promise.all(["pet_profiles", "clinical_events", "conversations", "reminders", "billing_customers",
    "billing_one_time_purchases"].map((t) => ids(t))),
);
const untouched = await everything();
for (const wrong of [-1, 0, 1, 3]) {
  await assert.rejects(db.exec(part2.replace("integer := -1;", `integer := ${wrong};`)), /FERMO/);
  assert.equal(await everything(), untouched, `attesi = ${wrong} must change nothing`);
}

await db.exec(part2.replace("integer := -1;", "integer := 2;"));
assert.deepEqual(await ids("pet_profiles"), ["alive", "demo", "shared"]);
assert.deepEqual(await ids("clinical_events"), ["e-alive", "e-demo"]);
assert.deepEqual(await ids("conversations"), ["c-alive"]);
assert.deepEqual(await ids("reminders"), ["r-demo"]);
assert.deepEqual(await ids("owner_profiles", "owner_id"), [ALIVE]);
assert.deepEqual(await ids("owner_billing_entitlements", "owner_id"), [ALIVE]);
for (const table of ["billing_customers", "billing_one_time_purchases"]) {
  assert.deepEqual(await ids(table), ["mine"], table);
}
const alive = (await db.query(`select email, city from public.owner_profiles where owner_id = '${ALIVE}'`)).rows[0];
assert.deepEqual([alive.email, alive.city], ["a@example.com", "Roma"]);

// The count after is zero, and running it again with that number changes nothing.
assert.equal(total(await counts()), 0);
const second = await everything();
await db.exec(part2.replace("integer := -1;", "integer := 0;"));
assert.equal(await everything(), second);

// A database without accounts is never "all orphans".
await db.exec("delete from auth.users");
await assert.rejects(db.exec(part2.replace("integer := -1;", "integer := 2;")), /nessun account/);

// -- 3. no TRUNCATE, TRIGGER or REFERENCES for the app's roles; what they need stays
{
  const privileges = await read("supabase/migrations/20261123201000_app_roles_no_truncate.sql");
  const p = new PGlite();
  await p.exec(`
    create role anon; create role authenticated; create role service_role;
    create table public.before(id text);
    grant all on public.before to anon, authenticated, service_role;
    alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  `);
  await p.exec(privileges);
  await p.exec(privileges); // idempotent
  await p.exec("create table public.after(id text)");
  const can = async (role, table, privilege) =>
    (await p.query("select has_table_privilege($1, $2, $3) as ok", [role, `public.${table}`, privilege])).rows[0].ok;
  for (const table of ["before", "after"]) {
    for (const role of ["anon", "authenticated"]) {
      for (const privilege of ["TRUNCATE", "TRIGGER", "REFERENCES"]) {
        assert.equal(await can(role, table, privilege), false, `${role} ${privilege} ${table}`);
      }
      for (const privilege of ["SELECT", "INSERT", "UPDATE", "DELETE"]) {
        assert.equal(await can(role, table, privilege), true, `${role} ${privilege} ${table}`);
      }
    }
    assert.equal(await can("service_role", table, "TRUNCATE"), true);
  }
}

console.log("legacy_signup_and_orphans: ok");

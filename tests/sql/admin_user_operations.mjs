// Run with node tests/sql/admin_user_operations.mjs <path-to-pglite-module>.
// Uses an embedded, throwaway PostgreSQL database. Never contacts Supabase.
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
  create table auth.users(id uuid primary key, last_sign_in_at timestamptz);
  create table public.user_locations(owner_id text primary key);
  create table public.pet_profiles(id text primary key, owner_id text);
  create table public.conversations(id text primary key, owner_id text, messages jsonb);
  create table public.marketplace_listings(id text primary key, owner_id text);
  create table public.chat_user_daily_usage(owner_id text, day date, messages int default 0,
      vision int default 0, dictation int default 0, summary int default 0, sonnet int default 0, followup int default 0);
  create table public.marketplace_user_restrictions(owner_id text primary key, reason text, note text,
      created_at timestamptz, created_by_admin_id text, lifted_at timestamptz, lifted_by_admin_id text);
  create table public.user_devices(owner_id text, device_id text, first_seen_at timestamptz,
      last_seen_at timestamptz, revoked_at timestamptz);
  grant usage on schema public, auth to service_role;
  grant all on all tables in schema public to service_role;
`);
const migration = await readFile(new URL("../../supabase/migrations/20261121165154_admin_user_operations.sql", import.meta.url), "utf8");
await db.exec(migration);
await db.exec(migration); // Idempotent setup.
const owner = "11111111-1111-4111-8111-111111111111";
await db.query("insert into auth.users values ($1, now())", [owner]);
assert.equal((await db.query("select * from public.user_login_events")).rows.length, 1);
await db.query("update auth.users set last_sign_in_at = last_sign_in_at where id = $1", [owner]);
assert.equal((await db.query("select * from public.user_login_events")).rows.length, 1);
await db.query("update auth.users set last_sign_in_at = now() + interval '1 second' where id = $1", [owner]);
assert.equal((await db.query("select * from public.user_login_events")).rows.length, 2);
await db.exec("set role anon");
await assert.rejects(db.query("select * from public.user_login_events"));
await assert.rejects(db.query("select * from public.admin_user_actions"));
await assert.rejects(db.query("select public.admin_user_usage($1)", [owner]));
await db.exec("reset role; set role authenticated");
await assert.rejects(db.query("select * from public.admin_user_actions"));
await assert.rejects(db.query("select public.admin_apply_user_action(gen_random_uuid(), $1, 'admin', 'revoke_devices', 'other', 'support')", [owner]));
await db.exec("reset role; set role service_role");
const request = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
async function action(id, verb = "restrict_marketplace", state = {}, note = "Verified rule breach", target = owner) {
  return (await db.query("select public.admin_apply_user_action($1,$2,'admin',$3,'other',$4,7,null,null,$5) as outcome", [id, target, verb, note, state])).rows[0].outcome;
}
assert.deepEqual(await action(request), { status: "applied", changed: true });
assert.deepEqual(await action(request), { status: "already_applied", changed: true });
assert.equal((await db.query("select * from public.admin_user_actions")).rows.length, 1);
const restriction = (await db.query("select created_at,lifted_at,expires_at from public.marketplace_user_restrictions")).rows[0];
assert.deepEqual(await action("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "lift_marketplace", {}), { status: "conflict", changed: false });
assert.deepEqual(await action("cccccccc-cccc-4ccc-8ccc-cccccccccccc", "lift_marketplace", restriction), { status: "applied", changed: true });
// Invalid audit input rolls the entire intervention back.
await assert.rejects(action("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "restrict_marketplace", null, "x"));
assert.equal((await db.query("select count(*)::int n from public.admin_user_actions")).rows[0].n, 2);
await assert.rejects(db.query("select public.admin_apply_user_action(gen_random_uuid(),$1,'admin','restrict_marketplace','invalid','a valid note',7)", [owner]));
assert.ok((await db.query("select lifted_at from public.marketplace_user_restrictions")).rows[0].lifted_at);
await assert.rejects(db.query("update public.admin_user_actions set note = 'overwritten'"));
await db.query("insert into public.user_devices values ($1,'device',now(),now(),null)", [owner]);
assert.deepEqual(await action("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee", "revoke_devices"), { status: "applied", changed: true });
assert.ok((await db.query("select revoked_at from public.user_devices")).rows[0].revoked_at);
await db.query("insert into public.chat_user_daily_usage(owner_id,day,messages) values ($1,current_date,2),($1,current_date - 7,1),('other',current_date,100)", [owner]);
await db.query("insert into public.conversations values ('chat',$1,$2)", [owner, JSON.stringify([{role:"user",content:"PRIVATE TEXT"},{role:"assistant",content:"OTHER PRIVATE TEXT"}])]);
const usage = (await db.query("select public.admin_user_usage($1) as usage", [owner])).rows[0].usage;
assert.equal(usage.messages, 1);
assert.equal(usage.quota_days_7d, 1);
assert.equal(usage.quota_days_30d, 2);
assert.ok(!JSON.stringify(usage).includes("PRIVATE TEXT"));
await db.exec("reset role");
// Expired restrictions do not affect the caller, including direct DB writes.
await db.exec(`create or replace function auth.uid() returns uuid language sql as $$ select '${owner}'::uuid $$;`);
await db.query("update public.marketplace_user_restrictions set lifted_at=null, expires_at=now()-interval '1 second' where owner_id=$1", [owner]);
assert.equal((await db.query("select public.marketplace_caller_is_restricted() as active")).rows[0].active, false);
await db.query("update public.marketplace_user_restrictions set expires_at=now()+interval '1 day' where owner_id=$1", [owner]);
assert.equal((await db.query("select public.marketplace_caller_is_restricted() as active")).rows[0].active, true);
await db.close();
console.log("SQL checks passed: permissions, login trigger, atomic audit, replay, conflicts, expiry, device revocation and private usage aggregates.");

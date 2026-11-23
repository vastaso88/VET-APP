// Run with: node tests/sql/schema_alignment.mjs [<path-to-pglite-module>]
// Embedded throwaway PostgreSQL (PGlite), synthetic rows, never contacts Supabase.
//
// 2026-11-23: production has clinical_events.owner_id / pet_id / event_type / event_date NOT NULL,
// clinical_events.created_at timestamptz default now(), and reminders.kind text NOT NULL default
// 'custom'. A database built by the old scripts (the collaudo twin) has them optional, with
// created_at as text. This runs the alignment blocks of scripts/setup/supabase_schema.sql on
// tables in the OLD shape, with rows, and checks that: the shape becomes production's, no row
// is lost, the old text timestamps are kept, a second run changes nothing, and rows that cannot
// be repaired stop the script with a clear message instead of disappearing.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";

const root = new URL("../../", import.meta.url);
const require = createRequire(new URL("apps/admin_portal/package.json", root));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const db = new PGlite();

const script = await readFile(new URL("scripts/setup/supabase_schema.sql", root), "utf8");
const slice = (from, to) => {
  const start = script.indexOf(from);
  assert.ok(start >= 0, `marker not found: ${from}`);
  const end = script.indexOf(to, start);
  assert.ok(end >= 0, `marker not found: ${to}`);
  return script.slice(start, end + to.length);
};
const clinical = slice(
  "create or replace function pg_temp.try_timestamptz",
  "alter table public.clinical_events alter column event_date set not null;",
);
const reminders = slice(
  "alter table public.reminders add column if not exists kind text not null default 'custom';",
  "alter table public.reminders alter column kind set not null;",
);

// -- the OLD shape, with rows
await db.exec(`
  create table public.pet_profiles(id text primary key, owner_id text);
  create table public.clinical_events(
    id text primary key,
    pet_id text references public.pet_profiles(id) on delete cascade,
    owner_id text, event_type text, event_date date, title text,
    created_at text not null default now()::text);
  create table public.reminders(id text primary key, owner_id text not null, kind text);
  insert into public.pet_profiles values ('pet-a', 'owner-a');
  insert into public.clinical_events(id, pet_id, owner_id, event_type, event_date, title, created_at) values
    ('e1', 'pet-a', 'owner-a', 'vaccine', '2026-11-20', 'complete row', '2026-11-22T10:00:00.000Z'),
    ('e2', 'pet-a', null, null, null, 'optional fields', '2026-11-21 09:30:00+00'),
    ('e3', 'pet-a', 'owner-a', 'exam', '2026-11-19', 'not a timestamp', 'not a date');
  insert into public.reminders(id, owner_id, kind) values ('r1', 'owner-a', null), ('r2', 'owner-a', 'spot');
`);

// -- a row nobody can repair stops the script, naming the problem, and nothing changes
await db.exec("insert into public.clinical_events(id, pet_id, owner_id, title) values ('e4', null, null, 'orphan')");
await assert.rejects(db.exec(clinical), /have no owner or no pet/);
assert.equal(
  (await db.query("select data_type from information_schema.columns where table_name = 'clinical_events' and column_name = 'created_at'")).rows[0].data_type,
  "text", // the failed run rolled back: still the old shape
);
await db.exec("delete from public.clinical_events where id = 'e4'"); // "fix or remove them by hand"

// -- now it runs
await db.exec(clinical);
await db.exec(reminders);

const column = async (table, name) =>
  (
    await db.query(
      `select data_type, is_nullable, column_default from information_schema.columns
        where table_schema = 'public' and table_name = $1 and column_name = $2`,
      [table, name],
    )
  ).rows[0];
for (const name of ["owner_id", "pet_id", "event_type", "event_date"]) {
  assert.equal((await column("clinical_events", name)).is_nullable, "NO", `${name} NOT NULL`);
}
const createdAt = await column("clinical_events", "created_at");
assert.equal(createdAt.data_type, "timestamp with time zone");
assert.equal(createdAt.is_nullable, "NO");
assert.match(createdAt.column_default, /now\(\)/);
const kind = await column("reminders", "kind");
assert.equal(kind.is_nullable, "NO");
assert.match(kind.column_default, /'custom'/);

// -- no row lost, values kept or derived
const events = (await db.query("select * from public.clinical_events order by id")).rows;
assert.deepEqual(events.map((e) => e.id), ["e1", "e2", "e3"]);
assert.equal(new Date(events[0].created_at).toISOString(), "2026-11-22T10:00:00.000Z"); // the Dart ISO text
assert.equal(new Date(events[1].created_at).toISOString(), "2026-11-21T09:30:00.000Z"); // the old now()::text
assert.ok(Math.abs(new Date(events[2].created_at) - new Date()) < 60_000); // garbage -> now()
assert.equal(events[1].owner_id, "owner-a"); // from the pet
assert.equal(events[1].event_type, "document");
assert.equal(events[1].event_date.toISOString().slice(0, 10), "2026-11-21"); // from created_at
assert.equal(events[0].event_type, "vaccine"); // untouched
const reminderKinds = (await db.query("select id, kind from public.reminders order by id")).rows;
assert.deepEqual(reminderKinds.map((r) => [r.id, r.kind]), [["r1", "custom"], ["r2", "spot"]]);

// -- a second run changes nothing
const before = JSON.stringify((await db.query("select * from public.clinical_events order by id")).rows);
await db.exec(clinical);
await db.exec(reminders);
assert.equal(JSON.stringify((await db.query("select * from public.clinical_events order by id")).rows), before);

// -- the new rules hold: a missing kind takes the default, an explicit null is refused
await db.exec("insert into public.reminders(id, owner_id) values ('r3', 'owner-a')");
assert.equal((await db.query("select kind from public.reminders where id = 'r3'")).rows[0].kind, "custom");
await assert.rejects(db.exec("insert into public.reminders(id, owner_id, kind) values ('r4', 'owner-a', null)"));
await assert.rejects(
  db.exec("insert into public.clinical_events(id, pet_id, owner_id, title) values ('e5', null, 'owner-a', 'x')"),
);
console.log("schema_alignment: ok");

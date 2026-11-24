// Run with: node tests/sql/upsert_of_old_rows.mjs [<path-to-pglite-module>]
// Embedded throwaway PostgreSQL (PGlite), synthetic data, never contacts Supabase.
//
// The app saves reminders and pets with an UPSERT: a «before insert» trigger fires for a row
// that already exists too. A row older than the rule must still be editable; a new bad value
// must still be refused, by insert, update and upsert.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const read = async (path) =>
  (await readFile(new URL(`../../${path}`, import.meta.url), "utf8")).replaceAll("\r\n", "\n");
const reminderSql = await read("scripts/setup/reminder_title_not_blank.sql");
const ricordi = await read("scripts/setup/ricordi_animali.sql");
const start = ricordi.indexOf("create or replace function public.ricordi_loss_date_not_in_future()");
const last = "for each row execute function public.ricordi_loss_date_not_in_future();";
assert.ok(start > 0 && ricordi.indexOf(last) > start);
const lossSql = ricordi.slice(start, ricordi.indexOf(last) + last.length);

const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create table public.reminders(id text primary key, title text, is_done boolean default false);
  create table public.pet_profiles(id text primary key, name text, memorial_date_label text);
  insert into public.reminders(id, title) values ('old', '   '), ('good', 'Vaccino');
  insert into public.pet_profiles values ('old', 'A', '15 mar 2099'), ('good', 'B', '2020');
`);
for (const sql of [reminderSql, lossSql]) {
  await db.exec(sql);
  await db.exec(sql); // idempotent
}

const CASES = [
  ["reminders", "title", "is_done", "true", "'   '", "'Controllo'", /reminder_title_required/],
  ["pet_profiles", "memorial_date_label", "name", "'C'", "'15 mar 2099'", "'2021'", /memorial_date_in_future/],
];
for (const [table, column, other, value, bad, good, refused] of CASES) {
  const upsert = (id, judged) => db.exec(`insert into public.${table}(id, ${column}, ${other})
    values ('${id}', ${judged}, ${value})
    on conflict (id) do update set ${column} = excluded.${column}, ${other} = excluded.${other}`);

  await upsert("old", bad); // the old row, untouched in that column, can still change
  await db.exec(`update public.${table} set ${other} = ${value} where id = 'old'`);
  await assert.rejects(upsert("good", bad), refused, "a good row cannot become bad by upsert");
  await assert.rejects(db.exec(`update public.${table} set ${column} = ${bad} where id = 'good'`), refused);
  await assert.rejects(upsert("new", bad), refused, "a new bad row is refused");
  await upsert("old", good); // it can be put right
  await assert.rejects(upsert("old", bad), refused, "and not back");
  await upsert("new", good);
  const { rows } = await db.query(`select count(*)::int as n from public.${table}`);
  assert.equal(rows[0].n, 3, table);
}
console.log("upsert_of_old_rows: ok");

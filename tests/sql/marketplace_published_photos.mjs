// Nobody but the backend writes where the published photos of the ads are: run with
//   node tests/sql/marketplace_published_photos.mjs [<path-to-pglite-module>]
// Uses an embedded, throwaway PostgreSQL database and synthetic data. Never contacts Supabase.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(new URL("../../apps/admin_portal/package.json", import.meta.url));
const { PGlite } = process.argv[2] ? await import(process.argv[2]) : require("@electric-sql/pglite");
const db = new PGlite();
const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create schema storage;
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable
    as $$ select (string_to_array(name, '/'))[1:greatest(array_length(string_to_array(name, '/'), 1) - 1, 0)] $$;
  grant usage on schema auth, storage to anon, authenticated, service_role;
  grant all on storage.objects to anon, authenticated, service_role;
`);
// The policies of the sellers' own folders, as they are in scripts/setup/marketplace_v2.sql.
const v2 = await readFile(new URL("../../scripts/setup/marketplace_v2.sql", import.meta.url), "utf8");
const own = v2.slice(v2.indexOf("drop policy if exists marketplace_photos_objects_select_own"));
await db.exec(own);
const script = await readFile(new URL("../../scripts/setup/marketplace_published_photos.sql", import.meta.url), "utf8");
await db.exec(script);
await db.exec(script); // Idempotent: the owner may run it twice.
// Even with a policy someone might add one day.
await db.exec(`create policy too_wide on storage.objects for all to authenticated using (true) with check (true);`);

const as = async (role, sub, run) => {
  await db.exec(`set role ${role}; select set_config('request.jwt.claim.sub', '${sub}', false);`);
  try {
    return await run();
  } finally {
    await db.exec("reset role");
  }
};
const insert = (bucket, name) =>
  db.query("insert into storage.objects(bucket_id, name) values ($1, $2)", [bucket, name]);

for (const name of ["published/ad-1/1.jpg", `published/${A}/1.jpg`, "published/1.jpg"]) {
  await insert("marketplace-photos", name); // the backend
  for (const sub of [A, B]) {
    await as("authenticated", sub, async () => {
      await assert.rejects(insert("marketplace-photos", name), `${sub} writes ${name}`);
      await db.query("update storage.objects set name = 'published/x/2.jpg' where name = $1", [name]);
      await db.query("delete from storage.objects where name = $1", [name]);
    });
    // Neither changed nor deleted: no row was theirs to touch.
    assert.equal((await db.query("select 1 from storage.objects where name = $1", [name])).rows.length, 1);
  }
}
await insert("marketplace-photos-held", "published/ad-1/1.jpg");
await as("authenticated", A, async () => {
  await assert.rejects(insert("marketplace-photos-held", `${A}/ad/1.jpg`));
  await insert("marketplace-photos", `${A}/ad/1.jpg`); // their own folder still works
  // ... and a file there cannot be moved among the published ones.
  await assert.rejects(
    db.query("update storage.objects set name = 'published/ad-1/9.jpg' where name = $1", [`${A}/ad/1.jpg`]),
  );
  await db.query("delete from storage.objects where bucket_id = 'marketplace-photos-held'");
  await insert("pet-photos", `${A}/1.jpg`); // other buckets are not touched
  assert.equal((await db.query("delete from storage.objects where name = $1 returning 1", [`${A}/ad/1.jpg`])).rows.length, 1);
});
assert.equal((await db.query("select 1 from storage.objects where bucket_id = 'marketplace-photos-held'")).rows.length, 1);
await as("anon", "", async () => {
  await assert.rejects(insert("marketplace-photos", "published/ad-1/7.jpg"));
});
console.log("marketplace_published_photos: ok");

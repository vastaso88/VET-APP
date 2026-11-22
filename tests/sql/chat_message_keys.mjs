// QK-03b. Run with node tests/sql/chat_message_keys.mjs <path-to-pglite-module>.
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
  grant usage on schema public, auth to service_role, anon, authenticated;
`);
const migration = await readFile(
  new URL("../../supabase/migrations/20261122120000_chat_message_keys.sql", import.meta.url),
  "utf8",
);
await db.exec(migration);
await db.exec(migration); // Idempotent: the owner may run it twice.

// The shape: a key per (owner, client message), text ids, nothing else stored.
const columns = (
  await db.query(
    `select column_name, data_type, is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'chat_message_keys' order by ordinal_position`,
  )
).rows;
assert.deepEqual(
  columns.map((c) => [c.column_name, c.data_type, c.is_nullable]),
  [
    ["owner_id", "text", "NO"],
    ["client_message_id", "text", "NO"],
    ["conversation_id", "text", "NO"],
    ["claimed_at", "timestamp with time zone", "NO"],
    ["answered_reply_id", "text", "YES"],
  ],
);
const primary = (
  await db.query(
    `select a.attname from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey)
      where i.indrelid = 'public.chat_message_keys'::regclass and i.indisprimary order by a.attnum`,
  )
).rows.map((r) => r.attname);
assert.deepEqual(primary, ["owner_id", "client_message_id"]);

// Row level security is on, the "own rows" policy exists, and only service_role has grants.
assert.equal(
  (await db.query("select relrowsecurity from pg_class where oid = 'public.chat_message_keys'::regclass")).rows[0]
    .relrowsecurity,
  true,
);
assert.equal(
  (await db.query("select count(*)::int n from pg_policies where tablename = 'chat_message_keys' and policyname = 'chat_message_keys_own'"))
    .rows[0].n,
  1,
);
for (const role of ["anon", "authenticated"]) {
  await db.exec(`set role ${role}`);
  await assert.rejects(db.query("select * from public.chat_message_keys"));
  await assert.rejects(db.query("insert into public.chat_message_keys(owner_id, client_message_id, conversation_id) values ('a','b','c')"));
  await assert.rejects(db.query("update public.chat_message_keys set answered_reply_id = 'x'"));
  await assert.rejects(db.query("delete from public.chat_message_keys"));
  await db.exec("reset role");
}

// The backend (service_role): reserve, conflict, orphan takeover, answer, retention.
await db.exec("set role service_role");
const claim = (owner, id, conversation) =>
  db.query(
    `insert into public.chat_message_keys(owner_id, client_message_id, conversation_id)
     values ($1, $2, $3) on conflict (owner_id, client_message_id) do nothing returning claimed_at`,
    [owner, id, conversation],
  );
assert.equal((await claim("owner-a", "msg-1", "chat-1")).rows.length, 1); // inserted: it owns the message
assert.equal((await claim("owner-a", "msg-1", "chat-2")).rows.length, 0); // conflict: nothing comes back
assert.equal((await claim("owner-b", "msg-1", "chat-b")).rows.length, 1); // another owner, same client id
assert.equal(
  (await db.query("select conversation_id from public.chat_message_keys where owner_id = 'owner-a'")).rows[0]
    .conversation_id,
  "chat-1",
);
await assert.rejects(
  db.query("insert into public.chat_message_keys(owner_id, client_message_id, conversation_id) values ('owner-a','msg-1','x')"),
);

// Orphan takeover: a conditional update on claimed_at, sent back exactly as read (as text: a JS Date
// would cut the microseconds); of two takers exactly one wins.
const seen = (await db.query("select claimed_at::text as claimed_at from public.chat_message_keys where owner_id = 'owner-a'")).rows[0].claimed_at;
const retake = (previous, conversation) =>
  db.query(
    `update public.chat_message_keys set conversation_id = $1, claimed_at = now(), answered_reply_id = null
      where owner_id = 'owner-a' and client_message_id = 'msg-1' and claimed_at = $2::timestamptz and answered_reply_id is null
      returning conversation_id`,
    [conversation, previous],
  );
assert.equal((await retake(seen, "chat-taker-1")).rows.length, 1);
assert.equal((await retake(seen, "chat-taker-2")).rows.length, 0);

// Once answered, an unanswered-only takeover no longer applies; releasing keeps an answered key.
await db.query("update public.chat_message_keys set answered_reply_id = 'reply-1' where owner_id = 'owner-a'");
const answeredSeen = (await db.query("select claimed_at::text as claimed_at from public.chat_message_keys where owner_id = 'owner-a'")).rows[0].claimed_at;
assert.equal((await retake(answeredSeen, "chat-late")).rows.length, 0);
assert.equal(
  (
    await db.query(
      "delete from public.chat_message_keys where owner_id = 'owner-a' and client_message_id = 'msg-1' and answered_reply_id is null returning 1",
    )
  ).rows.length,
  0,
);

// Retention: keys older than 30 days go, the others stay.
await db.query("update public.chat_message_keys set claimed_at = now() - interval '40 days' where owner_id = 'owner-b'");
assert.equal(
  (await db.query("delete from public.chat_message_keys where claimed_at < now() - interval '30 days' returning 1")).rows.length,
  1,
);
assert.deepEqual((await db.query("select owner_id from public.chat_message_keys")).rows.map((r) => r.owner_id), ["owner-a"]);
await db.exec("reset role");
console.log("chat_message_keys: ok");

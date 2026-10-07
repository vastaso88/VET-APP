create table if not exists public.pet_profiles (
    id text primary key,
    owner_id text not null,
    name text not null,
    species text not null,
    breed text,
    age_years integer,
    notes text
);

-- Additive columns for the rest of the mobile PetProfile model, wired up
-- 2026-09-26 (pets feature had no Supabase backing at all until then, see
-- docs/auth/01_brainstorm.md). `notes` above already covers medicalNote.
--
-- These MUST be `alter table add column if not exists`, never fields inside
-- the `create table if not exists` above: on an already-existing table (as
-- pet_profiles was here) `create table if not exists` is a no-op, so a
-- column declared only there silently never gets added — exactly what
-- happened to medical_record_consent/habitat/aquarium_stock below on
-- 2026-09-27 (every pet creation failed with postgrest's PGRST204 "column
-- ... not found in schema cache" until this was caught and fixed
-- 2026-09-28). If you add a new PetProfile field, add it as its own `alter
-- table` line here, not inside the `create table` block above.
alter table public.pet_profiles add column if not exists birth_date_label text;
alter table public.pet_profiles add column if not exists sex text;
alter table public.pet_profiles add column if not exists weight_label text;
alter table public.pet_profiles add column if not exists health_badge text;
alter table public.pet_profiles add column if not exists next_visit_label text;
alter table public.pet_profiles add column if not exists avatar_emoji text;
alter table public.pet_profiles add column if not exists accent_color_value bigint;
alter table public.pet_profiles add column if not exists identity_color_value bigint;
alter table public.pet_profiles add column if not exists dog_size_category text;
alter table public.pet_profiles add column if not exists is_memorial boolean not null default false;
alter table public.pet_profiles add column if not exists memorial_date_label text;
-- Medical-record access consent (spec v3 §18) — persisted per pet, not per
-- conversation, so it's asked once and revocable later. Nullable:
-- {granted: bool, version: text, decided_at: timestamptz}.
alter table public.pet_profiles add column if not exists medical_record_consent jsonb;
-- Enclosure characteristics for aquarium/terrarium/aviary species — field
-- shape agreed with the "UI/UX e funzionalità base" session's mobile-local
-- model (2026-09-20): {dimensions, volume_liters, temperature_label,
-- substrate, notes}, all optional.
alter table public.pet_profiles add column if not exists habitat jsonb;
-- Multi-species aquarium composition: [{species, male_count, female_count},
-- ...]. A non-empty array means this profile represents a whole aquarium
-- rather than a single fish.
alter table public.pet_profiles
    add column if not exists aquarium_stock jsonb not null default '[]'::jsonb;

create table if not exists public.conversations (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    title text not null,
    messages jsonb not null default '[]'::jsonb
);

-- Additive columns — see the pet_profiles comment above for why these must
-- stay as their own `alter table` lines (conversations pre-existed too, so
-- these were caught missing by the same 2026-09-28 fix).
-- VetGPT Milestone 1 (Situation Model / Interview / Coverage) — nullable.
alter table public.conversations add column if not exists situation_model jsonb;
alter table public.conversations add column if not exists coverage_score double precision;
alter table public.conversations
    add column if not exists state text not null default 'NEED_MORE_INFORMATION';
alter table public.conversations
    add column if not exists interview_turns_used integer not null default 0;
-- VetGPT Milestone 2 (medical record access consent) — nullable.
alter table public.conversations add column if not exists medical_record_consent boolean;
alter table public.conversations
    add column if not exists awaiting_medical_record_consent boolean not null default false;
-- Safety triage clarification (brief, category-specific follow-up before
-- escalating a red-flag message) — nullable.
alter table public.conversations
    add column if not exists awaiting_safety_clarification boolean not null default false;
alter table public.conversations add column if not exists safety_clarification_category text;

-- VetGPT Milestone 2: summaries of a pet's clinical documents, consulted by
-- the chat only after explicit owner consent (see ChatOrchestrator). This
-- table is also where the Flutter medical_records feature already writes
-- (as `clinical_events`); pet_id is nullable/additive so existing rows
-- written without it keep working, but the chat integration only reads
-- rows that do have a pet_id set.
create table if not exists public.clinical_events (
    id text primary key,
    pet_id text references public.pet_profiles(id) on delete cascade,
    pet_name text not null,
    title text not null,
    subtitle text,
    meta text,
    badge text,
    detail_source text,
    created_at text not null default now()::text
);

-- Links an uploaded referto (medical_records feature) to its real file,
-- stored via the existing chat-attachments pipeline (same bucket/service-
-- role posture, see chat_attachments below) rather than a new bucket. Not
-- a real FK: chat_attachments is declared later in this script, and
-- clinical_events (like pet_profiles/conversations, see the 2026-09-28
-- fix above) may already exist live, so this stays a plain nullable
-- column rather than depending on statement order. Additive — found
-- missing 2026-09-29 alongside the medical_records_repository table-name
-- bug (it was reading from a nonexistent `medical_records` table instead
-- of this one).
alter table public.clinical_events add column if not exists attachment_id text;

-- Found 2026-10-04 reading the live schema: clinical_events already existed
-- in the live project (from the earlier system) with a different shape, so
-- the `create table if not exists` above was a no-op there - same trap as
-- 9d6522f. Live columns: id, owner_id NOT NULL, pet_id NOT NULL, event_type
-- NOT NULL, title NOT NULL, event_date date NOT NULL, summary, severity,
-- source, linked_document_id, created_at timestamptz, attachment_id.
-- Every column the app writes is therefore declared explicitly here, and
-- the live table's NOT NULL columns that the app does not fill get a
-- default, so an insert from the app succeeds on either shape.
alter table public.clinical_events add column if not exists pet_name text;
alter table public.clinical_events add column if not exists subtitle text;
alter table public.clinical_events add column if not exists meta text;
alter table public.clinical_events add column if not exists badge text;
alter table public.clinical_events add column if not exists detail_source text;
-- The live table's own columns, so a database created from this script has
-- the same shape (nullable here; NOT NULL only where it already was).
alter table public.clinical_events add column if not exists owner_id text;
alter table public.clinical_events add column if not exists event_type text;
alter table public.clinical_events add column if not exists event_date date;
alter table public.clinical_events add column if not exists summary text;
alter table public.clinical_events alter column owner_id set default auth.uid()::text;
alter table public.clinical_events alter column event_type set default 'document';
alter table public.clinical_events alter column event_date set default current_date;
-- pet_name was NOT NULL only in this script's own (never applied live)
-- definition; the chat does not need it and old rows do not have it.
alter table public.clinical_events alter column pet_name drop not null;

create table if not exists public.reminders (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    title text not null,
    due_date date not null,
    notes text
);

-- Additive columns for the rest of the mobile ReminderEntry model (spot/
-- recurring/course kinds, recurrence rules) — same "existing table, add
-- column if not exists" pattern as 9d6522f, found missing 2026-09-29 when
-- saveReminder's upsert was failing silently against this table.
alter table public.reminders add column if not exists pet_name text;
alter table public.reminders add column if not exists kind text;
alter table public.reminders add column if not exists due_at timestamptz;
alter table public.reminders add column if not exists interval_unit text;
alter table public.reminders add column if not exists interval_value integer;
alter table public.reminders add column if not exists recurrence_end text;
alter table public.reminders add column if not exists occurrence_count integer;
alter table public.reminders add column if not exists recurrence_end_date timestamptz;
alter table public.reminders add column if not exists course_duration_days integer;
alter table public.reminders add column if not exists is_done boolean not null default false;
-- Daily dose times ("08:00", "20:00") of a medicine course, one phone
-- notification each per day (apps/mobile_app/lib/features/notifications/).
alter table public.reminders add column if not exists dose_times text[];

-- Account-level consents (docs/compliance/04_termini_e_consensi.md): ToS,
-- privacy policy, marketing email, analytics. One row per owner; each key
-- maps to {granted: bool, version: text, decided_at: timestamptz}.
create table if not exists public.account_consents (
    owner_id text primary key,
    consents jsonb not null default '{}'::jsonb
);

-- Subscriptions: single-row-per-owner, same shape as account_consents.
-- Starts the 10-day free trial (no card) on first lookup; `plan` stays
-- null while on trial, then holds the chosen plan key permanently.
create table if not exists public.subscriptions (
    owner_id text primary key,
    trial_ends_at timestamptz not null,
    plan text,
    created_at timestamptz not null default now()
);

create index if not exists idx_pet_profiles_owner_id on public.pet_profiles(owner_id);
create index if not exists idx_conversations_owner_id on public.conversations(owner_id);
create index if not exists idx_conversations_pet_id on public.conversations(pet_id);
create index if not exists idx_clinical_events_pet_id on public.clinical_events(pet_id);
create index if not exists idx_reminders_owner_id on public.reminders(owner_id);
create index if not exists idx_reminders_pet_id on public.reminders(pet_id);

alter table public.pet_profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.clinical_events enable row level security;
alter table public.reminders enable row level security;
alter table public.account_consents enable row level security;
alter table public.subscriptions enable row level security;

drop policy if exists pet_profiles_select_own on public.pet_profiles;
create policy pet_profiles_select_own
on public.pet_profiles
for select
using (owner_id = auth.uid()::text);

drop policy if exists pet_profiles_insert_own on public.pet_profiles;
create policy pet_profiles_insert_own
on public.pet_profiles
for insert
with check (owner_id = auth.uid()::text);

drop policy if exists pet_profiles_update_own on public.pet_profiles;
create policy pet_profiles_update_own
on public.pet_profiles
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

drop policy if exists pet_profiles_delete_own on public.pet_profiles;
create policy pet_profiles_delete_own
on public.pet_profiles
for delete
using (owner_id = auth.uid()::text);

drop policy if exists conversations_select_own on public.conversations;
create policy conversations_select_own
on public.conversations
for select
using (owner_id = auth.uid()::text);

drop policy if exists conversations_insert_own on public.conversations;
create policy conversations_insert_own
on public.conversations
for insert
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.conversations.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists conversations_update_own on public.conversations;
create policy conversations_update_own
on public.conversations
for update
using (owner_id = auth.uid()::text)
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.conversations.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists conversations_delete_own on public.conversations;
create policy conversations_delete_own
on public.conversations
for delete
using (owner_id = auth.uid()::text);

drop policy if exists clinical_events_select_own on public.clinical_events;
create policy clinical_events_select_own
on public.clinical_events
for select
using (
    pet_id is not null
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.clinical_events.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists clinical_events_insert_own on public.clinical_events;
create policy clinical_events_insert_own
on public.clinical_events
for insert
with check (
    pet_id is null
    or exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.clinical_events.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists reminders_select_own on public.reminders;
create policy reminders_select_own
on public.reminders
for select
using (owner_id = auth.uid()::text);

drop policy if exists reminders_insert_own on public.reminders;
create policy reminders_insert_own
on public.reminders
for insert
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.reminders.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists reminders_update_own on public.reminders;
create policy reminders_update_own
on public.reminders
for update
using (owner_id = auth.uid()::text)
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.reminders.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists reminders_delete_own on public.reminders;
create policy reminders_delete_own
on public.reminders
for delete
using (owner_id = auth.uid()::text);

drop policy if exists account_consents_select_own on public.account_consents;
create policy account_consents_select_own
on public.account_consents
for select
using (owner_id = auth.uid()::text);

drop policy if exists account_consents_insert_own on public.account_consents;
create policy account_consents_insert_own
on public.account_consents
for insert
with check (owner_id = auth.uid()::text);

drop policy if exists account_consents_update_own on public.account_consents;
create policy account_consents_update_own
on public.account_consents
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own
on public.subscriptions
for select
using (owner_id = auth.uid()::text);

drop policy if exists subscriptions_insert_own on public.subscriptions;
create policy subscriptions_insert_own
on public.subscriptions
for insert
with check (owner_id = auth.uid()::text);

drop policy if exists subscriptions_update_own on public.subscriptions;
create policy subscriptions_update_own
on public.subscriptions
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

-- Maps management (docs/maps/): shared location primitive, one row per
-- owner, same shape as account_consents. Plain lat/lng columns rather than
-- PostGIS - sufficient at this scale and avoids managing an extension in a
-- schema file with no migrations (docs/maps/01_localita_fondamenta_condivise.md).
create table if not exists public.user_locations (
    owner_id text primary key,
    mode text not null default 'current_position',
    home_latitude double precision,
    home_longitude double precision,
    home_label text,
    current_latitude double precision,
    current_longitude double precision,
    current_label text,
    current_source text,
    current_captured_at timestamptz,
    updated_at timestamptz not null default now()
);

-- Passeggiate con il cane. route is a JSONB array of
-- {coordinates: {latitude, longitude}, recorded_at, accuracy_meters}.
create table if not exists public.dog_walks (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    status text not null default 'in_progress',
    started_at timestamptz not null,
    ended_at timestamptz,
    distance_meters double precision not null default 0,
    duration_seconds integer,
    step_count_estimate integer,
    route jsonb not null default '[]'::jsonb,
    -- Starred by the owner, max 5 per pet (enforced client-side, see
    -- walk_retention.dart) - independent of is this the longest walk ever.
    is_favorite boolean not null default false,
    -- Pausa/Riavvia (client-side, active_walk_controller.dart): paused_at is
    -- when the current pause began (null if not paused), paused_seconds is
    -- the running total of every *completed* pause interval so far.
    is_paused boolean not null default false,
    paused_at timestamptz,
    paused_seconds integer not null default 0,
    created_at timestamptz not null default now()
);

-- dog_walks already existed on the live DB before is_favorite/is_paused/
-- paused_at/paused_seconds were added above - same "existing table, add
-- column if not exists" pattern as 9d6522f, needed or the first upsert
-- referencing these columns fails against the real schema even though a
-- fresh `create table if not exists` never runs on it again. `route` is
-- jsonb (starts_new_segment lives inside each point's JSON, not its own
-- column), so no alter is needed for the pause route-segment marker.
alter table public.dog_walks add column if not exists is_favorite boolean not null default false;
alter table public.dog_walks add column if not exists is_paused boolean not null default false;
alter table public.dog_walks add column if not exists paused_at timestamptz;
alter table public.dog_walks add column if not exists paused_seconds integer not null default 0;

-- Mercatino dell'usato. latitude/longitude are snapped to a ~1 km grid
-- before insert (the app's listing_location.dart, create_listing.py) and
-- again by the guard_marketplace_listing trigger further down.
create table if not exists public.marketplace_listings (
    id text primary key,
    owner_id text not null,
    title text not null,
    description text,
    category text not null,
    condition text not null,
    price_cents integer,
    photo_urls jsonb not null default '[]'::jsonb,
    latitude double precision not null,
    longitude double precision not null,
    city_label text,
    status text not null default 'active',
    report_count integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.marketplace_listing_reports (
    id text primary key,
    listing_id text not null references public.marketplace_listings(id) on delete cascade,
    reporter_owner_id text not null,
    reason text not null,
    created_at timestamptz not null default now()
);

-- "Segnala questa risposta": an owner flags a specific chat reply as
-- missing, limited, or wrong. Feeds the same real-usage bug pipeline the
-- app's own engineering already uses for stress testing, just sourced
-- from real users. reported_answer snapshots the message content at
-- report time rather than only storing message_id, so a report stays
-- self-contained for review. credited_bug_ref stays null until a human
-- confirms (at fix time, not automatically) that this report corresponds
-- to an actual shipped fix — the reward mechanics (a free week per
-- resolved bug, capped monthly per user) can't be wired to real billing
-- yet (only a local Flutter demo store exists today), so this field is
-- the hook for whenever that billing exists, rather than a future schema
-- change (docs/marketing/01_brainstorm.md).
-- Photo attachments: metadata only, the image bytes themselves go through
-- media_storage (local disk in dev, a Supabase Storage bucket named by
-- MEDIA_STORAGE_BUCKET when PERSISTENCE_BACKEND=supabase — required on
-- serverless deploys, whose filesystem is read-only), independent of this
-- table. conversation_id starts null — an
-- attachment can be uploaded before a conversation officially exists yet
-- (a brand new chat), scoped by pet_id until it's actually referenced in
-- a sent message. Deliberately unrelated to any pet gallery/memorial
-- feature: nothing links this table to pet_profiles beyond pet_id itself.
create table if not exists public.chat_attachments (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    conversation_id text references public.conversations(id) on delete set null,
    storage_key text not null,
    content_type text not null,
    original_filename text not null,
    analysis text,
    analysis_failed boolean not null default false,
    created_at timestamptz not null default now()
);

create table if not exists public.chat_response_reports (
    id text primary key,
    conversation_id text not null references public.conversations(id) on delete cascade,
    message_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    reporter_owner_id text not null,
    reason text not null default 'other',
    details text,
    reported_answer text not null,
    status text not null default 'reported',
    created_at timestamptz not null default now(),
    resolved_at timestamptz,
    resolution_note text,
    credited_bug_ref text
);

-- Attività attorno a te / Eventi nei dintorni. location is never fuzzed -
-- public venues/events that already advertise their own address.
create table if not exists public.local_activities (
    id text primary key,
    kind text not null,
    title text not null,
    description text,
    category text,
    latitude double precision not null,
    longitude double precision not null,
    address_label text,
    starts_at timestamptz,
    ends_at timestamptz,
    source text not null default 'user_submitted',
    submitted_by_owner_id text,
    status text not null default 'active',
    report_count integer not null default 0,
    created_at timestamptz not null default now()
);

create index if not exists idx_dog_walks_owner_id on public.dog_walks(owner_id);
create index if not exists idx_dog_walks_pet_id on public.dog_walks(pet_id);
create index if not exists idx_marketplace_listings_status on public.marketplace_listings(status);
create index if not exists idx_marketplace_listings_category
    on public.marketplace_listings(category);
create index if not exists idx_marketplace_listing_reports_listing_id
    on public.marketplace_listing_reports(listing_id);
create index if not exists idx_local_activities_status on public.local_activities(status);
create index if not exists idx_local_activities_kind on public.local_activities(kind);
-- Privacy posture for chat response reports (2026-10-03,
-- docs/compliance/07_contributi_utenti.md). Additive/idempotent, because
-- the table already exists live:
-- * reporter_ref: keyed pseudonym (HMAC of the owner id, computed by the
--   backend) stored instead of the owner id. reporter_owner_id is kept
--   only as a nullable legacy column: new rows leave it null, and the
--   backend maintenance job converts and blanks any old row.
-- * chat_response_report_counters: all that survives a report once its
--   retention (12 months after the outcome) has passed.
alter table public.chat_response_reports add column if not exists reporter_ref text;
alter table public.chat_response_reports alter column reporter_owner_id drop not null;
create index if not exists idx_chat_response_reports_reporter_ref
    on public.chat_response_reports(reporter_ref);

create table if not exists public.chat_response_report_counters (
    period text not null,
    reason text not null,
    status text not null,
    total integer not null default 0,
    primary key (period, reason, status)
);
alter table public.chat_response_report_counters enable row level security;

create index if not exists idx_chat_response_reports_conversation_id
    on public.chat_response_reports(conversation_id);
create index if not exists idx_chat_response_reports_status
    on public.chat_response_reports(status);
create index if not exists idx_chat_attachments_pet_id on public.chat_attachments(pet_id);
create index if not exists idx_chat_attachments_conversation_id
    on public.chat_attachments(conversation_id);

alter table public.user_locations enable row level security;
alter table public.dog_walks enable row level security;
alter table public.marketplace_listings enable row level security;
alter table public.marketplace_listing_reports enable row level security;
alter table public.local_activities enable row level security;
alter table public.chat_response_reports enable row level security;
alter table public.chat_attachments enable row level security;

-- user_locations: single-row-per-owner, same shape as account_consents.
drop policy if exists user_locations_select_own on public.user_locations;
create policy user_locations_select_own
on public.user_locations
for select
using (owner_id = auth.uid()::text);

drop policy if exists user_locations_insert_own on public.user_locations;
create policy user_locations_insert_own
on public.user_locations
for insert
with check (owner_id = auth.uid()::text);

drop policy if exists user_locations_update_own on public.user_locations;
create policy user_locations_update_own
on public.user_locations
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

-- dog_walks: owner-scoped + pet-ownership check, same shape as reminders.
drop policy if exists dog_walks_select_own on public.dog_walks;
create policy dog_walks_select_own
on public.dog_walks
for select
using (owner_id = auth.uid()::text);

drop policy if exists dog_walks_insert_own on public.dog_walks;
create policy dog_walks_insert_own
on public.dog_walks
for insert
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.dog_walks.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists dog_walks_update_own on public.dog_walks;
create policy dog_walks_update_own
on public.dog_walks
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

drop policy if exists dog_walks_delete_own on public.dog_walks;
create policy dog_walks_delete_own
on public.dog_walks
for delete
using (owner_id = auth.uid()::text);

-- marketplace_listings: FIRST table in this schema with intentionally open
-- read access - everyone needs to browse everyone's listings. Safe only
-- because latitude/longitude are snapped to a ~1 km grid at write time,
-- never the exact address (see guard_marketplace_listing below).
drop policy if exists marketplace_listings_select_all on public.marketplace_listings;
create policy marketplace_listings_select_all
on public.marketplace_listings
for select
using (true);

drop policy if exists marketplace_listings_insert_own on public.marketplace_listings;
create policy marketplace_listings_insert_own
on public.marketplace_listings
for insert
with check (owner_id = auth.uid()::text);

drop policy if exists marketplace_listings_update_own on public.marketplace_listings;
create policy marketplace_listings_update_own
on public.marketplace_listings
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

drop policy if exists marketplace_listings_delete_own on public.marketplace_listings;
create policy marketplace_listings_delete_own
on public.marketplace_listings
for delete
using (owner_id = auth.uid()::text);

-- marketplace_listing_reports: insert-only for regular users. No select
-- policy at all -> default deny, reviewable only via the service role.
drop policy if exists marketplace_listing_reports_insert_own on public.marketplace_listing_reports;
create policy marketplace_listing_reports_insert_own
on public.marketplace_listing_reports
for insert
with check (reporter_owner_id = auth.uid()::text);

-- The deny-by-default posture above is intentional (a reporter shouldn't
-- see who else reported a listing) but it also means an ordinary client
-- can never count distinct reporters or flip someone else's listing to
-- "removed" - both are blocked by RLS regardless of who is asking. This
-- function runs with the privileges of its owner (not the caller), so it
-- can do both safely; the trigger below is what actually makes
-- REPORT_COUNT_AUTO_REMOVE_THRESHOLD (packages/core/domain/marketplace/models.py)
-- take effect for reports written directly from the mobile app.
create or replace function public.handle_marketplace_listing_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    distinct_reporters integer;
begin
    select count(distinct reporter_owner_id)
    into distinct_reporters
    from public.marketplace_listing_reports
    where listing_id = new.listing_id;

    update public.marketplace_listings
    set report_count = distinct_reporters,
        status = case
            when distinct_reporters >= 3 and status not in ('sold', 'removed') then 'removed'
            else status
        end,
        updated_at = now()
    where id = new.listing_id;

    return new;
end;
$$;

drop trigger if exists on_marketplace_listing_report_insert on public.marketplace_listing_reports;
create trigger on_marketplace_listing_report_insert
after insert on public.marketplace_listing_reports
for each row execute function public.handle_marketplace_listing_report();

-- local_activities: open read (public venues/events), submitter-scoped write.
drop policy if exists local_activities_select_all on public.local_activities;
create policy local_activities_select_all
on public.local_activities
for select
using (true);

drop policy if exists local_activities_insert_own on public.local_activities;
create policy local_activities_insert_own
on public.local_activities
for insert
with check (submitted_by_owner_id = auth.uid()::text);

drop policy if exists local_activities_update_own on public.local_activities;
create policy local_activities_update_own
on public.local_activities
for update
using (submitted_by_owner_id = auth.uid()::text)
with check (submitted_by_owner_id = auth.uid()::text);

-- chat_response_reports: no client access at all. RLS is enabled with NO
-- policy -> default deny for select/insert/update/delete, so nobody can
-- read (or forge) a report through the Supabase client; every read and
-- write goes through the Python backend's service-role client, which
-- pseudonymizes the reporter and anonymizes the text before storing, and
-- restricts review to the developer allowlist. The earlier insert-own
-- policy is dropped: a direct client insert would bypass exactly those
-- protections. Same for chat_response_report_counters (RLS on, no policy).
drop policy if exists chat_response_reports_insert_own on public.chat_response_reports;

-- chat_attachments: insert-only for regular users, same posture as
-- chat_response_reports. No select/update policy -> default deny; the
-- Python backend's service-role client is the only reader (see
-- GET /chat-attachments/{id}/file, which does its own ownership check).
-- pet_id-scoped rather than conversation_id-scoped in the check because
-- an attachment can be uploaded before a conversation exists yet.
drop policy if exists chat_attachments_insert_own on public.chat_attachments;
create policy chat_attachments_insert_own
on public.chat_attachments
for insert
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.chat_attachments.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

-- Storage bucket for chat/medical-record attachment bytes (see
-- SupabaseMediaStorage). Private: only the Python backend's service-role
-- client reads/writes it, same posture as the chat_attachments table
-- above, so no storage.objects policy is needed for regular users.
insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

-- Nearby pet-services radar ("cosa c'e' attorno"): places imported from
-- OpenStreetMap/Overpass, cached per geographic cell and shared by every
-- user in that cell (see packages/core/domain/coverage/models.py). RLS on
-- with no policies: only the Python backend's service-role client
-- reads/writes them, same posture as chat_attachments.
create table if not exists public.radar_coverage_cells (
    coverage_key text primary key,
    center_latitude double precision not null,
    center_longitude double precision not null,
    radius_km double precision not null,
    source_name text not null,
    place_count integer not null default 0,
    refreshed_at timestamptz not null default now(),
    expires_at timestamptz not null
);

create table if not exists public.radar_places_cache (
    id text primary key,
    coverage_key text not null,
    place_type text not null,
    subtype text,
    name text not null,
    summary text,
    city text,
    address_label text,
    latitude double precision not null,
    longitude double precision not null,
    source_name text not null,
    source_external_id text not null,
    source_url text,
    phone text,
    website_url text,
    is_pet_friendly boolean not null default true,
    tags jsonb not null default '[]'::jsonb,
    source_fetched_at timestamptz,
    status text not null default 'active'
);

create index if not exists radar_places_cache_coverage_key_idx
    on public.radar_places_cache (coverage_key);

alter table public.radar_places_cache add column if not exists opening_hours text;
alter table public.radar_places_cache
    add column if not exists species jsonb not null default '[]'::jsonb;

alter table public.radar_coverage_cells enable row level security;
alter table public.radar_places_cache enable row level security;

-- Pet photos: profile picture (pet_profiles.photo_path points at the current
-- one) plus a gallery. Files live in the private 'pet-photos' bucket under
-- <owner_id>/<pet_id>/<photo_id>.jpg; the owner-folder policies below key on that.
alter table public.pet_profiles add column if not exists photo_path text;

create table if not exists public.pet_photos (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    storage_path text not null,
    created_at timestamptz not null default now(),
    is_profile boolean not null default false
);
create index if not exists pet_photos_pet_created_idx on public.pet_photos (pet_id, created_at desc);

-- Short videos share the gallery table and the same private bucket (the file
-- keeps its mp4/mov extension in storage_path). Rows written before this
-- migration are photos by default, so the app works with or without it.
alter table public.pet_photos add column if not exists media_type text not null default 'photo';
alter table public.pet_photos add column if not exists duration_seconds integer;
alter table public.pet_photos add column if not exists size_bytes bigint;

-- When a photo or video was actually shot (in-app camera time, or the EXIF
-- date of an imported photo) - created_at is only the upload time. Lets the
-- gallery caption a shot taken during a walk ("Passeggiata del 07/10/26").
-- Nullable: unknown for older rows and imported videos. The app saves rows
-- without it until this has run.
alter table public.pet_photos add column if not exists taken_at timestamptz;
do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'pet_photos_media_type_check'
    ) then
        alter table public.pet_photos
            add constraint pet_photos_media_type_check check (media_type in ('photo', 'video'));
    end if;
end $$;

alter table public.pet_photos enable row level security;

drop policy if exists pet_photos_select_own on public.pet_photos;
create policy pet_photos_select_own on public.pet_photos
for select using (owner_id = auth.uid()::text);

drop policy if exists pet_photos_insert_own on public.pet_photos;
create policy pet_photos_insert_own on public.pet_photos
for insert with check (owner_id = auth.uid()::text);

drop policy if exists pet_photos_update_own on public.pet_photos;
create policy pet_photos_update_own on public.pet_photos
for update using (owner_id = auth.uid()::text) with check (owner_id = auth.uid()::text);

drop policy if exists pet_photos_delete_own on public.pet_photos;
create policy pet_photos_delete_own on public.pet_photos
for delete using (owner_id = auth.uid()::text);

insert into storage.buckets (id, name, public)
values ('pet-photos', 'pet-photos', false)
on conflict (id) do nothing;

-- Server-side ceiling for one object, equal to petVideoMaxBytes in the app
-- (pet_video_rules.dart): 20 MB since build 26, when the phone started
-- re-encoding videos to 720p (was 50 MB). The app checks first, this stops
-- anything that bypasses it. Photos are ~0.3-0.6 MB.
update storage.buckets set file_size_limit = 20000000 where id = 'pet-photos';

drop policy if exists pet_photos_objects_select_own on storage.objects;
create policy pet_photos_objects_select_own on storage.objects
for select using (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists pet_photos_objects_insert_own on storage.objects;
create policy pet_photos_objects_insert_own on storage.objects
for insert with check (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists pet_photos_objects_delete_own on storage.objects;
create policy pet_photos_objects_delete_own on storage.objects
for delete using (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Radar offline catalog: places imported in bulk by scripts/radar/, so
-- the API answers from this database instead of calling a provider while
-- a user waits. One table per source, never joined into a combined
-- table: OpenStreetMap is ODbL (share-alike) and must stay separable
-- from the permissively licensed Overture data. Sources are combined
-- only in memory, per request (packages/core/domain/radar_places/dedup.py).
-- RLS on with no policies: service-role only, same posture as the cache.
create table if not exists public.data_sources (
    source text primary key,
    release text not null,
    license text not null,
    attribution text not null,
    url text,
    place_count integer not null default 0,
    imported_at timestamptz not null default now(),
    min_latitude double precision,
    max_latitude double precision,
    min_longitude double precision,
    max_longitude double precision
);

create table if not exists public.radar_places_osm (
    id text primary key,
    place_type text not null,
    subtype text,
    name text not null,
    summary text,
    opening_hours text,
    species jsonb not null default '[]'::jsonb,
    details jsonb not null default '{}'::jsonb,
    city text,
    address_label text,
    latitude double precision not null,
    longitude double precision not null,
    source_external_id text not null,
    source_url text,
    phone text,
    website_url text,
    imported_at timestamptz not null default now()
);

create index if not exists radar_places_osm_position_idx
    on public.radar_places_osm (latitude, longitude);

create table if not exists public.radar_places_open (
    id text primary key,
    source text not null,
    source_id text not null,
    place_type text not null,
    subtype text,
    name text not null,
    latitude double precision not null,
    longitude double precision not null,
    address_label text,
    city text,
    phone text,
    website_url text,
    confidence double precision,
    license text not null,
    release text not null,
    imported_at timestamptz not null default now()
);

create index if not exists radar_places_open_position_idx
    on public.radar_places_open (latitude, longitude);

-- Manual corrections the importers and the API respect: a place listed
-- here with action 'exclude' is not imported again and not shown.
create table if not exists public.radar_place_overrides (
    source text not null,
    source_id text not null,
    action text not null default 'exclude',
    reason text,
    created_at timestamptz not null default now(),
    primary key (source, source_id, action)
);

alter table public.radar_places_cache
    add column if not exists details jsonb not null default '{}'::jsonb;

alter table public.data_sources enable row level security;
alter table public.radar_places_osm enable row level security;
alter table public.radar_places_open enable row level security;
alter table public.radar_place_overrides enable row level security;

-- "Segnala!": community reports on the radar, the votes that confirm or
-- deny them, and star ratings of public dog parks. Our own data, never
-- written to OpenStreetMap or into the open-data tables. People appear
-- only as a keyed pseudonym computed by the backend (RADAR_PSEUDONYM_KEY,
-- kept outside the database): no account id is stored here, and no
-- table maps pseudonyms back to accounts. RLS on with no policies: all
-- access goes through the backend's service-role client.
create table if not exists public.radar_user_reports (
    id text primary key,
    kind text not null,
    status text not null default 'pending',
    place_type text not null,
    name text not null,
    latitude double precision not null,
    longitude double precision not null,
    address_label text,
    target_source text,
    target_source_id text,
    reporter_pseudonym text not null,
    confirmations integer not null default 0,
    denials integer not null default 0,
    created_at timestamptz not null default now(),
    resolved_at timestamptz
);

create index if not exists radar_user_reports_position_idx
    on public.radar_user_reports (latitude, longitude);
create index if not exists radar_user_reports_reporter_idx
    on public.radar_user_reports (reporter_pseudonym, created_at);

create table if not exists public.radar_report_votes (
    report_id text not null references public.radar_user_reports(id) on delete cascade,
    voter_pseudonym text not null,
    vote smallint not null,
    created_at timestamptz not null default now(),
    primary key (report_id, voter_pseudonym)
);

create table if not exists public.radar_place_ratings (
    source text not null,
    source_id text not null,
    voter_pseudonym text not null,
    stars smallint not null check (stars between 1 and 5),
    latitude double precision not null,
    longitude double precision not null,
    updated_at timestamptz not null default now(),
    primary key (source, source_id, voter_pseudonym)
);

create index if not exists radar_place_ratings_position_idx
    on public.radar_place_ratings (latitude, longitude);

-- Position and category of an excluded place, so the same place listed by
-- another source is dropped too.
alter table public.radar_place_overrides add column if not exists place_type text;
alter table public.radar_place_overrides add column if not exists latitude double precision;
alter table public.radar_place_overrides add column if not exists longitude double precision;

alter table public.radar_user_reports enable row level security;
alter table public.radar_report_votes enable row level security;
alter table public.radar_place_ratings enable row level security;

-- ---------------------------------------------------------------------------
-- Eventi (sezione "Eventi" in Attività, docs/features/events_engine.md, Fase A
-- in versione snella). Una riga = una edizione (date concrete). Nazionale,
-- senza mappa: città/provincia/regione sono testo, niente coordinate né
-- tabella ISTAT (Fase B). Caricamento curato da data/events/curated/*.json con
-- scripts/events/import_curated.py (service role); l'app legge direttamente
-- con la anon key, quindi RLS è in SOLA LETTURA pubblica: nessuna policy di
-- scrittura -> solo la service role può inserire o modificare.
-- ---------------------------------------------------------------------------
create table if not exists public.events (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,             -- "petsfestival-cremona-2026"
    title text not null,
    description text,                      -- breve, scritta da noi
    event_type text not null default 'other',
    level text not null default 'local',   -- local|provincial|regional|national|international
    level_basis text not null default 'default',
    audience text not null default 'public',  -- public|professional
    species text[] not null default '{}',     -- vuoto = tutte
    starts_on date not null,
    ends_on date not null,
    city text,
    province_code text,                    -- sigla, es. 'CR'
    region text,                           -- nome, es. 'Lombardia'
    venue_name text,
    organizer_name text,                   -- solo enti e società, mai persone
    source_url text,                       -- pagina ufficiale dell'evento/organizzatore
    source text not null default 'curated',
    license text not null default 'fatti pubblici verificati dal curatore',
    status text not null default 'draft',  -- draft|published|cancelled|postponed|rejected
    verification_status text not null default 'unverified',
    last_verified_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (ends_on >= starts_on)
);

create index if not exists events_active_idx
    on public.events (ends_on, starts_on) where status in ('published', 'cancelled', 'postponed');
create index if not exists events_region_idx
    on public.events (region, starts_on) where status in ('published', 'cancelled', 'postponed');

alter table public.events enable row level security;

drop policy if exists events_select_public on public.events;
create policy events_select_public
on public.events
for select
using (status in ('published', 'cancelled', 'postponed') and audience = 'public');


-- Admin operations: moderation resolution metadata and recurring ingestion schedules.

alter table public.marketplace_listing_reports
    add column if not exists status text not null default 'open',
    add column if not exists resolution_action text,
    add column if not exists resolution_note text,
    add column if not exists resolved_at timestamptz,
    add column if not exists resolved_by_admin_id text;

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listing_reports_status_check'
          and conrelid = 'public.marketplace_listing_reports'::regclass
    ) then
        alter table public.marketplace_listing_reports
            add constraint marketplace_listing_reports_status_check
            check (status in ('open','resolved','dismissed'));
    end if;
end $$;

alter table public.radar_user_reports
    add column if not exists admin_resolution_note text,
    add column if not exists resolved_by_admin_id text;

create table if not exists public.admin_ingestion_schedules (
    id uuid primary key default extensions.gen_random_uuid(),
    name text not null,
    engine text not null check (engine in ('geographic','scientific')),
    enabled boolean not null default true,
    interval_hours integer not null check (interval_hours between 1 and 8760),
    payload jsonb not null default '{}'::jsonb,
    next_run_at timestamptz not null,
    last_run_at timestamptz,
    last_status text check (last_status is null or last_status in ('completed','failed')),
    last_error text,
    last_job_id text,
    locked_at timestamptz,
    created_by text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_admin_ingestion_schedules_due
    on public.admin_ingestion_schedules (enabled, next_run_at)
    where enabled = true;

drop trigger if exists trg_admin_ingestion_schedules_set_updated_at
    on public.admin_ingestion_schedules;
create trigger trg_admin_ingestion_schedules_set_updated_at
before update on public.admin_ingestion_schedules
for each row execute function public.set_updated_at();

alter table public.admin_ingestion_schedules enable row level security;

create or replace function public.admin_claim_due_schedules(limit_count integer default 10)
returns setof public.admin_ingestion_schedules
language plpgsql
security invoker
set search_path = public, extensions
as $$
begin
    return query
    with due as (
        select id
        from public.admin_ingestion_schedules
        where enabled = true
          and next_run_at <= now()
          and (locked_at is null or locked_at < now() - interval '2 hours')
        order by next_run_at asc
        for update skip locked
        limit greatest(coalesce(limit_count,10),1)
    )
    update public.admin_ingestion_schedules s
    set locked_at = now()
    from due
    where s.id = due.id
    returning s.*;
end;
$$;

revoke all on function public.admin_claim_due_schedules(integer)
    from public, anon, authenticated;
grant execute on function public.admin_claim_due_schedules(integer)
    to service_role;


-- Marketplace moderation changes report state after the original trigger was
-- introduced. Count only unresolved/open reports and keep the trigger function
-- non-callable as a public RPC; it is invoked automatically by PostgreSQL.
create or replace function public.handle_marketplace_listing_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    distinct_reporters integer;
begin
    select count(distinct reporter_owner_id)
    into distinct_reporters
    from public.marketplace_listing_reports
    where listing_id = new.listing_id
      and status = 'open';

    update public.marketplace_listings
    set report_count = distinct_reporters,
        status = case
            when distinct_reporters >= 3 and status not in ('sold', 'removed') then 'removed'
            else status
        end,
        updated_at = now()
    where id = new.listing_id;

    return new;
end;
$$;

revoke all on function public.handle_marketplace_listing_report()
from public, anon, authenticated;

grant execute on function public.handle_marketplace_listing_report()
to service_role;


-- Mercatino v2 (2026-10-07): species, new category list, grid-rounded
-- positions + moderation guard, public photo bucket. Same content as
-- scripts/setup/marketplace_v2.sql (the one-off for existing databases).

alter table public.marketplace_listings
    add column if not exists target_species jsonb not null default '[]'::jsonb;

-- Old form saved "0" as a price; free items are "in regalo" (null) now.
update public.marketplace_listings set price_cents = null where price_cents <= 0;

-- Rows written before the grid (randomly offset positions) are snapped too.
update public.marketplace_listings
set latitude = round(latitude::numeric, 2)::double precision,
    longitude = round(longitude::numeric, 2)::double precision
where latitude <> round(latitude::numeric, 2)::double precision
   or longitude <> round(longitude::numeric, 2)::double precision;

update public.marketplace_listings
set category = case category
        when 'transport_carriers' then 'kennels_carriers'
        when 'food' then 'feeding'
        when 'grooming' then 'hygiene_grooming'
        else 'other'
    end
where category in ('transport_carriers', 'food', 'grooming', 'accessories', 'health_wellness');

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_category_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_category_check
            check (category in (
                'kennels_carriers', 'leashes_collars', 'toys', 'clothing', 'feeding',
                'hygiene_grooming', 'aquariums_terrariums', 'cages_aviaries', 'other'
            ));
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_price_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_price_check
            check (price_cents is null or price_cents > 0);
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_photos_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_photos_check
            check (jsonb_typeof(photo_urls) = 'array' and jsonb_array_length(photo_urls) <= 6);
    end if;
end;
$$;

-- Runs as the caller (no security definer), so current_user tells a regular
-- app user ('authenticated'/'anon') apart from the service role (admin
-- moderation in apps/api/routes/admin.py) and from the report trigger,
-- which runs as its owner and must keep updating report_count/status.
create or replace function public.guard_marketplace_listing()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.latitude := round(new.latitude::numeric, 2)::double precision;
    new.longitude := round(new.longitude::numeric, 2)::double precision;

    if current_user in ('authenticated', 'anon') then
        if tg_op = 'INSERT' then
            new.report_count := 0;
            new.status := 'active';
        else
            new.owner_id := old.owner_id;
            new.created_at := old.created_at;
            new.report_count := old.report_count;
            if old.status = 'removed' or new.status = 'removed' then
                new.status := old.status;
            end if;
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists marketplace_listing_guard on public.marketplace_listings;
create trigger marketplace_listing_guard
before insert or update on public.marketplace_listings
for each row execute function public.guard_marketplace_listing();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marketplace-photos', 'marketplace-photos', true, 5000000, array['image/jpeg'])
on conflict (id) do update
set public = true,
    file_size_limit = 5000000,
    allowed_mime_types = array['image/jpeg'];

-- Viewing goes through the public url and needs no policy; this select
-- policy is what Storage requires (with delete) for the author to remove
-- their own photos.
drop policy if exists marketplace_photos_objects_select_own on storage.objects;
create policy marketplace_photos_objects_select_own on storage.objects
for select using (
    bucket_id = 'marketplace-photos' and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists marketplace_photos_objects_insert_own on storage.objects;
create policy marketplace_photos_objects_insert_own on storage.objects
for insert with check (
    bucket_id = 'marketplace-photos' and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists marketplace_photos_objects_delete_own on storage.objects;
create policy marketplace_photos_objects_delete_own on storage.objects
for delete using (
    bucket_id = 'marketplace-photos' and (storage.foldername(name))[1] = auth.uid()::text
);

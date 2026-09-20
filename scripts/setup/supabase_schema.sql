create table if not exists public.pet_profiles (
    id text primary key,
    owner_id text not null,
    name text not null,
    species text not null,
    breed text,
    age_years integer,
    notes text,
    -- Medical-record access consent (spec v3 §18) — persisted per pet, not
    -- per conversation, so it's asked once and revocable later. Additive,
    -- nullable: {granted: bool, version: text, decided_at: timestamptz}.
    medical_record_consent jsonb,
    -- Enclosure characteristics for aquarium/terrarium/aviary species —
    -- field shape agreed with the "UI/UX e funzionalità base" session's
    -- mobile-local model (2026-09-20): {dimensions, volume_liters,
    -- temperature_label, substrate, notes}, all optional. Additive,
    -- nullable — the mobile pets feature that would populate this is
    -- still local-only, not yet sending real data.
    habitat jsonb,
    -- Multi-species aquarium composition: [{species, male_count,
    -- female_count}, ...]. A non-empty array means this profile
    -- represents a whole aquarium rather than a single fish.
    aquarium_stock jsonb not null default '[]'::jsonb
);

create table if not exists public.conversations (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    title text not null,
    messages jsonb not null default '[]'::jsonb,
    -- VetGPT Milestone 1 (Situation Model / Interview / Coverage) — additive, nullable.
    situation_model jsonb,
    coverage_score double precision,
    state text not null default 'NEED_MORE_INFORMATION',
    interview_turns_used integer not null default 0,
    -- VetGPT Milestone 2 (medical record access consent) — additive, nullable.
    medical_record_consent boolean,
    awaiting_medical_record_consent boolean not null default false,
    -- Safety triage clarification (brief, category-specific follow-up before
    -- escalating a red-flag message) — additive, nullable.
    awaiting_safety_clarification boolean not null default false,
    safety_clarification_category text
);

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

create table if not exists public.reminders (
    id text primary key,
    owner_id text not null,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    title text not null,
    due_date date not null,
    notes text
);

-- Account-level consents (docs/compliance/04_termini_e_consensi.md): ToS,
-- privacy policy, marketing email, analytics. One row per owner; each key
-- maps to {granted: bool, version: text, decided_at: timestamptz}.
create table if not exists public.account_consents (
    owner_id text primary key,
    consents jsonb not null default '{}'::jsonb
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
    created_at timestamptz not null default now()
);

-- Mercatino dell'usato. latitude/longitude are ALREADY fuzzed before
-- insert (packages/core/application/services/create_listing.py) - the
-- application service, not this table, is the privacy boundary.
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
create index if not exists idx_chat_response_reports_conversation_id
    on public.chat_response_reports(conversation_id);
create index if not exists idx_chat_response_reports_status
    on public.chat_response_reports(status);

alter table public.user_locations enable row level security;
alter table public.dog_walks enable row level security;
alter table public.marketplace_listings enable row level security;
alter table public.marketplace_listing_reports enable row level security;
alter table public.local_activities enable row level security;
alter table public.chat_response_reports enable row level security;

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
-- because latitude/longitude are pre-fuzzed at write time by the service
-- layer, never the exact address (see create_listing.py).
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

-- chat_response_reports: insert-only for regular users, same posture as
-- marketplace_listing_reports. No select/update policy -> default deny;
-- the review/resolve workflow (list all, mark resolved, credit a bug
-- ref) goes through the Python backend's service-role client only. No
-- staff/admin role concept exists yet anywhere in this schema, so those
-- endpoints have no additional authorization gate today - same MVP
-- maturity level as the rest of this app, flagged here rather than
-- silently assumed safe.
drop policy if exists chat_response_reports_insert_own on public.chat_response_reports;
create policy chat_response_reports_insert_own
on public.chat_response_reports
for insert
with check (
    reporter_owner_id = auth.uid()::text
    and exists (
        select 1
        from public.conversations
        where public.conversations.id = public.chat_response_reports.conversation_id
          and public.conversations.owner_id = auth.uid()::text
    )
);

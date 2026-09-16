create table if not exists public.pet_profiles (
    id text primary key,
    owner_id text not null,
    name text not null,
    species text not null,
    breed text,
    age_years integer,
    notes text
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
    awaiting_medical_record_consent boolean not null default false
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

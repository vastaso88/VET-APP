-- Shared trigger function, defined FIRST (QK-30, 2026-11-22): trg_admin_ingestion_schedules_
-- set_updated_at below uses it, and until now it was created only by
-- supabase_llm_sources_schema.sql, which runs after this script: on an empty database this
-- script stopped there. Same definition as in that script (`create or replace`, so having it
-- in both places is harmless).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, extensions
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

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
-- Ricordi (2026-11-16, scripts/setup/ricordi_animali.sql): memory reminders
-- the owner chose for a pet moved to Ricordi, all off by default.
alter table public.pet_profiles add column if not exists memorial_birthday_reminder boolean not null default false;
alter table public.pet_profiles add column if not exists memorial_walks_reminder boolean not null default false;
alter table public.pet_profiles add column if not exists memorial_photos_reminder boolean not null default false;
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

-- Profilo animale v2 (2026-10-14): optional details, all nullable.
-- `is_sterilized` is separate from `sex`; body_condition and activity_level
-- hold language-independent codes (the app translates them).
alter table public.pet_profiles add column if not exists is_sterilized boolean;
alter table public.pet_profiles add column if not exists microchip_number text;
alter table public.pet_profiles add column if not exists coat_color text;
alter table public.pet_profiles add column if not exists body_condition text;
alter table public.pet_profiles add column if not exists activity_level text;

-- QK-07b (2026-11-22): three columns that already exist in production (read from the
-- real database) but were defined in no script. The real default of is_active is FALSE
-- and neither the app nor the backend ever writes any of the three.
-- non usate dal codice, vedi QK-07d: the admin panel derives "active" (not in Ricordi),
-- "exotic" and the species group from `species` and `is_memorial` instead
-- (packages/core/domain/pet_profile/directory_traits.py). They stay in the database.
alter table public.pet_profiles add column if not exists is_active boolean not null default false;
alter table public.pet_profiles add column if not exists is_exotic boolean;
alter table public.pet_profiles add column if not exists species_group text;

alter table public.pet_profiles drop constraint if exists pet_profiles_microchip_number_check;
alter table public.pet_profiles add constraint pet_profiles_microchip_number_check
    check (microchip_number is null or microchip_number ~ '^[0-9]{15}$');
alter table public.pet_profiles drop constraint if exists pet_profiles_body_condition_check;
alter table public.pet_profiles add constraint pet_profiles_body_condition_check
    check (body_condition is null or body_condition in
        ('very_thin', 'thin', 'normal', 'slightly_overweight', 'overweight'));
alter table public.pet_profiles drop constraint if exists pet_profiles_activity_level_check;
alter table public.pet_profiles add constraint pet_profiles_activity_level_check
    check (activity_level is null or activity_level in ('sedentary', 'normal', 'active'));

-- Sex is now Maschio / Femmina / Sconosciuto; the old combined values are
-- split into sex + is_sterilized. Idempotent: once converted, no row matches.
-- (tests/unit/test_pet_sex_migration.py runs this exact statement.)
-- migrate-sex:begin
update public.pet_profiles
set is_sterilized = case sex
        when 'Maschio castrato' then true
        when 'Femmina sterilizzata' then true
        else false
    end,
    sex = case sex
        when 'Maschio castrato' then 'Maschio'
        when 'Maschio intero' then 'Maschio'
        when 'Femmina sterilizzata' then 'Femmina'
        when 'Femmina intera' then 'Femmina'
    end
where sex in ('Maschio castrato', 'Maschio intero', 'Femmina sterilizzata', 'Femmina intera');
-- migrate-sex:end

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
-- Chat plan "fratello maggiore" and free anamnesis replies (2026-11-10): both
-- are saved on every conversation; without them every chat reply fails.
alter table public.conversations
    add column if not exists escalate_next_health boolean not null default false;
alter table public.conversations
    add column if not exists awaiting_anamnesis boolean not null default false;

-- VetGPT Milestone 2: summaries of a pet's clinical documents, consulted by
-- the chat only after explicit owner consent (see ChatOrchestrator). This
-- table is also where the Flutter medical_records feature already writes
-- (as `clinical_events`); pet_id is nullable/additive so existing rows
-- written without it keep working, but the chat integration only reads
-- rows that do have a pet_id set. (2026-11-23: the live table has pet_id NOT NULL,
-- like the other three columns the app always writes: see the alignment block
-- below.)
create table if not exists public.clinical_events (
    id text primary key,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    pet_name text not null,
    title text not null,
    subtitle text,
    meta text,
    badge text,
    detail_source text,
    created_at timestamptz not null default now()
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

-- Cartella clinica per categorie (2026-10-14). Every entry has a category
-- (visit / exam / vaccine / therapy / document), an optional finer type for
-- visits, exams and therapies, and the owner's own notes. `event_date`
-- (above) is the date of the event, which the owner can now set apart from
-- the day the file was uploaded. Rows written before the categories existed
-- become "document"; re-running only touches rows still without a valid one.
alter table public.clinical_events add column if not exists category text;
alter table public.clinical_events add column if not exists subtype text;
alter table public.clinical_events add column if not exists notes text;
update public.clinical_events
    set category = 'document'
    where category is null
       or category not in ('visit', 'exam', 'vaccine', 'therapy', 'document');
alter table public.clinical_events alter column category set default 'document';
alter table public.clinical_events alter column category set not null;

-- Allineamento alla produzione (2026-11-23, confronto con information_schema.columns di ywbuz).
-- In produzione clinical_events ha owner_id, pet_id, event_type ed event_date NOT NULL e
-- created_at di tipo timestamptz (default now()). Gli script qui sopra le lasciavano
-- facoltative e created_at era text: un database costruito dagli script (il gemello di
-- collaudo) accettava righe che la produzione rifiuta. Ogni percorso che scrive la tabella
-- (medical_records_repository.dart: saveRecord, updateRecordDetails) valorizza tutti e
-- quattro i campi; il backend Python la legge soltanto. Idempotente e senza perdere righe:
-- prima si converte e si riempie, poi si impone NOT NULL.
create or replace function pg_temp.try_timestamptz(text_value text)
returns timestamptz language plpgsql as $$
begin
    return text_value::timestamptz;
exception when others then
    return null;
end;
$$;
do $$
begin
    if exists (
        select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'clinical_events'
           and column_name = 'created_at' and data_type = 'text'
    ) then
        -- Il default text (now()::text) non si converte da solo: via e poi di nuovo.
        alter table public.clinical_events alter column created_at drop default;
        alter table public.clinical_events alter column created_at type timestamptz
            using coalesce(pg_temp.try_timestamptz(created_at), now());
    end if;
end;
$$;
alter table public.clinical_events alter column created_at set default now();
alter table public.clinical_events alter column created_at set not null;
-- Righe scritte prima che i campi fossero obbligatori: si ricavano, non si cancellano.
update public.clinical_events e
    set owner_id = p.owner_id
    from public.pet_profiles p
    where e.owner_id is null and e.pet_id = p.id;
update public.clinical_events set event_type = 'document' where event_type is null;
update public.clinical_events set event_date = created_at::date where event_date is null;
do $$
declare
    missing bigint;
begin
    select count(*) into missing from public.clinical_events
     where owner_id is null or pet_id is null;
    if missing > 0 then
        raise exception 'clinical_events: % rows have no owner or no pet (the live table does not allow them): fix or remove them by hand, then run this script again', missing;
    end if;
end;
$$;
alter table public.clinical_events alter column owner_id set not null;
alter table public.clinical_events alter column pet_id set not null;
alter table public.clinical_events alter column event_type set not null;
alter table public.clinical_events alter column event_date set not null;

-- Patologie (2026-10-14): one row per illness of a pet. `status` is
-- 'ongoing' or 'resolved'; `ended_on` only when resolved. An optional file
-- goes through the same chat-attachments upload as the referti.
create table if not exists public.pet_conditions (
    id text primary key,
    owner_id text not null default auth.uid()::text,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    name text not null,
    started_on date,
    status text not null default 'ongoing',
    ended_on date,
    therapy text,
    notes text,
    attachment_id text,
    attachment_name text,
    created_at timestamptz not null default now()
);

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
-- kind is NOT NULL with default 'custom' on the live table (2026-11-23): a row saved without
-- it gets 'custom'. An explicit null is refused, so writers leave the key out when they have
-- no value (SupabaseReminderRepository.save); the Flutter app always sends one.
alter table public.reminders add column if not exists kind text not null default 'custom';
update public.reminders set kind = 'custom' where kind is null;
alter table public.reminders alter column kind set default 'custom';
alter table public.reminders alter column kind set not null;
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

-- Categoria dei promemoria (2026-10-21): the same keys as the cartella clinica
-- (visit / exam / vaccine / therapy) plus grooming and other, and the finer
-- type of a clinical one (clinical_events.subtype). Completing a clinical
-- reminder writes a clinical_events row with the id reminder-<reminder id>-
-- <yyyymmdd>, so no link column is needed. Reminders saved before this stay
-- NULL: the app guesses their category from the title and never writes the guess.
alter table public.reminders add column if not exists category text;
alter table public.reminders add column if not exists subtype text;

-- Account-level consents (docs/compliance/04_termini_e_consensi.md): ToS,
-- privacy policy, marketing email, analytics. One row per owner; each key
-- maps to {granted: bool, version: text, decided_at: timestamptz}.
create table if not exists public.account_consents (
    owner_id text primary key,
    consents jsonb not null default '{}'::jsonb
);

-- Declared date of birth (docs/compliance/10_pareri_dal_2026_11_06.md §3).
-- Written only by the backend (service role), never from user_metadata;
-- never shown to anyone and erased with the account. Same SQL as
-- .local/account_age.sql.
create table if not exists public.account_age (
    owner_id text primary key,
    birth_date date not null,
    declared_at timestamptz not null default now(),
    -- Quando un minorenne (14-17) ha confermato di avere l'autorizzazione
    -- di un genitore per un piano a pagamento.
    guardian_ok_at timestamptz,
    -- Set by the team when the owner wrote to say the date was a mistake: while
    -- it is set, a closed account is not erased from the portal.
    correction_requested_at timestamptz
);
alter table public.account_age add column if not exists correction_requested_at timestamptz;

alter table public.account_age enable row level security;

drop policy if exists account_age_select_own on public.account_age;
create policy account_age_select_own
on public.account_age
for select
using (owner_id = auth.uid()::text);

revoke insert, update, delete on public.account_age from anon, authenticated;

-- Deletion with a period to change one's mind: the account is deactivated at
-- once and erased for good at purge_after. Written only by the backend. Same
-- SQL as scripts/setup/account_deletion_requests.sql.
create table if not exists public.account_deletion_requests (
    owner_id text primary key,
    requested_at timestamptz not null default now(),
    purge_after timestamptz not null
);

create index if not exists idx_account_deletion_requests_purge_after
    on public.account_deletion_requests (purge_after);

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_deletion_requests_select_own on public.account_deletion_requests;
create policy account_deletion_requests_select_own
on public.account_deletion_requests
for select
using (owner_id = auth.uid()::text);

revoke insert, update, delete on public.account_deletion_requests from anon, authenticated;

-- Last e-mail notice sent for a deletion request (docs/compliance/18 §5). Same SQL as
-- scripts/setup/account_deletion_notices.sql.
alter table public.account_deletion_requests add column if not exists last_notice text;
alter table public.account_deletion_requests add column if not exists last_notice_at timestamptz;

-- Register of account deletions: pseudonymised data kept AFTER the deletion
-- (see RETAINED_AFTER_DELETION in the eraser). Same SQL as
-- scripts/setup/account_deletion_log.sql.
create table if not exists public.account_deletion_log (
    id bigint generated always as identity primary key,
    -- SHA-256 hex of "vetapp-deletion-log-v1:" + id dell'account. Nessuna chiave.
    owner_hash text not null unique,
    deleted_at timestamptz not null default now(),
    reason text not null check (reason in (
        'user_now', 'user_period_end', 'closed_by_age_user',
        'closed_by_age_team', 'support_request', 'no_plan_expired',
        'notice_not_sent'
    )),
    -- Vuoto finche' la cancellazione e' in corso: una riga incompleta viene
    -- rifatta come le altre.
    completed_at timestamptz
);

create index if not exists idx_account_deletion_log_deleted_at
    on public.account_deletion_log (deleted_at);

-- Servizio soltanto: RLS accesa e NESSUNA policy. La chiave service_role del
-- backend la salta; anon e authenticated non vedono nulla.
alter table public.account_deletion_log enable row level security;
revoke all on public.account_deletion_log from anon, authenticated;

-- Copia fuori dal database: un oggetto per cancellazione in un bucket PRIVATO
-- senza policy di storage (solo service_role). Un ripristino del database non la
-- tocca.
insert into storage.buckets (id, name, public)
values ('deletion-log', 'deletion-log', false)
on conflict (id) do update set public = false;

-- Subscriptions: single-row-per-owner, same shape as account_consents.
-- Starts the 14-day free trial (no card) on first lookup; `plan` stays
-- null while on trial, then holds the chosen plan key permanently.
create table if not exists public.subscriptions (
    owner_id text primary key,
    trial_ends_at timestamptz not null,
    plan text,
    created_at timestamptz not null default now()
);
-- The day the account was first seen without access: the start of the four
-- months its data is kept (packages/core/domain/subscription/retention.py).
-- Written only by the backend; nothing is sent or erased from it yet.
alter table public.subscriptions add column if not exists access_lost_at timestamptz;

-- Store subscriptions (Apple/Google), their notifications and the pseudonymous
-- purchase token: written only by the backend. Full script with RLS:
-- supabase/migrations/20261121180000_store_billing.sql.
create table if not exists public.store_subscriptions (
    id uuid primary key default gen_random_uuid(),
    owner_id text not null,
    store text not null,
    store_subscription_id text not null,
    latest_transaction_id text,
    product_id text not null,
    plan text not null,
    period text not null,
    state text not null,
    expires_at timestamptz,
    auto_renew boolean not null default false,
    grace_expires_at timestamptz,
    revoked_at timestamptz,
    environment text not null default 'production',
    last_event_at timestamptz not null default now(),
    last_verified_at timestamptz not null default now(),
    verification_error_at timestamptz,
    anomaly text,
    created_at timestamptz not null default now(),
    unique (store, store_subscription_id)
);
create table if not exists public.store_events (
    store text not null,
    event_id text not null,
    notification_type text not null,
    owner_id text,
    store_subscription_id text,
    signed_at timestamptz not null,
    received_at timestamptz not null default now(),
    outcome text not null,
    primary key (store, event_id)
);
create table if not exists public.store_account_tokens (
    owner_id text primary key,
    account_token text not null unique,
    created_at timestamptz not null default now()
);

-- Devices signed in to an account, to hold the plan's limit on simultaneous
-- devices (docs/marketing/03_prezzi_per_paese.md, plan limits). `device_id` is
-- a random id the app makes at sign-in; nothing else about the phone is
-- stored. Written only by the backend; the owner can read their own rows.
create table if not exists public.user_devices (
    owner_id text not null,
    device_id text not null,
    first_seen_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    revoked_at timestamptz,
    primary key (owner_id, device_id)
);

create index if not exists idx_pet_profiles_owner_id on public.pet_profiles(owner_id);
create index if not exists idx_conversations_owner_id on public.conversations(owner_id);
create index if not exists idx_conversations_pet_id on public.conversations(pet_id);
create index if not exists idx_clinical_events_pet_id on public.clinical_events(pet_id);
create index if not exists idx_pet_conditions_pet_id on public.pet_conditions(pet_id);
create index if not exists idx_pet_conditions_owner_id on public.pet_conditions(owner_id);
create index if not exists idx_reminders_owner_id on public.reminders(owner_id);
create index if not exists idx_reminders_pet_id on public.reminders(pet_id);

alter table public.pet_profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.clinical_events enable row level security;
alter table public.pet_conditions enable row level security;
alter table public.reminders enable row level security;
alter table public.account_consents enable row level security;
alter table public.subscriptions enable row level security;
alter table public.user_devices enable row level security;
alter table public.store_subscriptions enable row level security;
alter table public.store_events enable row level security;
alter table public.store_account_tokens enable row level security;

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

-- The app renames, recategorizes and deletes its own entries: policies are
-- permissive (OR-ed), so these add to whatever the live table already has.
drop policy if exists clinical_events_update_own on public.clinical_events;
create policy clinical_events_update_own
on public.clinical_events
for update
using (
    pet_id is not null
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.clinical_events.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
)
with check (
    exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.clinical_events.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists clinical_events_delete_own on public.clinical_events;
create policy clinical_events_delete_own
on public.clinical_events
for delete
using (
    pet_id is not null
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.clinical_events.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

-- pet_conditions: the owner's own list of a pet's past and current illnesses
-- (the "Patologie" tile of the cartella clinica). Owner only: every policy
-- checks both the row's owner and that the pet is theirs. The chat reads the
-- ongoing ones (name and start date only), with the owner's consent, through
-- the backend's service role.
drop policy if exists pet_conditions_select_own on public.pet_conditions;
create policy pet_conditions_select_own
on public.pet_conditions
for select
using (owner_id = auth.uid()::text);

drop policy if exists pet_conditions_insert_own on public.pet_conditions;
create policy pet_conditions_insert_own
on public.pet_conditions
for insert
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.pet_conditions.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists pet_conditions_update_own on public.pet_conditions;
create policy pet_conditions_update_own
on public.pet_conditions
for update
using (owner_id = auth.uid()::text)
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.pet_conditions.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists pet_conditions_delete_own on public.pet_conditions;
create policy pet_conditions_delete_own
on public.pet_conditions
for delete
using (owner_id = auth.uid()::text);

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

-- Subscriptions are written only by the backend (service role). A client-side
-- insert/update would let an owner extend the trial or pick a plan without
-- paying: see scripts/setup/subscriptions_lock_writes.sql.
drop policy if exists subscriptions_insert_own on public.subscriptions;
drop policy if exists subscriptions_update_own on public.subscriptions;

-- Devices: the owner reads their own rows; only the backend writes them.
drop policy if exists user_devices_select_own on public.user_devices;
create policy user_devices_select_own
on public.user_devices
for select
using (owner_id = auth.uid()::text);

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

-- marketplace_listings: an owner reads only their OWN ads directly. Everyone
-- else's ads are served by the backend (service role, which bypasses RLS):
-- GET /marketplace/listings (radius 1-300 km), GET /marketplace/listings/{id}
-- and the admin portal (through the backend). Before 2026-10-26 this was
-- `using (true)`, which let anyone with the anon key read the whole table and
-- skip the radius; scripts/setup/marketplace_read_protection.sql applies the
-- change to an existing database. latitude/longitude are snapped to a ~1 km
-- grid at write time (guard_marketplace_listing below).
drop policy if exists marketplace_listings_select_all on public.marketplace_listings;
drop policy if exists marketplace_listings_select_own on public.marketplace_listings;
create policy marketplace_listings_select_own
on public.marketplace_listings
for select
using (owner_id = auth.uid()::text);

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

-- Types the bucket accepts (collaudo F34: a text file named .jpg was stored). These are
-- exactly the Content-Types the app and the maintenance scripts send: photos and thumbnails
-- are always compressed to image/jpeg (png and webp: the metadata clean-up of old objects),
-- videos are video/mp4 or video/quicktime (pet_video_rules.dart: mp4, m4v, mov).
-- WHAT THIS DOES NOT DO: Supabase Storage compares the Content-Type the client DECLARES, it
-- never reads the file. A text file uploaded as image/jpeg still passes, so the real check of
-- the bytes (the file signature) cannot happen at this door while the app writes straight to
-- Storage; it needs the upload to go through the backend (like chat attachments, which check
-- the signature in upload_chat_attachment.py) or a periodic server-side audit of the bucket.
update storage.buckets
set allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime'
]
where id = 'pet-photos';

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

-- Multi-country radar (docs/maps/COUNTRIES.md). Every imported place carries
-- the ISO country code of the run that wrote it, so a re-import of one
-- country replaces only that country's rows. Rows imported before this
-- migration are Italy's.
alter table public.radar_places_osm
    add column if not exists country text not null default 'IT';
alter table public.radar_places_open
    add column if not exists country text not null default 'IT';
create index if not exists radar_places_osm_country_idx on public.radar_places_osm (country);
create index if not exists radar_places_open_country_idx on public.radar_places_open (country);

-- What is imported for each country. OpenStreetMap counts as complete only
-- when every region of the country went in during one run (osm_complete_at
-- set); until then the API serves the country from the live per-cell cache.
create table if not exists public.radar_country_coverage (
    country text primary key,
    osm_complete_at timestamptz,
    osm_release text,
    osm_place_count integer not null default 0,
    osm_regions jsonb not null default '[]'::jsonb,
    overture_release text,
    overture_imported_at timestamptz,
    overture_place_count integer not null default 0,
    updated_at timestamptz not null default now()
);

-- Italy was imported before this table existed: derive its row from the
-- areas recorded in data_sources (idempotent).
insert into public.radar_country_coverage
    (country, osm_complete_at, osm_release, osm_place_count)
select 'IT', imported_at, release, place_count
from public.data_sources
where source = 'openstreetmap_overpass' and min_latitude is not null
on conflict (country) do nothing;

update public.radar_country_coverage as coverage
set overture_release = source.release,
    overture_imported_at = source.imported_at,
    overture_place_count = source.place_count
from public.data_sources as source
where coverage.country = 'IT'
  and source.source = 'overture'
  and coverage.overture_imported_at is null;

alter table public.radar_country_coverage enable row level security;

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

-- "Dichiarano di trattare animali esotici": segnalazioni di competenza confermate a mano.
-- Stesso blocco di scripts/setup/radar_exotic_competences.sql.
create table if not exists public.radar_competence_claims (
    id text primary key,
    target_source text not null check (char_length(target_source) <= 60),
    target_source_id text not null check (char_length(target_source_id) <= 120),
    place_name text not null check (char_length(place_name) <= 120),
    latitude double precision not null,
    longitude double precision not null,
    groups jsonb not null default '[]'::jsonb,
    evidence_kind text not null check (evidence_kind in ('website', 'sign', 'other')),
    status text not null default 'pending'
        check (status in ('pending', 'confirmed', 'rejected')),
    reporter_pseudonym text not null,
    created_at timestamptz not null default now(),
    resolved_at timestamptz,
    evidence_url text check (evidence_url is null or char_length(evidence_url) <= 500),
    resolution_note text check (resolution_note is null or char_length(resolution_note) <= 300)
);

create index if not exists radar_competence_claims_position_idx
    on public.radar_competence_claims (status, latitude, longitude);
create index if not exists radar_competence_claims_reporter_idx
    on public.radar_competence_claims (reporter_pseudonym, created_at);

alter table public.radar_competence_claims enable row level security;
revoke all on table public.radar_competence_claims from anon, authenticated;

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
            if old.status in ('removed', 'removed_policy')
               or new.status in ('removed', 'removed_policy') then
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

-- ---------------------------------------------------------------------------
-- Model usage ledger and daily budget (build 32, 2026-10-14).
-- The backend records every model call (counts only: never
-- the owner's words), keeps the day's totals per model so every serverless
-- instance sees the same figures, counts each owner's messages per day, and
-- caches answers to general curiosities. Retention: llm_usage rows have no
-- personal data (keep 90 days for analysis); chat_user_daily_usage links an
-- owner id to a count only (keep 30 days). Cleanup, to run periodically:
--   delete from public.llm_usage where day < current_date - 90;
--   delete from public.chat_user_daily_usage where day < current_date - 30;
--   delete from public.chat_answer_cache where expires_at < now();
create table if not exists public.llm_usage (
    id text primary key,
    occurred_at timestamptz not null default now(),
    day date not null,
    model text not null,
    model_class text not null default 'main',
    purpose text not null,
    prompt_tokens integer not null default 0,
    completion_tokens integer not null default 0,
    cached_prompt_tokens integer not null default 0,
    total_tokens integer not null default 0,
    duration_ms integer not null default 0,
    outcome text not null default 'ok'
);
create index if not exists idx_llm_usage_day_model on public.llm_usage(day, model);
create index if not exists idx_llm_usage_day_purpose on public.llm_usage(day, purpose);
alter table public.llm_usage enable row level security;

create table if not exists public.llm_usage_daily (
    day date not null,
    model text not null,
    calls integer not null default 0,
    prompt_tokens integer not null default 0,
    completion_tokens integer not null default 0,
    cached_prompt_tokens integer not null default 0,
    total_tokens integer not null default 0,
    exhausted_until timestamptz,
    primary key (day, model)
);
-- Tokens written to the provider's prompt cache (priced above plain input in
-- the euro spending cap); see scripts/setup/llm_usage_cache_writes.sql.
alter table public.llm_usage_daily
    add column if not exists cache_write_tokens integer not null default 0;
alter table public.llm_usage_daily enable row level security;

-- Atomic add: concurrent instances never lose each other's tokens.
create or replace function public.llm_usage_add(
    p_day date,
    p_model text,
    p_prompt_tokens integer,
    p_completion_tokens integer,
    p_cached_tokens integer,
    p_total_tokens integer
)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.llm_usage_daily (
        day, model, calls, prompt_tokens, completion_tokens, cached_prompt_tokens, total_tokens
    )
    values (
        p_day, p_model, 1, p_prompt_tokens, p_completion_tokens, p_cached_tokens, p_total_tokens
    )
    on conflict (day, model) do update set
        calls = public.llm_usage_daily.calls + 1,
        prompt_tokens = public.llm_usage_daily.prompt_tokens + excluded.prompt_tokens,
        completion_tokens = public.llm_usage_daily.completion_tokens + excluded.completion_tokens,
        cached_prompt_tokens =
            public.llm_usage_daily.cached_prompt_tokens + excluded.cached_prompt_tokens,
        total_tokens = public.llm_usage_daily.total_tokens + excluded.total_tokens;
$$;

-- The cache writes of a call, added to the day's total on their own so that a
-- database without this function still counts every call.
create or replace function public.llm_usage_add_cache_writes(
    p_day date,
    p_model text,
    p_tokens integer
)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.llm_usage_daily (day, model, cache_write_tokens)
    values (p_day, p_model, greatest(p_tokens, 0))
    on conflict (day, model) do update set
        cache_write_tokens =
            public.llm_usage_daily.cache_write_tokens + excluded.cache_write_tokens;
$$;

create table if not exists public.chat_user_daily_usage (
    owner_id text not null,
    day date not null,
    messages integer not null default 0,
    primary key (owner_id, day)
);
alter table public.chat_user_daily_usage enable row level security;

-- Counts one more message for the owner today and returns the new total.
create or replace function public.chat_user_daily_usage_add(p_owner_id text, p_day date)
returns integer
language sql
security definer
set search_path = public
as $$
    insert into public.chat_user_daily_usage (owner_id, day, messages)
    values (p_owner_id, p_day, 1)
    on conflict (owner_id, day) do update set
        messages = public.chat_user_daily_usage.messages + 1
    returning messages;
$$;

-- Answers to general questions about a kind of animal, shared for a day.
-- `question` is the normalized question (no names, no personal case: the
-- backend only caches questions that pass answer_cache.py's rules).
create table if not exists public.chat_answer_cache (
    key text primary key,
    species text not null,
    language text not null default 'it',
    question text not null,
    answer text not null,
    provider text not null,
    model text not null,
    sources jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    expires_at timestamptz not null,
    hits integer not null default 0
);
create index if not exists idx_chat_answer_cache_expires_at on public.chat_answer_cache(expires_at);
alter table public.chat_answer_cache enable row level security;

create or replace function public.chat_answer_cache_hit(p_key text)
returns void
language sql
security definer
set search_path = public
as $$
    update public.chat_answer_cache set hits = hits + 1 where key = p_key;
$$;

-- These three functions run as their owner (security definer) and are the
-- only way the backend moves the shared counters. They must not be callable
-- from the app's own key: otherwise anyone could add tokens to the day's
-- total (switching the whole chat to degraded mode) or add messages to
-- another owner's daily count (locking them out). Only the backend, with
-- the service role, may call them.
revoke all on function public.llm_usage_add(date, text, integer, integer, integer, integer)
    from public, anon, authenticated;
grant execute on function public.llm_usage_add(date, text, integer, integer, integer, integer)
    to service_role;
revoke all on function public.llm_usage_add_cache_writes(date, text, integer)
    from public, anon, authenticated;
grant execute on function public.llm_usage_add_cache_writes(date, text, integer)
    to service_role;

revoke all on function public.chat_user_daily_usage_add(text, date)
    from public, anon, authenticated;
grant execute on function public.chat_user_daily_usage_add(text, date)
    to service_role;

revoke all on function public.chat_answer_cache_hit(text)
    from public, anon, authenticated;
grant execute on function public.chat_answer_cache_hit(text)
    to service_role;

-- Retention for the usage ledger and the answer cache (build 33). One
-- function deletes what has aged out: llm_usage rows after 90 days,
-- chat_user_daily_usage after 30 days, expired chat_answer_cache rows; the
-- per-day totals in llm_usage_daily stay (a few rows a day, no personal
-- data). Two ways to run it, either is enough:
--   * pg_cron (enable the extension once in the Supabase dashboard,
--     Database > Extensions > pg_cron): the block below then schedules it
--     every night at 03:15 UTC; re-running this script keeps one schedule;
--   * the backend route POST /chat/maintenance (developer accounts only),
--     from any external scheduler.
create or replace function public.chat_usage_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    usage_rows integer;
    user_rows integer;
    cache_rows integer;
begin
    delete from public.llm_usage where day < current_date - 90;
    get diagnostics usage_rows = row_count;
    delete from public.chat_user_daily_usage where day < current_date - 30;
    get diagnostics user_rows = row_count;
    delete from public.chat_answer_cache where expires_at < now();
    get diagnostics cache_rows = row_count;
    return jsonb_build_object(
        'llm_usage', usage_rows,
        'chat_user_daily_usage', user_rows,
        'chat_answer_cache', cache_rows
    );
end;
$$;
revoke all on function public.chat_usage_cleanup()
    from public, anon, authenticated;
grant execute on function public.chat_usage_cleanup()
    to service_role;

do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule(jobid)
            from cron.job where jobname = 'vetapp-chat-usage-cleanup';
        perform cron.schedule(
            'vetapp-chat-usage-cleanup', '15 3 * * *', 'select public.chat_usage_cleanup()'
        );
    end if;
end
$$;

-- Misurazioni del peso (pagina "Monitoraggio" del pet, 2026-10-14). Una riga
-- per pesata: data, peso SEMPRE in kg (l'app converte da/verso lb nella
-- visualizzazione), corporatura facoltativa a 5 livelli (1 molto magro ...
-- 5 sovrappeso) e nota. L'app legge/scrive direttamente da Supabase (come
-- pet_profiles e dog_walks); il backend della chat legge l'ultima riga con la
-- service key. Non per i pesci/acquari (filtro lato app).
create table if not exists public.pet_weight_measurements (
    id text primary key,
    pet_id text not null references public.pet_profiles(id) on delete cascade,
    owner_id text not null,
    measured_at date not null,
    weight_kg numeric(7, 3) not null check (weight_kg > 0 and weight_kg <= 2000),
    body_condition smallint check (body_condition between 1 and 5),
    note text check (note is null or char_length(note) <= 500),
    created_at timestamptz not null default now()
);

create index if not exists idx_pet_weight_measurements_pet_date
    on public.pet_weight_measurements(pet_id, measured_at desc);
create index if not exists idx_pet_weight_measurements_owner_id
    on public.pet_weight_measurements(owner_id);

alter table public.pet_weight_measurements enable row level security;

-- Solo il proprietario: stessa forma di dog_walks (insert verifica anche che
-- il pet sia suo).
drop policy if exists pet_weight_measurements_select_own on public.pet_weight_measurements;
create policy pet_weight_measurements_select_own
on public.pet_weight_measurements
for select
using (owner_id = auth.uid()::text);

drop policy if exists pet_weight_measurements_insert_own on public.pet_weight_measurements;
create policy pet_weight_measurements_insert_own
on public.pet_weight_measurements
for insert
with check (
    owner_id = auth.uid()::text
    and exists (
        select 1
        from public.pet_profiles
        where public.pet_profiles.id = public.pet_weight_measurements.pet_id
          and public.pet_profiles.owner_id = auth.uid()::text
    )
);

drop policy if exists pet_weight_measurements_update_own on public.pet_weight_measurements;
create policy pet_weight_measurements_update_own
on public.pet_weight_measurements
for update
using (owner_id = auth.uid()::text)
with check (owner_id = auth.uid()::text);

drop policy if exists pet_weight_measurements_delete_own on public.pet_weight_measurements;
create policy pet_weight_measurements_delete_own
on public.pet_weight_measurements
for delete
using (owner_id = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- Curiosità per i tuoi animali (GET /news). Il backend legge i feed RSS e tiene
-- qui l'ultima copia valida (una riga per pubblico, oggi 'it'): se le fonti non
-- rispondono si serve questa. Solo service role (RLS attiva, nessuna policy).
-- ---------------------------------------------------------------------------
create table if not exists public.pet_news_snapshots (
    key text primary key,
    fetched_at timestamptz not null,
    items jsonb not null default '[]'::jsonb
);
alter table public.pet_news_snapshots enable row level security;

-- ---------------------------------------------------------------------------
-- "Segnala un evento": proposte degli utenti per la sezione Eventi (POST
-- /events/submissions). Restano qui in moderazione: il team le controlla con
-- scripts/events/moderate_submissions.py e solo allora diventano righe di
-- public.events. `submitted_by` serve solo a limitare gli abusi, non si mostra
-- mai. Solo service role (RLS attiva, nessuna policy); cancellata con l'account.
-- ---------------------------------------------------------------------------
create table if not exists public.event_submissions (
    id text primary key,
    submitted_by text not null,
    title text not null,
    event_type text not null,
    starts_on date not null,
    ends_on date not null,
    city text not null,
    province_code text,
    region text,
    venue_name text,
    source_url text not null,
    status text not null default 'pending'
        check (status in ('pending', 'approved', 'rejected')),
    review_note text,
    event_slug text,
    created_at timestamptz not null default now(),
    reviewed_at timestamptz,
    check (ends_on >= starts_on)
);
create index if not exists event_submissions_status_idx
    on public.event_submissions (status, created_at);
create index if not exists event_submissions_owner_idx
    on public.event_submissions (submitted_by, created_at);
alter table public.event_submissions enable row level security;

-- Origine e licenza delle righe di public.events non curate a mano (feed
-- importati, segnalazioni approvate). Le colonne `source` e `license` esistono
-- già: qui si documenta soltanto che i valori possono essere altri.

-- Notizie, eventi e Mercatino per territorio (2026-10-14, sessione "Notizie,
-- eventi e Mercatino per territorio"). Idempotente: si puo' eseguire piu' volte.
-- Lo stesso blocco e' in fondo a supabase_schema.sql, cosi' un setup nuovo lo
-- ha gia'; ESEGUI QUESTO FILE UNA VOLTA sul database esistente, PRIMA di
-- pubblicare la versione dell'app/backend che legge la colonna.
--
-- 1. events.country: paese in cui si svolge l'evento (ISO 3166-1 alpha-2).
--    L'app mostra solo gli eventi del paese dell'utente. Le righe esistenti
--    sono italiane (valore predefinito 'IT').
-- 2. marketplace_listings.country: paese del venditore. Prezzi nella valuta
--    del paese; l'app e il backend mostrano solo annunci dello stesso paese
--    dell'utente. Le righe esistenti sono italiane.

alter table public.events
    add column if not exists country text not null default 'IT';

create index if not exists events_country_idx
    on public.events (country, starts_on) where status in ('published', 'cancelled', 'postponed');

alter table public.marketplace_listings
    add column if not exists country text not null default 'IT';

create index if not exists idx_marketplace_listings_country
    on public.marketplace_listings (country) where status = 'active';

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_country_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_country_check
            check (country ~ '^[A-Z]{2}$');
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'events_country_check'
          and conrelid = 'public.events'::regclass
    ) then
        alter table public.events
            add constraint events_country_check
            check (country ~ '^[A-Z]{2}$');
    end if;
end;
$$;

-- Mercatino, 2026-10-26: la lettura diretta e' ora limitata ai propri annunci
-- (policy marketplace_listings_select_own, sopra). Dettaglio, elenco, mappa e
-- portale admin passano dal backend. Per scrivere anche solo dal backend (cosi'
-- il filtro "niente animali" non si aggira) vedere l'opzionale
-- scripts/setup/marketplace_lock_writes.sql; per nascondere gli annunci di
-- animali gia' presenti, scripts/setup/marketplace_no_animals.sql.

-- ---------------------------------------------------------------------------
-- Security audit 2026-10-26 (BE-4/LLM-4, retention).
-- 1) Per-owner daily allowances for every feature that calls a model: the
--    counters table gains one column per kind, and one atomic function
--    adds to the kind asked for (the older messages-only function stays).
alter table public.chat_user_daily_usage add column if not exists vision integer not null default 0;
alter table public.chat_user_daily_usage
    add column if not exists dictation integer not null default 0;
alter table public.chat_user_daily_usage add column if not exists summary integer not null default 0;
-- Plan "fratello maggiore" (2026-11-10): Sonnet answers and messages that
-- continue a topic; see scripts/setup/chat_usage_sonnet_followups.sql.
alter table public.chat_user_daily_usage
    add column if not exists sonnet integer not null default 0;
alter table public.chat_user_daily_usage
    add column if not exists followup integer not null default 0;

create or replace function public.chat_user_daily_usage_add_kind(
    p_owner_id text, p_day date, p_kind text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    total integer;
begin
    if p_kind not in ('messages', 'vision', 'dictation', 'summary', 'sonnet', 'followup') then
        raise exception 'unknown usage kind: %', p_kind;
    end if;
    insert into public.chat_user_daily_usage (
        owner_id, day, messages, vision, dictation, summary, sonnet, followup
    )
    values (
        p_owner_id, p_day,
        (p_kind = 'messages')::integer, (p_kind = 'vision')::integer,
        (p_kind = 'dictation')::integer, (p_kind = 'summary')::integer,
        (p_kind = 'sonnet')::integer, (p_kind = 'followup')::integer
    )
    on conflict (owner_id, day) do update set
        messages = public.chat_user_daily_usage.messages + (p_kind = 'messages')::integer,
        vision = public.chat_user_daily_usage.vision + (p_kind = 'vision')::integer,
        dictation = public.chat_user_daily_usage.dictation + (p_kind = 'dictation')::integer,
        summary = public.chat_user_daily_usage.summary + (p_kind = 'summary')::integer,
        sonnet = public.chat_user_daily_usage.sonnet + (p_kind = 'sonnet')::integer,
        followup = public.chat_user_daily_usage.followup + (p_kind = 'followup')::integer
    returning case p_kind
        when 'messages' then messages
        when 'vision' then vision
        when 'dictation' then dictation
        when 'sonnet' then sonnet
        when 'followup' then followup
        else summary
    end into total;
    return total;
end;
$$;
revoke all on function public.chat_user_daily_usage_add_kind(text, date, text)
    from public, anon, authenticated;
grant execute on function public.chat_user_daily_usage_add_kind(text, date, text)
    to service_role;

-- 2) Retention of the chat. A conversation lives 24 months after its last
--    message (the owner can delete it earlier from the app), its files
--    with it; a file uploaded but never sent goes after 7 days.
--    `last_message_at` is kept by the backend on every save; the backfill
--    below fills it for existing rows from the messages themselves.
--    The backend's maintenance (POST /chat/maintenance, or the nightly
--    pg_cron job below for the rows) applies it. Deleting a row of
--    chat_attachments does NOT remove the file from the storage bucket:
--    that is the backend's part (it deletes the file, then the row), so
--    the SQL function below only removes conversations whose attachments
--    are already gone, and reports what is left for the backend.
alter table public.conversations add column if not exists last_message_at timestamptz;
create index if not exists idx_conversations_last_message_at
    on public.conversations(last_message_at);
update public.conversations
set last_message_at = (
    select max((m->>'created_at')::timestamptz) from jsonb_array_elements(messages) m
)
where last_message_at is null and jsonb_array_length(messages) > 0;

create or replace function public.chat_retention_cleanup(
    p_months integer default 24, p_orphan_days integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    conversations_deleted integer;
    attachments_pending integer;
begin
    -- Conversations past retention with no file left to remove.
    delete from public.conversations c
    where c.last_message_at < now() - make_interval(months => p_months)
      and not exists (
          select 1 from public.chat_attachments a where a.conversation_id = c.id
      );
    get diagnostics conversations_deleted = row_count;
    -- Files the backend still has to delete (past retention, or orphans).
    select count(*) into attachments_pending
    from public.chat_attachments a
    left join public.conversations c on c.id = a.conversation_id
    where (c.id is not null and c.last_message_at < now() - make_interval(months => p_months))
       or (a.conversation_id is null and a.created_at < now() - make_interval(days => p_orphan_days));
    return jsonb_build_object(
        'conversations_deleted', conversations_deleted,
        'attachments_pending_backend_cleanup', attachments_pending
    );
end;
$$;
revoke all on function public.chat_retention_cleanup(integer, integer)
    from public, anon, authenticated;
grant execute on function public.chat_retention_cleanup(integer, integer)
    to service_role;

do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule(jobid)
            from cron.job where jobname = 'vetapp-chat-retention';
        perform cron.schedule(
            'vetapp-chat-retention', '45 3 * * *', 'select public.chat_retention_cleanup()'
        );
    end if;
end
$$;

-- Mercatino: messaggi dentro l'app (decisione del proprietario, 2026-11-07) e
-- blocco di una persona dal Mercatino da parte del team di moderazione.
-- Un compratore scrive al venditore di un annuncio e nessuno dei due conosce il
-- numero, l'e-mail o l'id dell'altro. Idempotente. Lo stesso blocco sta in
-- supabase_schema.sql (un test controlla che i due restino allineati).
--
-- Si scrive e si legge SOLO dal backend (chiave service_role, che non passa da
-- RLS): lì stanno le regole (partecipazione, abbonamento, blocchi, limite
-- giornaliero, annuncio chiuso). Per questo a anon e authenticated è tolto ogni
-- privilegio: leggere direttamente una conversazione mostrerebbe l'id dell'altra
-- persona. RLS e policy *_own restano come seconda difesa, nel caso i privilegi
-- venissero ridati per errore; nessuna policy permette di scrivere.

create table if not exists public.marketplace_conversations (
    id text primary key,
    -- Null quando l'annuncio viene cancellato: la conversazione resta leggibile.
    listing_id text references public.marketplace_listings(id) on delete set null,
    listing_title text not null check (char_length(listing_title) <= 200),
    buyer_id text not null,
    seller_id text not null,
    buyer_unread integer not null default 0 check (buyer_unread >= 0),
    seller_unread integer not null default 0 check (seller_unread >= 0),
    moderation_closed_at timestamptz,
    erased_participant_at timestamptz,
    created_at timestamptz not null default now(),
    last_message_at timestamptz not null default now(),
    check (buyer_id <> seller_id)
);

create table if not exists public.marketplace_messages (
    id text primary key,
    conversation_id text not null
        references public.marketplace_conversations(id) on delete cascade,
    sender_id text not null,
    body text not null check (char_length(body) between 1 and 1000),
    created_at timestamptz not null default now()
);

create table if not exists public.marketplace_user_blocks (
    blocker_id text not null,
    blocked_id text not null,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id)
);

create table if not exists public.marketplace_conversation_reports (
    id text primary key,
    conversation_id text not null
        references public.marketplace_conversations(id) on delete cascade,
    reporter_id text not null,
    reason text not null
        check (reason in ('spam', 'scam', 'harassment', 'inappropriate', 'other')),
    status text not null default 'open' check (status in ('open', 'dismissed', 'resolved')),
    resolution_action text,
    resolution_note text check (resolution_note is null or char_length(resolution_note) <= 1000),
    resolved_at timestamptz,
    resolved_by_admin_id text,
    created_at timestamptz not null default now(),
    unique (conversation_id, reporter_id)
);

create table if not exists public.marketplace_user_restrictions (
    -- Una riga per persona: il team la tiene fuori dal Mercatino (niente annunci
    -- nuovi, niente modifiche, niente messaggi). Annullare il blocco riempie
    -- lifted_at e lascia la riga, con chi e quando.
    owner_id text primary key,
    reason text not null
        check (reason in ('spam', 'scam', 'harassment', 'prohibited_items', 'other')),
    note text check (note is null or char_length(note) <= 1000),
    created_at timestamptz not null default now(),
    created_by_admin_id text,
    lifted_at timestamptz,
    lifted_by_admin_id text
);
-- Scadenza del blocco (2026-11-21): vuota = senza scadenza. Prima della funzione che la legge.
alter table public.marketplace_user_restrictions
    add column if not exists expires_at timestamptz;

-- Conversazione tenuta dopo la cancellazione di un account perché segnalata
-- (decisione del proprietario 2026-11-08, parere docs/compliance/10 §2.3).
alter table public.marketplace_conversations
    add column if not exists erased_participant_at timestamptz;

-- Traccia di chi del team ha letto o deciso una conversazione segnalata. Solo
-- backend: nessuna policy per gli utenti, privilegi tolti ad anon e authenticated.
create table if not exists public.marketplace_moderation_access_log (
    id text primary key,
    admin_id text not null,
    report_id text not null,
    conversation_id text not null,
    action text not null
        check (action in ('read', 'close_conversation', 'dismiss_report', 'reopen_report')),
    accessed_at timestamptz not null default now()
);
create index if not exists idx_marketplace_moderation_access_log_report
    on public.marketplace_moderation_access_log(report_id, accessed_at desc);
alter table public.marketplace_moderation_access_log enable row level security;
revoke all on table public.marketplace_moderation_access_log from anon, authenticated;

-- Una sola conversazione per annuncio e compratore. I NULL (annuncio cancellato)
-- non collidono tra loro.
create unique index if not exists idx_marketplace_conversations_listing_buyer
    on public.marketplace_conversations(listing_id, buyer_id);
create index if not exists idx_marketplace_conversations_buyer
    on public.marketplace_conversations(buyer_id, last_message_at desc);
create index if not exists idx_marketplace_conversations_seller
    on public.marketplace_conversations(seller_id, last_message_at desc);
create index if not exists idx_marketplace_messages_conversation
    on public.marketplace_messages(conversation_id, created_at desc);
create index if not exists idx_marketplace_messages_sender
    on public.marketplace_messages(sender_id);
create index if not exists idx_marketplace_user_blocks_blocked
    on public.marketplace_user_blocks(blocked_id);
create index if not exists idx_marketplace_conversation_reports_reporter
    on public.marketplace_conversation_reports(reporter_id);
create index if not exists idx_marketplace_conversation_reports_status
    on public.marketplace_conversation_reports(status, created_at desc);

alter table public.marketplace_conversations enable row level security;
alter table public.marketplace_messages enable row level security;
alter table public.marketplace_user_blocks enable row level security;
alter table public.marketplace_conversation_reports enable row level security;
alter table public.marketplace_user_restrictions enable row level security;

drop policy if exists marketplace_conversations_select_own on public.marketplace_conversations;
create policy marketplace_conversations_select_own
on public.marketplace_conversations
for select
using (buyer_id = auth.uid()::text or seller_id = auth.uid()::text);

drop policy if exists marketplace_messages_select_own on public.marketplace_messages;
create policy marketplace_messages_select_own
on public.marketplace_messages
for select
using (sender_id = auth.uid()::text);

drop policy if exists marketplace_user_blocks_select_own on public.marketplace_user_blocks;
create policy marketplace_user_blocks_select_own
on public.marketplace_user_blocks
for select
using (blocker_id = auth.uid()::text);

drop policy if exists marketplace_conversation_reports_select_own
    on public.marketplace_conversation_reports;
create policy marketplace_conversation_reports_select_own
on public.marketplace_conversation_reports
for select
using (reporter_id = auth.uid()::text);

revoke all on table public.marketplace_conversations from anon, authenticated;
revoke all on table public.marketplace_messages from anon, authenticated;
revoke all on table public.marketplace_user_blocks from anon, authenticated;
revoke all on table public.marketplace_conversation_reports from anon, authenticated;
revoke all on table public.marketplace_user_restrictions from anon, authenticated;

drop policy if exists marketplace_user_restrictions_select_own
    on public.marketplace_user_restrictions;
create policy marketplace_user_restrictions_select_own
on public.marketplace_user_restrictions
for select
using (owner_id = auth.uid()::text);

-- Chi è bloccato non pubblica né modifica annunci nemmeno scrivendo direttamente
-- nella tabella con la propria sessione (finché le policy insert/update esistono:
-- marketplace_lock_writes.sql le toglie). La funzione guarda solo chi chiama, così
-- nessuno può chiedere se un'altra persona è bloccata.
-- Stesso testo della migrazione 20261121165154: un blocco scaduto non vale più.
create or replace function public.marketplace_caller_is_restricted()
returns boolean language sql stable security definer set search_path = '' as $$
    select exists (
        select 1 from public.marketplace_user_restrictions r
        where r.owner_id = auth.uid()::text and r.lifted_at is null
          and (r.expires_at is null or r.expires_at > now())
    );
$$;
revoke all on function public.marketplace_caller_is_restricted()
    from public, anon, authenticated;
grant execute on function public.marketplace_caller_is_restricted()
    to authenticated;

drop policy if exists marketplace_listings_insert_not_restricted on public.marketplace_listings;
create policy marketplace_listings_insert_not_restricted
on public.marketplace_listings
as restrictive
for insert
to authenticated
with check (not public.marketplace_caller_is_restricted());

drop policy if exists marketplace_listings_update_not_restricted on public.marketplace_listings;
create policy marketplace_listings_update_not_restricted
on public.marketplace_listings
as restrictive
for update
to authenticated
using (not public.marketplace_caller_is_restricted())
with check (not public.marketplace_caller_is_restricted());

-- Conservazione. Decisioni del proprietario, riferite dall'Orchestratore: 2026-11-07,
-- confermata il 2026-11-23 («come promettono i testi»); 2026-11-23 sera, B e C.
-- * La conversazione si cancella 6 mesi dopo l'ultimo messaggio se l'annuncio è chiuso
--   (venduto o cancellato), 12 mesi dopo l'ultimo messaggio comunque.
-- * Mai finché ha una segnalazione aperta, né nei 6 mesi dopo che una segnalazione è
--   stata decisa (accolta o respinta): serve a un riesame, anche oltre i 6 e i 12 mesi.
-- * Un annuncio tolto (dal team, o in attesa del team per le segnalazioni) si può
--   ripristinare: non conta come chiuso finché non viene cancellato. I 12 mesi valgono
--   anche per lui.
-- * La chiusura della conversazione da parte del team NON conta: i testi parlano solo
--   dell'annuncio. (Dall'8 novembre 2026 fino a questa versione i 6 mesi si contavano
--   anche dalla chiusura: non corrispondeva ai testi.)
-- * Le conversazioni mai segnalate di un annuncio che il team ha tolto si cancellano
--   insieme all'annuncio (dal sistema dopo 6 mesi, o prima se lo cancella chi vende): lo fa
--   un automatismo sull'annuncio, qui sotto.
-- * Con un account eliminato resta solo una conversazione con una segnalazione aperta o
--   accolta: fino a 6 mesi dopo la decisione; respinta, si cancella subito.
-- Messaggi e segnalazioni seguono la conversazione (on delete cascade). I blocchi tra
-- utenti restano finché esiste l'account; un blocco del team si cancella 12 mesi dopo
-- che è finito (annullato o scaduto), uno in vigore resta.
create or replace function public.marketplace_messages_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    -- Mesi in cui una conversazione con una segnalazione DECISA resta dopo la decisione:
    -- accolta o respinta con i due account, solo accolta se un account è stato eliminato.
    -- Anche oltre i 6 e i 12 mesi. Lo dicono anche i testi: si cambia solo insieme a loro.
    review_months constant integer := 6;
    conversation_rows integer;
    restriction_rows integer;
begin
    delete from public.marketplace_conversations c
    where c.erased_participant_at is null
      and not exists (
            select 1 from public.marketplace_conversation_reports r
            where r.conversation_id = c.id
              and (r.status = 'open'
                   or r.resolved_at > now() - make_interval(months => review_months))
        )
        and (
            c.last_message_at < now() - interval '12 months'
            or (
                c.last_message_at < now() - interval '6 months'
                and (
                    c.listing_id is null
                    or exists (
                        select 1 from public.marketplace_listings l
                        where l.id = c.listing_id
                          and l.status = 'sold'
                    )
                )
            )
        );
    get diagnostics conversation_rows = row_count;
    -- Tenute dopo una cancellazione: via appena la segnalazione è respinta, o
    -- review_months dopo la decisione; mai finché è aperta.
    delete from public.marketplace_conversations c
    where c.erased_participant_at is not null
      and not exists (
            select 1 from public.marketplace_conversation_reports r
            where r.conversation_id = c.id
              and (r.status = 'open'
                   or (r.status = 'resolved'
                       and r.resolved_at > now() - make_interval(months => review_months)))
        );
    delete from public.marketplace_moderation_access_log
    where accessed_at < now() - interval '24 months';
    -- La prima delle due date; least() ignora quella che manca. Senza nessuna delle due
    -- il blocco è in vigore, e una scadenza futura non è ancora passata.
    delete from public.marketplace_user_restrictions
    where least(lifted_at, expires_at) < now() - interval '12 months';
    get diagnostics restriction_rows = row_count;
    return jsonb_build_object(
        'marketplace_conversations', conversation_rows,
        'marketplace_user_restrictions', restriction_rows
    );
end;
$$;
revoke all on function public.marketplace_messages_cleanup()
    from public, anon, authenticated;
grant execute on function public.marketplace_messages_cleanup()
    to service_role;

-- Quando si cancella un annuncio che il team ha tolto ('removed_policy'), le sue conversazioni
-- mai segnalate vanno con lui. Quelle segnalate restano e seguono i tempi qui sopra. Un annuncio
-- venduto, attivo o nascosto in automatico ('removed') non è «tolto dal team»: tempi normali.
create or replace function public.marketplace_drop_conversations_of_removed_ad()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if old.status = 'removed_policy' then
        delete from public.marketplace_conversations c
        where c.listing_id = old.id
          and c.erased_participant_at is null
          and not exists (
                select 1 from public.marketplace_conversation_reports r
                where r.conversation_id = c.id
            );
    end if;
    return old;
end;
$$;
revoke all on function public.marketplace_drop_conversations_of_removed_ad()
    from public, anon, authenticated;
drop trigger if exists marketplace_listing_10_drop_conversations on public.marketplace_listings;
create trigger marketplace_listing_10_drop_conversations
before delete on public.marketplace_listings
for each row execute function public.marketplace_drop_conversations_of_removed_ad();

-- La riga per la pulizia automatica, ogni notte alle 03:30 UTC. Serve pg_cron
-- (Supabase: Database > Extensions); senza, questo blocco non fa nulla.
do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule(jobid)
            from cron.job where jobname = 'vetapp-marketplace-messages-cleanup';
        perform cron.schedule(
            'vetapp-marketplace-messages-cleanup',
            '30 3 * * *',
            'select public.marketplace_messages_cleanup()'
        );
    end if;
end
$$;

-- Mercatino solo per privati (decisione del proprietario, 2026-11-09). Chi
-- pubblica o modifica un annuncio dichiara di vendere come privato, non come
-- attività commerciale; il backend rifiuta senza la dichiarazione e ne salva la
-- data qui. Gli annunci più vecchi restano con null. Idempotente.
alter table public.marketplace_listings
    add column if not exists private_seller_declared_at timestamptz;
-- Quale testo della dichiarazione è stato spuntato (es. '2026-11-09').
alter table public.marketplace_listings
    add column if not exists private_seller_declaration_version text
    check (
        private_seller_declaration_version is null
        or char_length(private_seller_declaration_version) <= 32
    );

-- Anche scrivendo direttamente nella tabella con la propria sessione (finché le
-- policy insert/update esistono: marketplace_lock_writes.sql le toglie), un
-- annuncio nuovo o modificato deve portare la dichiarazione. Policy restrittive:
-- tolgono un diritto, non ne danno. Il backend usa la service role e non passa
-- da qui (la regola lì è nella rotta).
drop policy if exists marketplace_listings_insert_private_seller on public.marketplace_listings;
create policy marketplace_listings_insert_private_seller
on public.marketplace_listings
as restrictive
for insert
to authenticated
with check (private_seller_declared_at is not null);

drop policy if exists marketplace_listings_update_private_seller on public.marketplace_listings;
create policy marketplace_listings_update_private_seller
on public.marketplace_listings
as restrictive
for update
to authenticated
with check (private_seller_declared_at is not null);
-- Backend-only support data. No IPs, access tokens, chat text or coordinates.
create table if not exists public.user_login_events (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id) on delete cascade,
    occurred_at timestamptz not null,
    unique (owner_id, occurred_at)
);
create index if not exists user_login_events_owner_time
    on public.user_login_events(owner_id, occurred_at desc);
create index if not exists user_login_events_time on public.user_login_events(occurred_at);
alter table public.user_login_events enable row level security;
revoke all on public.user_login_events from public, anon, authenticated;
grant select, insert, delete on public.user_login_events to service_role;

-- Captures successful real Auth sign-ins, including clients that bypass /auth/login.
-- No backfill: last_sign_in_at remains explicitly labelled as a single legacy value.
create schema if not exists vet_admin_private;
revoke all on schema vet_admin_private from public, anon, authenticated;
create or replace function vet_admin_private.capture_login()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  begin
    if new.last_sign_in_at is not null
       and (tg_op = 'INSERT' or new.last_sign_in_at is distinct from old.last_sign_in_at) then
        insert into public.user_login_events(owner_id, occurred_at)
        values (new.id, new.last_sign_in_at) on conflict do nothing;
        delete from public.user_login_events where occurred_at < now() - interval '90 days';
    end if;
  exception when others then
    -- Observability must not prevent a legitimate sign-in.
    null;
  end;
    return new;
end;
$$;
revoke all on function vet_admin_private.capture_login() from public, anon, authenticated;
drop trigger if exists vet_admin_capture_login on auth.users;
create trigger vet_admin_capture_login after insert or update of last_sign_in_at on auth.users
    for each row execute function vet_admin_private.capture_login();

alter table public.user_locations add column if not exists home_country_code text
    check (home_country_code is null or home_country_code ~ '^[A-Z]{2}$');
alter table public.user_locations add column if not exists home_city text;
alter table public.user_locations add column if not exists home_saved_at timestamptz;

alter table public.marketplace_user_restrictions add column if not exists expires_at timestamptz;
create or replace function public.marketplace_caller_is_restricted()
returns boolean language sql stable security definer set search_path = '' as $$
    select exists (
        select 1 from public.marketplace_user_restrictions r
        where r.owner_id = auth.uid()::text and r.lifted_at is null
          and (r.expires_at is null or r.expires_at > now())
    );
$$;
revoke all on function public.marketplace_caller_is_restricted() from public, anon, authenticated;
grant execute on function public.marketplace_caller_is_restricted() to authenticated;

create table if not exists public.admin_user_actions (
    id uuid primary key default gen_random_uuid(),
    request_id uuid not null,
    owner_id uuid not null references auth.users(id) on delete cascade,
    admin_id text not null,
    action text not null check (action in ('restrict_marketplace', 'lift_marketplace', 'revoke_devices')),
    reason text not null check (reason in ('spam', 'scam', 'harassment', 'prohibited_items', 'other')),
    note text not null check (char_length(note) between 3 and 1000),
    case_queue text check (case_queue in ('marketplace', 'marketplace_messages')),
    case_id text,
    expires_at timestamptz,
    changed boolean not null,
    created_at timestamptz not null default now(),
    unique (request_id, owner_id)
);
create index if not exists admin_user_actions_owner_time
    on public.admin_user_actions(owner_id, created_at desc);
create index if not exists admin_user_actions_time on public.admin_user_actions(created_at);
alter table public.admin_user_actions enable row level security;
-- Team-only evidence, not a public/user-editable audit trail. Owner erasure removes it;
-- export strips team-only notes and admin ids. Records are immutable to API roles.
revoke all on public.admin_user_actions from public, anon, authenticated;
grant select, insert, delete on public.admin_user_actions to service_role;
revoke update on public.admin_user_actions from service_role;

create or replace function public.admin_apply_user_action(
    p_request_id uuid, p_owner_id text, p_admin_id text, p_action text,
    p_reason text, p_note text, p_duration_days integer default null,
    p_case_queue text default null, p_case_id text default null,
    p_expected_restriction jsonb default null
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
    previous public.admin_user_actions;
    restriction public.marketplace_user_restrictions;
    changed boolean := false;
    deadline timestamptz;
    affected integer;
begin
    if current_user <> 'service_role' then raise insufficient_privilege; end if;
    if p_action not in ('restrict_marketplace', 'lift_marketplace', 'revoke_devices')
       or p_note is null or char_length(trim(p_note)) not between 3 and 1000
       or p_owner_id = p_admin_id then
        raise exception 'Invalid action';
    end if;
    -- Serialises all interventions for one account, including simultaneous retries.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_owner_id, 0));
    select * into previous from public.admin_user_actions
        where request_id = p_request_id and owner_id = p_owner_id::uuid;
    if found then
        if previous.admin_id <> p_admin_id or previous.action <> p_action then
            raise exception 'Request id already used';
        end if;
        return jsonb_build_object('status', 'already_applied', 'changed', previous.changed);
    end if;
    select * into restriction from public.marketplace_user_restrictions where owner_id = p_owner_id;
    if p_action <> 'revoke_devices' and p_expected_restriction is not null then
        if restriction.created_at is distinct from (p_expected_restriction->>'created_at')::timestamptz
           or restriction.lifted_at is distinct from (p_expected_restriction->>'lifted_at')::timestamptz
           or restriction.expires_at is distinct from (p_expected_restriction->>'expires_at')::timestamptz then
            return jsonb_build_object('status', 'conflict', 'changed', false);
        end if;
    end if;
    -- Account existence and protected-admin checks are performed with Auth Admin
    -- by the backend immediately before this service-role-only call.
    if p_action = 'restrict_marketplace' then
        if p_duration_days is null or p_duration_days not between 1 and 90 then
            raise exception 'Invalid duration';
        end if;
        deadline := now() + pg_catalog.make_interval(days => p_duration_days);
        select * into restriction from public.marketplace_user_restrictions where owner_id = p_owner_id;
        -- A bulk retry never extends or silently replaces an existing active decision.
        if not found or restriction.lifted_at is not null
           or (restriction.expires_at is not null and restriction.expires_at <= now()) then
            insert into public.marketplace_user_restrictions
                (owner_id, reason, note, created_at, created_by_admin_id, expires_at)
            values (p_owner_id, p_reason, trim(p_note), now(), p_admin_id, deadline)
            on conflict (owner_id) do update set
                reason = excluded.reason, note = excluded.note, created_at = excluded.created_at,
                created_by_admin_id = excluded.created_by_admin_id, expires_at = excluded.expires_at,
                lifted_at = null, lifted_by_admin_id = null;
            changed := true;
        end if;
    elsif p_action = 'lift_marketplace' then
        update public.marketplace_user_restrictions set lifted_at = now(), lifted_by_admin_id = p_admin_id
            where owner_id = p_owner_id and lifted_at is null
              and (expires_at is null or expires_at > now());
        get diagnostics affected = row_count;
        changed := affected > 0;
    else
        update public.user_devices set revoked_at = now()
            where owner_id = p_owner_id and revoked_at is null;
        get diagnostics affected = row_count;
        changed := affected > 0;
    end if;
    insert into public.admin_user_actions
        (request_id, owner_id, admin_id, action, reason, note, case_queue, case_id, expires_at, changed)
    values (p_request_id, p_owner_id::uuid, p_admin_id, p_action, p_reason, trim(p_note),
        p_case_queue, p_case_id, case when changed then deadline else null end, changed);
    delete from public.admin_user_actions where created_at < now() - interval '365 days';
    return jsonb_build_object('status', 'applied', 'changed', changed);
end;
$$;
revoke all on function public.admin_apply_user_action(uuid,text,text,text,text,text,integer,text,text,jsonb)
    from public, anon, authenticated;
grant execute on function public.admin_apply_user_action(uuid,text,text,text,text,text,integer,text,text,jsonb)
    to service_role;

create or replace function public.admin_user_usage(p_owner_id text)
returns jsonb language sql stable security invoker set search_path = '' as $$
    select jsonb_build_object(
        'pets', (select count(*) from public.pet_profiles where owner_id = p_owner_id),
        'conversations', (select count(*) from public.conversations where owner_id = p_owner_id),
        'messages', (select count(*) from public.conversations c cross join lateral
            jsonb_array_elements(case when jsonb_typeof(c.messages) = 'array' then c.messages else '[]'::jsonb end) m
            where c.owner_id = p_owner_id and m->>'role' = 'user'),
        'listings', (select count(*) from public.marketplace_listings where owner_id = p_owner_id),
        'last_device_activity_at', (select max(last_seen_at) from public.user_devices where owner_id = p_owner_id),
        'quota_days_7d', (select count(*) from public.chat_user_daily_usage
            where owner_id = p_owner_id and day between current_date - 6 and current_date
              and messages + vision + dictation + summary + sonnet + followup > 0),
        'quota_days_30d', (select count(*) from public.chat_user_daily_usage
            where owner_id = p_owner_id and day between current_date - 29 and current_date
              and messages + vision + dictation + summary + sonnet + followup > 0),
        'daily', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'messages', messages,
            'vision', vision, 'dictation', dictation, 'summary', summary, 'sonnet', sonnet, 'followup', followup)
            order by day desc) from public.chat_user_daily_usage
            where owner_id = p_owner_id and day between current_date - 29 and current_date), '[]'::jsonb)
    );
$$;
revoke all on function public.admin_user_usage(text) from public, anon, authenticated;
grant execute on function public.admin_user_usage(text) to service_role;

create or replace function public.admin_user_operations_cleanup()
returns void language plpgsql security invoker set search_path = '' as $$
begin
    delete from public.user_login_events where occurred_at < now() - interval '90 days';
    delete from public.admin_user_actions where created_at < now() - interval '365 days';
end;
$$;
revoke all on function public.admin_user_operations_cleanup() from public, anon, authenticated;
grant execute on function public.admin_user_operations_cleanup() to service_role;
do $$
begin
    if exists (select 1 from pg_catalog.pg_extension where extname = 'pg_cron') then
        perform cron.schedule('admin-user-support-retention', '35 3 * * *',
            'select public.admin_user_operations_cleanup()');
    end if;
end;
$$;

-- Audit of plan changes made by the team (POST /admin/users/{id}/plan). Full
-- script with the function and the policy:
-- supabase/migrations/20261121210000_admin_plan_changes.sql. owner_id is TEXT like
-- every other owner_id (QK-07c): the policy compares it with auth.uid()::text.
create table if not exists public.admin_plan_changes (
  id bigint generated always as identity primary key,
  owner_id text not null,
  admin_id uuid not null,
  old_plan text,
  new_plan text,
  changed_at timestamptz not null default now()
);
create index if not exists admin_plan_changes_owner_time
  on public.admin_plan_changes(owner_id, changed_at desc);
alter table public.admin_plan_changes enable row level security;
revoke all on public.admin_plan_changes from public, anon, authenticated;
grant select, insert, delete on public.admin_plan_changes to service_role;

-- No grant to authenticated: the policy below reads nothing today. It is the
-- "own rows only" rule every table carries, should a read ever be granted.
drop policy if exists admin_plan_changes_select_own on public.admin_plan_changes;
-- A table created by the first version of the script has a uuid column: convert it
-- (the policy is dropped above because a column used by a policy cannot change type).
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'admin_plan_changes'
       and column_name = 'owner_id' and data_type = 'uuid'
  ) then
    alter table public.admin_plan_changes alter column owner_id type text using owner_id::text;
  end if;
end $$;
create policy admin_plan_changes_select_own on public.admin_plan_changes
  for select to authenticated
  using (owner_id = (select auth.uid())::text);

-- ---------------------------------------------------------------------------
-- QK-03b (22/11/2026): one answer per chat message across serverless instances.
-- Same text as supabase/migrations/20261122120000_chat_message_keys.sql.
-- ---------------------------------------------------------------------------
-- QK-03b: one answer per chat message, even when two serverless instances receive the same
-- message at the same moment.
--
-- The app gives every message its own id (client_message_id) and sends it again on a retry.
-- Before the model is called, the backend reserves (owner_id, client_message_id) here with an
-- insert ... on conflict do nothing: the instance that inserts it answers; a duplicate finds
-- the key, waits, and then finds the answer already stored in conversations. The table is a
-- LOCK only: whether a message was answered is always read from conversations, never from here.
--
-- Only ids and dates are stored: no message text, no e-mail, no name. Keys older than 30 days
-- are removed by the hourly job (POST /admin/lifecycle/prune-chat-message-keys); the account
-- deletion and the data export read it like the other owner tables.
--
-- Backend only: the backend talks to Supabase with the service_role key. RLS is on and the
-- "own rows only" policy is written for completeness; authenticated and anon get no grant.
-- Idempotent: safe to run more than once. Until it is run, the backend works with the lock
-- inside each process (and says so in its log, once every few minutes).
create table if not exists public.chat_message_keys (
    owner_id text not null,
    client_message_id text not null,
    conversation_id text not null,
    claimed_at timestamptz not null default now(),
    answered_reply_id text,
    primary key (owner_id, client_message_id)
);
create index if not exists idx_chat_message_keys_claimed_at
    on public.chat_message_keys(claimed_at);

alter table public.chat_message_keys enable row level security;
revoke all on public.chat_message_keys from public, anon, authenticated;
grant select, insert, update, delete on public.chat_message_keys to service_role;

drop policy if exists chat_message_keys_own on public.chat_message_keys;
create policy chat_message_keys_own on public.chat_message_keys
    for select to authenticated
    using (owner_id = (select auth.uid())::text);

-- Mercatino: conferma di chi vende e controllo del team (decisioni del proprietario,
-- 2026-11-23; docs/compliance/24). Idempotente. Lo stesso blocco sta in
-- supabase_schema.sql (un test controlla che i due restino allineati).
--
-- Un annuncio il cui testo nomina cibo, integratori o una parola ambigua
-- ("antipulci", "shampoo") si pubblica subito dopo una conferma; il team lo controlla
-- dopo e puo' toglierlo. Se nessuno interviene, resta.
--
-- marketplace_listing_reviews: la conferma (data e versione del testo spuntato), cio'
-- che e' stato confermato e la decisione del team. Si cancella con l'annuncio o con
-- l'account. Si legge e si scrive SOLO dal backend (service_role): la riga contiene
-- la nota e l'id dell'amministratore, che chi vende non deve vedere. Per questo a
-- anon e authenticated e' tolto ogni privilegio; RLS e policy *_own restano come
-- seconda difesa.

create table if not exists public.marketplace_listing_reviews (
    id text primary key,
    listing_id text not null
        references public.marketplace_listings(id) on delete cascade,
    owner_id text not null,
    status text not null default 'open'
        check (status in ('open', 'checked', 'removed', 'superseded')),
    title text not null check (char_length(title) <= 200),
    description text check (description is null or char_length(description) <= 4000),
    category text not null,
    photo_urls jsonb not null default '[]'::jsonb,
    terms jsonb not null default '[]'::jsonb,
    notices jsonb not null default '[]'::jsonb,
    confirmed_at timestamptz not null default now(),
    confirmation_version text not null check (char_length(confirmation_version) <= 32),
    decided_at timestamptz,
    decided_by_admin_id text,
    removal_reason text
        check (removal_reason is null
               or removal_reason in ('food', 'supplement', 'medicine', 'other')),
    note text check (note is null or char_length(note) <= 1000)
);

create index if not exists idx_marketplace_listing_reviews_listing
    on public.marketplace_listing_reviews(listing_id, confirmed_at desc);
create index if not exists idx_marketplace_listing_reviews_owner
    on public.marketplace_listing_reviews(owner_id);
create index if not exists idx_marketplace_listing_reviews_status
    on public.marketplace_listing_reviews(status, confirmed_at);
create index if not exists idx_marketplace_listings_owner
    on public.marketplace_listings(owner_id, created_at desc);

alter table public.marketplace_listing_reviews enable row level security;

drop policy if exists marketplace_listing_reviews_select_own
    on public.marketplace_listing_reviews;
create policy marketplace_listing_reviews_select_own
on public.marketplace_listing_reviews
for select
using (owner_id = auth.uid()::text);

revoke all on table public.marketplace_listing_reviews from anon, authenticated;

-- Registro delle decisioni del team: senza il testo e senza l'id di chi vende, quindi
-- resta dopo la cancellazione dell'annuncio e dell'account (24 mesi). Solo backend:
-- nessuna policy per gli utenti (RLS attiva = nessuno legge), privilegi tolti.
create table if not exists public.marketplace_listing_decision_log (
    id text primary key,
    listing_id text not null,
    outcome text not null check (outcome in ('checked', 'removed', 'restored')),
    reason text check (reason is null or reason in ('food', 'supplement', 'medicine', 'other')),
    admin_id text not null,
    decided_at timestamptz not null default now()
);

create index if not exists idx_marketplace_listing_decision_log_date
    on public.marketplace_listing_decision_log(decided_at);

alter table public.marketplace_listing_decision_log enable row level security;
revoke all on table public.marketplace_listing_decision_log from anon, authenticated;

-- Foto degli annunci tolti dal team: fuori dal bucket pubblico, in questo privato
-- (nessuna policy: ci arriva solo il service_role), finche' il riesame e' possibile.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('marketplace-photos-held', 'marketplace-photos-held', false, 5000000, array['image/jpeg'])
on conflict (id) do update
set public = false,
    file_size_limit = 5000000,
    allowed_mime_types = array['image/jpeg'];

-- Tempi decisi dal proprietario (2026-11-23): un annuncio tolto dal team si cancella, con
-- le foto, 6 mesi dopo la decisione (chi vende puo' cancellarlo prima); il registro dopo
-- 24 mesi. Lo fa il backend ogni ora (POST /admin/lifecycle/prune-removed-listings),
-- perche' da SQL non si cancellano i file.

-- Mercatino: annunci nascosti o tolti dopo le segnalazioni (2026-11-23; docs/compliance/24,
-- punto 6: «Ti diciamo il motivo e la data»). Idempotente; va dopo
-- marketplace_content_review.sql. Lo stesso blocco sta in supabase_schema.sql (un test
-- controlla che i due restino allineati).

-- Una rimozione decisa dalla coda delle segnalazioni si registra come quella dalla coda
-- dei controlli, con i motivi di una segnalazione.
alter table public.marketplace_listing_reviews
    add column if not exists origin text not null default 'confirmation';
alter table public.marketplace_listing_reviews
    drop constraint if exists marketplace_listing_reviews_origin_check;
alter table public.marketplace_listing_reviews
    add constraint marketplace_listing_reviews_origin_check
    check (origin in ('confirmation', 'report'));

alter table public.marketplace_listing_reviews
    drop constraint if exists marketplace_listing_reviews_removal_reason_check;
alter table public.marketplace_listing_reviews
    add constraint marketplace_listing_reviews_removal_reason_check
    check (removal_reason is null
           or removal_reason in ('food', 'supplement', 'medicine', 'spam', 'scam',
                                 'prohibited_item', 'inappropriate', 'sells_animals', 'other'));

alter table public.marketplace_listing_decision_log
    drop constraint if exists marketplace_listing_decision_log_reason_check;
alter table public.marketplace_listing_decision_log
    add constraint marketplace_listing_decision_log_reason_check
    check (reason is null
           or reason in ('food', 'supplement', 'medicine', 'spam', 'scam',
                         'prohibited_item', 'inappropriate', 'sells_animals', 'other'));

-- Tre segnalazioni aperte di persone diverse nascondono un annuncio VISIBILE. Un annuncio
-- gia' tolto dal team ('removed_policy') non cambia stato: perderebbe motivo e scadenza.
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
            when distinct_reporters >= 3 and status in ('active', 'reserved') then 'removed'
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

create index if not exists idx_marketplace_listings_hidden
    on public.marketplace_listings(updated_at)
    where status in ('removed', 'removed_policy');

-- Mercatino (2026-11-23): nella cartella published/ di marketplace-photos e nel contenitore
-- privato scrive solo il backend (service_role). Policy restrittive. Idempotente. Stesso
-- blocco in supabase_schema.sql.

drop policy if exists marketplace_photos_published_insert on storage.objects;
create policy marketplace_photos_published_insert on storage.objects
as restrictive for insert to anon, authenticated
with check (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
);

drop policy if exists marketplace_photos_published_update on storage.objects;
create policy marketplace_photos_published_update on storage.objects
as restrictive for update to anon, authenticated
using (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
)
with check (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
);

drop policy if exists marketplace_photos_published_delete on storage.objects;
create policy marketplace_photos_published_delete on storage.objects
as restrictive for delete to anon, authenticated
using (
    (bucket_id is distinct from 'marketplace-photos'
     or (storage.foldername(name))[1] is distinct from 'published')
    and bucket_id is distinct from 'marketplace-photos-held'
);

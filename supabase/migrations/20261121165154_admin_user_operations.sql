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

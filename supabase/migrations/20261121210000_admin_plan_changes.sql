-- Audit every administrative plan change (portal: Utenti > account > Piano).
-- Executed only by the service-role backend (POST /admin/users/{id}/plan).
-- Idempotent: safe to run again; re-running also replaces the function with
-- this version.
--
-- Fix 2026-11-21 (security review of PR #62): subscriptions.owner_id is text,
-- so the uuid parameter is compared as text; a new subscriptions row needs
-- trial_ends_at (not null, no default); RLS policy *_own added as required by
-- the project rules; service_role may delete (account deletion).
create table if not exists public.admin_plan_changes (
  id bigint generated always as identity primary key,
  owner_id uuid not null,
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
create policy admin_plan_changes_select_own on public.admin_plan_changes
  for select to authenticated
  using (owner_id = (select auth.uid()));

create or replace function public.admin_change_user_plan(
  p_owner_id uuid, p_admin_id uuid, p_plan text
) returns void language plpgsql security invoker set search_path = public as $$
declare
  v_old text;
begin
  if current_user <> 'service_role' then
    raise exception 'Forbidden' using errcode = '42501';
  end if;
  if p_plan is not null and p_plan not in ('plus', 'pro', 'ultra') then
    raise exception 'Invalid plan' using errcode = '22023';
  end if;
  select plan into v_old
    from public.subscriptions
   where owner_id = p_owner_id::text
     for update;
  if not found then
    -- The owner never opened the app (no trial row yet). A plan set by the
    -- team replaces the trial, so the trial ends now; removing a plan from an
    -- account without a row changes nothing.
    if p_plan is not null then
      insert into public.subscriptions (owner_id, plan, trial_ends_at)
      values (p_owner_id::text, p_plan, now());
    end if;
  else
    update public.subscriptions set plan = p_plan where owner_id = p_owner_id::text;
  end if;
  insert into public.admin_plan_changes (owner_id, admin_id, old_plan, new_plan)
  values (p_owner_id, p_admin_id, v_old, p_plan);
end $$;
revoke all on function public.admin_change_user_plan(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_change_user_plan(uuid, uuid, text) to service_role;

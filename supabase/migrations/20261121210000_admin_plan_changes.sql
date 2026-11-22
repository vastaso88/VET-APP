-- corpo = produzione (versione Rob) al 22/11, non rieseguire per cambiare il comportamento
-- (body of admin_change_user_plan = production, Rob's version, as of 2026-11-22: do not
-- re-run this script to change the behaviour).
-- Audit every administrative plan change (portal: Utenti > account > Piano).
-- Executed only by the service-role backend (POST /admin/users/{id}/plan).
-- Idempotent: safe to run again; re-running also replaces the function with
-- this version.
--
-- Fix 2026-11-21 (security review of PR #62): subscriptions.owner_id is text,
-- so the uuid parameter is compared as text; a new subscriptions row needs
-- trial_ends_at (not null, no default); RLS policy *_own added as required by
-- the project rules; service_role may delete (account deletion).
-- Fix 2026-11-22 (QK-07c): admin_plan_changes.owner_id is TEXT, like every other
-- owner_id of the project (the production table already is): the policy compares
-- it with auth.uid() cast to text (a plain `text = uuid` comparison fails), and the
-- function takes the owner id as text (the only signature, see below). A table
-- created earlier with a uuid column is converted below, so this script is safe on
-- either state.
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
-- A table created by the first version of this script has a uuid column: convert it
-- (the policy was dropped above because a column used by a policy cannot change type).
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

-- ONE version only, with p_owner_id text (the signature in production, and the one
-- admin_change_user_plan_totp calls). The first version of this script created a
-- (uuid, uuid, text) overload; two versions make the RPC call ambiguous, so it is
-- dropped here (a no-op where it never existed). Run again, this script ends with
-- exactly one admin_change_user_plan.
drop function if exists public.admin_change_user_plan(uuid, uuid, text);

-- Body = production (Rob's version, read with pg_get_functiondef) on 2026-11-22, only
-- laid out on several lines: do not re-run this script to change the behaviour. A team
-- plan on an account with no subscription row opens a 14-day trial row with that plan.
CREATE OR REPLACE FUNCTION public.admin_change_user_plan(
  p_owner_id text, p_admin_id uuid, p_plan text
) RETURNS void LANGUAGE plpgsql SET search_path TO 'public' AS $function$
declare
  v_old text;
begin
  if current_user <> 'service_role' then
    raise exception 'Forbidden' using errcode='42501';
  end if;
  if p_plan is not null and p_plan not in ('plus','pro','ultra') then
    raise exception 'Invalid plan' using errcode='22023';
  end if;
  select plan into v_old from public.subscriptions where owner_id = p_owner_id for update;
  if not found then
    insert into public.subscriptions (owner_id, trial_ends_at, plan)
    values (p_owner_id, now() + interval '14 days', p_plan);
  else
    update public.subscriptions set plan = p_plan where owner_id = p_owner_id;
  end if;
  insert into public.admin_plan_changes (owner_id,admin_id,old_plan,new_plan)
  values (p_owner_id,p_admin_id,v_old,p_plan);
end $function$;
revoke all on function public.admin_change_user_plan(text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_change_user_plan(text, uuid, text) to service_role;


-- The direct Flutter writes use the same updated max-pets entitlement as the
-- FastAPI services. The baseline script's caller_can_write equated "no pets"
-- with "no subscription"; keep paid access separate so disabling pets does
-- not unintentionally block clinical events, walks, or reminders.
create or replace function public.caller_max_pets()
returns integer language plpgsql stable security definer set search_path=public as $$
declare
  caller uuid := auth.uid();
  configured_test_plan text;
  stored_plan text;
  stored_trial_ends_at timestamptz;
  configured_quota integer;
begin
  if caller is null then return 0; end if;
  if exists(select 1 from public.plan_access_unlimited u where u.owner_id=caller)
    then return null; end if;
  select test_plan into configured_test_plan from public.plan_access_config where id=1;
  if configured_test_plan is not null then
    stored_plan := configured_test_plan;
  else
    select plan,trial_ends_at into stored_plan,stored_trial_ends_at
      from public.subscriptions where owner_id=caller::text;
    if not found then
      select created_at+interval '14 days' into stored_trial_ends_at
        from auth.users where id=caller;
    end if;
  end if;
  if stored_plan not in ('plus','pro','ultra') or stored_plan is null then
    if stored_trial_ends_at is null or stored_trial_ends_at <= now() then return 0; end if;
    stored_plan := 'pro';
  end if;
  -- The base setup can be rerun before the pricing migration.
  if to_regclass('public.pricing_plan_features') is not null then
    select case when enabled then quota else 0 end into configured_quota
      from public.pricing_plan_features
      where plan=stored_plan and feature='max_pets';
    if found then return configured_quota; end if;
  end if;
  return case stored_plan when 'plus' then 4 when 'pro' then 8 else 15 end;
end $$;

create or replace function public.caller_can_write()
returns boolean language plpgsql stable security definer set search_path=public as $$
declare
  caller uuid := auth.uid();
  stored_plan text;
  stored_trial_ends_at timestamptz;
begin
  if caller is null then return false; end if;
  if exists(select 1 from public.plan_access_unlimited u where u.owner_id=caller)
    then return true; end if;
  select test_plan into stored_plan from public.plan_access_config where id=1;
  if stored_plan in ('plus','pro','ultra') then return true; end if;
  select plan,trial_ends_at into stored_plan,stored_trial_ends_at
    from public.subscriptions where owner_id=caller::text;
  if not found then
    select created_at+interval '14 days' into stored_trial_ends_at
      from auth.users where id=caller;
  end if;
  return coalesce(stored_plan in ('plus','pro','ultra'),false)
    or coalesce(stored_trial_ends_at>now(),false);
end $$;
revoke all on function public.caller_max_pets() from public,anon;
revoke all on function public.caller_can_write() from public,anon;
grant execute on function public.caller_max_pets() to authenticated,service_role;
grant execute on function public.caller_can_write() to authenticated,service_role;

-- Admin PRICING: region/store price drafts and enforceable plan quotas.
-- Apply after 20261121222500_admin_plan_totp.sql and plan_access_rules.sql.
-- Store price rows are internal targets only: Apple/Google remain the authority
-- for customer-facing prices. No external billing API is called by these RPCs.

begin;

create table if not exists public.pricing_plan_features (
  plan text not null check (plan in ('plus','pro','ultra')),
  feature text not null check (feature in
    ('max_pets','max_chats_per_pet','daily_questions','max_devices','daily_sonnet_answers')),
  enabled boolean not null default true,
  quota integer not null check (quota between 0 and 2000),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (plan,feature)
);

insert into public.pricing_plan_features (plan, feature, quota) values
  ('plus','max_pets',4),('plus','max_chats_per_pet',2),('plus','daily_questions',9),
  ('plus','max_devices',2),('plus','daily_sonnet_answers',1),
  ('pro','max_pets',8),('pro','max_chats_per_pet',4),('pro','daily_questions',16),
  ('pro','max_devices',3),('pro','daily_sonnet_answers',2),
  ('ultra','max_pets',15),('ultra','max_chats_per_pet',6),('ultra','daily_questions',30),
  ('ultra','max_devices',3),('ultra','daily_sonnet_answers',3)
on conflict (plan, feature) do nothing;

create table if not exists public.pricing_store_prices (
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  store text not null check (store in ('apple','google')),
  plan text not null check (plan in ('plus','pro','ultra')),
  period text not null check (period in ('monthly','yearly')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  amount_minor integer not null check (amount_minor between 1 and 100000000),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (country_code,store,plan,period)
);

-- Approved Italian list-price references, not statements of live store prices.
insert into public.pricing_store_prices
(country_code, store, plan, period, currency, amount_minor)
select 'IT', store, plan, period, 'EUR', amount_minor
from (values ('apple'),('google')) as stores(store)
cross join (values
 ('plus','monthly',459),('plus','yearly',4599),
 ('pro','monthly',859),('pro','yearly',8599),
 ('ultra','monthly',1559),('ultra','yearly',15599)
) as prices(plan,period,amount_minor)
on conflict (country_code,store,plan,period) do nothing;

create table if not exists public.pricing_admin_audit (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  entity_type text not null check (entity_type in ('feature','price')),
  entity_key text not null,
  before_value jsonb,
  after_value jsonb,
  changed_at timestamptz not null default now()
);
create index if not exists idx_pricing_admin_audit_recent
  on public.pricing_admin_audit(changed_at desc);

alter table public.pricing_plan_features enable row level security;
alter table public.pricing_store_prices enable row level security;
alter table public.pricing_admin_audit enable row level security;
revoke all on table public.pricing_plan_features from public,anon,authenticated;
revoke all on table public.pricing_store_prices from public,anon,authenticated;
revoke all on table public.pricing_admin_audit from public,anon,authenticated;
grant select,insert,update on table public.pricing_plan_features to service_role;
grant select,insert,update,delete on table public.pricing_store_prices to service_role;
grant select,insert on table public.pricing_admin_audit to service_role;
grant usage,select on sequence public.pricing_admin_audit_id_seq to service_role;

-- Same replay protection used by /admin/users/{id}/plan. A single six-digit
-- TOTP code may authorize one mutation across BOTH admin interfaces.
create or replace function public.admin_pricing_consume_totp(
  p_admin_id uuid, p_code_digest text
) returns void language plpgsql security invoker set search_path=public as $$
declare v_claimed uuid;
begin
  if current_user <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
  if p_admin_id is null or p_code_digest !~ '^[a-f0-9]{64}$' then
    raise exception 'Invalid proof' using errcode='22023';
  end if;
  insert into public.admin_plan_totp_replay(admin_id,code_digest,used_at)
  values(p_admin_id,p_code_digest,now())
  on conflict (admin_id,code_digest) do update
    set used_at=excluded.used_at
    where public.admin_plan_totp_replay.used_at < now()-interval '2 minutes'
  returning admin_id into v_claimed;
  if v_claimed is null then
    raise exception 'TOTP already used' using errcode='22023';
  end if;
end $$;
revoke all on function public.admin_pricing_consume_totp(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_pricing_consume_totp(uuid,text) to service_role;

create or replace function public.admin_pricing_save_feature(
  p_admin_id uuid, p_plan text, p_feature text, p_enabled boolean,
  p_quota integer, p_code_digest text
) returns void language plpgsql security invoker set search_path=public as $$
declare
  v_before public.pricing_plan_features%rowtype;
  v_after public.pricing_plan_features%rowtype;
begin
  if current_user <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
  if p_plan not in ('plus','pro','ultra')
    or p_feature not in ('max_pets','max_chats_per_pet','daily_questions','max_devices','daily_sonnet_answers')
    or p_enabled is null or p_quota is null or p_quota < 0 or p_quota > 2000 then
    raise exception 'Invalid feature configuration' using errcode='22023';
  end if;
  perform public.admin_pricing_consume_totp(p_admin_id,p_code_digest);
  select * into v_before from public.pricing_plan_features
    where plan=p_plan and feature=p_feature for update;
  insert into public.pricing_plan_features(plan,feature,enabled,quota,updated_by)
  values(p_plan,p_feature,p_enabled,p_quota,p_admin_id)
  on conflict (plan,feature) do update set
    enabled=excluded.enabled, quota=excluded.quota,
    updated_at=now(), updated_by=excluded.updated_by
  returning * into v_after;
  insert into public.pricing_admin_audit
    (admin_id,entity_type,entity_key,before_value,after_value)
  values(p_admin_id,'feature',p_plan||':'||p_feature,
         to_jsonb(v_before),to_jsonb(v_after));
end $$;
revoke all on function public.admin_pricing_save_feature(uuid,text,text,boolean,integer,text)
  from public,anon,authenticated;
grant execute on function public.admin_pricing_save_feature(uuid,text,text,boolean,integer,text)
  to service_role;

create or replace function public.admin_pricing_save_price(
  p_admin_id uuid, p_country_code text, p_store text, p_plan text,
  p_period text, p_currency text, p_amount_minor integer, p_code_digest text
) returns void language plpgsql security invoker set search_path=public as $$
declare
  v_before public.pricing_store_prices%rowtype;
  v_after public.pricing_store_prices%rowtype;
begin
  if current_user <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
  if p_country_code !~ '^[A-Z]{2}$'
    or p_store not in ('apple','google')
    or p_plan not in ('plus','pro','ultra')
    or p_period not in ('monthly','yearly')
    or p_currency !~ '^[A-Z]{3}$'
    or (p_amount_minor is not null and (p_amount_minor < 1 or p_amount_minor > 100000000)) then
    raise exception 'Invalid price configuration' using errcode='22023';
  end if;
  perform public.admin_pricing_consume_totp(p_admin_id,p_code_digest);
  select * into v_before from public.pricing_store_prices
    where country_code=p_country_code and store=p_store
      and plan=p_plan and period=p_period for update;
  if p_amount_minor is null then
    delete from public.pricing_store_prices
      where country_code=p_country_code and store=p_store
        and plan=p_plan and period=p_period;
    v_after := null;
  else
    insert into public.pricing_store_prices
      (country_code,store,plan,period,currency,amount_minor,updated_by)
    values(p_country_code,p_store,p_plan,p_period,p_currency,p_amount_minor,p_admin_id)
    on conflict (country_code,store,plan,period) do update set
      currency=excluded.currency, amount_minor=excluded.amount_minor,
      updated_at=now(), updated_by=excluded.updated_by
    returning * into v_after;
  end if;
  insert into public.pricing_admin_audit
    (admin_id,entity_type,entity_key,before_value,after_value)
  values(p_admin_id,'price',
         p_country_code||':'||p_store||':'||p_plan||':'||p_period,
         to_jsonb(v_before),to_jsonb(v_after));
end $$;
revoke all on function public.admin_pricing_save_price(uuid,text,text,text,text,text,integer,text)
  from public,anon,authenticated;
grant execute on function public.admin_pricing_save_price(uuid,text,text,text,text,text,integer,text)
  to service_role;

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
  select case when enabled then quota else 0 end into configured_quota
    from public.pricing_plan_features
    where plan=stored_plan and feature='max_pets';
  if found then return configured_quota; end if;
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

commit;

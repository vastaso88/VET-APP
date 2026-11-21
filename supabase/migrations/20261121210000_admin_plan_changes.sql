-- Audit every administrative plan override. Executed only by the service-role backend.
create table if not exists public.admin_plan_changes (
  id bigint generated always as identity primary key,
  owner_id uuid not null,
  admin_id uuid not null,
  old_plan text,
  new_plan text,
  changed_at timestamptz not null default now()
);
alter table public.admin_plan_changes enable row level security;
revoke all on public.admin_plan_changes from public, anon, authenticated;
grant select, insert on public.admin_plan_changes to service_role;
create or replace function public.admin_change_user_plan(
  p_owner_id uuid, p_admin_id uuid, p_plan text
) returns void language plpgsql security invoker set search_path = public as $$
declare v_old text;
begin
  if current_user <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
  if p_plan is not null and p_plan not in ('plus','pro','ultra') then
    raise exception 'Invalid plan' using errcode='22023';
  end if;
  select plan into v_old from public.subscriptions where owner_id = p_owner_id for update;
  if not found then
    insert into public.subscriptions (owner_id, plan) values (p_owner_id, p_plan);
  else
    update public.subscriptions set plan = p_plan where owner_id = p_owner_id;
  end if;
  insert into public.admin_plan_changes (owner_id,admin_id,old_plan,new_plan)
  values (p_owner_id,p_admin_id,v_old,p_plan);
end $$;
revoke all on function public.admin_change_user_plan(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_change_user_plan(uuid,uuid,text) to service_role;

-- Per-administrator rate limiting and one-time TOTP proof for plan changes.
-- Both tables are private to service_role; TOTP codes are NEVER stored.
create table if not exists public.admin_plan_totp_attempts (
  admin_id uuid primary key,
  window_started_at timestamptz not null default now(),
  attempts integer not null default 0
);
create table if not exists public.admin_plan_totp_replay (
  admin_id uuid not null,
  code_digest text not null,
  used_at timestamptz not null default now(),
  primary key (admin_id, code_digest)
);
alter table public.admin_plan_totp_attempts enable row level security;
alter table public.admin_plan_totp_replay enable row level security;
revoke all on public.admin_plan_totp_attempts from public, anon, authenticated;
revoke all on public.admin_plan_totp_replay from public, anon, authenticated;
grant select, insert, update on public.admin_plan_totp_attempts to service_role;
grant select, insert, update on public.admin_plan_totp_replay to service_role;

-- Atomic and shared across Vercel serverless instances: 5 attempts per 5 minutes.
create or replace function public.admin_plan_totp_register_attempt(p_admin_id uuid)
returns boolean language plpgsql security invoker set search_path=public as $$
declare v_attempts integer;
begin
  if current_user <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
  insert into public.admin_plan_totp_attempts(admin_id,window_started_at,attempts)
  values(p_admin_id,now(),1)
  on conflict (admin_id) do update set
    attempts = case
      when public.admin_plan_totp_attempts.window_started_at <= now()-interval '5 minutes'
      then 1 else public.admin_plan_totp_attempts.attempts+1 end,
    window_started_at = case
      when public.admin_plan_totp_attempts.window_started_at <= now()-interval '5 minutes'
      then now() else public.admin_plan_totp_attempts.window_started_at end
  returning attempts into v_attempts;
  return v_attempts <= 5;
end $$;
revoke all on function public.admin_plan_totp_register_attempt(uuid) from public, anon, authenticated;
grant execute on function public.admin_plan_totp_register_attempt(uuid) to service_role;

-- The proof must be verified by Supabase Auth BEFORE calling this RPC.
-- A successfully verified six-digit code can authorize only one plan change.
-- Reuse is blocked for 2 minutes (TOTP validity + clock skew).
-- The code digest is a keyed HMAC generated on the trusted API backend.
create or replace function public.admin_change_user_plan_totp(
  p_owner_id text, p_admin_id uuid, p_plan text, p_code_digest text
) returns void language plpgsql security invoker set search_path=public as $$
declare v_claimed uuid;
begin
  if current_user <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
  if p_code_digest !~ '^[a-f0-9]{64}$' then
    raise exception 'Invalid proof digest' using errcode='22023';
  end if;
  insert into public.admin_plan_totp_replay(admin_id,code_digest,used_at)
  values(p_admin_id,p_code_digest,now())
  on conflict (admin_id,code_digest) do update
    set used_at=excluded.used_at
    where public.admin_plan_totp_replay.used_at < now()-interval '2 minutes'
  returning admin_id into v_claimed;
  if v_claimed is null then
    raise exception 'TOTP code already used' using errcode='22023';
  end if;
  -- Existing transaction handles plan update + immutable audit entry.
  -- Old deployments use text owner_id; newer baselines may use UUID.
  if to_regprocedure('public.admin_change_user_plan(text,uuid,text)') is not null then
    perform public.admin_change_user_plan(p_owner_id,p_admin_id,p_plan);
  else
    perform public.admin_change_user_plan(p_owner_id::uuid,p_admin_id,p_plan);
  end if;
end $$;
revoke all on function public.admin_change_user_plan_totp(text,uuid,text,text) from public, anon, authenticated;
grant execute on function public.admin_change_user_plan_totp(text,uuid,text,text) to service_role;

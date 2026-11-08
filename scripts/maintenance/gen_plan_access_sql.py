"""Writes scripts/setup/plan_access_rules.sql: the plan rules (access after the
trial, maximum number of pets) enforced in the database on the writes the app
makes directly, generated from the backend's own numbers so the two can never
disagree:

* packages/core/domain/subscription/limits.py (plans, trial, no-access limits)
* packages/core/domain/subscription/models.py (plan keys, trial length)
* packages/core/domain/subscription/direct_writes.py (tables, bucket, codes)

``python scripts/maintenance/gen_plan_access_sql.py`` rewrites the script;
``--check`` exits 1 when it is out of date (tests/unit/test_plan_access_sql.py
runs it).
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from packages.core.domain.subscription.direct_writes import (  # noqa: E402
    GATED_BUCKET,
    GATED_TABLES,
    PETS_LIMIT_KIND,
    PLAN_LIMIT_CODE,
    PLAN_LIMIT_SQLSTATE,
    SUBSCRIPTION_REQUIRED_CODE,
    SUBSCRIPTION_REQUIRED_SQLSTATE,
)
from packages.core.domain.subscription.limits import (  # noqa: E402
    LIMITS_BY_PLAN,
    NO_ACCESS_LIMITS,
    TRIAL_LIMITS,
)
from packages.core.domain.subscription.models import (  # noqa: E402
    TRIAL_DURATION,
    SubscriptionPlan,
)

SQL_PATH = ROOT / "scripts/setup/plan_access_rules.sql"


def _check_invariants() -> None:
    """caller_can_write() is "max pets is unlimited or above zero": that only
    holds while no plan allows zero pets and having no access allows none."""
    if NO_ACCESS_LIMITS.max_pets != 0:
        raise SystemExit("NO_ACCESS_LIMITS.max_pets must be 0 (no access = no new pet)")
    for plan, limits in LIMITS_BY_PLAN.items():
        if limits.max_pets <= 0:
            raise SystemExit(f"plan {plan!r} must allow at least one pet")
    if TRIAL_LIMITS.max_pets <= 0:
        raise SystemExit("the trial must allow at least one pet")
    if set(LIMITS_BY_PLAN) != set(SubscriptionPlan.ALL):
        raise SystemExit("every plan needs its limits and every limit its plan")


def render_sql() -> str:
    _check_invariants()
    plans = sorted(SubscriptionPlan.ALL)
    plan_list = ", ".join(f"'{plan}'" for plan in plans)
    max_pets_case = "\n".join(
        f"        when '{plan}' then {LIMITS_BY_PLAN[plan].max_pets}" for plan in plans
    )
    trial_days = TRIAL_DURATION.days
    if TRIAL_DURATION.total_seconds() != trial_days * 86400:
        raise SystemExit("TRIAL_DURATION must be a whole number of days")

    gate_blocks = "\n".join(
        f"""drop trigger if exists plan_access_10_gate on public.{table};
create trigger plan_access_10_gate
before insert or update on public.{table}
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.{table};
create policy plan_access_insert
on public.{table}
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.{table};
create policy plan_access_update
on public.{table}
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());
"""
        for table in GATED_TABLES
    )

    return f"""-- Regole del piano sulle scritture dirette dell'app (proposta A approvata,
-- decisioni del proprietario 2026-11-09). GENERATO da
-- scripts/maintenance/gen_plan_access_sql.py a partire da limits.py, models.py
-- e direct_writes.py: non modificare a mano.
--
-- In parole semplici: l'app scrive alcune tabelle direttamente nel database.
-- Fino a oggi il database controllava solo che la riga fosse dell'utente.
-- Da qui in poi controlla anche il piano: dopo la prova, senza un piano,
-- si possono leggere, esportare e cancellare i propri dati, ma non aggiungerne
-- ne' modificarli (Termini it/03 par. 4); e gli animali non superano il numero
-- che il piano consente. Le scritture del backend (chiave service_role) non
-- sono toccate: il backend applica le stesse regole per conto suo.
--
-- QUANDO: dopo scripts/setup/subscriptions_lock_writes.sql (senza quello un
-- utente puo' scriversi da solo il piano e la regola non vale nulla).
-- Idempotente: si puo' rilanciare.
--
-- PERIODO DI TEST: la riga di plan_access_config con test_plan = 'pro' fa
-- scrivere tutti come sul piano Pro, come SUBSCRIPTION_TEST_PLAN sul backend.
-- Il backend tiene allineata la riga alla variabile a ogni controllo dello
-- stato dell'abbonamento; lo script la crea gia' su 'pro' cosi' nessuno resta
-- bloccato prima di quel controllo. Quando i pagamenti diventano veri basta
-- togliere SUBSCRIPTION_TEST_PLAN su Vercel (oppure:
--   update public.plan_access_config set test_plan = null where id = 1;).
--
-- Codici che l'app riceve (gli stessi del backend):
--   {SUBSCRIPTION_REQUIRED_CODE} (HTTP 402, SQLSTATE {SUBSCRIPTION_REQUIRED_SQLSTATE})
--   {PLAN_LIMIT_CODE} (HTTP 403, SQLSTATE {PLAN_LIMIT_SQLSTATE}), details = '{PETS_LIMIT_KIND}',
--     hint = il numero massimo di animali del piano

begin;

-- ---------------------------------------------------------------------------
-- 1. Tabelle di supporto (solo backend: nessun privilegio per l'app)
-- ---------------------------------------------------------------------------
create table if not exists public.plan_access_config (
    id integer primary key default 1 check (id = 1),
    test_plan text check (test_plan is null or test_plan in ({plan_list})),
    updated_at timestamptz not null default now()
);
insert into public.plan_access_config (id, test_plan)
values (1, 'pro')
on conflict (id) do nothing;

-- Gli account della lista sviluppatori (DEVELOPER_EMAILS sul backend): nessun
-- limite. Il backend aggiunge e toglie le righe; la riga sparisce con l'account.
create table if not exists public.plan_access_unlimited (
    owner_id uuid primary key references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

alter table public.plan_access_config enable row level security;
alter table public.plan_access_unlimited enable row level security;
revoke all on table public.plan_access_config from anon, authenticated;
revoke all on table public.plan_access_unlimited from anon, authenticated;
grant all on table public.plan_access_config to service_role;
grant all on table public.plan_access_unlimited to service_role;

-- ---------------------------------------------------------------------------
-- 2. Cosa consente il piano a chi chiama (mai a un'altra persona)
-- ---------------------------------------------------------------------------
-- Il numero massimo di animali di chi chiama; NULL = nessun limite. Zero vuol
-- dire "nessun accesso": la prova e' finita e non c'e' un piano.
create or replace function public.caller_max_pets()
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    caller uuid := auth.uid();
    configured_test_plan text;
    stored_plan text;
    stored_trial_ends_at timestamptz;
begin
    if caller is null then
        return 0;
    end if;
    if exists (select 1 from public.plan_access_unlimited u where u.owner_id = caller) then
        return null;
    end if;
    select c.test_plan into configured_test_plan from public.plan_access_config c where c.id = 1;
    if configured_test_plan is not null then
        stored_plan := configured_test_plan;
    else
        select s.plan, s.trial_ends_at into stored_plan, stored_trial_ends_at
        from public.subscriptions s
        where s.owner_id = caller::text;
        if not found then
            -- Nessuna riga ancora (il backend la crea al primo controllo dello
            -- stato): la prova conta dalla creazione dell'account.
            select u.created_at + interval '{trial_days} days' into stored_trial_ends_at
            from auth.users u
            where u.id = caller;
        end if;
    end if;
    if stored_plan in ({plan_list}) then
        return case stored_plan
{max_pets_case}
        end;
    end if;
    if stored_trial_ends_at is not null and stored_trial_ends_at > now() then
        return {TRIAL_LIMITS.max_pets};
    end if;
    return {NO_ACCESS_LIMITS.max_pets};
end;
$$;

create or replace function public.caller_can_write()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(public.caller_max_pets(), 1) > 0;
$$;

revoke all on function public.caller_max_pets() from public, anon;
revoke all on function public.caller_can_write() from public, anon;
grant execute on function public.caller_max_pets() to authenticated, service_role;
grant execute on function public.caller_can_write() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. I controlli (trigger per dire il perche', policy come seconda difesa)
-- ---------------------------------------------------------------------------
-- Solo le scritture fatte con il token di un utente (app): il backend
-- (service_role) e lo SQL Editor (nessun token) passano.
create or replace function public.plan_access_gate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
        return new;
    end if;
    if not public.caller_can_write() then
        raise exception using
            errcode = '{SUBSCRIPTION_REQUIRED_SQLSTATE}',
            message = '{SUBSCRIPTION_REQUIRED_CODE}',
            detail = 'trial over and no plan: read, export and delete only';
    end if;
    return new;
end;
$$;

create or replace function public.plan_access_pet_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    limit_count integer;
    current_count integer;
begin
    if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
        return new;
    end if;
    -- Un upsert di un animale che esiste gia' e' una modifica, non un animale
    -- in piu' (il trigger "before insert" scatta anche per insert ... on conflict).
    if exists (
        select 1 from public.pet_profiles p where p.id = new.id and p.owner_id = new.owner_id
    ) then
        return new;
    end if;
    -- Due creazioni nello stesso istante non superano il limite insieme.
    perform pg_advisory_xact_lock(hashtextextended('vetapp_pet_limit:' || new.owner_id, 0));
    limit_count := public.caller_max_pets();
    if limit_count is null then
        return new;
    end if;
    select count(*) into current_count
    from public.pet_profiles p
    where p.owner_id = new.owner_id;
    if current_count >= limit_count then
        raise exception using
            errcode = '{PLAN_LIMIT_SQLSTATE}',
            message = '{PLAN_LIMIT_CODE}',
            detail = '{PETS_LIMIT_KIND}',
            hint = limit_count::text;
    end if;
    return new;
end;
$$;

revoke all on function public.plan_access_gate() from public, anon, authenticated;
revoke all on function public.plan_access_pet_limit() from public, anon, authenticated;

{gate_blocks}
-- Il limite di animali, dopo il controllo del piano (i trigger scattano in
-- ordine alfabetico: 10 prima di 20).
drop trigger if exists plan_access_20_pet_limit on public.pet_profiles;
create trigger plan_access_20_pet_limit
before insert on public.pet_profiles
for each row execute function public.plan_access_pet_limit();

-- Foto, video e foto profilo: caricare o sostituire un file richiede il piano,
-- toglierlo no. Gli altri bucket non sono toccati.
drop policy if exists plan_access_pet_photos_insert on storage.objects;
create policy plan_access_pet_photos_insert
on storage.objects
as restrictive
for insert
to authenticated
with check (bucket_id <> '{GATED_BUCKET}' or public.caller_can_write());

drop policy if exists plan_access_pet_photos_update on storage.objects;
create policy plan_access_pet_photos_update
on storage.objects
as restrictive
for update
to authenticated
using (true)
with check (bucket_id <> '{GATED_BUCKET}' or public.caller_can_write());

commit;

-- ---------------------------------------------------------------------------
-- Verifiche (solo lettura, da lanciare dopo)
-- ---------------------------------------------------------------------------
-- a) il periodo di test e' attivo (atteso durante il test: 'pro')
--   select test_plan from public.plan_access_config where id = 1;
-- b) ogni tabella ha il suo controllo (attese {len(GATED_TABLES)} righe piu' quella del limite)
--   select event_object_table, trigger_name from information_schema.triggers
--   where trigger_name like 'plan_access_%' order by 1, 2;
-- c) le policy restrittive ci sono
--   select tablename, policyname from pg_policies
--   where policyname like 'plan_access_%' order by 1, 2;
"""


def main() -> int:
    check = "--check" in sys.argv[1:]
    content = render_sql()
    if check:
        current = SQL_PATH.read_text(encoding="utf-8") if SQL_PATH.exists() else ""
        if current.replace("\r\n", "\n") != content:
            print(f"out of date: {SQL_PATH.relative_to(ROOT)} (run the script)")
            return 1
        return 0
    SQL_PATH.write_text(content, encoding="utf-8", newline="\n")
    print(f"wrote {SQL_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

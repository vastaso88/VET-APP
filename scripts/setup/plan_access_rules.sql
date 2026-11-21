-- Regole del piano sulle scritture dirette dell'app (proposta A approvata,
-- decisioni del proprietario 2026-11-09). GENERATO da
-- scripts/maintenance/gen_plan_access_sql.py a partire da limits.py, models.py
-- e direct_writes.py: non modificare a mano.
--
-- In parole semplici: l'app scrive alcune tabelle direttamente nel database.
-- Fino a oggi il database controllava solo che la riga fosse dell'utente.
-- Da qui in poi controlla anche il piano: dopo la prova, senza un piano,
-- si possono leggere, esportare e cancellare i propri dati, ma non aggiungerne
-- ne' modificarli (Termini it/03 par. 4), con una sola eccezione: spostare un
-- animale nei Ricordi (decisione del proprietario, 16/11/2026: chi perde un
-- animale non deve trovare un paywall); e gli animali non superano il numero
-- che il piano consente. Contano solo gli animali ATTIVI: quelli nei Ricordi
-- non occupano un posto, e riportarne uno tra gli animali richiede un posto
-- libero (decisione del proprietario, 16/11/2026). Nei Ricordi si possono
-- tenere al massimo plan_access_config.max_memorial_pets animali
-- (30 se non altrimenti impostato): il backend scrive il numero
-- scelto con la variabile MEMORIAL_PETS_MAX (il valore dello script e' solo
-- quello di partenza). Le scritture del backend (chiave service_role) non
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
--   subscription_required (HTTP 402, SQLSTATE PT402)
--   plan_limit_reached (HTTP 403, SQLSTATE PT403), details = 'pets',
--     hint = il numero massimo di animali del piano
--   plan_limit_reached (HTTP 403, SQLSTATE PT403),
--     details = 'memorials',
--     hint = il numero massimo di animali nei Ricordi

begin;

-- La colonna che dice se un animale e' nei Ricordi (c'e' gia' su ogni database
-- aggiornato: qui solo per non fallire su uno vecchio).
alter table public.pet_profiles add column if not exists is_memorial boolean not null default false;

-- ---------------------------------------------------------------------------
-- 1. Tabelle di supporto (solo backend: nessun privilegio per l'app)
-- ---------------------------------------------------------------------------
create table if not exists public.plan_access_config (
    id integer primary key default 1 check (id = 1),
    test_plan text check (test_plan is null or test_plan in ('plus', 'pro', 'ultra')),
    updated_at timestamptz not null default now()
);
-- Quanti animali si possono tenere nei Ricordi (uguale per ogni piano). Il
-- backend lo allinea alla variabile MEMORIAL_PETS_MAX a ogni controllo dello
-- stato dell'abbonamento; il valore qui sotto e' solo quello di partenza.
alter table public.plan_access_config
    add column if not exists max_memorial_pets integer not null default 30
    check (max_memorial_pets > 0);
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
            select u.created_at + interval '14 days' into stored_trial_ends_at
            from auth.users u
            where u.id = caller;
        end if;
    end if;
    if stored_plan in ('plus', 'pro', 'ultra') then
        return case stored_plan
        when 'plus' then 4
        when 'pro' then 8
        when 'ultra' then 15
        end;
    end if;
    if stored_trial_ends_at is not null and stored_trial_ends_at > now() then
        return 8;
    end if;
    return 0;
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
            errcode = 'PT402',
            message = 'subscription_required',
            detail = 'trial over and no plan: read, export and delete only';
    end if;
    return new;
end;
$$;

-- Il controllo di pet_profiles: come plan_access_gate, con UNA eccezione per chi
-- non ha un piano (decisione del proprietario, 16/11/2026): spostare un animale
-- nei Ricordi, cioe' is_memorial da falso a vero su un profilo che esiste, con la
-- data della perdita. Chi perde un animale a prova finita non deve trovare un
-- paywall per smettere di ricevere promemoria, farmaci e auguri; lo spostamento
-- non occupa un posto del piano. Ogni altra scrittura resta rifiutata, anche il
-- ritorno tra gli animali (da vero a falso). L'app scrive con un upsert: il
-- trigger "before insert" scatta anche quando la riga esiste gia' (insert ...
-- on conflict), e allora decide la modifica che segue; un animale NUOVO che
-- nasce nei Ricordi resta rifiutato. Il tetto ai Ricordi (plan_access_30_*)
-- vale anche qui.
create or replace function public.plan_access_move_gate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
        return new;
    end if;
    if public.caller_can_write() then
        return new;
    end if;
    if coalesce(new.is_memorial, false) and coalesce(new.memorial_date_label, '') <> '' then
        if tg_op = 'UPDATE' then
            if not coalesce(old.is_memorial, false) then
                return new;
            end if;
        elsif exists (
            select 1
            from public.pet_profiles p
            where p.id = new.id and p.owner_id = new.owner_id and not p.is_memorial
        ) then
            return new;
        end if;
    end if;
    raise exception using
        errcode = 'PT402',
        message = 'subscription_required',
        detail = 'trial over and no plan: read, export and delete only';
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
    -- Un animale nei Ricordi non occupa un posto del piano (decisione del
    -- proprietario, 16/11/2026): ne' quando ci va (e' una modifica) ne' quando
    -- nasce gia' li'.
    if coalesce(new.is_memorial, false) then
        return new;
    end if;
    if tg_op = 'UPDATE' then
        -- Aggiunge un animale solo il RITORNO dai Ricordi (true -> false): ogni
        -- altra modifica no. (OLD si legge solo qui: in un inserimento non c'e'.)
        if not coalesce(old.is_memorial, false) then
            return new;
        end if;
    elsif exists (
        select 1 from public.pet_profiles p where p.id = new.id and p.owner_id = new.owner_id
    ) then
        -- Un upsert di un animale che esiste gia' e' una modifica, non un animale
        -- in piu' (il trigger "before insert" scatta anche per insert ... on conflict;
        -- se era nei Ricordi, il controllo lo fa la modifica che segue).
        return new;
    end if;
    -- Due creazioni (o ritorni) nello stesso istante non superano il limite insieme.
    perform pg_advisory_xact_lock(hashtextextended('vetapp_pet_limit:' || new.owner_id, 0));
    limit_count := public.caller_max_pets();
    if limit_count is null then
        return new;
    end if;
    -- Contano solo gli animali attivi, escluso questo (nel ritorno dai Ricordi
    -- la riga c'e' gia').
    select count(*) into current_count
    from public.pet_profiles p
    where p.owner_id = new.owner_id and not p.is_memorial and p.id <> new.id;
    if current_count >= limit_count then
        raise exception using
            errcode = 'PT403',
            message = 'plan_limit_reached',
            detail = 'pets',
            hint = limit_count::text;
    end if;
    return new;
end;
$$;

-- Il tetto agli animali nei Ricordi: conta solo chi ci ENTRA (una modifica che
-- porta is_memorial da falso a vero, o una riga che nasce gia' li'); le altre
-- modifiche a un animale gia' nei Ricordi non cambiano il numero. Il tetto non
-- dipende dal piano.
create or replace function public.plan_access_memorial_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    cap integer;
    current_count integer;
begin
    if coalesce(auth.role(), '') not in ('authenticated', 'anon') then
        return new;
    end if;
    if not coalesce(new.is_memorial, false) then
        return new;
    end if;
    if tg_op = 'UPDATE' then
        -- Gia' nei Ricordi: una modifica qualunque non ne aggiunge uno.
        if coalesce(old.is_memorial, false) then
            return new;
        end if;
    elsif exists (
        select 1 from public.pet_profiles p where p.id = new.id and p.owner_id = new.owner_id
    ) then
        -- Un upsert di un animale che esiste gia': il controllo lo fa la modifica
        -- che segue (come per il limite degli animali).
        return new;
    end if;
    -- Due spostamenti nello stesso istante non superano il tetto insieme.
    perform pg_advisory_xact_lock(hashtextextended('vetapp_memorial_limit:' || new.owner_id, 0));
    select c.max_memorial_pets into cap from public.plan_access_config c where c.id = 1;
    cap := coalesce(cap, 30);
    -- Solo gli animali di chi scrive, escluso questo.
    select count(*) into current_count
    from public.pet_profiles p
    where p.owner_id = new.owner_id and p.is_memorial and p.id <> new.id;
    if current_count >= cap then
        raise exception using
            errcode = 'PT403',
            message = 'plan_limit_reached',
            detail = 'memorials',
            hint = cap::text;
    end if;
    return new;
end;
$$;

revoke all on function public.plan_access_gate() from public, anon, authenticated;
revoke all on function public.plan_access_move_gate() from public, anon, authenticated;
revoke all on function public.plan_access_pet_limit() from public, anon, authenticated;
revoke all on function public.plan_access_memorial_limit() from public, anon, authenticated;

drop trigger if exists plan_access_10_gate on public.pet_profiles;
create trigger plan_access_10_gate
before insert or update on public.pet_profiles
for each row execute function public.plan_access_move_gate();

drop policy if exists plan_access_insert on public.pet_profiles;
create policy plan_access_insert
on public.pet_profiles
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.pet_profiles;
create policy plan_access_update
on public.pet_profiles
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write() or is_memorial);

drop trigger if exists plan_access_10_gate on public.clinical_events;
create trigger plan_access_10_gate
before insert or update on public.clinical_events
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.clinical_events;
create policy plan_access_insert
on public.clinical_events
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.clinical_events;
create policy plan_access_update
on public.clinical_events
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

drop trigger if exists plan_access_10_gate on public.pet_conditions;
create trigger plan_access_10_gate
before insert or update on public.pet_conditions
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.pet_conditions;
create policy plan_access_insert
on public.pet_conditions
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.pet_conditions;
create policy plan_access_update
on public.pet_conditions
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

drop trigger if exists plan_access_10_gate on public.reminders;
create trigger plan_access_10_gate
before insert or update on public.reminders
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.reminders;
create policy plan_access_insert
on public.reminders
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.reminders;
create policy plan_access_update
on public.reminders
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

drop trigger if exists plan_access_10_gate on public.dog_walks;
create trigger plan_access_10_gate
before insert or update on public.dog_walks
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.dog_walks;
create policy plan_access_insert
on public.dog_walks
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.dog_walks;
create policy plan_access_update
on public.dog_walks
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

drop trigger if exists plan_access_10_gate on public.pet_weight_measurements;
create trigger plan_access_10_gate
before insert or update on public.pet_weight_measurements
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.pet_weight_measurements;
create policy plan_access_insert
on public.pet_weight_measurements
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.pet_weight_measurements;
create policy plan_access_update
on public.pet_weight_measurements
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

drop trigger if exists plan_access_10_gate on public.pet_photos;
create trigger plan_access_10_gate
before insert or update on public.pet_photos
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.pet_photos;
create policy plan_access_insert
on public.pet_photos
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.pet_photos;
create policy plan_access_update
on public.pet_photos
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

drop trigger if exists plan_access_10_gate on public.local_activities;
create trigger plan_access_10_gate
before insert or update on public.local_activities
for each row execute function public.plan_access_gate();

drop policy if exists plan_access_insert on public.local_activities;
create policy plan_access_insert
on public.local_activities
as restrictive
for insert
to authenticated
with check (public.caller_can_write());

drop policy if exists plan_access_update on public.local_activities;
create policy plan_access_update
on public.local_activities
as restrictive
for update
to authenticated
using (true)
with check (public.caller_can_write());

-- Il limite di animali, dopo il controllo del piano (i trigger scattano in
-- ordine alfabetico: 10 prima di 20). Alla creazione e al ritorno dai Ricordi.
drop trigger if exists plan_access_20_pet_limit on public.pet_profiles;
create trigger plan_access_20_pet_limit
before insert or update on public.pet_profiles
for each row execute function public.plan_access_pet_limit();

-- Il tetto ai Ricordi, per ultimo dei controlli del piano: i trigger partono in
-- ordine alfabetico (plan_access_10, poi _20, poi _30); i controlli dei Ricordi,
-- ricordi_10_*, partono dopo perche' 'p' viene prima di 'r'.
drop trigger if exists plan_access_30_memorial_limit on public.pet_profiles;
create trigger plan_access_30_memorial_limit
before insert or update on public.pet_profiles
for each row execute function public.plan_access_memorial_limit();

-- Foto, video e foto profilo: caricare o sostituire un file richiede il piano,
-- toglierlo no. Gli altri bucket non sono toccati.
drop policy if exists plan_access_pet_photos_insert on storage.objects;
create policy plan_access_pet_photos_insert
on storage.objects
as restrictive
for insert
to authenticated
with check (bucket_id <> 'pet-photos' or public.caller_can_write());

drop policy if exists plan_access_pet_photos_update on storage.objects;
create policy plan_access_pet_photos_update
on storage.objects
as restrictive
for update
to authenticated
using (true)
with check (bucket_id <> 'pet-photos' or public.caller_can_write());

commit;

-- ---------------------------------------------------------------------------
-- Verifiche (solo lettura, da lanciare dopo)
-- ---------------------------------------------------------------------------
-- a) il periodo di test e' attivo (atteso durante il test: 'pro')
--   select test_plan from public.plan_access_config where id = 1;
-- b) ogni tabella ha il suo controllo (attese 8 righe piu' quelle
--    dei due limiti, animali e Ricordi)
--   select event_object_table, trigger_name from information_schema.triggers
--   where trigger_name like 'plan_access_%' order by 1, 2;
-- c) le policy restrittive ci sono
--   select tablename, policyname from pg_policies
--   where policyname like 'plan_access_%' order by 1, 2;

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

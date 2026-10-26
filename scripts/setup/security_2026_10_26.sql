-- VetApp: hardening di sicurezza del progetto Supabase (audit 2026-10-26).
--
-- Da eseguire nel SQL Editor del progetto canonico (ywbuzgwbkrmkukkpysbz)
-- DOPO scripts/setup/supabase_schema.sql (che crea le tabelle e le policy).
-- Idempotente: si può rilanciare quante volte si vuole.
--
-- Cosa fa, in parole semplici:
--  1. Toglie al ruolo "anon" (chi NON ha fatto login: la chiave publishable è
--     nell'app, quindi chiunque) ogni privilegio sulle tabelle con dati
--     personali. Le policy RLS già restituiscono zero righe, ma senza
--     privilegio la tabella non è nemmeno interrogabile: difesa in profondità
--     contro una policy futura scritta male (es. "using (true)").
--  2. Toglie anche al ruolo "authenticated" (utente loggato) i privilegi sulle
--     tabelle che devono essere lette e scritte SOLO dal backend con la chiave
--     service_role (ledger, cache, segnalazioni, radar, scheduler).
--  3. Imposta i privilegi di default cosi' che le tabelle e le funzioni create
--     in futuro NON siano esposte ad "anon": chi aggiunge una tabella pubblica
--     deve concedere il grant esplicitamente (vedi fondo).
--  4. Chiude i bucket privati e limita dimensione e tipi di file ammessi.
--
-- Tabelle pubbliche per scelta (restano leggibili senza login):
--   events (eventi pubblicati), local_activities (luoghi pubblici),
--   billing_plans (catalogo piani, ramo roberto), marketplace_listings
--   (annunci: la policy di lettura e' in revisione dalla sessione UI/UX;
--   qui si lascia il grant SELECT ad anon per non interferire).

begin;

-- ---------------------------------------------------------------------------
-- 1. anon: nessun privilegio sulle tabelle con dati personali
-- ---------------------------------------------------------------------------
do $$
declare
    t record;
begin
    for t in
        select tablename
        from pg_tables
        where schemaname = 'public'
          and tablename not in ('events', 'local_activities', 'billing_plans', 'marketplace_listings')
    loop
        execute format('revoke all on table public.%I from anon', t.tablename);
    end loop;
end;
$$;

-- Le tabelle pubbliche: solo lettura per chi non ha fatto login.
do $$
declare
    t text;
begin
    foreach t in array array['events', 'local_activities', 'billing_plans', 'marketplace_listings']
    loop
        if exists (select 1 from pg_tables where schemaname = 'public' and tablename = t) then
            execute format('revoke insert, update, delete, truncate, references, trigger on table public.%I from anon', t);
            execute format('grant select on table public.%I to anon', t);
        end if;
    end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. authenticated: fuori dalle tabelle "solo backend"
--    (RLS attiva senza policy = gia' deny; qui si toglie anche il privilegio)
-- ---------------------------------------------------------------------------
do $$
declare
    t text;
begin
    foreach t in array array[
        'chat_response_reports', 'chat_response_report_counters',
        'radar_coverage_cells', 'radar_places_cache', 'data_sources',
        'radar_places_osm', 'radar_places_open', 'radar_place_overrides',
        'radar_country_coverage', 'radar_user_reports', 'radar_report_votes',
        'radar_place_ratings', 'admin_ingestion_schedules',
        'llm_usage', 'llm_usage_daily', 'chat_user_daily_usage',
        'chat_answer_cache', 'pet_news_snapshots', 'event_submissions',
        'billing_founder_slots', 'billing_webhook_events'
    ]
    loop
        if exists (select 1 from pg_tables where schemaname = 'public' and tablename = t) then
            execute format('revoke all on table public.%I from anon, authenticated', t);
            execute format('grant all on table public.%I to service_role', t);
        end if;
    end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Privilegi di default per gli oggetti creati in futuro dal ruolo postgres
--    (quello del SQL Editor): niente per anon; le funzioni non sono
--    chiamabili via RPC da anon ne' da authenticated finche' non si concede
--    esplicitamente. Chi crea una tabella o una funzione pubblica aggiunge:
--      grant select on table public.<t> to anon;
--      grant execute on function public.<f>(...) to authenticated;
-- ---------------------------------------------------------------------------
alter default privileges for role postgres in schema public
    revoke all on tables from anon;
alter default privileges for role postgres in schema public
    revoke all on sequences from anon;
alter default privileges for role postgres in schema public
    revoke execute on functions from anon, authenticated;

-- Funzioni esistenti nello schema public: nessuna e' pensata per essere
-- chiamata da anon. (Quelle del backend sono gia' limitate a service_role
-- in supabase_schema.sql; questo copre eventuali funzioni create a mano.)
do $$
declare
    f record;
begin
    for f in
        select p.oid::regprocedure as signature
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
    loop
        execute format('revoke execute on function %s from anon', f.signature);
    end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Storage: bucket privati chiusi, limiti di dimensione e tipi
-- ---------------------------------------------------------------------------
update storage.buckets
set public = false,
    -- il backend accetta al massimo 4 MB (upload_chat_attachment.py); il
    -- bucket blocca cio' che dovesse aggirare quel controllo
    file_size_limit = 5000000,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
where id = 'chat-attachments';

update storage.buckets
set public = false
where id = 'pet-photos';

-- marketplace-photos resta pubblico per scelta (foto degli annunci), gia'
-- limitato a 5 MB e image/jpeg in supabase_schema.sql.

commit;

-- ---------------------------------------------------------------------------
-- Verifiche (solo lettura, da lanciare dopo): devono restituire 0 righe
-- ---------------------------------------------------------------------------
-- a) tabelle con dati personali ancora accessibili ad anon
--   select table_name, privilege_type
--   from information_schema.role_table_grants
--   where grantee = 'anon' and table_schema = 'public'
--     and table_name not in ('events','local_activities','billing_plans','marketplace_listings');
--
-- b) tabelle public senza RLS
--   select tablename from pg_tables
--   where schemaname = 'public' and rowsecurity = false;
--
-- c) funzioni SECURITY DEFINER senza search_path fissato (rischio di
--    dirottamento tramite oggetti con lo stesso nome in altri schemi)
--   select p.oid::regprocedure
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname in ('public','ai') and p.prosecdef
--     and (p.proconfig is null or not exists (
--         select 1 from unnest(p.proconfig) c where c like 'search_path=%'));
--
-- d) bucket pubblici (atteso: solo marketplace-photos)
--   select id, public, file_size_limit, allowed_mime_types from storage.buckets;
--
-- Impostazioni che NON sono SQL (dashboard Supabase, azioni del proprietario):
--  - Authentication -> Providers -> Email -> "Confirm email" = ON
--    (oggi e' OFF: chiunque si registra con un indirizzo altrui senza
--    dimostrare di possederlo; vedi docs/security/02_audit.md, DB-2).
--  - Authentication -> Settings -> "Leaked password protection" = ON
--    (piano Pro) e lunghezza minima password >= 8.
--  - Authentication -> Rate limits: lasciare i default o abbassarli.
--  - Organization -> Members: 2FA obbligatoria per tutti gli account.
--  - Settings -> API: rigenerare la chiave service_role se e' mai stata
--    condivisa fuori da Vercel/GitHub secrets (rotazione periodica).

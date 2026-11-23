-- Righe di account che non esistono più (docs/security/13_righe_orfane.md, 2026-11-23).
-- Lo lancia SOLO il proprietario, a mano, dopo la copia manuale (docs/security/12), in tre passi:
--   1) PARTE 1 da sola (sola lettura): dice quanti account e quante righe.
--   2) scrivere nella PARTE 2 il numero di account letto (attesi) e lanciarla da sola.
--   3) di nuovo la PARTE 1: deve dare zero righe.
--
-- Che cosa cancella: le righe il cui proprietario è un id in formato UUID che non è tra gli
-- account. Non tocca mai: gli account esistenti (anche in pausa o in attesa di eliminazione),
-- i proprietari di prova non UUID («demo-user», «shared»), il registro delle cancellazioni, le
-- conversazioni del Mercatino tenute per una segnalazione (hanno un segnaposto al posto dell'id),
-- le righe radar_* del vecchio portale (prima si chiede a chi le ha create), i file nei
-- contenitori: da SQL resterebbero nell'archivio. Il contenitore «clinical-documents» del vecchio
-- sistema si conta qui sotto e si svuota dalla dashboard (Storage), dopo la PARTE 2. Gli acquisti del vecchio sistema si cancellano: letti il 2026-11-23, sono solo
-- righe dimostrative («demo_seed», «mock_»).
-- L'elenco delle tabelle è quello della cancellazione (un test controlla che sia lo stesso).

-- ============================== PARTE 1 · SOLA LETTURA ==============================
-- La funzione è temporanea: vive solo in questa sessione e legge soltanto.
create or replace function pg_temp.orfani_di(tabella text) returns setof text
language plpgsql stable as $$
begin
    if to_regclass('public.' || tabella) is not null then
        return query execute format(
            'select lower(owner_id::text) from public.%I x
              where owner_id::text ~* ''^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$''
                and not exists (select 1 from auth.users u where u.id::text = lower(x.owner_id::text))',
            tabella);
    end if;
end;
$$;
create or replace function pg_temp.file_vecchi() returns integer
language plpgsql stable as $$
declare
    n integer := 0;
begin
    if to_regclass('storage.objects') is not null then
        execute 'select count(*) from storage.objects where bucket_id = ''clinical-documents'''
           into n;
    end if;
    return n;
end;
$$;
with elenco(tabella) as (
    select unnest(array[
        -- ELENCO-INIZIO
        'user_login_events', 'admin_user_actions', 'admin_plan_changes',
        'marketplace_user_restrictions', 'marketplace_listing_reviews', 'marketplace_listings',
        'chat_message_keys', 'chat_attachments', 'pet_photos', 'pet_weight_measurements',
        'pet_conditions', 'dog_walks', 'reminders', 'conversations', 'pet_profiles',
        'account_age', 'account_consents', 'account_pauses', 'subscriptions',
        'store_subscriptions', 'store_events', 'store_account_tokens', 'user_devices',
        'user_locations', 'chat_user_daily_usage', 'adoption_contact_requests',
        'adoption_listings', 'billing_founder_slots', 'billing_one_time_purchases',
        'billing_subscriptions', 'billing_customers', 'owner_billing_entitlements',
        'owner_profiles', 'clinical_documents', 'local_service_reviews',
        'local_service_events', 'local_service_venues'
        -- ELENCO-FINE
    ])
), righe as (
    select e.tabella, o.owner_id from elenco e, lateral pg_temp.orfani_di(e.tabella) as o(owner_id)
)
select 'TOTALE ACCOUNT (da scrivere in «attesi»)' as tabella, count(*)::int as righe,
       count(distinct owner_id)::int as account
  from righe
union all
select 'FILE in clinical-documents (dalla dashboard, Storage)', pg_temp.file_vecchi(), 0
union all
select * from (select tabella, count(*)::int, count(distinct owner_id)::int
                 from righe group by tabella order by tabella) t;

-- ============================== PARTE 2 · CANCELLAZIONE ==============================
do $pulizia$
declare
    attesi constant integer := -1;  -- <<< il numero della PARTE 1; con -1 non parte
    uuid_re constant text := '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$';
    tabelle constant text[] := array[
        -- ELENCO-INIZIO
        'user_login_events', 'admin_user_actions', 'admin_plan_changes',
        'marketplace_user_restrictions', 'marketplace_listing_reviews', 'marketplace_listings',
        'chat_message_keys', 'chat_attachments', 'pet_photos', 'pet_weight_measurements',
        'pet_conditions', 'dog_walks', 'reminders', 'conversations', 'pet_profiles',
        'account_age', 'account_consents', 'account_pauses', 'subscriptions',
        'store_subscriptions', 'store_events', 'store_account_tokens', 'user_devices',
        'user_locations', 'chat_user_daily_usage', 'adoption_contact_requests',
        'adoption_listings', 'billing_founder_slots', 'billing_one_time_purchases',
        'billing_subscriptions', 'billing_customers', 'owner_billing_entitlements',
        'owner_profiles', 'clinical_documents', 'local_service_reviews',
        'local_service_events', 'local_service_venues'
        -- ELENCO-FINE
    ];
    orfani text[] := '{}';
    trovati text[];
    tabella text;
begin
    if (select count(*) from auth.users) = 0 then
        raise exception 'FERMO: nessun account, il database non è quello giusto o non è completo';
    end if;
    foreach tabella in array tabelle loop
        continue when to_regclass('public.' || tabella) is null;
        execute format(
            'select coalesce(array_agg(distinct lower(owner_id::text)), ''{}'') from public.%I x
              where owner_id::text ~* $1 and not exists
                    (select 1 from auth.users u where u.id::text = lower(x.owner_id::text))',
            tabella) into trovati using uuid_re;
        orfani := array(select distinct unnest(orfani || trovati));
    end loop;
    if coalesce(array_length(orfani, 1), 0) is distinct from attesi then
        raise exception 'FERMO: account trovati %, attesi %. Nulla è stato cancellato',
            coalesce(array_length(orfani, 1), 0), attesi;
    end if;

    -- Gli eventi clinici seguono l'animale; si tolgono prima, come fa la cancellazione.
    delete from public.clinical_events e
     using public.pet_profiles p
     where p.id = e.pet_id and lower(p.owner_id::text) = any (orfani);
    foreach tabella in array tabelle loop
        continue when to_regclass('public.' || tabella) is null;
        execute format('delete from public.%I where lower(owner_id::text) = any($1)', tabella)
          using orfani;
    end loop;
end;
$pulizia$;

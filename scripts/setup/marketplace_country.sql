-- Notizie, eventi e Mercatino per territorio (2026-10-14, sessione "Notizie,
-- eventi e Mercatino per territorio"). Idempotente: si puo' eseguire piu' volte.
-- Lo stesso blocco e' in fondo a supabase_schema.sql, cosi' un setup nuovo lo
-- ha gia'; ESEGUI QUESTO FILE UNA VOLTA sul database esistente, PRIMA di
-- pubblicare la versione dell'app/backend che legge la colonna.
--
-- 1. events.country: paese in cui si svolge l'evento (ISO 3166-1 alpha-2).
--    L'app mostra solo gli eventi del paese dell'utente. Le righe esistenti
--    sono italiane (valore predefinito 'IT').
-- 2. marketplace_listings.country: paese del venditore. Prezzi nella valuta
--    del paese; l'app e il backend mostrano solo annunci dello stesso paese
--    dell'utente. Le righe esistenti sono italiane.

alter table public.events
    add column if not exists country text not null default 'IT';

create index if not exists events_country_idx
    on public.events (country, starts_on) where status in ('published', 'cancelled', 'postponed');

alter table public.marketplace_listings
    add column if not exists country text not null default 'IT';

create index if not exists idx_marketplace_listings_country
    on public.marketplace_listings (country) where status = 'active';

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'marketplace_listings_country_check'
          and conrelid = 'public.marketplace_listings'::regclass
    ) then
        alter table public.marketplace_listings
            add constraint marketplace_listings_country_check
            check (country ~ '^[A-Z]{2}$');
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'events_country_check'
          and conrelid = 'public.events'::regclass
    ) then
        alter table public.events
            add constraint events_country_check
            check (country ~ '^[A-Z]{2}$');
    end if;
end;
$$;

-- DECISIONE DEL PROPRIETARIO (NON applicata qui): oggi chiunque abbia la anon
-- key puo' leggere TUTTA la tabella marketplace_listings con una query diretta
-- (policy marketplace_listings_select_all, using (true)), cioe' aggirare il
-- raggio massimo e il filtro per paese che il backend (GET /marketplace/listings)
-- e l'app applicano. Per rendere la regola davvero vincolante lato database,
-- dopo aver pubblicato app e backend nuovi, si puo' sostituire la policy con
-- una che lascia leggere direttamente solo i propri annunci:
--
--   drop policy if exists marketplace_listings_select_all on public.marketplace_listings;
--   create policy marketplace_listings_select_own
--   on public.marketplace_listings
--   for select
--   using (owner_id = auth.uid()::text);
--
-- La lettura "vicino a me" passerebbe solo dal backend (service role). Prima di
-- farlo vanno verificati il dettaglio annuncio, la mappa e il portale admin.

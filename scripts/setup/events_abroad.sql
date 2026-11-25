-- EVENTI: PAESE DELLE SEGNALAZIONI E COORDINATE (collaudo, scheda F42, 2026-11-25).
-- Idempotente. Da eseguire al rilascio (in produzione lo lancia il proprietario).
--
-- 1. event_submissions.country: il paese in cui si svolge l'evento segnalato (ISO 3166-1
--    alpha-2). Le righe esistenti sono italiane (valore predefinito 'IT'). Senza questa colonna
--    le segnalazioni italiane si salvano come prima; quelle di un altro paese danno errore.
-- 2. events.latitude / events.longitude: dove si svolge l'evento, facoltative, scritte solo dagli
--    script di curatela. Servono a una cosa sola: mostrare un evento di un altro paese a chi ha
--    la Localita' entro 30 km (packages/core/domain/events/abroad.py). Senza colonne o senza
--    valori quegli eventi non si vedono; il resto funziona come prima. Sono il luogo pubblico
--    di una manifestazione, non un dato di una persona.
--
-- Nessuna tabella nuova: RLS e policy restano quelle di oggi (event_submissions: RLS attiva e
-- nessuna policy, solo backend; events: supabase_schema.sql ed events_read_via_backend.sql).
-- La cancellazione dell'account toglie gia' le righe di event_submissions intere.

alter table public.event_submissions
    add column if not exists country text not null default 'IT';

alter table public.events
    add column if not exists latitude double precision;
alter table public.events
    add column if not exists longitude double precision;

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'event_submissions_country_check'
          and conrelid = 'public.event_submissions'::regclass
    ) then
        alter table public.event_submissions
            add constraint event_submissions_country_check
            check (country ~ '^[A-Z]{2}$');
    end if;
    if not exists (
        select 1 from pg_constraint
        where conname = 'events_coordinates_check'
          and conrelid = 'public.events'::regclass
    ) then
        alter table public.events
            add constraint events_coordinates_check
            -- Both or none, said first: a check whose value is null passes.
            check (
                (latitude is null) = (longitude is null)
                and (
                    latitude is null
                    or (latitude between -90 and 90 and longitude between -180 and 180)
                )
            );
    end if;
end;
$$;

-- Per annullare:
--   alter table public.event_submissions drop column if exists country;
--   alter table public.events drop constraint if exists events_coordinates_check;
--   alter table public.events drop column if exists latitude, drop column if exists longitude;

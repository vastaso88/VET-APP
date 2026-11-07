-- "Esperti in esotici" (Vicino a me), 2026-11-07: segnalazioni "questa
-- struttura cura animali esotici" fatte con Segnala!. Idempotente. Lo stesso
-- blocco sta in supabase_schema.sql (un test controlla che restino allineati).
--
-- Una segnalazione resta in attesa e invisibile finché il team non ha letto
-- la pagina pubblica della struttura e l'ha confermata a mano con quella
-- pagina come prova (scripts/radar/confirm_competence_claim.py). Chi segnala
-- è indicato solo con uno pseudonimo che calcola il backend; la riga si
-- cancella con l'account (supabase_account_eraser, RADAR_PSEUDONYM_TABLES).
--
-- Si scrive e si legge SOLO dal backend (chiave service_role). RLS attiva
-- senza policy, come per le altre tabelle dei contributi radar: non c'è un
-- owner_id su cui scrivere una policy *_own, e a anon e authenticated è
-- tolto ogni privilegio.
--
-- Le competenze lette da OpenStreetMap (tag veterinary:treats:*) non hanno
-- bisogno di colonne nuove: stanno già nella colonna details di
-- radar_places_osm e radar_places_cache.

create table if not exists public.radar_competence_claims (
    id text primary key,
    target_source text not null check (char_length(target_source) <= 60),
    target_source_id text not null check (char_length(target_source_id) <= 120),
    place_name text not null check (char_length(place_name) <= 120),
    latitude double precision not null,
    longitude double precision not null,
    groups jsonb not null default '[]'::jsonb,
    evidence_kind text not null check (evidence_kind in ('website', 'sign', 'other')),
    status text not null default 'pending'
        check (status in ('pending', 'confirmed', 'rejected')),
    reporter_pseudonym text not null,
    created_at timestamptz not null default now(),
    resolved_at timestamptz,
    evidence_url text check (evidence_url is null or char_length(evidence_url) <= 500),
    resolution_note text check (resolution_note is null or char_length(resolution_note) <= 300)
);

create index if not exists radar_competence_claims_position_idx
    on public.radar_competence_claims (status, latitude, longitude);
create index if not exists radar_competence_claims_reporter_idx
    on public.radar_competence_claims (reporter_pseudonym, created_at);

alter table public.radar_competence_claims enable row level security;
revoke all on table public.radar_competence_claims from anon, authenticated;

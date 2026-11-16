-- Ricordi: animali che non ci sono piu' (2026-11-16, docs/product/17_ricordi_animali.md).
-- Idempotente: si puo' eseguire piu' volte. Le stesse righe sono in
-- supabase_schema.sql, cosi' un setup nuovo le ha gia'; ESEGUI QUESTO FILE UNA
-- VOLTA sul database esistente. L'app funziona anche prima (salva il resto e
-- non le scelte dei ricordi), ma le scelte non restano finche' non lo esegui.
--
-- Nessuna tabella nuova: tre scelte nel profilo dell'animale, tutte spente di
-- partenza. Valgono gia' le policy RLS "pet_profiles_*_own" della tabella e la
-- cancellazione dell'account (cancella la riga intera).
--   memorial_birthday_reminder: un pensiero nel giorno del compleanno
--   memorial_walks_reminder:    nel giorno di una passeggiata preferita
--   memorial_photos_reminder:   foto di questo giorno negli anni passati
-- La data della perdita usa la colonna gia' esistente memorial_date_label.

alter table public.pet_profiles
    add column if not exists memorial_birthday_reminder boolean not null default false;
alter table public.pet_profiles
    add column if not exists memorial_walks_reminder boolean not null default false;
alter table public.pet_profiles
    add column if not exists memorial_photos_reminder boolean not null default false;

-- Lo schema in cache di PostgREST deve vedere subito le colonne nuove.
notify pgrst, 'reload schema';

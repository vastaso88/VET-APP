-- Ai ruoli dell'app (anon, authenticated) non servono TRUNCATE, TRIGGER e REFERENCES: li hanno
-- per i privilegi predefiniti di Supabase (lettura del 2026-11-23). TRUNCATE non passa dalle
-- regole RLS; oggi nessuna strada dell'app lo raggiunge (PostgREST non lo espone), quindi è
-- difesa in profondità, non la chiusura di un buco. Lettura e scrittura restano come sono.
-- Nessuna riga e nessuna tabella cambiano. Idempotente. Lo lancia il proprietario.
begin;
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
alter default privileges in schema public
    revoke truncate, trigger, references on tables from anon, authenticated;
commit;

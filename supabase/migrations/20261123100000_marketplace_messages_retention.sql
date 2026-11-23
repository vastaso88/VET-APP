-- Mercatino: la pulizia dei messaggi segue i testi (Informativa it/02, Termini it/03 §8,
-- Regole doc 24). Decisioni del proprietario del 2026-11-23, riferite dall'Orchestratore:
-- «come promettono i testi», poi B (6 mesi dopo una segnalazione decisa, anche con un account
-- eliminato; un annuncio tolto dal team non è chiuso finché non viene cancellato, e allora le
-- conversazioni mai segnalate vanno con lui) e C (blocchi scaduti).
-- NON lanciare in produzione prima che i testi pubblicati dicano B e C.
--
-- Cambia marketplace_messages_cleanup() e aggiunge un automatismo alla cancellazione di un
-- annuncio: nessuna tabella, nessun dato, e il lavoro notturno (che chiama la prima per nome)
-- resta quello. Idempotente: si può rilanciare.
-- Stesso testo in scripts/setup/marketplace_messages.sql e supabase_schema.sql
-- (tests/unit/test_marketplace_messages_sql.py controlla che restino uguali).
--
-- Prima del Run in produzione: copia manuale (docs/security/12_copie_dati_e_backup.md)
-- e conteggio in sola lettura di ciò che verrebbe cancellato. Serve la colonna
-- marketplace_user_restrictions.expires_at (migrazione 20261121165154).

-- Conservazione. Decisioni del proprietario, riferite dall'Orchestratore: 2026-11-07,
-- confermata il 2026-11-23 («come promettono i testi»); 2026-11-23 sera, B e C.
-- * La conversazione si cancella 6 mesi dopo l'ultimo messaggio se l'annuncio è chiuso
--   (venduto o cancellato), 12 mesi dopo l'ultimo messaggio comunque.
-- * Mai finché ha una segnalazione aperta, né nei 6 mesi dopo che una segnalazione è
--   stata decisa (accolta o respinta): serve a un riesame, anche oltre i 6 e i 12 mesi.
-- * Un annuncio tolto (dal team, o in attesa del team per le segnalazioni) si può
--   ripristinare: non conta come chiuso finché non viene cancellato. I 12 mesi valgono
--   anche per lui.
-- * La chiusura della conversazione da parte del team NON conta: i testi parlano solo
--   dell'annuncio. (Dall'8 novembre 2026 fino a questa versione i 6 mesi si contavano
--   anche dalla chiusura: non corrispondeva ai testi.)
-- * Le conversazioni mai segnalate di un annuncio che il team ha tolto si cancellano
--   insieme all'annuncio (dal sistema dopo 6 mesi, o prima se lo cancella chi vende): lo fa
--   un automatismo sull'annuncio, qui sotto.
-- * Con un account eliminato resta solo una conversazione con una segnalazione aperta o
--   accolta: fino a 6 mesi dopo la decisione; respinta, si cancella subito.
-- Messaggi e segnalazioni seguono la conversazione (on delete cascade). I blocchi tra
-- utenti restano finché esiste l'account; un blocco del team si cancella 12 mesi dopo
-- che è finito (annullato o scaduto), uno in vigore resta.
create or replace function public.marketplace_messages_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    -- Mesi in cui una conversazione con una segnalazione DECISA resta dopo la decisione:
    -- accolta o respinta con i due account, solo accolta se un account è stato eliminato.
    -- Anche oltre i 6 e i 12 mesi. Lo dicono anche i testi: si cambia solo insieme a loro.
    review_months constant integer := 6;
    conversation_rows integer;
    restriction_rows integer;
begin
    delete from public.marketplace_conversations c
    where c.erased_participant_at is null
      and not exists (
            select 1 from public.marketplace_conversation_reports r
            where r.conversation_id = c.id
              and (r.status = 'open'
                   or r.resolved_at > now() - make_interval(months => review_months))
        )
        and (
            c.last_message_at < now() - interval '12 months'
            or (
                c.last_message_at < now() - interval '6 months'
                and (
                    c.listing_id is null
                    or exists (
                        select 1 from public.marketplace_listings l
                        where l.id = c.listing_id
                          and l.status = 'sold'
                    )
                )
            )
        );
    get diagnostics conversation_rows = row_count;
    -- Tenute dopo una cancellazione: via appena la segnalazione è respinta, o
    -- review_months dopo la decisione; mai finché è aperta.
    delete from public.marketplace_conversations c
    where c.erased_participant_at is not null
      and not exists (
            select 1 from public.marketplace_conversation_reports r
            where r.conversation_id = c.id
              and (r.status = 'open'
                   or (r.status = 'resolved'
                       and r.resolved_at > now() - make_interval(months => review_months)))
        );
    delete from public.marketplace_moderation_access_log
    where accessed_at < now() - interval '24 months';
    -- La prima delle due date; least() ignora quella che manca. Senza nessuna delle due
    -- il blocco è in vigore, e una scadenza futura non è ancora passata.
    delete from public.marketplace_user_restrictions
    where least(lifted_at, expires_at) < now() - interval '12 months';
    get diagnostics restriction_rows = row_count;
    return jsonb_build_object(
        'marketplace_conversations', conversation_rows,
        'marketplace_user_restrictions', restriction_rows
    );
end;
$$;
revoke all on function public.marketplace_messages_cleanup()
    from public, anon, authenticated;
grant execute on function public.marketplace_messages_cleanup()
    to service_role;

-- Quando si cancella un annuncio che il team ha tolto ('removed_policy'), le sue conversazioni
-- mai segnalate vanno con lui. Quelle segnalate restano e seguono i tempi qui sopra. Un annuncio
-- venduto, attivo o nascosto in automatico ('removed') non è «tolto dal team»: tempi normali.
create or replace function public.marketplace_drop_conversations_of_removed_ad()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if old.status = 'removed_policy' then
        delete from public.marketplace_conversations c
        where c.listing_id = old.id
          and c.erased_participant_at is null
          and not exists (
                select 1 from public.marketplace_conversation_reports r
                where r.conversation_id = c.id
            );
    end if;
    return old;
end;
$$;
revoke all on function public.marketplace_drop_conversations_of_removed_ad()
    from public, anon, authenticated;
drop trigger if exists marketplace_listing_10_drop_conversations on public.marketplace_listings;
create trigger marketplace_listing_10_drop_conversations
before delete on public.marketplace_listings
for each row execute function public.marketplace_drop_conversations_of_removed_ad();

-- Contatori giornalieri per utente: risposte di Sonnet e messaggi che
-- continuano un argomento.
--
-- Il piano "fratello maggiore" (decisione del proprietario, 10 novembre 2026)
-- ha bisogno di due contatori nuovi, sul giorno dell'utente come le domande:
--   sonnet   = risposte scritte da Claude Sonnet (tetto per piano: 1, 2, 3);
--   followup = messaggi che continuano un argomento (la risposta a una
--              domanda di chiarimento della chat), che non sono domande del
--              piano ma hanno un loro tetto (3 volte le domande del piano).
-- La funzione chat_user_daily_usage_add_kind accetta solo i tipi che
-- conosce: questo script aggiunge i due tipi. Idempotente. Non cambia le
-- colonne ne' i conteggi che ci sono gia'.
--
-- QUANDO: prima di accendere Sonnet nella chat. Senza questo script il
-- backend funziona: il tetto di Sonnet FALLISCE CHIUSO (risponde Haiku) e i
-- messaggi di continuazione non vengono contati (nessun errore per l'utente).

alter table public.chat_user_daily_usage
    add column if not exists sonnet integer not null default 0;
alter table public.chat_user_daily_usage
    add column if not exists followup integer not null default 0;

create or replace function public.chat_user_daily_usage_add_kind(
    p_owner_id text, p_day date, p_kind text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    total integer;
begin
    if p_kind not in ('messages', 'vision', 'dictation', 'summary', 'sonnet', 'followup') then
        raise exception 'unknown usage kind: %', p_kind;
    end if;
    insert into public.chat_user_daily_usage (
        owner_id, day, messages, vision, dictation, summary, sonnet, followup
    )
    values (
        p_owner_id, p_day,
        (p_kind = 'messages')::integer, (p_kind = 'vision')::integer,
        (p_kind = 'dictation')::integer, (p_kind = 'summary')::integer,
        (p_kind = 'sonnet')::integer, (p_kind = 'followup')::integer
    )
    on conflict (owner_id, day) do update set
        messages = public.chat_user_daily_usage.messages + (p_kind = 'messages')::integer,
        vision = public.chat_user_daily_usage.vision + (p_kind = 'vision')::integer,
        dictation = public.chat_user_daily_usage.dictation + (p_kind = 'dictation')::integer,
        summary = public.chat_user_daily_usage.summary + (p_kind = 'summary')::integer,
        sonnet = public.chat_user_daily_usage.sonnet + (p_kind = 'sonnet')::integer,
        followup = public.chat_user_daily_usage.followup + (p_kind = 'followup')::integer
    returning case p_kind
        when 'messages' then messages
        when 'vision' then vision
        when 'dictation' then dictation
        when 'sonnet' then sonnet
        when 'followup' then followup
        else summary
    end into total;
    return total;
end;
$$;

-- Come prima: solo il backend, con la chiave service_role, muove i contatori.
-- (create or replace conserva i permessi; qui sono richiamati per sicurezza.)
revoke all on function public.chat_user_daily_usage_add_kind(text, date, text)
    from public, anon, authenticated;
grant execute on function public.chat_user_daily_usage_add_kind(text, date, text)
    to service_role;

-- Per annullare (rimette i quattro tipi di prima; le colonne restano, vuote):
--   rieseguire la definizione di chat_user_daily_usage_add_kind in
--   scripts/setup/supabase_schema.sql prima di questa modifica.

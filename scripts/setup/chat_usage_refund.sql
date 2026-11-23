-- Contatori giornalieri per utente: RESTITUZIONE (collaudo K13).
--
-- Regola: si conta solo cio' che l'utente ha ricevuto. Il backend prenota l'uso (domanda,
-- lettura foto, dettatura, riepilogo) prima di chiamare il fornitore; se poi il servizio
-- fallisce per colpa nostra (errore 500, fornitore fermo, tempo scaduto, risposta di
-- scuse al posto della risposta) l'uso viene restituito con questa funzione. Toglie 1 al
-- contatore del tipo indicato, mai sotto zero, e restituisce il nuovo totale.
--
-- Idempotente. Non cambia colonne ne' conteggi esistenti. La spesa dei modelli
-- (llm_usage) NON si tocca: i soldi spesi restano contati, si restituisce solo la quota
-- dell'utente.
--
-- QUANDO: prima di mettere online il backend che la usa. Senza questo script il backend
-- funziona come prima: la restituzione fallisce in silenzio (solo un messaggio nel log,
-- senza dati personali) e il contatore resta com'e'.

-- Le due colonne che chat_usage_sonnet_followups.sql aggiunge: qui per non dipendere
-- dall'ordine in cui si lanciano gli script (non cambiano nulla se ci sono gia').
alter table public.chat_user_daily_usage
    add column if not exists sonnet integer not null default 0;
alter table public.chat_user_daily_usage
    add column if not exists followup integer not null default 0;

create or replace function public.chat_user_daily_usage_remove_kind(
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
    update public.chat_user_daily_usage set
        messages = greatest(messages - (p_kind = 'messages')::integer, 0),
        vision = greatest(vision - (p_kind = 'vision')::integer, 0),
        dictation = greatest(dictation - (p_kind = 'dictation')::integer, 0),
        summary = greatest(summary - (p_kind = 'summary')::integer, 0),
        sonnet = greatest(sonnet - (p_kind = 'sonnet')::integer, 0),
        followup = greatest(followup - (p_kind = 'followup')::integer, 0)
    where owner_id = p_owner_id and day = p_day
    returning case p_kind
        when 'messages' then messages
        when 'vision' then vision
        when 'dictation' then dictation
        when 'sonnet' then sonnet
        when 'followup' then followup
        else summary
    end into total;
    return coalesce(total, 0);
end;
$$;

-- Solo il backend, con la chiave service_role, muove i contatori (come add_kind).
revoke all on function public.chat_user_daily_usage_remove_kind(text, date, text)
    from public, anon, authenticated;
grant execute on function public.chat_user_daily_usage_remove_kind(text, date, text)
    to service_role;

-- Per annullare:
--   drop function if exists public.chat_user_daily_usage_remove_kind(text, date, text);

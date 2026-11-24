-- Consensi dell'account: UNA decisione alla volta, senza toccare le altre (collaudo, T06).
--
-- Difetto: all'iscrizione l'app manda Termini, Privacy e avviso sulle urgenze insieme; il
-- backend leggeva la riga, aggiungeva la sua chiave e riscriveva tutto il JSON. L'ultima
-- scrittura cancellava le altre: restava un solo consenso su tre. Qui l'unione la fa il
-- database, in un solo comando: due richieste insieme si mettono in fila sulla riga.
--
-- Idempotente. Non cambia colonne, righe o consensi esistenti.
--
-- QUANDO: prima di mettere online il backend che la usa. Senza questo script il backend
-- funziona come prima (leggi, aggiungi, riscrivi), con il vecchio difetto.

create or replace function public.account_consent_record(
    p_owner_id text, p_key text, p_record jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    result jsonb;
begin
    if coalesce(p_owner_id, '') = '' or coalesce(p_key, '') = '' or length(p_key) > 64 then
        raise exception 'owner and consent key are required';
    end if;
    if jsonb_typeof(p_record) is distinct from 'object' then
        raise exception 'the consent record must be an object';
    end if;
    insert into public.account_consents as c (owner_id, consents)
    values (p_owner_id, jsonb_build_object(p_key, p_record))
    on conflict (owner_id) do update
        set consents = coalesce(c.consents, '{}'::jsonb) || excluded.consents
    returning c.consents into result;
    return result;
end;
$$;

-- Solo il backend, con la chiave service_role, scrive i consensi.
revoke all on function public.account_consent_record(text, text, jsonb)
    from public, anon, authenticated;
grant execute on function public.account_consent_record(text, text, jsonb) to service_role;

-- Per annullare:
--   drop function if exists public.account_consent_record(text, text, jsonb);

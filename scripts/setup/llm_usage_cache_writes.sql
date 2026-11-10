-- Registro dell'uso dei modelli: i token scritti nella cache dei prompt.
--
-- Il tetto giornaliero di spesa per l'IA e' in euro (packages/core/domain/
-- llm_usage/pricing.py): una scrittura in cache costa il 25% in piu' di un
-- token in entrata normale (Haiku 5.5: 0,125 $ contro 0,10 $ per milione).
-- Senza questa colonna il backend continua a funzionare e conta quei token
-- come entrata normale: un piccolo sottoconteggio della spesa (al massimo il
-- 25% del prezzo di entrata sui token scritti), niente di piu'.
--
-- QUANDO: prima di passare la chat a Claude (oggi la produzione usa ancora
-- Groq, che non ha scritture in cache). Idempotente. Aggiunge solo una
-- colonna e una funzione: non cambia nulla di quello che c'e' gia'.

alter table public.llm_usage_daily
    add column if not exists cache_write_tokens integer not null default 0;

-- Somma atomica, come llm_usage_add: istanze diverse non si perdono i token.
create or replace function public.llm_usage_add_cache_writes(
    p_day date,
    p_model text,
    p_tokens integer
)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.llm_usage_daily (day, model, cache_write_tokens)
    values (p_day, p_model, greatest(p_tokens, 0))
    on conflict (day, model) do update set
        cache_write_tokens =
            public.llm_usage_daily.cache_write_tokens + excluded.cache_write_tokens;
$$;

-- Come le altre funzioni del registro: solo il backend, con la chiave
-- service_role, puo' muovere i contatori condivisi.
revoke all on function public.llm_usage_add_cache_writes(date, text, integer)
    from public, anon, authenticated;
grant execute on function public.llm_usage_add_cache_writes(date, text, integer)
    to service_role;

-- Per annullare:
--   drop function if exists public.llm_usage_add_cache_writes(date, text, integer);
--   alter table public.llm_usage_daily drop column if exists cache_write_tokens;

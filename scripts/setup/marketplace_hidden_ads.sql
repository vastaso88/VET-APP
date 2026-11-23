-- Mercatino: annunci nascosti o tolti dopo le segnalazioni (2026-11-23; docs/compliance/24,
-- punto 6: «Ti diciamo il motivo e la data»). Idempotente; va dopo
-- marketplace_content_review.sql. Lo stesso blocco sta in supabase_schema.sql (un test
-- controlla che i due restino allineati).

-- Una rimozione decisa dalla coda delle segnalazioni si registra come quella dalla coda
-- dei controlli, con i motivi di una segnalazione.
alter table public.marketplace_listing_reviews
    add column if not exists origin text not null default 'confirmation';
alter table public.marketplace_listing_reviews
    drop constraint if exists marketplace_listing_reviews_origin_check;
alter table public.marketplace_listing_reviews
    add constraint marketplace_listing_reviews_origin_check
    check (origin in ('confirmation', 'report'));

alter table public.marketplace_listing_reviews
    drop constraint if exists marketplace_listing_reviews_removal_reason_check;
alter table public.marketplace_listing_reviews
    add constraint marketplace_listing_reviews_removal_reason_check
    check (removal_reason is null
           or removal_reason in ('food', 'supplement', 'medicine', 'spam', 'scam',
                                 'prohibited_item', 'inappropriate', 'sells_animals', 'other'));

alter table public.marketplace_listing_decision_log
    drop constraint if exists marketplace_listing_decision_log_reason_check;
alter table public.marketplace_listing_decision_log
    add constraint marketplace_listing_decision_log_reason_check
    check (reason is null
           or reason in ('food', 'supplement', 'medicine', 'spam', 'scam',
                         'prohibited_item', 'inappropriate', 'sells_animals', 'other'));

-- Tre segnalazioni aperte di persone diverse nascondono un annuncio VISIBILE. Un annuncio
-- gia' tolto dal team ('removed_policy') non cambia stato: perderebbe motivo e scadenza.
create or replace function public.handle_marketplace_listing_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    distinct_reporters integer;
begin
    select count(distinct reporter_owner_id)
    into distinct_reporters
    from public.marketplace_listing_reports
    where listing_id = new.listing_id
      and status = 'open';

    update public.marketplace_listings
    set report_count = distinct_reporters,
        status = case
            when distinct_reporters >= 3 and status in ('active', 'reserved') then 'removed'
            else status
        end,
        updated_at = now()
    where id = new.listing_id;

    return new;
end;
$$;

revoke all on function public.handle_marketplace_listing_report()
from public, anon, authenticated;
grant execute on function public.handle_marketplace_listing_report()
to service_role;

create index if not exists idx_marketplace_listings_hidden
    on public.marketplace_listings(updated_at)
    where status in ('removed', 'removed_policy');

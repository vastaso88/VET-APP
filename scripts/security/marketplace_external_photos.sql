-- Foto degli annunci del Mercatino per tipo di collegamento (2026-11-23). SOLA LETTURA: nessuna
-- scrittura, e il risultato sono conteggi (nessun id, nessun indirizzo, nessun testo).
-- `progetti_diversi` deve essere 0 o 1.
with foto as (
    select l.id, l.status, l.owner_id, u.link
    from public.marketplace_listings l
    cross join lateral jsonb_array_elements_text(
        case when jsonb_typeof(l.photo_urls) = 'array' then l.photo_urls else '[]'::jsonb end
    ) as u(link)
),
esame as (
    select
        *,
        link ~ '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/marketplace-photos/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+\.jpg$'
            and (
                split_part(split_part(link, '/marketplace-photos/', 2), '/', 1) = owner_id
                or (
                    split_part(split_part(link, '/marketplace-photos/', 2), '/', 1) = 'published'
                    and split_part(split_part(link, '/marketplace-photos/', 2), '/', 2) = id
                )
            )
            as conforme,
        link like '%/marketplace-photos/published/%' as copiata
    from foto
)
select
    status as stato_annuncio,
    count(*) as foto_totali,
    count(*) filter (where conforme and copiata) as foto_gia_copiate,
    count(*) filter (where conforme and not copiata) as foto_da_copiare,
    count(*) filter (where not conforme) as foto_non_mostrate,
    count(distinct id) filter (where not conforme) as annunci_coinvolti,
    count(*) filter (where not conforme and link !~ '^https://[a-z0-9]+\.supabase\.co/') as di_altri_siti,
    count(distinct substring(link from '^https://([a-z0-9]+)\.supabase\.co/')) as progetti_diversi
from esame
group by status
order by status;

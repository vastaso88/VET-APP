-- LLM trusted sources catalog and retrieval schema.
-- Note: the vector size is set to 1536 for an embedding model in that range.
-- If you choose a different embedding model, adjust the vector dimensions
-- before ingesting any real chunks.

create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create schema if not exists ai;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create table if not exists ai.trusted_source_domains (
    id uuid primary key default extensions.gen_random_uuid(),
    host text not null unique,
    display_name text not null,
    base_url text not null,
    source_kind text not null check (
        source_kind in (
            'journal',
            'guideline_body',
            'publisher',
            'government',
            'university',
            'association',
            'knowledge_base',
            'other'
        )
    ),
    allow_subdomains boolean not null default true,
    is_active boolean not null default true,
    discovery_only boolean not null default false,
    allowed_for_direct_ingest boolean not null default false,
    authority_score numeric(4,3) not null default 0.500 check (
        authority_score >= 0 and authority_score <= 1
    ),
    direct_source_score numeric(4,3) not null default 0.500 check (
        direct_source_score >= 0 and direct_source_score <= 1
    ),
    registry_consensus_score numeric(4,3) not null default 0.000 check (
        registry_consensus_score >= 0 and registry_consensus_score <= 1
    ),
    veterinary_relevance_score numeric(4,3) not null default 0.500 check (
        veterinary_relevance_score >= 0 and veterinary_relevance_score <= 1
    ),
    evidence_policy text not null default 'curated_only' check (
        evidence_policy in ('curated_only', 'allow_manual_docs', 'allow_auto_ingest')
    ),
    notes text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists ai.source_registries (
    id uuid primary key default extensions.gen_random_uuid(),
    registry_key text not null unique,
    display_name text not null,
    registry_kind text not null check (
        registry_kind in ('ranking', 'discovery', 'direct_source')
    ),
    metric_name text not null,
    normalization_strategy text not null check (
        normalization_strategy in ('rank_percentile', 'value_percentile', 'manual')
    ),
    weight numeric(4,3) not null default 0.250 check (
        weight >= 0 and weight <= 1
    ),
    is_active boolean not null default true,
    source_url text,
    notes text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table ai.trusted_source_domains
    add column if not exists discovery_only boolean not null default false,
    add column if not exists allowed_for_direct_ingest boolean not null default false,
    add column if not exists direct_source_score numeric(4,3) not null default 0.500,
    add column if not exists registry_consensus_score numeric(4,3) not null default 0.000;

create table if not exists ai.source_registry_entries (
    id uuid primary key default extensions.gen_random_uuid(),
    registry_id uuid not null references ai.source_registries(id) on delete cascade,
    source_domain_id uuid references ai.trusted_source_domains(id) on delete cascade,
    host text,
    journal_title text,
    raw_rank integer,
    registry_size integer,
    raw_metric_name text,
    raw_metric_value numeric,
    normalized_percentile numeric(4,3) check (
        normalized_percentile is null or (normalized_percentile >= 0 and normalized_percentile <= 1)
    ),
    source_url text,
    captured_at timestamptz not null default now(),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    unique (registry_id, host, journal_title)
);

create index if not exists idx_source_registry_entries_registry_id
    on ai.source_registry_entries (registry_id);

create index if not exists idx_source_registry_entries_source_domain_id
    on ai.source_registry_entries (source_domain_id);

create index if not exists idx_source_registry_entries_percentile
    on ai.source_registry_entries (normalized_percentile desc);

create table if not exists ai.source_documents (
    id uuid primary key default extensions.gen_random_uuid(),
    domain_id uuid not null references ai.trusted_source_domains(id) on delete restrict,
    canonical_url text not null,
    url_host text not null,
    title text not null,
    document_kind text not null default 'other' check (
        document_kind in (
            'guideline',
            'consensus',
            'systematic_review',
            'meta_analysis',
            'review',
            'trial',
            'cohort',
            'case_series',
            'reference_page',
            'abstract',
            'other'
        )
    ),
    journal_name text,
    publisher text,
    doi text,
    pmid text,
    pmcid text,
    publication_date date,
    publication_year integer,
    language_code text not null default 'en',
    species_tags text[] not null default '{}'::text[],
    clinical_domain text[] not null default '{}'::text[],
    reliability_tier text not null default 'D' check (
        reliability_tier in ('A', 'B', 'C', 'D')
    ),
    trust_score numeric(4,3) not null default 0.500 check (
        trust_score >= 0 and trust_score <= 1
    ),
    peer_reviewed boolean not null default true,
    is_preprint boolean not null default false,
    is_retracted boolean not null default false,
    eligible_for_rag boolean not null default false,
    embedding_status text not null default 'pending' check (
        embedding_status in ('pending', 'queued', 'embedded', 'blocked', 'failed')
    ),
    embedding_priority integer not null default 100 check (
        embedding_priority >= 1 and embedding_priority <= 999
    ),
    ingestion_status text not null default 'pending' check (
        ingestion_status in ('pending', 'ingested', 'blocked', 'archived', 'error')
    ),
    summary text,
    source_text text,
    source_text_sha256 text,
    metadata jsonb not null default '{}'::jsonb,
    last_verified_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table ai.source_documents
    add column if not exists embedding_status text not null default 'pending',
    add column if not exists embedding_priority integer not null default 100;

create unique index if not exists idx_source_documents_canonical_url
    on ai.source_documents (lower(canonical_url));

create index if not exists idx_source_documents_domain_id
    on ai.source_documents (domain_id);

create index if not exists idx_source_documents_species_tags
    on ai.source_documents using gin (species_tags);

create index if not exists idx_source_documents_clinical_domain
    on ai.source_documents using gin (clinical_domain);

create index if not exists idx_source_documents_rag
    on ai.source_documents (eligible_for_rag, reliability_tier);

create index if not exists idx_source_documents_embedding_queue
    on ai.source_documents (eligible_for_rag, embedding_status, embedding_priority);

create table if not exists ai.source_document_chunks (
    id uuid primary key default extensions.gen_random_uuid(),
    document_id uuid not null references ai.source_documents(id) on delete cascade,
    chunk_index integer not null,
    section_label text,
    content text not null,
    token_count integer,
    embedding_model text,
    embedding extensions.vector(1536),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (document_id, chunk_index)
);

create index if not exists idx_source_document_chunks_document_id
    on ai.source_document_chunks (document_id);

create index if not exists idx_source_document_chunks_embedding
    on ai.source_document_chunks
    using hnsw (embedding extensions.vector_cosine_ops);

create table if not exists ai.answer_audits (
    id uuid primary key default extensions.gen_random_uuid(),
    app_conversation_id text,
    user_query text not null,
    species_filter text,
    clinical_domain_filter text,
    provider_name text not null,
    provider_model text not null,
    selected_document_ids uuid[] not null default '{}'::uuid[],
    selected_chunk_ids uuid[] not null default '{}'::uuid[],
    response_confidence text,
    prompt_snapshot text,
    created_at timestamptz not null default now()
);

drop trigger if exists trg_trusted_source_domains_set_updated_at on ai.trusted_source_domains;
create trigger trg_trusted_source_domains_set_updated_at
before update on ai.trusted_source_domains
for each row
execute function public.set_updated_at();

drop trigger if exists trg_source_registries_set_updated_at on ai.source_registries;
create trigger trg_source_registries_set_updated_at
before update on ai.source_registries
for each row
execute function public.set_updated_at();

drop trigger if exists trg_source_documents_set_updated_at on ai.source_documents;
create trigger trg_source_documents_set_updated_at
before update on ai.source_documents
for each row
execute function public.set_updated_at();

drop trigger if exists trg_source_document_chunks_set_updated_at on ai.source_document_chunks;
create trigger trg_source_document_chunks_set_updated_at
before update on ai.source_document_chunks
for each row
execute function public.set_updated_at();

alter table ai.trusted_source_domains enable row level security;
alter table ai.source_registries enable row level security;
alter table ai.source_registry_entries enable row level security;
alter table ai.source_documents enable row level security;
alter table ai.source_document_chunks enable row level security;
alter table ai.answer_audits enable row level security;

drop policy if exists trusted_source_domains_read_backend on ai.trusted_source_domains;
create policy trusted_source_domains_read_backend
on ai.trusted_source_domains
for select
to authenticated
using (false);

drop policy if exists source_registries_read_backend on ai.source_registries;
create policy source_registries_read_backend
on ai.source_registries
for select
to authenticated
using (false);

drop policy if exists source_registry_entries_read_backend on ai.source_registry_entries;
create policy source_registry_entries_read_backend
on ai.source_registry_entries
for select
to authenticated
using (false);

drop policy if exists source_documents_read_backend on ai.source_documents;
create policy source_documents_read_backend
on ai.source_documents
for select
to authenticated
using (false);

drop policy if exists source_document_chunks_read_backend on ai.source_document_chunks;
create policy source_document_chunks_read_backend
on ai.source_document_chunks
for select
to authenticated
using (false);

drop policy if exists answer_audits_write_backend on ai.answer_audits;
create policy answer_audits_write_backend
on ai.answer_audits
for insert
to authenticated
with check (false);

create or replace function ai.tier_rank(tier text)
returns integer
language sql
immutable
as $$
    select case upper(coalesce(tier, 'D'))
        when 'A' then 4
        when 'B' then 3
        when 'C' then 2
        else 1
    end;
$$;

create or replace function ai.rank_to_percentile(
    rank_value integer,
    population_size integer
)
returns numeric
language sql
immutable
as $$
    select case
        when rank_value is null or population_size is null or population_size <= 1 then null
        else round((1 - ((rank_value - 1)::numeric / (population_size - 1)::numeric))::numeric, 3)
    end;
$$;

create or replace function ai.recompute_registry_consensus_scores()
returns void
language sql
as $$
    with consensus as (
        select
            e.source_domain_id,
            coalesce(
                sum(e.normalized_percentile * r.weight)
                / nullif(sum(r.weight), 0),
                0
            ) as registry_consensus_score
        from ai.source_registry_entries e
        join ai.source_registries r on r.id = e.registry_id
        where e.source_domain_id is not null
          and e.normalized_percentile is not null
          and r.is_active = true
        group by e.source_domain_id
    )
    update ai.trusted_source_domains d
    set
        registry_consensus_score = coalesce(c.registry_consensus_score, 0),
        authority_score = round(
            ((coalesce(c.registry_consensus_score, 0) * 0.60)
            + (d.direct_source_score * 0.40))::numeric,
            3
        ),
        updated_at = now()
    from consensus c
    where d.id = c.source_domain_id;
$$;

create or replace function ai.match_source_chunks(
    query_embedding extensions.vector(1536),
    candidate_document_ids uuid[] default null,
    match_count integer default 8,
    species_filter text default null,
    domain_filter text default null,
    min_tier text default 'C'
)
returns table (
    chunk_id uuid,
    document_id uuid,
    title text,
    canonical_url text,
    document_kind text,
    reliability_tier text,
    trust_score numeric,
    journal_name text,
    publication_year integer,
    species_tags text[],
    clinical_domain text[],
    section_label text,
    content text,
    similarity double precision
)
language sql
stable
as $$
    select
        c.id as chunk_id,
        d.id as document_id,
        d.title,
        d.canonical_url,
        d.document_kind,
        d.reliability_tier,
        d.trust_score,
        d.journal_name,
        d.publication_year,
        d.species_tags,
        d.clinical_domain,
        c.section_label,
        c.content,
        1 - (c.embedding <=> query_embedding) as similarity
    from ai.source_document_chunks c
    join ai.source_documents d on d.id = c.document_id
    where d.eligible_for_rag = true
      and d.is_retracted = false
      and ai.tier_rank(d.reliability_tier) >= ai.tier_rank(min_tier)
      and (
          candidate_document_ids is null
          or d.id = any(candidate_document_ids)
      )
      and (
          species_filter is null
          or species_filter = any(d.species_tags)
          or 'other' = any(d.species_tags)
      )
      and (
          domain_filter is null
          or domain_filter = any(d.clinical_domain)
      )
    order by
        c.embedding <=> query_embedding,
        d.trust_score desc
    limit greatest(match_count, 1);
$$;

create or replace function ai.rank_source_documents(
    species_filter text default null,
    domain_filter text default null,
    min_tier text default 'C',
    limit_count integer default 50
)
returns table (
    document_id uuid,
    trust_score numeric,
    registry_consensus_score numeric,
    direct_source_score numeric,
    retrieval_priority numeric
)
language sql
stable
as $$
    select
        d.id as document_id,
        d.trust_score,
        td.registry_consensus_score,
        td.direct_source_score,
        round(
            (
                (d.trust_score * 0.50)
                + (td.registry_consensus_score * 0.30)
                + (td.direct_source_score * 0.20)
            )::numeric,
            3
        ) as retrieval_priority
    from ai.source_documents d
    join ai.trusted_source_domains td on td.id = d.domain_id
    where d.eligible_for_rag = true
      and d.embedding_status = 'embedded'
      and d.is_retracted = false
      and td.discovery_only = false
      and td.allowed_for_direct_ingest = true
      and ai.tier_rank(d.reliability_tier) >= ai.tier_rank(min_tier)
      and (
          species_filter is null
          or species_filter = any(d.species_tags)
          or 'other' = any(d.species_tags)
      )
      and (
          domain_filter is null
          or domain_filter = any(d.clinical_domain)
      )
    order by retrieval_priority desc, d.embedding_priority asc
    limit greatest(limit_count, 1);
$$;

insert into ai.trusted_source_domains (
    host,
    display_name,
    base_url,
    source_kind,
    discovery_only,
    allowed_for_direct_ingest,
    authority_score,
    direct_source_score,
    veterinary_relevance_score,
    evidence_policy,
    notes
)
values
    (
        'pubmed.ncbi.nlm.nih.gov',
        'PubMed',
        'https://pubmed.ncbi.nlm.nih.gov',
        'knowledge_base',
        true,
        false,
        0.980,
        0.850,
        0.850,
        'allow_auto_ingest',
        'Indicizzazione primaria per abstract e metadata biomedici.'
    ),
    (
        'pmc.ncbi.nlm.nih.gov',
        'PubMed Central',
        'https://pmc.ncbi.nlm.nih.gov',
        'knowledge_base',
        false,
        true,
        0.990,
        0.920,
        0.850,
        'allow_auto_ingest',
        'Preferibile per full text open access.'
    ),
    (
        'wsava.org',
        'WSAVA',
        'https://wsava.org',
        'association',
        false,
        true,
        0.950,
        0.980,
        0.980,
        'allow_manual_docs',
        'Guideline e position statement di alto valore pratico.'
    ),
    (
        'aaha.org',
        'AAHA',
        'https://www.aaha.org',
        'association',
        false,
        true,
        0.930,
        0.960,
        0.960,
        'allow_manual_docs',
        'Fonte utile per guideline e standard clinici companion animals.'
    ),
    (
        'merckvetmanual.com',
        'Merck Veterinary Manual',
        'https://www.merckvetmanual.com',
        'knowledge_base',
        false,
        true,
        0.900,
        0.880,
        0.970,
        'allow_manual_docs',
        'Knowledge base secondaria, non sostituisce guideline o review.'
    ),
    (
        'avmajournals.avma.org',
        'AVMA Journals',
        'https://avmajournals.avma.org',
        'journal',
        false,
        true,
        0.960,
        0.980,
        0.950,
        'allow_manual_docs',
        'Fonte diretta primaria per articoli JAVMA e altri journal AVMA.'
    )
on conflict (host) do update
set
    display_name = excluded.display_name,
    base_url = excluded.base_url,
    source_kind = excluded.source_kind,
    discovery_only = excluded.discovery_only,
    allowed_for_direct_ingest = excluded.allowed_for_direct_ingest,
    authority_score = excluded.authority_score,
    direct_source_score = excluded.direct_source_score,
    veterinary_relevance_score = excluded.veterinary_relevance_score,
    evidence_policy = excluded.evidence_policy,
    notes = excluded.notes,
    updated_at = now();

insert into ai.source_registries (
    registry_key,
    display_name,
    registry_kind,
    metric_name,
    normalization_strategy,
    weight,
    source_url,
    notes
)
values
    (
        'ooir_jif',
        'OOIR JIF Ranking',
        'ranking',
        'jif',
        'rank_percentile',
        0.350,
        'https://ooir.org/journals.php?field=Plant+%26+Animal+Science&category=Veterinary+Sciences&metric=jif',
        'Usare solo come ranking secondario e non come fonte diretta.'
    ),
    (
        'research_com',
        'Research.com Veterinary Ranking',
        'ranking',
        'estimated_h_index',
        'rank_percentile',
        0.350,
        'https://research.com/journals-rankings/animal-science-and-veterinary',
        'Ranking secondario basato su metodologia proprietaria.'
    ),
    (
        'pjip_sjr',
        'PJIP Veterinary Ranking',
        'ranking',
        'sjr',
        'rank_percentile',
        0.300,
        'https://www.pjip.org/Veterinary-journal-rankings.html',
        'Usare una sola metrica base per evitare doppio conteggio.'
    ),
    (
        'avma_direct',
        'AVMA Journals Direct Source',
        'direct_source',
        'editorial_authority',
        'manual',
        0.000,
        'https://avmajournals.avma.org',
        'Fonte diretta primaria, non confrontabile come ranking.'
    )
on conflict (registry_key) do update
set
    display_name = excluded.display_name,
    registry_kind = excluded.registry_kind,
    metric_name = excluded.metric_name,
    normalization_strategy = excluded.normalization_strategy,
    weight = excluded.weight,
    source_url = excluded.source_url,
    notes = excluded.notes,
    updated_at = now();


-- Admin scientific discovery ingestion.
-- Discovery metadata is stored in ai.source_documents but remains
-- ineligible for RAG until a later verification/full-text pipeline promotes it.

create unique index if not exists idx_source_documents_doi_unique
    on ai.source_documents (lower(doi))
    where doi is not null and btrim(doi) <> '';

create unique index if not exists idx_source_documents_pmid_unique
    on ai.source_documents (pmid)
    where pmid is not null and btrim(pmid) <> '';

insert into ai.trusted_source_domains (
    host, display_name, base_url, source_kind, discovery_only,
    allowed_for_direct_ingest, authority_score, direct_source_score,
    veterinary_relevance_score, evidence_policy, notes
)
values
    (
        'doi.org', 'DOI resolver', 'https://doi.org', 'knowledge_base', true,
        false, 0.700, 0.500, 0.700, 'curated_only',
        'Canonical DOI resolver used to deduplicate discovery metadata; never a RAG source by itself.'
    ),
    (
        'europepmc.org', 'Europe PMC', 'https://europepmc.org', 'knowledge_base', true,
        false, 0.900, 0.750, 0.850, 'allow_auto_ingest',
        'Discovery and metadata source. Full-text promotion requires a direct eligible source.'
    ),
    (
        'openalex.org', 'OpenAlex', 'https://openalex.org', 'knowledge_base', true,
        false, 0.800, 0.650, 0.750, 'curated_only',
        'Bibliographic discovery/enrichment source; not a direct RAG source.'
    )
on conflict (host) do update
set
    display_name = excluded.display_name,
    base_url = excluded.base_url,
    source_kind = excluded.source_kind,
    discovery_only = excluded.discovery_only,
    allowed_for_direct_ingest = excluded.allowed_for_direct_ingest,
    authority_score = excluded.authority_score,
    direct_source_score = excluded.direct_source_score,
    veterinary_relevance_score = excluded.veterinary_relevance_score,
    evidence_policy = excluded.evidence_policy,
    notes = excluded.notes,
    updated_at = now();

create or replace function public.admin_scientific_catalog(limit_count integer default 50)
returns jsonb
language sql
security invoker
set search_path = public, ai, extensions
as $$
    select jsonb_build_object(
        'metrics',
        jsonb_build_object(
            'trusted_domains', (select count(*) from ai.trusted_source_domains where is_active = true),
            'documents', (select count(*) from ai.source_documents),
            'eligible_for_rag', (select count(*) from ai.source_documents where eligible_for_rag = true),
            'embedded', (select count(*) from ai.source_documents where embedding_status = 'embedded'),
            'chunks', (select count(*) from ai.source_document_chunks)
        ),
        'recent_documents',
        coalesce(
            (
                select jsonb_agg(to_jsonb(x) order by x.created_at desc)
                from (
                    select
                        d.id,
                        d.title,
                        d.journal_name,
                        d.doi,
                        d.pmid,
                        d.publication_year,
                        d.reliability_tier,
                        d.eligible_for_rag,
                        d.embedding_status,
                        d.ingestion_status,
                        d.canonical_url,
                        d.species_tags,
                        d.clinical_domain,
                        d.created_at,
                        d.updated_at,
                        td.host as source_host,
                        td.display_name as source_name
                    from ai.source_documents d
                    join ai.trusted_source_domains td on td.id = d.domain_id
                    order by d.created_at desc
                    limit greatest(coalesce(limit_count, 50), 1)
                ) x
            ),
            '[]'::jsonb
        )
    );
$$;

revoke all on function public.admin_scientific_catalog(integer) from public, anon, authenticated;
grant execute on function public.admin_scientific_catalog(integer) to service_role;

create or replace function public.admin_ingest_scientific_documents(payload jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public, ai, extensions
as $$
declare
    item jsonb;
    domain_row ai.trusted_source_domains%rowtype;
    existing_id uuid;
    inserted_count integer := 0;
    updated_count integer := 0;
    skipped_count integer := 0;
    canonical text;
    normalized_doi text;
    normalized_pmid text;
    species_value text;
    domain_value text;
    metadata_value jsonb;
begin
    if payload is null or jsonb_typeof(payload) <> 'array' then
        raise exception 'payload must be a JSON array';
    end if;

    for item in select value from jsonb_array_elements(payload)
    loop
        canonical := nullif(btrim(item->>'canonical_url'), '');
        normalized_doi := nullif(lower(btrim(item->>'doi')), '');
        normalized_pmid := nullif(btrim(item->>'pmid'), '');
        species_value := coalesce(nullif(btrim(item->>'species'), ''), 'other');
        domain_value := coalesce(nullif(btrim(item->>'clinical_domain'), ''), 'general');
        metadata_value := coalesce(item->'metadata', '{}'::jsonb);

        if canonical is null or nullif(btrim(item->>'title'), '') is null then
            skipped_count := skipped_count + 1;
            continue;
        end if;

        select *
        into domain_row
        from ai.trusted_source_domains
        where host = lower(btrim(item->>'domain_host'))
          and is_active = true
        limit 1;

        if domain_row.id is null then
            skipped_count := skipped_count + 1;
            continue;
        end if;

        existing_id := null;

        if normalized_doi is not null then
            select id into existing_id
            from ai.source_documents
            where lower(doi) = normalized_doi
            limit 1;
        end if;

        if existing_id is null and normalized_pmid is not null then
            select id into existing_id
            from ai.source_documents
            where pmid = normalized_pmid
            limit 1;
        end if;

        if existing_id is null then
            select id into existing_id
            from ai.source_documents
            where lower(canonical_url) = lower(canonical)
            limit 1;
        end if;

        if existing_id is not null then
            update ai.source_documents
            set
                title = coalesce(nullif(btrim(item->>'title'), ''), title),
                journal_name = coalesce(nullif(btrim(item->>'journal'), ''), journal_name),
                doi = coalesce(normalized_doi, doi),
                pmid = coalesce(normalized_pmid, pmid),
                publication_year = coalesce((item->>'publication_year')::integer, publication_year),
                species_tags = array(
                    select distinct v
                    from unnest(species_tags || array[species_value]) as v
                    where v is not null and btrim(v) <> ''
                ),
                clinical_domain = array(
                    select distinct v
                    from unnest(clinical_domain || array[domain_value]) as v
                    where v is not null and btrim(v) <> ''
                ),
                reliability_tier = case
                    when ai.tier_rank(coalesce(item->>'reliability_tier', 'D'))
                         > ai.tier_rank(reliability_tier)
                    then coalesce(item->>'reliability_tier', reliability_tier)
                    else reliability_tier
                end,
                summary = coalesce(nullif(item->>'summary', ''), summary),
                metadata = metadata || metadata_value || jsonb_build_object('last_discovered_at', now())
            where id = existing_id;
            updated_count := updated_count + 1;
        else
            insert into ai.source_documents (
                domain_id,
                canonical_url,
                url_host,
                title,
                document_kind,
                journal_name,
                doi,
                pmid,
                publication_year,
                species_tags,
                clinical_domain,
                reliability_tier,
                trust_score,
                peer_reviewed,
                eligible_for_rag,
                embedding_status,
                ingestion_status,
                summary,
                metadata
            )
            values (
                domain_row.id,
                canonical,
                lower(btrim(item->>'domain_host')),
                btrim(item->>'title'),
                'abstract',
                nullif(btrim(item->>'journal'), ''),
                normalized_doi,
                normalized_pmid,
                nullif(item->>'publication_year', '')::integer,
                array[species_value],
                array[domain_value],
                coalesce(nullif(btrim(item->>'reliability_tier'), ''), 'C'),
                domain_row.authority_score,
                true,
                false,
                'pending',
                'pending',
                nullif(item->>'summary', ''),
                metadata_value || jsonb_build_object(
                    'first_discovered_at', now(),
                    'last_discovered_at', now()
                )
            );
            inserted_count := inserted_count + 1;
        end if;
    end loop;

    return jsonb_build_object(
        'inserted', inserted_count,
        'updated', updated_count,
        'skipped', skipped_count,
        'documents', (select count(*) from ai.source_documents)
    );
end;
$$;

revoke all on function public.admin_ingest_scientific_documents(jsonb) from public, anon, authenticated;
grant execute on function public.admin_ingest_scientific_documents(jsonb) to service_role;

# SPEC — Schema Dati Supabase per LLM + Fonti

> **Superseded**: dove questo documento (v1) è in contrasto con la VetGPT CORE ENGINE — MASTER
> DIRECTIONAL SPECIFICATION v3, vale la v3. Tenuto come riferimento storico.

## Obiettivo
Definire uno schema dati iniziale in Supabase/Postgres che supporti:
- autenticazione e dati utente/pet;
- archivio fonti scientifiche;
- embeddings e retrieval;
- tracciabilità delle risposte;
- aggiornamento delle fonti.

## Principi
- usare Postgres come source of truth;
- separare metadati bibliografici, chunk e conversazioni;
- rendere l'estensione a RLS e audit semplice;
- predisporre pgvector.

## Estensioni richieste
- `vector`
- `pgcrypto` o equivalente per UUID e sicurezza
- eventuali estensioni di text search se utili

## Tabelle principali

### 1. `profiles`
```sql
id uuid primary key references auth.users(id)
full_name text null
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 2. `pets`
```sql
id uuid primary key default gen_random_uuid()
owner_id uuid not null references profiles(id)
name text not null
species text not null check (species in ('dog', 'cat', 'other'))
breed text null
sex text null
birth_date date null
weight_kg numeric null
sterilized boolean null
medical_notes text null
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 3. `source_journals`
```sql
id uuid primary key default gen_random_uuid()
title text not null
issn_print text null
issn_online text null
publisher text null
subject_area text[] not null default '{}'
is_veterinary boolean not null default false
indexed_pubmed boolean not null default false
indexed_scopus boolean not null default false
indexed_wos boolean not null default false
indexed_doaj boolean not null default false
sjr numeric null
sjr_quartile text null
citescore numeric null
jif numeric null
quality_tier text null
trust_score_base numeric not null default 0
last_verified_at timestamptz null
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 4. `articles`
```sql
id uuid primary key default gen_random_uuid()
source_journal_id uuid null references source_journals(id)
doi text null unique
pmid text null unique
pmcid text null unique
title text not null
abstract text null
publication_year int null
publication_date date null
publication_type text[] not null default '{}'
study_design text null
species_tags text[] not null default '{}'
clinical_domain text[] not null default '{}'
peer_reviewed boolean not null default true
is_preprint boolean not null default false
is_retracted boolean not null default false
has_correction boolean not null default false
oa_available boolean not null default false
citation_count int null
article_quality_score numeric not null default 0
clinical_relevance_score numeric not null default 0
species_relevance_score numeric not null default 0
final_trust_score numeric not null default 0
reliability_tier text not null default 'D'
eligible_for_rag boolean not null default false
source_url text null
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 5. `article_authors`
```sql
id uuid primary key default gen_random_uuid()
article_id uuid not null references articles(id) on delete cascade
full_name text not null
affiliation text null
position_order int not null
created_at timestamptz not null default now()
```

### 6. `article_chunks`
```sql
id uuid primary key default gen_random_uuid()
article_id uuid not null references articles(id) on delete cascade
chunk_index int not null
section_type text null
content text not null
token_count int null
embedding vector(1536) null
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
unique(article_id, chunk_index)
```

> Nota: la dimensione del vettore deve essere parametrica e coerente con il modello embedding scelto.

### 7. `guidelines`
```sql
id uuid primary key default gen_random_uuid()
title text not null
issuing_body text not null
year int not null
species_tags text[] not null default '{}'
clinical_domain text[] not null default '{}'
recommendation_strength text null
summary text null
source_url text not null
trust_score numeric not null default 0
eligible_for_rag boolean not null default true
created_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 8. `claims`
```sql
id uuid primary key default gen_random_uuid()
article_id uuid null references articles(id) on delete cascade
guideline_id uuid null references guidelines(id) on delete cascade
claim_text text not null
claim_type text not null
species_tags text[] not null default '{}'
clinical_domain text[] not null default '{}'
confidence_score numeric not null default 0
created_at timestamptz not null default now()
```

### 9. `conversations`
```sql
id uuid primary key default gen_random_uuid()
user_id uuid not null references profiles(id)
pet_id uuid null references pets(id)
mode text not null
started_at timestamptz not null default now()
updated_at timestamptz not null default now()
```

### 10. `messages`
```sql
id uuid primary key default gen_random_uuid()
conversation_id uuid not null references conversations(id) on delete cascade
role text not null check (role in ('system', 'user', 'assistant', 'tool'))
content text not null
created_at timestamptz not null default now()
```

### 11. `answer_audits`
```sql
id uuid primary key default gen_random_uuid()
conversation_id uuid not null references conversations(id) on delete cascade
user_message_id uuid null references messages(id)
assistant_message_id uuid null references messages(id)
mode text not null
retrieval_query jsonb not null default '{}'
selected_sources jsonb not null default '[]'
prompt_snapshot text not null
provider_name text not null
provider_model text not null
confidence text null
created_at timestamptz not null default now()
```

### 12. `source_updates`
```sql
id uuid primary key default gen_random_uuid()
article_id uuid not null references articles(id) on delete cascade
update_type text not null
payload jsonb not null default '{}'
detected_at timestamptz not null default now()
processed_at timestamptz null
```

## Indici consigliati

```sql
create index if not exists idx_articles_species_tags on articles using gin (species_tags);
create index if not exists idx_articles_clinical_domain on articles using gin (clinical_domain);
create index if not exists idx_articles_tier on articles (reliability_tier);
create index if not exists idx_articles_rag on articles (eligible_for_rag);
create index if not exists idx_chunks_article_id on article_chunks (article_id);
```

## Funzione di similarity search
Codex deve preparare una funzione SQL/RPC che:
- riceve embedding query;
- filtra per species, domain, min tier, eligible_for_rag;
- ordina per distanza + punteggio;
- restituisce chunk e metadati articolo.

Pseudofirma:

```sql
match_evidence_chunks(
  query_embedding vector,
  match_count int,
  species_filter text,
  domain_filter text,
  min_tier text
)
```

## RLS
Nel prototipo:
- dati utente, pet, conversation e audit devono essere protetti con RLS per owner;
- catalogo fonti può essere read-only lato applicazione server;
- nessun client diretto deve poter alterare trust score e tier.

## Seed minimo richiesto
Codex deve prevedere seed scripts per:
- 1 utente demo
- 1 pet demo cane
- 1 pet demo gatto
- 10-20 fonti esempio
- 30-50 chunk indicizzati

## Acceptance criteria
1. Migrazioni SQL ripetibili.
2. Tabelle separate e coerenti.
3. Estensione pgvector attivabile.
4. Similarity search predisposta.
5. Audit trail persistito.

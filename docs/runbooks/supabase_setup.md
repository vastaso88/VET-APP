# Supabase Setup

## Database connection
The repository is prepared to read Supabase Postgres details from `.env`.

Use these variables:
- `PERSISTENCE_BACKEND`
- `AUTH_BACKEND`
- `DATABASE_URL`
- `SUPABASE_DB_HOST`
- `SUPABASE_DB_PORT`
- `SUPABASE_DB_NAME`
- `SUPABASE_DB_USER`
- `SUPABASE_DB_PASSWORD`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `BOOTSTRAP_USER_ID`
- `BOOTSTRAP_USER_EMAIL`

Secret handling rules:
- keep real values only in local `.env`
- never commit `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_PASSWORD`, or a populated `DATABASE_URL`
- `SUPABASE_ANON_KEY` is client-safe, but still keep it out of the repo-local `.env.example`
- when `AUTH_BACKEND=supabase`, `BOOTSTRAP_USER_ID` and `BOOTSTRAP_USER_EMAIL` are ignored

Current project values already prepared in `.env.example`:
- host: `aws-1-eu-west-1.pooler.supabase.com`
- port: `5432`
- database: `postgres`
- user: `postgres.ywbuzgwbkrmkukkpysbz`

## Current bootstrap mode
- `PERSISTENCE_BACKEND=supabase` enables Supabase repositories
- `AUTH_BACKEND=supabase` enables real Supabase email/password auth and bearer-token user resolution

Fail-fast validation:
- if `PERSISTENCE_BACKEND=supabase`, the app now requires `DATABASE_URL`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY`
- if `AUTH_BACKEND=supabase`, the app now requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`

## Schema to apply
Run the SQL in `scripts/setup/supabase_schema.sql` inside the Supabase SQL editor before starting the app with the Supabase backend.

The script now includes:
- base tables
- indexes
- Row Level Security
- owner-scoped policies for `pet_profiles`, `conversations`, and `reminders`

For the LLM evidence layer, also run `scripts/setup/supabase_llm_sources_schema.sql`.

That schema adds:
- a curated registry of trusted domains and base URLs
- external ranking registries with normalized scores
- a catalog of approved source documents with trust metadata
- vector-ready chunks for retrieval
- an audit table for tracking which sources were used in answers
- RPC-ready SQL functions such as `ai.rank_source_documents(...)` and `ai.match_source_chunks(...)`

Policy model:
- users can only read/update/delete rows where `owner_id = auth.uid()::text`
- insert on `conversations` and `reminders` is allowed only if the referenced pet belongs to the same authenticated user

## Implemented integration points
- `packages/infrastructure/persistence/supabase/`
- `packages/infrastructure/auth/supabase_auth_provider.py`
- `packages/bootstrap/container.py`

## Next step after schema
When the tables exist, start the app normally. The bootstrap container will use Supabase repositories and Supabase auth automatically from `.env`.

To seed stable demo data directly into Supabase and immediately verify readback on the same tables, run:
- `python scripts/setup/seed_demo_supabase.py --reset`

What this script does:
- uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from local `.env`
- seeds `pet_profiles`, `conversations`, and `reminders` for `BOOTSTRAP_USER_ID` by default
- re-reads the same rows from Supabase and prints a JSON summary with counts and pet names

Current scope:
- this validates the core Python persistence path against real Supabase tables
- Flutter preview sections that still rely on local seed stores, such as some dashboard/chat/medical-record widgets, remain outside this seed flow until their repositories are aligned to the same schema

For the LLM path, the recommended flow is:
- import journal rankings into registry tables and normalize them to percentiles
- curate allowed hosts in `ai.trusted_source_domains`
- ingest only documents that belong to those hosts into `ai.source_documents`
- chunk and embed only approved text marked `eligible_for_rag = true`
- call `ai.rank_source_documents(...)` first, then `ai.match_source_chunks(...)` before sending context to Groq

Recommended backend toggle:
- `EVIDENCE_BACKEND=in_memory` for preview mode
- `EVIDENCE_BACKEND=supabase` when the RPC-backed evidence retriever is enabled
- `EVIDENCE_BACKEND=europe_pmc` for real scientific literature via the Europe
  PMC REST API only (no API key needed) — see
  `packages/infrastructure/llm/retrieval/europe_pmc_evidence_retriever.py`.
- `EVIDENCE_BACKEND=scientific_multi` to query Europe PMC, PubMed, Crossref
  and OpenAlex together (spec v3 §20 — none of the four needs an API key
  for this call volume), deduplicated by DOI/PMID/title via
  `packages/infrastructure/llm/retrieval/multi_source_evidence_retriever.py`.
  All four share the same Italian→English keyword query translation
  (`packages/core/application/services/evidence_query_planner.py`) — a
  deliberate MVP stand-in, not the full multi-concept query expansion the
  spec describes.

Initial registry seed workflow:
- run the schema SQL first
- dry-run the registry seed with `python scripts/setup/seed_source_registry.py`
- apply it with `python scripts/setup/seed_source_registry.py --apply`
- optionally import curated registry snapshots with `--snapshot-json path/to/export.json`

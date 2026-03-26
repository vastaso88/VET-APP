# Vet App

Web-first pet-tech product with a Flutter client and a Python backend bootstrap. The repository is set up to show a convincing browser demo first, while keeping the core ready for APIs, Supabase, and multiple LLM providers, with mobile-ready configuration for later releases.

## Goals
- validate onboarding, auth, home, pet profile, chat, records, and reminders in a single web flow
- keep domain and application logic independent from delivery frameworks
- make the Flutter client the primary web demo surface without coupling the core to it

## Repository shape
- `apps/mobile_app`: Flutter client and demo surface
- `apps/api`: FastAPI delivery layer
- `packages/core`: domain and application layers
- `packages/infrastructure`: concrete adapters
- `packages/shared`: config, errors, shared types
- `tests`: unit, integration, contract, e2e
- `docs`: architecture notes, ADRs, runbooks, product references

## Quickstart
1. Install `uv` or use `python -m pip install -e .[dev]` as fallback.
2. Copy `.env.example` to `.env`.
3. Choose one backend pair:
   - `AUTH_BACKEND=bootstrap` and `PERSISTENCE_BACKEND=in_memory` for browser demo mode
   - `AUTH_BACKEND=supabase` and `PERSISTENCE_BACKEND=supabase` for real Supabase mode
4. Choose the evidence backend:
   - `EVIDENCE_BACKEND=in_memory` for preview mode
   - `EVIDENCE_BACKEND=supabase` for the RPC-backed trusted-sources retriever
5. Keep `LLM_PROVIDER=echo` for browser demo runs. Switch to `LLM_PROVIDER=groq` only when you want to exercise the hosted LLM path and have set `LLM_API_KEY`.
6. Install dependencies with `make setup`.
7. Start the API with `make run-api`.
8. Start the Flutter web client with `cd apps/mobile_app && flutter pub get && flutter run -d chrome`.

For the trusted-sources rubric in Supabase:
- run `scripts/setup/supabase_llm_sources_schema.sql`
- preview the initial registry seed with `python scripts/setup/seed_source_registry.py`
- write it with `python scripts/setup/seed_source_registry.py --apply`

## Main commands
- `make format`
- `make lint`
- `make typecheck`
- `make test`
- `make run-api`
- `make run-web`
- `make run-web-server`
- `make build-web`

For terminals without administrator rights, prefer `make run-web-server` and open the printed URL manually in your browser. This avoids Flutter-managed Chrome profiles and keeps the demo flow inside the current user session.

For `flutter analyze` in the same no-admin environment, use the documented workaround in `docs/runbooks/flutter_analyze_no_admin.md`.

## Vercel deploy
The repository supports two Vercel projects:

- `apps/mobile_app` for the founder demo preview as a Flutter web app
- repository root for the FastAPI bootstrap backend

1. Import the repository into Vercel.
2. For the web demo preview, set the project root to `apps/mobile_app`.
3. For the backend bootstrap, keep the project root at the repository root.
4. Configure the required environment variables only for the backend project.
5. Deploy.

For demo deployments, use:
- `AUTH_BACKEND=bootstrap`
- `PERSISTENCE_BACKEND=in_memory`
- `LLM_PROVIDER=echo`

For production-like deployments with Supabase, also configure the Supabase and LLM secrets described below.

## Environment variables
Configuration is centralized in `packages/shared/config/settings.py`. The bootstrap expects:
- `ENVIRONMENT`
- `APP_NAME`
- `API_HOST`
- `API_PORT`
- `DATABASE_URL`
- `EVIDENCE_BACKEND`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_HOST`
- `SUPABASE_DB_PORT`
- `SUPABASE_DB_NAME`
- `SUPABASE_DB_USER`
- `SUPABASE_DB_PASSWORD`
- `LLM_PROVIDER`
- `LLM_MODEL`
- `LLM_API_KEY`
- `LOG_LEVEL`
- `ENABLE_TELEMETRY`

When Supabase mode is enabled, the app now fails fast at startup if the required auth or persistence secrets are missing.

See `docs/runbooks/vercel_deploy.md` for the deployment checklist.

## Architecture notes
- Flutter web is the primary demo client.
- FastAPI routes stay thin and delegate to application services.
- Domain models do not depend on Flutter, FastAPI, or external providers.
- In-memory adapters keep the bootstrap runnable while Supabase/Postgres adapters are prepared as extension points.
- LLM integration is still a demo stub in this first bootstrap push.
- Supabase auth flow is now wired for runtime email/password login and bearer-token user resolution.
- Supabase persistence tables are protected by RLS owner-based policies.
- Browser preview should use `AUTH_BACKEND=bootstrap`, `PERSISTENCE_BACKEND=in_memory`, and `LLM_PROVIDER=echo` until the Supabase and Groq paths are intentionally enabled.

## Product source material
Product and strategy documents now live under `docs/`:
- `docs/product/`
- `docs/llm/`
- `docs/architecture/overview.md`
- `docs/architecture/repo_bootstrap_instructions.md`
- `docs/decisions/*`
- `docs/runbooks/`

Recent implementation notes:
- `docs/runbooks/flutter_analyze_no_admin.md`
- `docs/frontend/10-ux-review-2026-03-26.md`

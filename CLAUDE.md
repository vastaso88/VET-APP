# VetApp

Flutter-first pet-tech app. Flutter web/mobile client + Python/FastAPI backend.

## Layout
- `apps/mobile_app/` — Flutter client (`lib/`), web-first, Supabase auth/storage.
- `apps/api/` — FastAPI app (`main.py`, `routes/`, `schemas/`).
- `packages/` — shared backend logic: `core` (domain/application), `infrastructure`, `bootstrap` (DI container), `sdk`, `shared`.
- `app.py` — re-exports the FastAPI app for Vercel deploy.

## Commands (see `Makefile`)
- `uv run pytest` — backend tests
- `uv run ruff check .` / `uv run ruff format .` — lint/format
- `uv run mypy apps packages tests` — typecheck
- `uv run uvicorn apps.api.main:app --reload` — run API locally
- `cd apps/mobile_app && flutter analyze` — Flutter static checks
- `cd apps/mobile_app && flutter run -d chrome` — run Flutter web client
- `npx ccusage@latest` — check local Claude Code token/cost usage (reads local logs only, no upload)

## Conventions
- Backend: hexagonal-ish split — `core/domain`, `core/application/{ports,services}`, `infrastructure/persistence` (Supabase + in-memory test doubles), wired via `bootstrap/container.py`.
- Tests: `tests/unit/` and `tests/integration/`; run targeted files during iteration, full suite before considering a change done.
- Python 3.12+, strict mypy (`disallow_untyped_defs`), ruff line-length 100.

## Style
Be concise. No filler, no restating the request, no unsolicited summaries at the end of routine edits.

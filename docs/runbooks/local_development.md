# Web Preview

1. Install `uv`, or use `python -m pip install -e .[dev]` if `uv` is unavailable.
2. Copy `.env.example` to `.env`.
3. Set the preview defaults in `.env`:
   - `AUTH_BACKEND=bootstrap`
   - `PERSISTENCE_BACKEND=in_memory`
   - `LLM_PROVIDER=echo`
   - `LLM_API_KEY=` can stay empty in echo mode
   - to chat with Claude locally: `LLM_PROVIDER=anthropic` and `ANTHROPIC_API_KEY=...`
     (the other variables are listed in `docs/runbooks/vercel_deploy.md`)
4. Run `make setup`.
5. Run `make run-api`.
6. Run `cd apps/mobile_app && flutter pub get && flutter run -d chrome`.
7. Execute `make lint`, `make typecheck`, and `make test` before pushing.

# Vercel deployment

This project exposes the FastAPI application through the repository root `app.py`, which makes it compatible with the Vercel Python runtime.

## Recommended targets
- Founder demo preview: deploy the Flutter web client as a separate Vercel project rooted at `apps/mobile_app`.
- Deploy `apps/api` via the root `app.py` entrypoint.
- Keep the API deployment separate from the Flutter web preview.

## Flutter web preview
Use this for the founder demo and other visual review flows.

1. Import the Git repository into Vercel.
2. Create a dedicated project with root directory `apps/mobile_app`.
3. Keep the project as a preview deployment, not production.
4. Let Vercel use [apps/mobile_app/vercel.json](C:/Users/vasta/OneDrive%20-%20Techbau%20SpA/Documenti/PERS/VET%20APP/GIT/apps/mobile_app/vercel.json).
5. The build runs through [apps/mobile_app/scripts/vercel_build_flutter_web.sh](C:/Users/vasta/OneDrive%20-%20Techbau%20SpA/Documenti/PERS/VET%20APP/GIT/apps/mobile_app/scripts/vercel_build_flutter_web.sh) and outputs `build/web`.

Notes:
- No backend environment variables are required for the demo preview.
- The Flutter app already falls back to demo-safe auth, pet, chat, records, and reminders data when runtime config is empty.
- SPA rewrites are handled inside `apps/mobile_app/vercel.json`.

## API project
Use this as a second Vercel project only when you want the bootstrap backend online.

## Setup steps
1. Import the Git repository into Vercel.
2. Leave the project root unchanged: use the repository root.
3. Add the environment variables required by your chosen backend mode.
4. Deploy.

## Minimum demo variables
- `ENVIRONMENT=production`
- `APP_NAME=Vet App`
- `AUTH_BACKEND=bootstrap`
- `PERSISTENCE_BACKEND=in_memory`
- `LLM_PROVIDER=echo`
- `ENABLE_TELEMETRY=false`

## Supabase mode variables
If you enable Supabase-backed auth or persistence, also configure:
- `DATABASE_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Claude mode variables (chat on Claude Haiku 5.5, from 2026-11-07)
The chat answers with Claude through the official SDK. There is no reserve provider, no
voice dictation and no photo reading on the server (removed on 2026-11-25): the variables
of that time are ignored, and one log line at start-up names the ones still set (names
only); remove them from the project. `LLM_PROVIDER` accepts `anthropic` and `echo` only:
any other value stops the start-up.
- `LLM_PROVIDER=anthropic`
- `ANTHROPIC_API_KEY` (a key of its own from the Anthropic console; never in the repository)
- `ANTHROPIC_MODEL=claude-haiku-5-5` (default)
- `ANTHROPIC_EFFORT=low` and `ANTHROPIC_EFFORT_LIGHT=low` (optional; `low`, `medium` or `high`)
- `ANTHROPIC_THINKING_HEADROOM_TOKENS=1200` and `ANTHROPIC_TIMEOUT_SECONDS=30` (optional)
- `URGENT_ANSWER_TIMEOUT_SECONDS=12` (optional; `0` = fixed first-aid texts only)
- `LLM_DAILY_BUDGET_EUR` (default 1): the day's spending cap, after which the chat says
  kindly that today's answers are over, until midnight UTC

## Notes
- `vercel.json` rewrites all incoming paths to the FastAPI entrypoint so API routes such as `/health` keep working.
- Local `.env` files are not uploaded to Vercel. Configure secrets in the Vercel project settings.
- Healthcheck endpoint: `/health`

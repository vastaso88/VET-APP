# VET APP Admin Portal

Internal, desktop-first backoffice for VET APP.

## Boundary

This is intentionally a separate product surface from `apps/mobile_app`.

- no Flutter dependency
- no shared navigation or client state
- no browser-side service-role access
- privileged operations go through dedicated server-side admin endpoints
- release/deploy lifecycle can be independent from the user app

## v0.2

- Supabase-backed login through the existing FastAPI `/auth/login`
- server-side admin allowlist enforced by FastAPI
- Overview with live Auth / pet / conversations / Radar / moderation / scrape metrics
- latest data sources and scrape runs, read-only

## Authorization

The backend reads:

- `ADMIN_EMAILS` (comma-separated) when explicitly configured
- otherwise it falls back to the existing `DEVELOPER_EMAILS`

No personal email address is committed to source control.

The portal stores the returned access token only in an HTTP-only, SameSite cookie and sends it server-to-server to the FastAPI admin endpoints. Supabase service-role credentials stay in the backend only.

## Vercel environment

For the admin Vercel project set:

```
VET_API_BASE_URL=https://<your-fastapi-backend>.vercel.app
```

The code currently falls back to `https://vet-app-psi-nine.vercel.app`, the backend alias already referenced in repository configuration. Set the environment variable explicitly if your live backend uses another alias.

## Run locally

```bash
cd apps/admin_portal
npm install
VET_API_BASE_URL=http://localhost:8000 npm run dev
```

Open `http://localhost:3000`.

## Next steps

1. Make Moderation read real queues and records.
2. Add geographic ingestion dry-run.
3. Introduce a unified ingestion job/audit model.
4. Wire scientific discovery to the existing evidence providers.
5. Add audited moderation and ingestion write actions.

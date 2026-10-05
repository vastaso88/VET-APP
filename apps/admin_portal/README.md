# VET APP Admin Portal

Internal, desktop-first backoffice for VET APP.

## Boundary

This is intentionally a separate product surface from `apps/mobile_app`.

- no Flutter dependency
- no shared navigation or client state
- no browser-side service-role access
- privileged operations must go through dedicated server-side admin endpoints
- release/deploy lifecycle can be independent from the user app

## v0.1 sections

- Overview
- Moderation
- Geographic data
- Scientific data
- Ingestion jobs

The first iteration is deliberately read-only/static. It establishes navigation and operational information architecture before connecting privileged APIs.

## Run locally

```bash
cd apps/admin_portal
npm install
npm run dev
```

Open `http://localhost:3000`.

## Next steps

1. Add admin authentication and server-side role enforcement.
2. Add read-only admin API endpoints for overview metrics and source status.
3. Introduce a unified ingestion job/audit model.
4. Wire geographic dry-run/execution to existing Radar import pipelines.
5. Wire scientific discovery to the existing evidence providers.
6. Add moderation actions with audit logging.

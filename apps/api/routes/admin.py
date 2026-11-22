"""Admin router: the dashboard, moderation and ingestion routers under one `router`.

Shared helpers live in admin_common.py. Import order keeps the route matching order the
single file had (the moderation routes stay together, in their old order)."""

from fastapi import APIRouter

from apps.api.routes.admin_dashboard import router as dashboard_router
from apps.api.routes.admin_ingestion import router as ingestion_router
from apps.api.routes.admin_moderation import router as moderation_router

router = APIRouter()
router.include_router(dashboard_router)
router.include_router(moderation_router)
router.include_router(ingestion_router)

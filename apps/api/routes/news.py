from typing import Annotated

from fastapi import APIRouter, Query

from apps.api.dependencies.container import get_container
from packages.core.domain.pet_news.models import NEWS_CATEGORIES, PetNewsEntry

router = APIRouter(prefix="/news", tags=["news"])


def _item_payload(item: PetNewsEntry) -> dict[str, object]:
    return {
        "title": item.title,
        "source": item.source,
        "url": item.url,
        "published_at": item.published_at.isoformat() if item.published_at else None,
    }


@router.get("")
def list_pet_news(
    category: Annotated[list[str] | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=30)] = 12,
) -> dict[str, object]:
    """Headlines for "Curiosità per i tuoi animali". Public: it carries no
    owner data and the app shows it on the first screens. Read from the shared
    snapshot (see GetPetNewsService); `stale` is true when the feeds were
    unreachable and an older copy is served."""
    result = get_container().pet_news_service().get(categories=category, limit=limit)
    return {
        "categories": {
            name: [_item_payload(item) for item in items]
            for name, items in result.categories.items()
        },
        "available_categories": list(NEWS_CATEGORIES),
        "updated_at": result.updated_at.isoformat() if result.updated_at else None,
        "stale": result.stale,
    }

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.geo.models import Coordinates

ListingCategory = Literal[
    "food",
    "accessories",
    "health_wellness",
    "transport_carriers",
    "toys",
    "grooming",
    "other",
]
ListingCondition = Literal["new", "like_new", "good", "worn"]
ListingStatus = Literal["active", "reserved", "sold", "removed"]
ListingReportReason = Literal["spam", "scam", "prohibited_item", "inappropriate", "other"]

# Non-goals (docs/maps/): no moderation queue, no image scanning, no
# in-app messaging/payment - this is a listings board, not a
# transactional marketplace.
REPORT_COUNT_AUTO_REMOVE_THRESHOLD = 3


class MarketplaceListing(BaseModel):
    id: str = Field(default_factory=new_id)
    owner_id: str
    title: str
    description: str | None = None
    category: ListingCategory
    condition: ListingCondition
    price_cents: int | None = None
    photo_urls: list[str] = Field(default_factory=list)
    # Already fuzzed via geo.models.fuzz_coordinates before this is saved -
    # the exact seller address is never persisted here.
    location: Coordinates
    city_label: str | None = None
    status: ListingStatus = "active"
    report_count: int = 0
    created_at: datetime = Field(default_factory=utc_now)
    updated_at: datetime = Field(default_factory=utc_now)


class ListingReport(BaseModel):
    id: str = Field(default_factory=new_id)
    listing_id: str
    reporter_owner_id: str
    reason: ListingReportReason
    created_at: datetime = Field(default_factory=utc_now)

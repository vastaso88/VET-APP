from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.dependencies.marketplace import require_marketplace_not_restricted
from apps.api.dependencies.subscription import owner_has_access, require_active_subscription
from packages.core.application.services.create_listing import CreateListingInput
from packages.core.application.services.list_nearby_listings import ListNearbyListingsInput
from packages.core.application.services.report_listing import ReportListingInput
from packages.core.application.services.update_listing import UpdateListingInput
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import (
    ListingCategory,
    ListingCondition,
    ListingReportReason,
    ListingSpecies,
    MarketplaceListing,
)
from packages.core.domain.marketplace.visibility import limit_listing_row
from packages.core.domain.territory.rules import (
    MARKETPLACE_MAX_RADIUS_KM,
    MARKETPLACE_MIN_RADIUS_KM,
)

router = APIRouter(prefix="/marketplace", tags=["marketplace"])


def _public_row(listing: MarketplaceListing, requester_id: str) -> dict[str, object]:
    """An ad as other owners may see it. The seller's account id leaves only
    with the seller's own ads (`is_mine` tells the app which ones they are):
    to everyone else it is an internal identifier that would let a stranger
    link the ad to an account."""
    is_mine = listing.owner_id == requester_id
    hidden = {"location"} if is_mine else {"location", "owner_id"}
    row = listing.model_dump(mode="json", exclude=hidden)
    row["is_mine"] = is_mine
    row["latitude"] = listing.location.latitude
    row["longitude"] = listing.location.longitude
    return row


# The Mercatino is local: no search, only a distance. `radius_km` has no
# default and a value outside [MARKETPLACE_MIN_RADIUS_KM, MARKETPLACE_MAX_RADIUS_KM]
# is refused (400), whatever the app sends. Ads are found by distance alone, so
# near a border the ads across it show up too (each carries its seller's country).
# `country` is accepted for older app builds and ignored.
@router.get("/listings")
def list_nearby_listings(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    radius_km: Annotated[float, Query()],
    country: Annotated[str | None, Query(max_length=2)] = None,
    category: ListingCategory | None = None,
) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    # An owner without a plan (trial over) still browses, but sees only the
    # first look of each ad (domain/marketplace/visibility.py).
    limited = not owner_has_access()
    result = container.list_nearby_listings_service().execute(
        ListNearbyListingsInput(
            buyer_location=Coordinates(latitude=latitude, longitude=longitude),
            max_distance_km=radius_km,
            category=category,
        )
    )
    listings = []
    for item in result.listings:
        row = _public_row(item, user.id)
        row["distance_km"] = round(result.distances_km[item.id], 3)
        listings.append(limit_listing_row(row) if limited else row)
    return {
        "listings": listings,
        "context": {
            "radius_km": radius_km,
            "min_radius_km": MARKETPLACE_MIN_RADIUS_KM,
            "max_radius_km": MARKETPLACE_MAX_RADIUS_KM,
            "limited": limited,
        },
    }


class ListingPayload(BaseModel):
    """What the app sends to publish or edit an ad. `latitude`/`longitude` are
    the seller's place; only a ~1 km grid snap of it is ever stored."""

    title: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    category: ListingCategory
    condition: ListingCondition
    price_cents: int | None = Field(default=None, ge=1)
    photo_urls: list[str] = Field(default_factory=list, max_length=6)
    target_species: list[ListingSpecies] = Field(default_factory=list)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    city_label: str | None = Field(default=None, max_length=120)
    country: str = Field(default="IT", min_length=2, max_length=2)


# The one door through which an ad is written: the content rule (no animals)
# is applied here, so it does not depend on what the app did.
@router.post(
    "/listings",
    dependencies=[
        Depends(require_active_subscription),
        Depends(require_marketplace_not_restricted),
    ],
)
def create_listing(payload: ListingPayload) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.create_listing_service().execute(
        CreateListingInput(
            owner_id=user.id,
            title=payload.title.strip(),
            description=payload.description.strip() if payload.description else None,
            category=payload.category,
            condition=payload.condition,
            exact_location=Coordinates(latitude=payload.latitude, longitude=payload.longitude),
            price_cents=payload.price_cents,
            photo_urls=payload.photo_urls,
            target_species=payload.target_species,
            city_label=payload.city_label,
            country=payload.country,
        )
    )
    return {"listing": _public_row(result.listing, user.id)}


@router.put(
    "/listings/{listing_id}",
    dependencies=[
        Depends(require_active_subscription),
        Depends(require_marketplace_not_restricted),
    ],
)
def update_listing(listing_id: str, payload: ListingPayload) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.update_listing_service().execute(
        UpdateListingInput(
            owner_id=user.id,
            listing_id=listing_id,
            title=payload.title.strip(),
            description=payload.description.strip() if payload.description else None,
            category=payload.category,
            condition=payload.condition,
            exact_location=Coordinates(latitude=payload.latitude, longitude=payload.longitude),
            price_cents=payload.price_cents,
            photo_urls=payload.photo_urls,
            target_species=payload.target_species,
            city_label=payload.city_label,
            country=payload.country,
        )
    )
    return {"listing": _public_row(result.listing, user.id)}


# One ad by id (the detail page): an active ad to anyone signed in, any state to
# its author. Anything else looks exactly like a missing one.
@router.get("/listings/{listing_id}")
def get_listing(listing_id: str) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    listing = container.marketplace_listing_repository.get(listing_id)
    if listing is None or (listing.status != "active" and listing.owner_id != user.id):
        raise HTTPException(status_code=404, detail="Annuncio non trovato.")
    row = _public_row(listing, user.id)
    if not owner_has_access():
        # The same fields as in the list (the distance is only in the list).
        return {"listing": limit_listing_row(row), "limited": True}
    return {"listing": row, "limited": False}


class ReportListingRequest(BaseModel):
    reason: ListingReportReason


# Reporting an ad is open to everyone signed in, with or without a plan (owner
# decision 2026-11-08): it is a safety tool, the only action left to someone
# without a plan. The auto-removal threshold is applied here, not by the app.
@router.post("/listings/{listing_id}/report")
def report_listing(listing_id: str, request: ReportListingRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.report_listing_service().execute(
        ReportListingInput(listing_id=listing_id, reporter_owner_id=user.id, reason=request.reason)
    )
    return {"report_count": result.listing.report_count, "status": result.listing.status}

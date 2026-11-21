from typing import Literal

from pydantic import BaseModel, Field


class SelectPlanRequest(BaseModel):
    plan: str = Field(max_length=20)


class VerifyPurchaseRequest(BaseModel):
    store: Literal["apple", "google"]
    # Apple: transaction id from StoreKit 2; Google: purchase token.
    store_subscription_id: str = Field(min_length=1, max_length=4096)
    product_id: str | None = Field(default=None, max_length=200)


class RestorePurchasesRequest(BaseModel):
    store: Literal["apple", "google"]
    store_subscription_ids: list[str] = Field(max_length=50)


class AppleNotificationRequest(BaseModel):
    signedPayload: str = Field(min_length=1, max_length=65536)  # noqa: N815 - Apple's field name

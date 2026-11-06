from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import utc_now


class UserDevice(BaseModel):
    """One install of the app signed in to an account. `device_id` is a
    random id the app generates at sign-in and keeps in its private storage;
    nothing else about the phone is stored. A device is "revoked" when a
    newer one took its place after the plan's device limit was reached."""

    owner_id: str
    device_id: str
    first_seen_at: datetime = Field(default_factory=utc_now)
    last_seen_at: datetime = Field(default_factory=utc_now)
    revoked_at: datetime | None = None

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None

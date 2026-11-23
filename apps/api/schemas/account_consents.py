from pydantic import BaseModel, Field


class SetAccountConsentRequest(BaseModel):
    consent_key: str = Field(max_length=64)
    granted: bool

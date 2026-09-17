from pydantic import BaseModel


class SetAccountConsentRequest(BaseModel):
    consent_key: str
    granted: bool

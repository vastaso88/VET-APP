from pydantic import BaseModel, Field


class SetAccountConsentRequest(BaseModel):
    consent_key: str = Field(max_length=64)
    granted: bool
    # The version of the text the app SHOWED (docs/compliance/04). An app that does not send it
    # is still served (the gap is counted in the log); one that sends another version than the
    # one in force records nothing and is told to show the current text.
    shown_version: str | None = Field(default=None, max_length=20)

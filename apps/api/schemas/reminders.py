from datetime import date

from pydantic import BaseModel, Field


class CreateReminderRequest(BaseModel):
    pet_id: str = Field(max_length=128)
    title: str = Field(max_length=120)
    due_date: date
    notes: str | None = Field(default=None, max_length=2000)

from pydantic import BaseModel


class SelectPlanRequest(BaseModel):
    plan: str

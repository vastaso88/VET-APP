from pydantic import BaseModel, Field


class SituationModel(BaseModel):
    """Structured, dynamic representation of the current case (spec v3 §10).

    This is NOT a diagnosis. It only tracks what is known/unknown about the
    case so far, to drive interview planning and coverage estimation.
    """

    species: str | None = None
    age: str | None = None
    presenting_problem: str | None = None
    onset: str | None = None
    contexts: list[str] = Field(default_factory=list)
    observed_behaviours: list[str] = Field(default_factory=list)
    associated_signs: list[str] = Field(default_factory=list)
    known_medical_context: str | None = None
    environmental_changes: list[str] = Field(default_factory=list)
    working_domains: list[str] = Field(default_factory=list)
    known_facts: list[str] = Field(default_factory=list)
    relevant_unknowns: list[str] = Field(default_factory=list)
    safety_critical_unknowns: list[str] = Field(default_factory=list)
    # Fields InterviewPlanner has already asked about in this conversation,
    # regardless of whether the answer actually filled them — extraction is
    # an LLM call and isn't guaranteed to populate a field just because the
    # owner answered (e.g. "no known conditions" often extracts to null
    # rather than a descriptive string). Without this, a field that never
    # gets filled would have the interview loop ask the identical question
    # every remaining turn instead of moving on or giving up gracefully.
    asked_interview_fields: list[str] = Field(default_factory=list)

    def merge(self, update: "SituationModel") -> "SituationModel":
        """Fold newly extracted fields into this model.

        Scalars are overwritten only when the update provides a non-null value
        (never erase something already known with a blank re-extraction).
        List fields are unioned, preserving order and skipping duplicates.
        """
        data = self.model_dump()
        for field, value in update.model_dump().items():
            if isinstance(value, list):
                merged = list(data[field])
                for item in value:
                    if item not in merged:
                        merged.append(item)
                data[field] = merged
            elif value is not None:
                data[field] = value
        return SituationModel.model_validate(data)

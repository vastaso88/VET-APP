from pydantic import BaseModel, Field


class Citation(BaseModel):
    source: str
    snippet: str | None = None


class EvidenceSource(BaseModel):
    title: str
    journal: str | None = None
    year: int | None = None
    doi: str | None = None
    pmid: str | None = None
    tier: str = "C"
    source_type: str = "scientific_reference"
    authority_level: str = "reviewed"
    trust_score: float = 0.6
    clinical_domain: str = "general"
    species: str = "other"
    snippet: str | None = None
    source_url: str | None = None
    update_frequency_days: int | None = None
    license_constraints: list[str] = Field(default_factory=list)

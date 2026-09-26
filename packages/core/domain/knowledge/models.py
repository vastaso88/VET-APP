from pydantic import BaseModel


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
    """Methodological/publication-type reliability (spec v3 §2, guideline >
    systematic review > RCT > ... > case report)."""
    access_depth: str = "C"
    """A distinct axis from `tier` (spec v3 §21): how much of the source we
    can actually see — A=full text legally accessible, B=guideline/
    consensus document, C=metadata/abstract only, D=secondary
    professional/owner-facing content. Deliberately not reusing the same
    A-D letters' meaning as `tier`."""
    clinical_domain: str = "general"
    species: str = "other"
    snippet: str | None = None
    source_url: str | None = None

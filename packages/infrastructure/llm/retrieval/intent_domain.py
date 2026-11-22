"""Mapping shared by the scientific-source adapters (Crossref, Europe PMC,
OpenAlex, PubMed): the chat intent becomes the `clinical_domain` stored on
each retrieved `EvidenceSource`."""

_DOMAIN_BY_INTENT: dict[str, str] = {
    "clinical_question": "clinical",
    "nutrition_question": "nutrition",
    "behavior_question": "behavior",
    "preventive_care": "preventive",
}

GENERAL_DOMAIN = "general"


def domain_from_intent(intent: str) -> str:
    return _DOMAIN_BY_INTENT.get(intent, GENERAL_DOMAIN)

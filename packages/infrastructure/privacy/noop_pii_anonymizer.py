from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)


class NoopPiiAnonymizer:
    """Pass-through anonymizer: returns the text unchanged.

    Used as the default in tests/CI so they don't depend on the spaCy model
    download, and as a safe fallback outside production if Presidio isn't
    installed (mirrors EchoLLMClient's role for the LLM port).
    """

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        return PiiAnonymizationResult(anonymized_text=request.text, redaction_count=0)

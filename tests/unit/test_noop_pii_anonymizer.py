from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


def test_noop_pii_anonymizer_returns_text_unchanged() -> None:
    anonymizer = NoopPiiAnonymizer()

    result = anonymizer.anonymize(
        PiiAnonymizationRequest(text="Chiamami al 0491234567, sono Mario Rossi")
    )

    assert result.anonymized_text == "Chiamami al 0491234567, sono Mario Rossi"
    assert result.redaction_count == 0

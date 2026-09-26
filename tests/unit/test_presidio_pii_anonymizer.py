import pytest

pytest.importorskip("presidio_analyzer")

from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest  # noqa: E402
from packages.infrastructure.privacy.presidio_pii_anonymizer import (  # noqa: E402
    PresidioPiiAnonymizer,
)


def _build_anonymizer() -> PresidioPiiAnonymizer:
    try:
        return PresidioPiiAnonymizer()
    except OSError as exc:
        pytest.skip(f"spaCy Italian model not installed: {exc}")


def test_presidio_pii_anonymizer_redacts_email_and_name() -> None:
    anonymizer = _build_anonymizer()

    result = anonymizer.anonymize(
        PiiAnonymizationRequest(text="Sono Mario Rossi, scrivimi a mario.rossi@example.com")
    )

    assert result.redaction_count > 0
    assert "mario.rossi@example.com" not in result.anonymized_text

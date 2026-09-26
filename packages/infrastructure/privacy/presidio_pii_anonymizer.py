from presidio_analyzer import AnalyzerEngine, Pattern, PatternRecognizer
from presidio_analyzer.nlp_engine import NlpEngineProvider
from presidio_anonymizer import AnonymizerEngine

from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)

DEFAULT_SPACY_MODEL = "it_core_news_lg"


class PresidioPiiAnonymizer:
    """Local/offline PII detection and anonymization, backed by Microsoft
    Presidio + a spaCy Italian NLP model. Runs entirely on-device: no text
    leaves the process for this step.

    Construct once and reuse — loading the spaCy model is slow, so this must
    be a singleton (built once in the application container), never built
    per-request.
    """

    def __init__(self, *, spacy_model: str = DEFAULT_SPACY_MODEL) -> None:
        nlp_engine = NlpEngineProvider(
            nlp_configuration={
                "nlp_engine_name": "spacy",
                "models": [{"lang_code": "it", "model_name": spacy_model}],
            }
        ).create_engine()

        self._analyzer = AnalyzerEngine(nlp_engine=nlp_engine, supported_languages=["it"])
        for recognizer in self._build_italian_recognizers():
            self._analyzer.registry.add_recognizer(recognizer)
        self._anonymizer = AnonymizerEngine()

    def _build_italian_recognizers(self) -> list[PatternRecognizer]:
        """Presidio's built-in recognizers (PERSON via spaCy NER,
        EMAIL_ADDRESS, generic PHONE_NUMBER, ...) already work for Italian
        text through the spaCy IT model, and are registered automatically.
        These two patterns cover Italian-specific formats the generic
        recognizers miss or under-match.
        """
        # Codice fiscale: 6 letters + 2 digits + 1 month letter (only
        # A/B/C/D/E/H/L/M/P/R/S/T are valid month codes) + 2 digits +
        # 1 letter + 3 digits + 1 checksum letter — a fixed, distinctive
        # 16-char structure, so a fairly strict regex still has good
        # recall while keeping false positives low (a looser "any 16
        # alphanumeric chars" pattern would flag order/tracking numbers,
        # API keys, etc. as PII).
        codice_fiscale = PatternRecognizer(
            supported_entity="IT_CODICE_FISCALE",
            supported_language="it",
            patterns=[
                Pattern(
                    name="codice_fiscale_pattern",
                    regex=(
                        r"\b[A-Za-z]{6}[0-9]{2}[ABCDEHLMPRSTabcdehlmprst]"
                        r"[0-9]{2}[A-Za-z][0-9]{3}[A-Za-z]\b"
                    ),
                    score=0.85,
                )
            ],
            context=["codice fiscale", "cf", "c.f."],
        )
        # Italian mobile numbers (the common case in vet-owner chat: "richiamami
        # al ..."), optionally with a +39 prefix. Kept separate from Presidio's
        # generic PHONE_NUMBER recognizer, which is tuned for other locales and
        # under-matches this shape; scored lower than the codice fiscale
        # pattern since a bare 9-10 digit run starting with 3 is a weaker,
        # more ambiguous signal.
        it_mobile_phone = PatternRecognizer(
            supported_entity="IT_PHONE_NUMBER",
            supported_language="it",
            patterns=[
                Pattern(
                    name="it_mobile_phone_pattern",
                    regex=r"\b(?:\+39\s?)?3\d{2}[\s./-]?\d{6,7}\b",
                    score=0.6,
                )
            ],
            context=["telefono", "cellulare", "numero", "chiamami", "richiamami"],
        )
        return [codice_fiscale, it_mobile_phone]

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        results = self._analyzer.analyze(text=request.text, language=request.language)
        # presidio-analyzer and presidio-anonymizer each ship their own
        # RecognizerResult class; they're structurally identical (this is
        # the documented way to wire the two packages together) but mypy
        # sees two distinct types.
        anonymized = self._anonymizer.anonymize(
            text=request.text, analyzer_results=results  # type: ignore[arg-type]
        )
        entity_types = sorted({result.entity_type for result in results})
        return PiiAnonymizationResult(
            anonymized_text=anonymized.text,
            redaction_count=len(results),
            entity_types_found=entity_types,
        )

from presidio_analyzer import AnalyzerEngine, PatternRecognizer
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
        text through the spaCy IT model, and are registered automatically —
        the adapter is functional without anything added here.

        # TODO(human): add PatternRecognizer(s) for Italian-specific PII
        # formats that the generic recognizers miss or under-match, most
        # notably the codice fiscale (16 fixed-structure alphanumeric
        # chars, e.g. RSSMRA85M01H501Z). Return them from this method —
        # they'll be registered automatically in __init__.
        #
        # Trade-off to weigh: a stricter regex catches fewer real codici
        # fiscali but also fewer false positives (e.g. an unrelated 16-char
        # alphanumeric token); a looser one is more forgiving of odd
        # formatting/casing but risks redacting things that aren't PII.
        # supported_language must be "it" to match this adapter's locale.
        return []

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        results = self._analyzer.analyze(text=request.text, language=request.language)
        anonymized = self._anonymizer.anonymize(text=request.text, analyzer_results=results)
        entity_types = sorted({result.entity_type for result in results})
        return PiiAnonymizationResult(
            anonymized_text=anonymized.text,
            redaction_count=len(results),
            entity_types_found=entity_types,
        )

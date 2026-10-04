from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest, PiiAnonymizer

# Lets a test double (or EchoLLMClient) recognise this call, same idea as
# EvidenceSynthesizer.SYNTHESIS_MARKER.
DOCUMENT_SUMMARY_MARKER = "transcribing a veterinary document"

# How much extracted text is handed to the model: a lab report's useful
# content sits in its first pages, and this keeps one upload's cost bounded.
MAX_DOCUMENT_TEXT_CHARS = 12_000


class DocumentSummarizer:
    """Turns the raw text of an uploaded clinical document into the compact
    transcription stored on the attachment (`ChatAttachment.analysis`) —
    the text-PDF counterpart of what the vision model produces for a
    photographed document.
    """

    def __init__(self, llm_client: LLMClient, pii_anonymizer: PiiAnonymizer) -> None:
        self._llm_client = llm_client
        self._pii_anonymizer = pii_anonymizer

    def summarize(
        self, document_text: str, species: str, known_person_names: list[str] | None = None
    ) -> str:
        """Raises ProviderError when the LLM provider is unavailable."""
        outbound = self._pii_anonymizer.anonymize(
            PiiAnonymizationRequest(
                text=document_text[:MAX_DOCUMENT_TEXT_CHARS],
                known_person_names=known_person_names or [],
            )
        ).anonymized_text
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=(
                    f"You are a veterinary assistant {DOCUMENT_SUMMARY_MARKER} an owner "
                    "uploaded to their pet's medical records. Transcribe its relevant "
                    "content faithfully in Italian as compact plain text, up to about 12 "
                    "lines: document type, date, the values/findings with their units "
                    "and reference ranges, therapies prescribed, and the written "
                    "conclusions. Copy what is written: never interpret it, never add or "
                    "correct a value, never give advice. Omit names of people, "
                    "addresses, phone numbers and tax codes. If the text is not a "
                    "clinical document, say so in one line."
                ),
                user_prompt=f"Species: {species}\nDocument text:\n{outbound}",
                max_tokens=900,
            )
        )
        return response.content.strip()

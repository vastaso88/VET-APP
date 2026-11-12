from pydantic import BaseModel

from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.core.application.services.llm_budget import LlmBudget, require_feature_allowance


class TranscribeAudioInput(BaseModel):
    audio_bytes: bytes
    filename: str
    content_type: str
    # For the per-owner daily allowance (security audit BE-4): who asks,
    # whether the account is exempt, the language of the refusal.
    owner_id: str = ""
    quota_exempt: bool = False
    language: str = "it"


class TranscribeAudioOutput(BaseModel):
    text: str


class TranscribeAudioService:
    """Voice dictation (spec: user dictates a question instead of typing
    it) — a standalone utility, not part of ChatOrchestrator: the
    transcribed text is handed back to the client to populate the message
    field, then sent through the normal /chat flow like any typed
    message, rather than being a distinct chat input path of its own.
    """

    def __init__(
        self,
        provider: SpeechToTextProvider,
        *,
        budget: LlmBudget | None = None,
        daily_limit: int = 0,
    ) -> None:
        self._provider = provider
        self._budget = budget
        self._daily_limit = daily_limit

    def execute(self, data: TranscribeAudioInput) -> TranscribeAudioOutput:
        require_feature_allowance(
            self._budget,
            owner_id=data.owner_id,
            kind="dictation",
            limit=self._daily_limit,
            exempt=data.quota_exempt,
            language=data.language,
        )
        text = self._provider.transcribe(data.audio_bytes, data.filename, data.content_type)
        return TranscribeAudioOutput(text=text)

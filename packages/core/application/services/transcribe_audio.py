from pydantic import BaseModel

from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.core.application.services.llm_budget import (
    LlmBudget,
    refund_if_our_failure,
    require_feature_allowance,
)
from packages.core.domain.localization import translate


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
    # True when the recording had no speech (silence, or only what the recogniser invents out
    # of it): [text] is then empty and [message] says so in the owner's language.
    heard_nothing: bool = False
    message: str | None = None


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
        with refund_if_our_failure(self._budget):
            result = self._execute(data)
        if self._budget is not None:
            # Delivered (a text, or "I heard nothing"): the use is final.
            self._budget.commit_request_quota_uses()
        return result

    def _execute(self, data: TranscribeAudioInput) -> TranscribeAudioOutput:
        require_feature_allowance(
            self._budget,
            owner_id=data.owner_id,
            kind="dictation",
            limit=self._daily_limit,
            exempt=data.quota_exempt,
            language=data.language,
        )
        text = self._provider.transcribe(data.audio_bytes, data.filename, data.content_type)
        if not text.strip():
            return TranscribeAudioOutput(
                text="",
                heard_nothing=True,
                message=translate("dictation_heard_nothing", data.language),
            )
        return TranscribeAudioOutput(text=text)

from fastapi import APIRouter, File, Header, UploadFile

from apps.api.dependencies.container import get_container
from packages.core.application.services.transcribe_audio import TranscribeAudioInput
from packages.core.domain.common.language import resolve_language
from packages.shared.errors.base import ValidationError

router = APIRouter(prefix="/speech-to-text", tags=["speech-to-text"])

# A dictated question is seconds long; 4 MB is roughly a minute of
# uncompressed audio and well under the serverless body ceiling.
MAX_AUDIO_BYTES = 4 * 1024 * 1024


@router.post("")
async def transcribe(
    file: UploadFile = File(...), accept_language: str | None = Header(default=None)
) -> dict[str, object]:
    container = get_container()
    # Nothing is persisted and nothing is scoped by owner; the user is
    # needed for the uniform access gate and for the daily allowance
    # (security audit BE-4: dictation used to be outside every quota).
    user = container.auth_provider.get_current_user()
    audio_bytes = await file.read(MAX_AUDIO_BYTES + 1)
    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise ValidationError("audio too large (max 4 MB)")
    if not audio_bytes:
        raise ValidationError("audio is empty")
    result = container.transcribe_audio_service().execute(
        TranscribeAudioInput(
            audio_bytes=audio_bytes,
            filename=file.filename or "audio",
            content_type=file.content_type or "application/octet-stream",
            owner_id=user.id,
            quota_exempt=user.email.strip().lower() in container.developer_emails,
            language=resolve_language(None, accept_language),
        )
    )
    return result.model_dump()

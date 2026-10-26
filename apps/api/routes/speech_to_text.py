from fastapi import APIRouter, File, UploadFile

from apps.api.dependencies.container import get_container
from packages.core.application.services.transcribe_audio import TranscribeAudioInput
from packages.shared.errors.base import ValidationError

router = APIRouter(prefix="/speech-to-text", tags=["speech-to-text"])

# A dictated question is seconds long; 4 MB is roughly a minute of
# uncompressed audio and well under the serverless body ceiling.
MAX_AUDIO_BYTES = 4 * 1024 * 1024


@router.post("")
async def transcribe(file: UploadFile = File(...)) -> dict[str, object]:
    container = get_container()
    # No per-user data involved (nothing persisted, no owner scoping) —
    # still goes through auth for the same uniform access gate every
    # other endpoint has, not because this result needs to be scoped.
    container.auth_provider.get_current_user()
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
        )
    )
    return result.model_dump()

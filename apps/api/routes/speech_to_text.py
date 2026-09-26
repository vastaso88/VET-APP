from fastapi import APIRouter, File, UploadFile

from apps.api.dependencies.container import get_container
from packages.core.application.services.transcribe_audio import TranscribeAudioInput

router = APIRouter(prefix="/speech-to-text", tags=["speech-to-text"])


@router.post("")
async def transcribe(file: UploadFile = File(...)) -> dict[str, object]:
    container = get_container()
    # No per-user data involved (nothing persisted, no owner scoping) —
    # still goes through auth for the same uniform access gate every
    # other endpoint has, not because this result needs to be scoped.
    container.auth_provider.get_current_user()
    audio_bytes = await file.read()
    result = container.transcribe_audio_service().execute(
        TranscribeAudioInput(
            audio_bytes=audio_bytes,
            filename=file.filename or "audio",
            content_type=file.content_type or "application/octet-stream",
        )
    )
    return result.model_dump()

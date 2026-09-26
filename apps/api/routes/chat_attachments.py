from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

from apps.api.dependencies.container import get_container
from packages.core.application.services.upload_chat_attachment import UploadChatAttachmentInput

router = APIRouter(prefix="/chat-attachments", tags=["chat-attachments"])


@router.post("")
async def upload_attachment(
    pet_id: str = Form(...), file: UploadFile = File(...)
) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    file_bytes = await file.read()
    result = container.upload_chat_attachment_service().execute(
        UploadChatAttachmentInput(
            owner_id=user.id,
            pet_id=pet_id,
            file_bytes=file_bytes,
            filename=file.filename or "photo",
            content_type=file.content_type or "application/octet-stream",
        )
    )
    return result.model_dump()


@router.get("/{attachment_id}/file")
def get_attachment_file(attachment_id: str) -> Response:
    container = get_container()
    user = container.auth_provider.get_current_user()
    attachment = container.chat_attachment_repository.get(attachment_id)
    if attachment is None or attachment.owner_id != user.id:
        # Same response for "not found" and "not yours" — never confirm
        # to a caller that a given id exists but belongs to someone else.
        raise HTTPException(status_code=404, detail="attachment not found")
    content = container.media_storage.read(attachment.storage_key)
    if content is None:
        raise HTTPException(status_code=404, detail="attachment file not found")
    return Response(content=content, media_type=attachment.content_type)

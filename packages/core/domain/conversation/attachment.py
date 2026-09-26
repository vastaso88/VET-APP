from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now


class ChatAttachment(BaseModel):
    """A photo an owner attaches to a chat message, so the AI can factor
    in what it actually shows (visible skin/coat condition, a wound, an
    enclosure...) rather than the owner having to describe it entirely in
    words.

    Deliberately separate from PetProfile and from any memorial/gallery
    feature: this is conversation-scoped content, not something that
    should ever surface in a pet's photo gallery unless the owner
    explicitly chooses to save it there themselves — nothing in this
    codebase links a ChatAttachment to a gallery, and it should stay that
    way.

    `conversation_id` starts null: the owner may attach a photo before a
    conversation officially exists yet (a brand new chat) — it's filled
    in once the attachment is actually referenced in a sent message (see
    SendChatMessageService), scoped by `pet_id` until then.
    """

    id: str = Field(default_factory=new_id)
    owner_id: str
    pet_id: str
    conversation_id: str | None = None
    storage_key: str
    content_type: str
    original_filename: str
    analysis: str | None = None
    """Plain-text visual description from ImageAnalyzer, folded into the
    chat's case context as though the owner had described it in words —
    never a diagnosis, see GroqImageAnalyzer's system prompt."""
    analysis_failed: bool = False
    created_at: datetime = Field(default_factory=utc_now)

from pathlib import Path

from packages.core.application.ports.media_storage import MediaStorage
from packages.shared.config.settings import Settings


class LocalFileStorage(MediaStorage):
    """Chat attachments are stored on local disk, not an external
    service (product decision: keep the MVP simple and avoid taking on a
    cloud storage dependency for this). `key` is always an id this
    codebase generates itself (ChatAttachment.id, from new_id()), never
    raw user input, but path separators are still stripped defensively
    before touching the filesystem.
    """

    def __init__(self, settings: Settings) -> None:
        self._base_dir = Path(settings.media_storage_dir)
        self._base_dir.mkdir(parents=True, exist_ok=True)

    def save(self, key: str, content: bytes) -> None:
        self._resolve(key).write_bytes(content)

    def read(self, key: str) -> bytes | None:
        path = self._resolve(key)
        if not path.is_file():
            return None
        return path.read_bytes()

    def _resolve(self, key: str) -> Path:
        safe_key = key.replace("..", "").replace("/", "").replace("\\", "")
        return self._base_dir / safe_key

from typing import Protocol


class MediaStorage(Protocol):
    def save(self, key: str, content: bytes) -> None: ...

    def read(self, key: str) -> bytes | None: ...

    def delete(self, key: str) -> None:
        """Removes the object; a missing key is not an error."""
        ...

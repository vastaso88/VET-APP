from typing import Protocol


class MediaStorage(Protocol):
    def save(self, key: str, content: bytes) -> None: ...

    def read(self, key: str) -> bytes | None: ...

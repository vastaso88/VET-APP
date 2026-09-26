from pathlib import Path

from packages.infrastructure.storage.local_file_storage import LocalFileStorage
from packages.shared.config.settings import Settings


def _storage(tmp_path: Path) -> LocalFileStorage:
    return LocalFileStorage(Settings(MEDIA_STORAGE_DIR=str(tmp_path / "attachments")))


def test_round_trips_saved_content(tmp_path: Path) -> None:
    storage = _storage(tmp_path)

    storage.save("abc123", b"fake-image-bytes")

    assert storage.read("abc123") == b"fake-image-bytes"


def test_reading_an_unknown_key_returns_none(tmp_path: Path) -> None:
    storage = _storage(tmp_path)

    assert storage.read("missing") is None


def test_creates_the_base_directory_if_it_does_not_exist(tmp_path: Path) -> None:
    target = tmp_path / "does" / "not" / "exist"

    storage = LocalFileStorage(Settings(MEDIA_STORAGE_DIR=str(target)))
    storage.save("key", b"data")

    assert target.is_dir()
    assert storage.read("key") == b"data"


def test_strips_path_separators_from_the_key(tmp_path: Path) -> None:
    # Defensive: keys are always ids this codebase generates itself, but
    # a traversal attempt must still not escape the base directory.
    base_dir = tmp_path / "attachments"
    storage = LocalFileStorage(Settings(MEDIA_STORAGE_DIR=str(base_dir)))

    storage.save("../../escape", b"data")

    assert not (tmp_path / "escape").exists()
    assert list(base_dir.iterdir()) == [base_dir / "escape"]
    assert storage.read("../../escape") == b"data"

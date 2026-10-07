"""The retroactive cleanup of stored images, against a fake bucket."""

from pathlib import Path
from typing import Any

from test_media_privacy import (
    pdf_with_metadata,
    phone_jpeg,
    png_with_metadata,
    webp_with_metadata,
)

from packages.core.domain.conversation.media_privacy import strip_image_metadata
from packages.core.domain.conversation.media_type import JPEG, PNG, WEBP
from packages.infrastructure.documents.pypdf_reader import PypdfReader
from packages.infrastructure.storage.media_metadata_cleanup import (
    BucketReport,
    CleanupState,
    image_has_gps,
    inspect_image,
    is_complete_image,
    iter_objects,
    object_fingerprint,
    pdf_has_metadata,
    process_bucket,
)

CLEAN_JPEG = strip_image_metadata(phone_jpeg(orientation=1), JPEG)
VIDEO_BYTES = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64


class FakeBucket:
    """A bucket as Supabase lists it: one level at a time, folders have id None."""

    def __init__(self, files: dict[str, bytes], mimetypes: dict[str, str] | None = None) -> None:
        self.files = dict(files)
        self.mimetypes = mimetypes or {}
        self.uploads: list[tuple[str, str]] = []
        self.downloads: list[str] = []
        self.fail_downloads: set[str] = set()

    def list_entries(self, prefix: str, offset: int, limit: int) -> list[dict[str, Any]]:
        depth = len(prefix.split("/")) if prefix else 0
        names: dict[str, bool] = {}  # name -> is_folder
        for path in sorted(self.files):
            parts = path.split("/")
            if prefix and not path.startswith(prefix + "/"):
                continue
            if len(parts) <= depth:
                continue
            names[parts[depth]] = len(parts) > depth + 1
        entries: list[dict[str, Any]] = []
        for name, is_folder in names.items():
            if is_folder:
                entries.append({"name": name, "id": None})
            else:
                full = f"{prefix}/{name}" if prefix else name
                entries.append(
                    {
                        "name": name,
                        "id": f"id-{full}",
                        "metadata": {
                            "size": len(self.files[full]),
                            "mimetype": self.mimetypes.get(full),
                        },
                    }
                )
        return entries[offset : offset + limit]

    def download(self, path: str) -> bytes:
        self.downloads.append(path)
        if path in self.fail_downloads:
            raise RuntimeError("boom")
        return self.files[path]

    def upload(self, path: str, content: bytes, content_type: str) -> None:
        self.files[path] = content
        self.uploads.append((path, content_type))


def _run(
    bucket: FakeBucket, *, apply: bool, state: CleanupState | None = None, **kwargs: Any
) -> BucketReport:
    return process_bucket(
        bucket,
        "pet-photos",
        apply=apply,
        state=state if state is not None else CleanupState(),
        **kwargs,
    )


# --- seeing what is in an image -------------------------------------------------


def test_the_fixture_really_carries_gps_and_the_cleaner_removes_it() -> None:
    original = phone_jpeg()

    inspection = inspect_image(original, JPEG)

    assert inspection.has_metadata and inspection.has_gps
    assert inspection.safe_to_write
    assert not image_has_gps(inspection.cleaned, JPEG)
    assert b"TelefonoDiProva" not in inspection.cleaned


def test_gps_is_found_in_png_and_webp_too() -> None:
    assert inspect_image(webp_with_metadata(), WEBP).has_gps
    assert inspect_image(png_with_metadata(), PNG).has_metadata


def test_an_already_clean_image_is_left_alone() -> None:
    inspection = inspect_image(CLEAN_JPEG, JPEG)

    assert not inspection.has_metadata
    assert not inspection.has_gps
    assert not inspection.safe_to_write


def test_cleaning_is_idempotent_including_the_orientation_only_exif() -> None:
    once = inspect_image(phone_jpeg(orientation=6), JPEG).cleaned

    again = inspect_image(once, JPEG)

    assert not again.has_metadata, "a cleaned file must not be rewritten forever"


def test_a_truncated_cleaning_result_is_never_judged_safe() -> None:
    corrupt = phone_jpeg()[:60]  # cut inside the EXIF: the cleaner stops where it understood

    inspection = inspect_image(corrupt, JPEG)

    assert not is_complete_image(inspection.cleaned, JPEG)
    assert not inspection.safe_to_write


# --- walking a bucket -----------------------------------------------------------


def test_objects_are_found_through_folders_and_pages() -> None:
    files = {f"owner/pet/{index}.jpg": b"x" for index in range(7)}
    files["flat.bin"] = b"y"
    files["owner/pet/.emptyFolderPlaceholder"] = b""

    found = sorted(info.path for info in iter_objects(FakeBucket(files), page_size=3))

    assert found == sorted([*(f"owner/pet/{i}.jpg" for i in range(7)), "flat.bin"])


# --- dry run --------------------------------------------------------------------


def test_dry_run_counts_and_writes_nothing() -> None:
    bucket = FakeBucket(
        {
            "o/p/gps.jpg": phone_jpeg(),
            "o/p/clean.jpg": CLEAN_JPEG,
            "o/p/png.png": png_with_metadata(),
            "o/p/doc.pdf": pdf_with_metadata(),
            "o/p/clip.mp4": VIDEO_BYTES,
            "o/p/notes.txt": b"ciao",
        }
    )
    before = dict(bucket.files)
    state = CleanupState()

    report = _run(bucket, apply=False, state=state)

    assert report.images == 3
    assert report.images_with_metadata == 2
    assert report.images_with_gps == 1
    assert report.pdfs == 1
    assert report.videos_skipped == 1
    assert report.other == 1
    assert report.images_cleaned == 0
    assert bucket.uploads == []
    assert bucket.files == before
    assert len(state) == 0, "a dry run must not mark anything as done"
    assert "o/p/clip.mp4" not in bucket.downloads, "videos are not even downloaded"


# --- apply ----------------------------------------------------------------------


def test_apply_overwrites_only_images_that_really_had_metadata() -> None:
    bucket = FakeBucket({"o/p/gps.jpg": phone_jpeg(), "o/p/clean.jpg": CLEAN_JPEG})

    report = _run(bucket, apply=True)

    assert report.images_cleaned == 1
    assert [path for path, _ in bucket.uploads] == ["o/p/gps.jpg"]
    assert bucket.uploads[0][1] == JPEG
    assert not image_has_gps(bucket.files["o/p/gps.jpg"], JPEG)
    assert bucket.files["o/p/clean.jpg"] == CLEAN_JPEG


def test_apply_never_touches_videos_or_pdfs_by_default() -> None:
    pdf = pdf_with_metadata()
    bucket = FakeBucket({"o/p/clip.mov": VIDEO_BYTES, "o/p/doc.pdf": pdf})

    report = _run(bucket, apply=True)

    assert bucket.uploads == []
    assert bucket.files["o/p/doc.pdf"] == pdf
    assert report.pdfs == 1 and report.pdfs_cleaned == 0


def test_a_file_that_cannot_be_cleaned_safely_is_left_exactly_as_it_was() -> None:
    corrupt = phone_jpeg()[:60]
    bucket = FakeBucket({"o/p/broken.jpg": corrupt})

    report = _run(bucket, apply=True)

    assert bucket.files["o/p/broken.jpg"] == corrupt
    assert bucket.uploads == []
    assert report.images_unsafe == 1
    assert report.needs_attention


def test_a_failing_download_is_counted_and_does_not_stop_the_run() -> None:
    bucket = FakeBucket({"o/p/a.jpg": phone_jpeg(), "o/p/b.jpg": phone_jpeg()})
    bucket.fail_downloads.add("o/p/a.jpg")

    report = _run(bucket, apply=True)

    assert report.errors == 1
    assert report.images_cleaned == 1
    assert report.needs_attention


def test_a_file_without_extension_is_recognised_by_its_bytes() -> None:
    # chat-attachments keys are bare ids, stored without a usable content type.
    bucket = FakeBucket({"3f9a-attachment-id": phone_jpeg()}, {"3f9a-attachment-id": "text/plain"})

    report = _run(bucket, apply=True)

    assert report.images_cleaned == 1


def test_oversized_objects_are_skipped_without_downloading() -> None:
    bucket = FakeBucket({"o/p/huge.jpg": phone_jpeg()})

    report = _run(bucket, apply=True, max_bytes=10)

    assert report.too_big_skipped == 1
    assert bucket.downloads == []


def test_limit_caps_the_number_of_objects_examined() -> None:
    bucket = FakeBucket({f"o/p/{i}.jpg": phone_jpeg() for i in range(5)})

    report = _run(bucket, apply=True, limit=2)

    assert report.images_cleaned == 2


# --- resuming -------------------------------------------------------------------


def test_a_rerun_skips_what_an_interrupted_run_already_finished(tmp_path: Path) -> None:
    state_file = tmp_path / "state.json"
    bucket = FakeBucket({f"o/p/{i}.jpg": phone_jpeg() for i in range(4)})

    first = _run(bucket, apply=True, state=CleanupState(state_file), limit=2)
    assert first.images_cleaned == 2

    second = _run(bucket, apply=True, state=CleanupState(state_file))

    assert second.already_done == 2
    assert second.images_cleaned == 2
    assert len(bucket.uploads) == 4, "no object is written twice"


def test_the_resume_file_holds_hashes_not_paths(tmp_path: Path) -> None:
    state_file = tmp_path / "state.json"
    bucket = FakeBucket({"owner-123/pet-456/photo.jpg": phone_jpeg()})

    _run(bucket, apply=True, state=CleanupState(state_file))

    saved = state_file.read_text(encoding="utf-8")
    assert "owner-123" not in saved and "pet-456" not in saved
    assert object_fingerprint("pet-photos", "owner-123/pet-456/photo.jpg") in saved


def test_the_report_names_no_owner_pet_or_file() -> None:
    bucket = FakeBucket({"owner-123/pet-456/broken.jpg": phone_jpeg()[:60]})
    bucket.fail_downloads.add("owner-123/pet-456/broken.jpg")

    report = _run(bucket, apply=False)

    text = " ".join(report.problems)
    assert "owner-123" not in text and "pet-456" not in text and "broken" not in text
    assert text, "the problem is still described, by hash"


# --- PDFs, on request -----------------------------------------------------------


def test_pdf_metadata_is_detected_and_cleaned_only_with_the_flag() -> None:
    pdf = pdf_with_metadata()
    assert pdf_has_metadata(pdf)
    cleaner = PypdfReader().strip_metadata

    dry = _run(FakeBucket({"o/p/doc.pdf": pdf}), apply=False, include_pdf=True, pdf_cleaner=cleaner)
    assert dry.pdfs_with_metadata == 1 and dry.pdfs_cleaned == 0

    bucket = FakeBucket({"o/p/doc.pdf": pdf})
    applied = _run(bucket, apply=True, include_pdf=True, pdf_cleaner=cleaner)

    assert applied.pdfs_cleaned == 1
    assert not pdf_has_metadata(bucket.files["o/p/doc.pdf"])

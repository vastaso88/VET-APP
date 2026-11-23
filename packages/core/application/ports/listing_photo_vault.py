from typing import Protocol


class ListingPhotoVault(Protocol):
    """Where the photos of an ad the team took down wait for a review: out of the public
    bucket, whose links work for anyone who has them."""

    def paths(self, owner_id: str, photo_urls: list[str]) -> list[str]:
        """The stored files behind these links. A link outside the owner's own folder is
        not theirs to move or delete, and is left out."""
        ...

    def withhold(self, paths: list[str]) -> None:
        """Public to private. A file that is not public any more is skipped."""
        ...

    def release(self, paths: list[str]) -> None:
        """Private to public, after an accepted review. A file not held is skipped."""
        ...

    def signed_urls(self, paths: list[str]) -> list[str]:
        """Short links for the team to look at the files held."""
        ...

    def held_paths(self) -> list[str]: ...

    def purge(self, paths: list[str]) -> int:
        """Deletes them for good, wherever they are; how many were asked for."""
        ...

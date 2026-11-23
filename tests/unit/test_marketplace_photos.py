"""Where the photos of an ad may come from (K23). Synthetic data only."""

import pytest

from packages.core.domain.marketplace.photos import (
    LOCAL_PHOTO_BASE,
    PHOTO_LINK_MAX_LENGTH,
    is_plain_name,
    mentioned_paths,
    owner_links,
    photo_base,
    photo_link,
    published_links,
    published_path,
    stored_paths,
    upload_path,
)

BASE = "https://project.supabase.example.com"
OWNER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"
PATH = f"{OWNER}/listing-1/1763900000-a1b2.jpg"
PUBLIC = "/storage/v1/object/public/marketplace-photos/"
LINK = f"{BASE}{PUBLIC}{PATH}"

REFUSED = {
    "another site": "https://example.com/1.jpg",
    "another site with the same path": f"https://example.com{PUBLIC}{PATH}",
    "the address as a user name": f"{BASE}@example.com{PUBLIC}{PATH}",
    "the address as a subdomain": f"{BASE}.example.com{PUBLIC}{PATH}",
    "the address in the query": f"https://example.com/?{LINK}",
    "another port": f"{BASE}:8443{PUBLIC}{PATH}",
    "http": LINK.replace("https://", "http://"),
    "no scheme": LINK.removeprefix("https:"),
    "data": "data:image/jpeg;base64,AAAA",
    "javascript": "javascript:alert(1)",
    "file": "file:///etc/passwd",
    "memory": "memory://listing-1/1",
    "another bucket": LINK.replace("marketplace-photos", "pet-photos"),
    "the private bucket": LINK.replace("marketplace-photos", "marketplace-photos-held"),
    "a signed link": LINK.replace("/public/", "/sign/"),
    "another owner": LINK.replace(OWNER, OTHER),
    "another owner's path": PATH.replace(OWNER, OTHER),
    "up and into another folder": f"{BASE}{PUBLIC}{OWNER}/../{OTHER}/1.jpg",
    "up, encoded": f"{BASE}{PUBLIC}{OWNER}/%2e%2e/1.jpg",
    "up, from the path": f"{OWNER}/../x/1.jpg",
    "a backslash": f"{OWNER}/listing-1\\..\\1.jpg",
    "an encoded slash": f"{OWNER}/listing-1%2f1.jpg",
    "a double slash": f"{OWNER}//1.jpg",
    "too short": f"{OWNER}/1.jpg",
    "too deep": f"{OWNER}/a/b/1.jpg",
    "a query": f"{LINK}?to=https://example.com",
    "a fragment": f"{LINK}#x",
    "another type": LINK.replace(".jpg", ".svg"),
    "a new line": f"{LINK}\n",
    "a leading space": f" {LINK}",
    "empty": "",
}


AD = "33333333-3333-4333-8333-333333333333"
COPY = f"published/{AD}/44444444-4444-4444-8444-444444444444.jpg"
COPY_LINK = f"{BASE}{PUBLIC}{COPY}"


@pytest.mark.parametrize("link", REFUSED.values(), ids=REFUSED.keys())
def test_anything_but_the_sellers_own_photo_is_refused(link: str) -> None:
    assert upload_path(link, OWNER, BASE) is None
    assert published_path(link, AD, BASE) is None
    assert stored_paths([link, LINK, COPY_LINK], AD, OWNER, BASE) == [PATH, COPY]
    assert published_links([link, COPY_LINK], AD, BASE) == [COPY_LINK]


@pytest.mark.parametrize("link", [LINK, PATH])
def test_an_upload_of_the_seller_is_recognised(link: str) -> None:
    assert upload_path(link, OWNER, BASE) == PATH
    assert len(photo_link(PATH, BASE)) < PHOTO_LINK_MAX_LENGTH


def test_other_people_are_shown_the_copies_only_the_seller_the_old_uploads_too() -> None:
    links = [LINK, COPY_LINK, COPY_LINK, "https://example.com/1.jpg"]

    assert published_links(links, AD, BASE) == [COPY_LINK]
    assert owner_links(links, AD, OWNER, BASE) == [LINK, COPY_LINK]


def test_a_copy_belongs_to_one_ad_only() -> None:
    other = "55555555-5555-4555-8555-555555555555"

    assert published_path(COPY_LINK, AD, BASE) == COPY
    assert published_links([COPY_LINK], other, BASE) == []
    assert published_links([COPY_LINK], "", BASE) == []


def test_user_b_owns_none_of_it() -> None:
    assert upload_path(LINK, OTHER, BASE) is None and upload_path(LINK, "", BASE) is None


def test_no_choice_of_ids_turns_an_upload_into_a_copy() -> None:
    """A row written straight into the database may have the seller's id as its own, or an
    account (there is none) could be called like the folder of the copies."""
    assert published_path(LINK, OWNER, BASE) is None
    assert published_links([LINK], OWNER, BASE) == []
    assert upload_path(COPY_LINK, "published", BASE) is None


@pytest.mark.parametrize("name", ["", ".", "..", "a/b", "a\\b", "a b", "a%2f", "a\n", None, 7])
def test_only_a_plain_name_is_a_folder(name: object) -> None:
    assert not is_plain_name(name)
    assert is_plain_name(AD)


def test_a_file_is_protected_whatever_the_address_before_it() -> None:
    for base in (BASE, "https://photos.example.com", "http://wrong"):
        assert mentioned_paths([f"{base}{PUBLIC}{COPY}"]) == {COPY}
    assert mentioned_paths([COPY, f"{COPY_LINK}?x=1"]) == {COPY}


def test_the_address_comes_from_the_configuration() -> None:
    assert photo_base(f"{BASE}/ ") == BASE
    assert photo_base("") == LOCAL_PHOTO_BASE
    assert LOCAL_PHOTO_BASE.endswith(".invalid"), "never a real site"

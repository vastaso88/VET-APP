"""Languages the app can talk in (multilingual groundwork).

Today the app is Italian only: every function here falls back to "it", so a
client that sends nothing, or something unknown, behaves exactly as before.
"""

from collections.abc import Iterable

DEFAULT_LANGUAGE = "it"

# code -> English name (used in LLM instructions)
LANGUAGE_NAMES: dict[str, str] = {
    "it": "Italian",
    "en": "English",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
}
SUPPORTED_LANGUAGES: tuple[str, ...] = tuple(LANGUAGE_NAMES)


def supported_language_or_none(value: str | None) -> str | None:
    """ "en-GB" / "en_GB" / " EN " -> "en"; None when empty or unsupported."""
    if not value:
        return None
    code = value.strip().lower().replace("_", "-").split("-")[0]
    return code if code in LANGUAGE_NAMES else None


def normalize_language(value: str | None) -> str:
    """The supported language code for [value], or "it" when unknown/missing."""
    return supported_language_or_none(value) or DEFAULT_LANGUAGE


def language_from_accept_header(header: str | None) -> str | None:
    """First supported language of an `Accept-Language` header, in the order
    listed ("fr-CH, ja;q=0.9, en;q=0.8" -> "fr"); None when none is supported."""
    if not header:
        return None
    for item in _header_items(header.split(",")):
        found = supported_language_or_none(item)
        if found is not None:
            return found
    return None


def resolve_language(explicit: str | None, accept_language: str | None) -> str:
    """The body field wins, then the header, then "it". An explicit value that
    is present but unsupported means "it" (the client chose, we can't serve it)."""
    if explicit is not None and explicit.strip():
        return normalize_language(explicit)
    return language_from_accept_header(accept_language) or DEFAULT_LANGUAGE


def _header_items(parts: Iterable[str]) -> list[str]:
    return [part.split(";")[0].strip() for part in parts if part.strip()]


def response_language_instruction(language: str) -> str:
    """One line for the system prompt; empty for Italian (prompts stay as they
    are today, byte for byte)."""
    code = normalize_language(language)
    if code == DEFAULT_LANGUAGE:
        return ""
    return (
        f"Always reply in the user's language: {LANGUAGE_NAMES[code]} ({code}). "
        "This overrides any earlier instruction about the language of the reply."
        " Reply exclusively in this selected language even when the owner writes "
        "in another language."
    )

"""The language to answer a refusal in."""

from fastapi import Request

from apps.api.dependencies.container import get_container
from packages.core.domain.common.language import language_from_accept_header


def request_language(request: Request) -> str:
    """The request's Accept-Language when it names a language the app speaks, else
    the account's own choice, else Italian. A refusal is written for the owner, so it
    must not stay Italian for someone who uses the app in German or English."""
    from_header = language_from_accept_header(request.headers.get("accept-language"))
    if from_header is not None:
        return from_header
    try:
        return get_container().auth_provider.get_current_user().preferred_locale
    except Exception:  # noqa: BLE001 - a refusal must never fail because of its language
        return "it"

"""External hosts our programs never contact (CLAUDE.md "Richieste a siti
esterni"): a host whose robots.txt forbids the paths we would use is out
for good, for the backend and for the offline importers alike.
"""

from urllib.parse import urlsplit

# host -> why (neutral, shown in errors and in the importers' stop list)
FORBIDDEN_HOSTS: dict[str, str] = {
    "overpass-api.de": "il suo robots.txt vieta /api/ ai programmi",
}


def forbidden_reason(url_or_host: str) -> str | None:
    """Why `url_or_host` (a URL or a bare host name) may not be contacted,
    or None. Subdomains count: z.overpass-api.de is overpass-api.de."""
    text = url_or_host.strip().lower()
    host = urlsplit(text).hostname if "://" in text else text.split(":", 1)[0]
    if not host:
        return None
    for forbidden, reason in FORBIDDEN_HOSTS.items():
        if host == forbidden or host.endswith("." + forbidden):
            return reason
    return None

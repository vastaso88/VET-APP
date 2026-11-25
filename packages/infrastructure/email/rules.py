from collections.abc import Sequence

from packages.core.application.ports.email_sender import EmailMessage

# Reserved for examples and tests (RFC 2606, RFC 6761): nobody can own an address there, and
# the accounts of the collaudo twin all live there. A message to one of them never leaves,
# not even in production.
_RESERVED_TLDS = frozenset({"test", "invalid", "localhost", "example"})
_RESERVED_DOMAINS = frozenset({"example.com", "example.org", "example.net"})


def _domain(address: str) -> str:
    return address.rsplit("@", 1)[-1].strip().lower().rstrip(".")


def is_reserved_domain(address: str) -> bool:
    """True for example.com / example.org / example.net and everything under them, and for
    the reserved top-level names. Compared label by label: `sub.example.com` is reserved,
    `notexample.com` is not."""
    labels = _domain(address).split(".")
    if labels[-1] in _RESERVED_TLDS:
        return True
    return ".".join(labels[-2:]) in _RESERVED_DOMAINS


def parse_allowed_recipients(raw: str | None) -> tuple[str, ...] | None:
    """EMAIL_ALLOWED_RECIPIENTS as the sender reads it. Two different cases, on purpose:

    - the variable does NOT EXIST (`None`): there is no allow-list, EMAIL_SENDING_ENABLED
      alone decides, and the result is `None`;
    - the variable EXISTS (even empty): an allow-list is in force. It is closed in case of
      doubt: an empty value, or any entry that is not a plain address, gives an EMPTY tuple,
      which allows nobody. A typo must never open the door.
    """
    if raw is None:
        return None
    entries = [item.strip() for item in raw.split(",") if item.strip()]
    if not entries:
        return ()
    for entry in entries:
        local, _, domain = entry.partition("@")
        if (
            not local
            or "." not in domain
            or "@" in domain
            or any(c in entry for c in " \t\r\n<>;\"'")
        ):
            return ()
    return tuple(item.lower() for item in entries)


def check_recipient(address: str, allowed: Sequence[str] | None = None) -> str | None:
    """A short reason code when a message to [address] must not go out, else None.

    Reserved domains are refused always. [allowed] is the allow-list: `None` = there is none;
    anything else (even an empty tuple, which allows nobody) = only those exact addresses,
    compared without case, receive mail."""
    if is_reserved_domain(address):
        return "reserved_recipient"
    if allowed is not None and address.strip().lower() not in {
        item.strip().lower() for item in allowed
    }:
        return "recipient_not_allowed"
    return None


def check_message(message: EmailMessage) -> str | None:
    """A short reason code when the message must not go out, else None."""
    if "@" not in message.to or any(c in message.to for c in "\r\n<>, ;"):
        return "invalid"
    if any(c in message.subject for c in "\r\n"):
        return "invalid"
    if message.category == "commercial" and not (
        message.unsubscribe_url and message.unsubscribe_url.startswith("https://")
    ):
        # A commercial message without a one-click unsubscribe is never sent.
        return "invalid"
    return None

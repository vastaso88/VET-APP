"""The reminder before a yearly plan renews: when it is due and what it says.

Owner decision of 25 November 2026: one service e-mail, seven days before the store charges a
yearly subscription that renews by itself. Never for the trial, a monthly plan, a subscription
that was cancelled or whose payment is failing. Nothing is sold in it.

The subject says «in 7 days», and there is no other text for a late message: it goes only on
the day that is exactly seven calendar days before the renewal (UTC, like the other e-mails of
the server, see `exit_notices/timing.py`). Missed that day, it is not sent.
"""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from packages.core.domain.exit_notices import layout
from packages.core.domain.exit_notices.texts import first_word
from packages.core.domain.localization import SupportedLocale
from packages.core.domain.subscription.renewal_texts import BODIES, SUBJECTS
from packages.core.domain.subscription.store import (
    BillingPeriod,
    Store,
    StoreEntitlement,
    StorePrice,
    StoreState,
)

DAYS_BEFORE = 7

# How a booked reminder is written in the register of the store events (`store_events`).
EVENT_TYPE = "QUOKKA_RENEWAL_NOTICE"
# A yearly period lasts a year: a reminder booked in the last two months is about this renewal,
# even if the store has moved its date by a few days since.
SAME_PERIOD = timedelta(days=60)

# The stores an owner really pays. The team's test grants have nothing to renew.
STORE_NAMES: dict[Store, str] = {Store.APPLE: "Apple", Store.GOOGLE: "Google"}


def renewal_day(now: datetime) -> tuple[datetime, datetime]:
    """The day (UTC, from midnight to midnight) whose renewals are told today."""
    start = now.astimezone(UTC).replace(hour=0, minute=0, second=0, microsecond=0)
    start += timedelta(days=DAYS_BEFORE)
    return start, start + timedelta(days=1)


def is_due(entitlement: StoreEntitlement, now: datetime) -> bool:
    """A yearly subscription of a real store, active, renewing by itself, in exactly 7 days."""
    if entitlement.expires_at is None:
        return False
    start, end = renewal_day(now)
    return (
        entitlement.store in STORE_NAMES
        and entitlement.period == BillingPeriod.YEARLY
        and entitlement.state == StoreState.ACTIVE
        and entitlement.auto_renew
        and start <= entitlement.expires_at < end
    )


def event_id(entitlement: StoreEntitlement) -> str:
    """The same for every run of the same renewal, so it can be booked only once. A digest: the
    store's identifier is not written twice."""
    day = entitlement.expires_at.date().isoformat() if entitlement.expires_at else ""
    key = f"{entitlement.store}:{entitlement.store_subscription_id}:{day}"
    return "renewal-notice:" + hashlib.sha256(key.encode()).hexdigest()[:40]


# --------------------------------------------------------------------------- the words

_MONTHS: dict[SupportedLocale, tuple[str, ...]] = {
    "it": (
        "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre",
    ),
    "en": (
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ),
    "es": (
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
    ),
    "de": (
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember",
    ),
    "fr": (
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre",
    ),
}  # fmt: skip


def format_date(moment: datetime, language: SupportedLocale) -> str:
    """«3 dicembre 2026», “3 December 2026”, «3 de diciembre de 2026», „3. Dezember 2026“,
    « 3 décembre 2026 » (« 1er » on the first of the month)."""
    moment = moment.astimezone(UTC)
    month = _MONTHS[language][moment.month - 1]
    if language == "es":
        return f"{moment.day} de {month} de {moment.year}"
    if language == "de":
        return f"{moment.day}. {month} {moment.year}"
    day = "1er" if language == "fr" and moment.day == 1 else str(moment.day)
    return f"{day} {month} {moment.year}"


_NBSP = " "
# (thousands, decimals) of each language.
_SEPARATORS: dict[SupportedLocale, tuple[str, str]] = {
    "it": (".", ","),
    "en": (",", "."),
    "es": (".", ","),
    "de": (".", ","),
    "fr": (_NBSP, ","),
}
_SYMBOLS = {"EUR": "€", "GBP": "£"}
# The dollars are told apart only in English; elsewhere the three-letter code says which one.
_ENGLISH_SYMBOLS = {**_SYMBOLS, "USD": "$", "AUD": "A$"}
_NO_DECIMALS = frozenset({"CLP", "ISK", "JPY", "KRW", "PYG", "UGX", "VND", "XAF", "XOF", "XPF"})


def format_price(price: StorePrice, language: SupportedLocale) -> str:
    """The store's amount, whole: «85,99 €», “€85.99”, “CHF 85.99”. It is written, never
    rounded and never converted."""
    amount = Decimal(price.micros) / 1_000_000
    digits = -int(amount.normalize().as_tuple().exponent)
    if price.currency not in _NO_DECIMALS:
        digits = max(digits, 2)
    thousands, decimals = _SEPARATORS[language]
    number = f"{amount:,.{max(digits, 0)}f}"
    number = number.replace(",", "\x00").replace(".", decimals).replace("\x00", thousands)
    if language == "en":
        symbol = _ENGLISH_SYMBOLS.get(price.currency)
        return f"{symbol}{number}" if symbol else f"{price.currency}{_NBSP}{number}"
    return f"{number}{_NBSP}{_SYMBOLS.get(price.currency, price.currency)}"


_CLOSING = " {titolare}, {contatto}."


def compose(
    language: SupportedLocale,
    *,
    first_name: str | None,
    renews_on: datetime,
    price: StorePrice,
    store: Store,
) -> tuple[str, list[str]]:
    """(subject, paragraphs). The closing «{titolare}, {contatto}.» is not in the body, as in the
    exit e-mails: the team signs, and the small line says the company and the contact once they
    are configured. With no name the greeting is «Ciao,». The text is cut into paragraphs before
    it is filled in, because a German date holds a full stop."""
    body = BODIES[language].removesuffix(_CLOSING)
    name = first_word(first_name)
    if not name:
        body = body.replace(" {nome},", ",")
    values = {
        "nome": name,
        "data_rinnovo": format_date(renews_on, language),
        "prezzo": format_price(price, language),
        "store": STORE_NAMES[store],
    }
    return SUBJECTS[language], [p.format(**values) for p in layout.split_paragraphs(body)]

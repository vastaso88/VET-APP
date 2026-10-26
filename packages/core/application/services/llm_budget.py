"""The daily token budget per model, shared through the usage ledger.

Groq's free tier gives each model its own tokens-per-day limit, counted for
the whole organization. The chat must not discover the limit by failing:

* under 80% of a model's budget (configurable) it is used normally;
* from 80% the reserve models go first, so the main model keeps a margin
  for when the reserves run out too;
* at 100%, or once Groq itself answered "per day" 429 for the model, it is
  left alone until the counter resets; when every model of a chain is in
  that state the chat says so kindly, with the time to wait, instead of
  "servizio non disponibile";
* each owner has a daily number of messages (configurable), so one account
  cannot spend the quota of everyone else. Emergencies never reach this
  check: the fixed triage replies use no model.

The counters live in the ledger (Supabase in production, so every
serverless instance sees the same totals) and are re-read at most every
`refresh_seconds`; between reads this process adds its own calls locally.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.domain.llm_usage.models import ModelDailyUsage, next_day_start
from packages.core.domain.localization import translate
from packages.shared.errors.base import ProviderError, QuotaExceededError

logger = logging.getLogger("vetgpt.budget")

DEFAULT_RESERVE_SHARE = 0.8
# Groq's "try again in" for a daily limit can be most of a day; anything
# past the next counter reset is pointless to remember.
MAX_EXHAUSTION_SECONDS = 24 * 3600


class QuotaExhausted(ProviderError):
    """Every model that could answer has used its day's tokens."""

    def __init__(self, retry_after_seconds: int) -> None:
        super().__init__(
            f"Daily model quota exhausted; retry in about {retry_after_seconds} seconds"
        )
        self.retry_after_seconds = max(60, int(retry_after_seconds))


class QuotaDenial(BaseModel):
    # "user_limit": this owner's messages for today are used up;
    # "models_exhausted": no model of the answer chain can answer today.
    reason: str
    retry_after_seconds: int
    daily_limit: int = 0


def parse_budgets(value: str) -> dict[str, int]:
    """ "a=200000, b=500000" -> {"a": 200000, "b": 500000} (an env setting)."""
    budgets: dict[str, int] = {}
    for item in value.split(","):
        model, separator, amount = item.strip().partition("=")
        if separator and model.strip():
            try:
                budgets[model.strip()] = int(amount.strip().replace("_", ""))
            except ValueError:
                continue
    return budgets


_WAIT_WORDS: dict[str, tuple[str, str, str, str, str]] = {
    # a few minutes, minutes, hour, hours, and
    "it": ("pochi minuti", "minuti", "ora", "ore", "e"),
    "en": ("a few minutes", "minutes", "hour", "hours", "and"),
    "es": ("unos minutos", "minutos", "hora", "horas", "y"),
    "de": ("wenigen Minuten", "Minuten", "Stunde", "Stunden", "und"),
    "fr": ("quelques minutes", "minutes", "heure", "heures", "et"),
}


def format_wait(seconds: int, locale: str = "it") -> str:
    """ "pochi minuti", "20 minuti", "2 ore", "2 ore e 20 minuti" (and the
    same in the chat's other languages)."""
    few, minutes_word, hour_word, hours_word, conjunction = _WAIT_WORDS.get(
        (locale or "it").split("-")[0].lower(), _WAIT_WORDS["it"]
    )
    minutes = max(1, round(seconds / 60))
    if minutes < 3:
        return few
    if minutes < 60:
        return f"{minutes} {minutes_word}"
    hours, rest = divmod(minutes, 60)
    unit = hour_word if hours == 1 else hours_word
    if rest < 5:
        return f"{hours} {unit}"
    return f"{hours} {unit} {conjunction} {rest} {minutes_word}"


def format_wait_it(seconds: int) -> str:
    return format_wait(seconds, "it")


def require_feature_allowance(
    budget: LlmBudget | None,
    *,
    owner_id: str,
    kind: str,
    limit: int,
    exempt: bool = False,
    language: str = "it",
) -> None:
    """Raises QuotaExceededError when [owner_id] has used today's [limit] of
    [kind] ("vision", "dictation", "summary"); counts the use otherwise.
    No budget, no limit or an exempt account: nothing happens."""
    if budget is None:
        return
    denial = budget.admit_feature(owner_id=owner_id, kind=kind, limit=limit, exempt=exempt)
    if denial is None:
        return
    raise QuotaExceededError(
        kind,
        limit=limit,
        retry_after_seconds=denial.retry_after_seconds,
        message=translate(
            f"quota_{kind}_exhausted",
            language,
            limit=limit,
            wait=format_wait(denial.retry_after_seconds, language),
        ),
    )


class LlmBudget:
    def __init__(
        self,
        repository: LlmUsageRepository,
        *,
        budgets: dict[str, int],
        default_budget: int,
        reserve_share: float = DEFAULT_RESERVE_SHARE,
        user_daily_limit: int = 0,
        refresh_seconds: float = 30.0,
        clock: Callable[[], datetime] | None = None,
        monotonic: Callable[[], float] = time.monotonic,
    ) -> None:
        self._repository = repository
        self._budgets = dict(budgets)
        self._default_budget = max(1, default_budget)
        self._reserve_share = reserve_share
        self._user_daily_limit = max(0, user_daily_limit)
        self._refresh_seconds = refresh_seconds
        self._clock = clock or (lambda: datetime.now(UTC))
        self._monotonic = monotonic
        self._known: dict[str, ModelDailyUsage] = {}
        self._known_day: date | None = None
        self._read_at: float | None = None

    # --- what the budget knows -------------------------------------------------

    def budget_for(self, model: str) -> int:
        return self._budgets.get(model, self._default_budget)

    def used_today(self, model: str) -> int:
        self._refresh()
        usage = self._known.get(model)
        return usage.total_tokens if usage else 0

    def state(self, model: str) -> str:
        """ "ok", "reserve" (past the reserve share) or "exhausted"."""
        self._refresh()
        now = self._clock()
        usage = self._known.get(model)
        if usage is not None and usage.exhausted_until is not None and usage.exhausted_until > now:
            return "exhausted"
        used = usage.total_tokens if usage else 0
        budget = self.budget_for(model)
        if used >= budget:
            return "exhausted"
        if used >= budget * self._reserve_share:
            return "reserve"
        return "ok"

    def retry_after_seconds(self, models: list[str]) -> int:
        """Seconds until the first of [models] can be used again."""
        now = self._clock()
        candidates = [next_day_start(now)]
        for model in models:
            usage = self._known.get(model)
            if usage is not None and usage.exhausted_until is not None:
                candidates.append(min(usage.exhausted_until, next_day_start(now)))
        earliest = min(candidates)
        return max(60, int((earliest - now).total_seconds()))

    # --- the provider's hooks ---------------------------------------------------

    def order(self, models: list[str]) -> list[str]:
        """[models] with the ones past their reserve share moved last and the
        exhausted ones dropped. Raises QuotaExhausted when none is left."""
        states = {model: self.state(model) for model in models}
        ordered = [m for m in models if states[m] == "ok"] + [
            m for m in models if states[m] == "reserve"
        ]
        if not ordered:
            raise QuotaExhausted(self.retry_after_seconds(models))
        if ordered[0] != models[0]:
            logger.warning(
                "llm budget: %s at %s of its daily budget, trying %s first",
                models[0],
                states[models[0]],
                ordered[0],
            )
        return ordered

    def note_usage(self, model: str, total_tokens: int) -> None:
        """Adds a call this process just made, ahead of the next refresh."""
        self._refresh()
        usage = self._known.get(model)
        if usage is None:
            usage = ModelDailyUsage(day=self._today(), model=model)
            self._known[model] = usage
        usage.total_tokens += max(0, total_tokens)
        usage.calls += 1

    def note_rate_limited(
        self, model: str, *, daily: bool, retry_after_seconds: int | None
    ) -> None:
        """The provider refused [model]: a daily limit marks it exhausted for
        everyone until the provider's own retry time (or the next reset)."""
        if not daily:
            return
        now = self._clock()
        wait = min(retry_after_seconds or MAX_EXHAUSTION_SECONDS, MAX_EXHAUSTION_SECONDS)
        until = min(now + timedelta(seconds=wait), next_day_start(now))
        self._refresh()
        usage = self._known.setdefault(model, ModelDailyUsage(day=self._today(), model=model))
        usage.exhausted_until = until
        try:
            self._repository.mark_exhausted(model, self._today(), until)
        except Exception:  # noqa: BLE001 - the ledger must never take the chat down
            logger.exception("llm budget: could not record that %s is exhausted", model)

    # --- admission of a chat turn ---------------------------------------------------

    def admit(
        self, *, owner_id: str, models: list[str], exempt: bool = False
    ) -> QuotaDenial | None:
        """Checked once per turn, before anything that may call a model and
        after the fixed emergency replies. Counts the owner's message only
        when the turn is admitted."""
        try:
            self.order(models)
        except QuotaExhausted as exc:
            return QuotaDenial(
                reason="models_exhausted", retry_after_seconds=exc.retry_after_seconds
            )
        if exempt or self._user_daily_limit <= 0 or not owner_id:
            return None
        try:
            count = self._repository.add_user_message(owner_id, self._today())
        except Exception:  # noqa: BLE001 - fail open: a ledger outage must not block owners
            logger.exception("llm budget: could not count the owner's message")
            return None
        if count > self._user_daily_limit:
            now = self._clock()
            return QuotaDenial(
                reason="user_limit",
                retry_after_seconds=max(60, int((next_day_start(now) - now).total_seconds())),
                daily_limit=self._user_daily_limit,
            )
        return None

    def admit_feature(
        self, *, owner_id: str, kind: str, limit: int, exempt: bool = False
    ) -> QuotaDenial | None:
        """The owner's daily allowance of one feature that calls a model
        (security audit BE-4/LLM-4): counts the use and refuses past
        [limit]. Same ledger and exemptions as the messages."""
        if exempt or limit <= 0 or not owner_id:
            return None
        try:
            count = self._repository.add_user_usage(owner_id, self._today(), kind)
        except Exception:  # noqa: BLE001 - fail open: a ledger outage must not block owners
            logger.exception("llm budget: could not count the owner's %s use", kind)
            return None
        if count > limit:
            now = self._clock()
            return QuotaDenial(
                reason=f"{kind}_limit",
                retry_after_seconds=max(60, int((next_day_start(now) - now).total_seconds())),
                daily_limit=limit,
            )
        return None

    # --- internals ------------------------------------------------------------------

    def _today(self) -> date:
        return self._clock().astimezone(UTC).date()

    def _refresh(self) -> None:
        today = self._today()
        fresh = (
            self._read_at is not None
            and self._known_day == today
            and self._monotonic() - self._read_at < self._refresh_seconds
        )
        if fresh:
            return
        try:
            rows = self._repository.usage_for_day(today)
        except Exception:  # noqa: BLE001 - without the ledger, go on with what is known
            logger.exception("llm budget: could not read today's usage")
            rows = list(self._known.values()) if self._known_day == today else []
        self._known = {row.model: row for row in rows}
        self._known_day = today
        self._read_at = self._monotonic()

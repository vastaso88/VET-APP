"""The daily budget of the models, shared through the usage ledger.

Two kinds of budget, by what a model costs (pricing.py):

* a PAID model (Claude Haiku) is capped in EUROS, for all the paid models
  together: the day's spend is each token type times its price (an output
  token is 5 times an input token, a cache read a tenth of one), converted
  at LLM_USD_PER_EUR. `daily_cap_eur()` is the one place where the cap is
  decided (today a fixed LLM_DAILY_BUDGET_EUR, minimum 1 EUR a day);
* a FREE model (Groq's free tier) has a tokens-per-day limit per model,
  counted for the whole organization.

The same rules apply to both. The chat must not discover a limit by failing:

* under 80% of a model's budget (configurable) it is used normally;
* from 80% the reserve models go first, so the main model keeps a margin
  for when the reserves run out too;
* at 100%, or once Groq itself answered "per day" 429 for the model, it is
  left alone until the counter resets; when every model of a chain is in
  that state the chat says so kindly, with the time to wait, instead of
  "servizio non disponibile";
* each owner has a daily number of messages (configurable), so one account
  cannot spend the quota of everyone else. The owner's day is their own:
  the counters start over at midnight on the clock of their phone (the
  offset the app sends, packages/shared/user_clock.py), while the models'
  token budgets above stay on the provider's day, UTC. Emergencies never
  reach this check: the fixed triage replies use no model.

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
from packages.core.domain.llm_usage.models import (
    ModelDailyUsage,
    next_day_start,
    next_owner_day_start,
    owner_day,
)
from packages.core.domain.llm_usage.pricing import (
    DEFAULT_INFERENCE_GEO,
    DEFAULT_USD_PER_EUR,
    price_for,
    spend_usd,
)
from packages.core.domain.localization import translate
from packages.shared.errors.base import ProviderError, QuotaExceededError
from packages.shared.user_clock import current_utc_offset_minutes

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
    "es": ("pocos minutos", "minutos", "hora", "horas", "y"),
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
        daily_budget_eur: float | None = None,
        usd_per_eur: float = DEFAULT_USD_PER_EUR,
        inference_geo: str = DEFAULT_INFERENCE_GEO,
    ) -> None:
        self._repository = repository
        self._budgets = dict(budgets)
        # None = no euro cap: every model keeps its token budget (the old
        # behaviour, for callers that never set one).
        self._daily_budget_eur = (
            None if daily_budget_eur is None else max(0.0, float(daily_budget_eur))
        )
        self._usd_per_eur = usd_per_eur if usd_per_eur > 0 else DEFAULT_USD_PER_EUR
        # Where the paid models run (ANTHROPIC_INFERENCE_GEO): "us" costs 1.1
        # times the standard price. The same value the client sends.
        self._inference_geo = inference_geo
        self._default_budget = max(1, default_budget)
        self._reserve_share = reserve_share
        self._user_daily_limit = max(0, user_daily_limit)
        self._refresh_seconds = refresh_seconds
        self._clock = clock or (lambda: datetime.now(UTC))
        self._monotonic = monotonic
        self._known: dict[str, ModelDailyUsage] = {}
        self._known_day: date | None = None
        self._read_at: float | None = None
        for model in self._budgets:
            if self._euro_governed(model):
                logger.warning(
                    "llm budget: the token budget of %s is ignored, its spend is capped in euros",
                    model,
                )

    # --- what the budget knows -------------------------------------------------

    def daily_cap_eur(self) -> float | None:
        """The day's spending cap for the paid models, in euros (None: no euro
        cap). THE single place where the cap is decided: today the fixed
        LLM_DAILY_BUDGET_EUR (owner decision 2026-11-10: at least 1 EUR a day).
        The rule "6% of the paying customers' revenue, never under that
        minimum" (docs/marketing/04_business_plan_costi_margini.md §5) is not
        built: when it is, it replaces this body and nothing else."""
        return self._daily_budget_eur

    def _euro_governed(self, model: str) -> bool:
        """A paid model, while there is a euro cap: its budget is money."""
        return self._daily_budget_eur is not None and price_for(model).is_paid

    def _spend_eur(self, usage: ModelDailyUsage) -> float:
        return (
            spend_usd(
                price_for(usage.model),
                prompt_tokens=usage.prompt_tokens,
                completion_tokens=usage.completion_tokens,
                cached_prompt_tokens=usage.cached_prompt_tokens,
                cache_write_tokens=usage.cache_write_tokens,
                inference_geo=self._inference_geo,
            )
            / self._usd_per_eur
        )

    def spent_today_eur(self) -> float:
        """What the paid models have cost today, in euros (the ledger's totals
        plus this process's own calls since the last read)."""
        self._refresh()
        return sum(
            self._spend_eur(usage)
            for usage in self._known.values()
            if price_for(usage.model).is_paid
        )

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
        if self._euro_governed(model):
            used_eur = self.spent_today_eur()
            cap = self.daily_cap_eur() or 0.0
            if used_eur >= cap:
                return "exhausted"
            if used_eur >= cap * self._reserve_share:
                return "reserve"
            return "ok"
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

    def note_usage(
        self,
        model: str,
        total_tokens: int,
        *,
        prompt_tokens: int | None = None,
        completion_tokens: int = 0,
        cached_prompt_tokens: int = 0,
        cache_write_tokens: int = 0,
    ) -> None:
        """Adds a call this process just made, ahead of the next refresh.

        The parts of the call are what the euro spend is made of. Told only
        the total, the call is counted as plain input: an undercount next to
        output tokens, but real calls always give their parts."""
        self._refresh()
        usage = self._known.get(model)
        if usage is None:
            usage = ModelDailyUsage(day=self._today(), model=model)
            self._known[model] = usage
        total = max(0, total_tokens)
        completion = max(0, completion_tokens)
        prompt = max(0, total - completion) if prompt_tokens is None else max(0, prompt_tokens)
        usage.total_tokens += total
        usage.prompt_tokens += prompt
        usage.completion_tokens += completion
        usage.cached_prompt_tokens += max(0, cached_prompt_tokens)
        usage.cache_write_tokens += max(0, cache_write_tokens)
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
        self,
        *,
        owner_id: str,
        models: list[str],
        exempt: bool = False,
        user_daily_limit: int | None = None,
    ) -> QuotaDenial | None:
        """Checked once per turn, before anything that may call a model and
        after the fixed emergency replies. Counts the owner's message only
        when the turn is admitted.

        [user_daily_limit] is the owner's plan allowance and replaces the
        deployment-wide default; unlike that default, 0 here means "none
        allowed" (an owner without access), not "no limit"."""
        try:
            self.order(models)
        except QuotaExhausted as exc:
            return QuotaDenial(
                reason="models_exhausted", retry_after_seconds=exc.retry_after_seconds
            )
        limit = self._user_daily_limit if user_daily_limit is None else user_daily_limit
        unlimited = user_daily_limit is None and self._user_daily_limit <= 0
        if exempt or unlimited or not owner_id:
            return None
        now = self._clock()
        offset = current_utc_offset_minutes()
        try:
            count = self._repository.add_user_message(owner_id, owner_day(now, offset))
        except Exception:  # noqa: BLE001 - fail open: a ledger outage must not block owners
            logger.exception("llm budget: could not count the owner's message")
            return None
        if count > limit:
            return QuotaDenial(
                reason="user_limit",
                retry_after_seconds=self._seconds_until_owner_midnight(now, offset),
                daily_limit=limit,
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
        now = self._clock()
        offset = current_utc_offset_minutes()
        try:
            count = self._repository.add_user_usage(owner_id, owner_day(now, offset), kind)
        except Exception:  # noqa: BLE001 - fail open: a ledger outage must not block owners
            logger.exception("llm budget: could not count the owner's %s use", kind)
            return None
        if count > limit:
            return QuotaDenial(
                reason=f"{kind}_limit",
                retry_after_seconds=self._seconds_until_owner_midnight(now, offset),
                daily_limit=limit,
            )
        return None

    # --- internals ------------------------------------------------------------------

    @staticmethod
    def _seconds_until_owner_midnight(now: datetime, offset_minutes: int) -> int:
        """When the owner's counters start over: their own midnight, from the
        offset their phone sent (0 = UTC). Never under a minute."""
        return max(60, int((next_owner_day_start(now, offset_minutes) - now).total_seconds()))

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

"""What the AI costs, for the admin portal's "AI usage" page.

Read-only and aggregate: it adds up the usage ledger's daily totals per model
(llm_usage_daily) and prices them with pricing.py, the same arithmetic the
daily spending cap uses (llm_budget.py), so the page shows exactly what the
chat decides by. Nothing here carries an owner, a message or any personal
datum: a model name, a day, counts and euros.

It is an estimate from our own counts, not the bill: the exact account is in
the Anthropic Console (https://platform.claude.com/cost). Days are the
ledger's days (UTC), and past days are priced with today's exchange rate and
inference region.
"""

from __future__ import annotations

import calendar
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.domain.llm_usage.models import DEMO_MODEL, ModelDailyUsage, utc_now
from packages.core.domain.llm_usage.pricing import (
    DEFAULT_INFERENCE_GEO,
    DEFAULT_USD_PER_EUR,
    price_for,
    spend_usd,
)

SERIES_DAYS = 30
ANTHROPIC = "anthropic"
ECHO = "echo"
# The reserve provider until 2026-11-25: nothing calls it any more, but the rows
# it left in the ledger stay readable (this month's table, the last 30 days).
GROQ = "groq"


class UsageTotals(BaseModel):
    # Calls to the model, not answers: one chat answer can take several (the
    # urgency check and keywords next to the answer itself).
    calls: int = 0
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cached_tokens: int = 0
    cache_write_tokens: int = 0
    total_tokens: int = 0
    usd: float = 0.0
    eur: float = 0.0


class ModelUsage(BaseModel):
    model: str
    label: str
    provider: str
    paid: bool
    today: UsageTotals
    month: UsageTotals


class DayUsage(BaseModel):
    date: date
    usd: float
    eur: float
    calls: int
    paid_calls: int
    # Calls with no price: the old rows of the removed reserve (and the stand-in).
    reserve_calls: int


class TodayUsage(BaseModel):
    date: date
    spent_usd: float
    spent_eur: float
    cap_eur: float | None
    # Share of the euro cap used (None without a cap).
    share_of_cap: float | None
    # "ok", "reserve" (past the reserve share: Sonnet is off) or "exhausted"
    # (Claude is left alone until midnight UTC and the chat says so).
    state: str


class MonthUsage(BaseModel):
    month: str
    spent_usd: float
    spent_eur: float
    credits_usd: float
    share_of_credits: float
    days_elapsed: int
    days_in_month: int
    # A straight-line estimate of the whole month at today's pace.
    projected_usd: float


class LlmUsageReport(BaseModel):
    generated_at: datetime
    usd_per_eur: float
    inference_geo: str
    today: TodayUsage
    month: MonthUsage
    models: list[ModelUsage]
    daily: list[DayUsage]
    sonnet_answers_today: int
    # Calls that failed before an answer (Claude over its cap, or not answering),
    # today and this month.
    failed_calls_today: int
    failed_calls_month: int


def describe_model(model: str) -> tuple[str, str]:
    """(label, provider) of a ledger model name: "Haiku 5.5" and "anthropic";
    for the rows of the removed reserve "gpt-oss-120b" and "groq"."""
    if model.startswith("claude-"):
        parts = model.split("-")
        family = parts[1].capitalize() if len(parts) > 1 else model
        version = ".".join(parts[2:]) if parts[2:] and all(p.isdigit() for p in parts[2:]) else ""
        return (f"{family} {version}".strip(), ANTHROPIC)
    if model == DEMO_MODEL:
        return (model, ECHO)
    return (model.split("/")[-1], GROQ)


def _is_failure_row(model: str) -> bool:
    # A call that failed is recorded under "(main)" or "(light)": no model
    # answered it, so no tokens and no price.
    return model.startswith("(")


def _add(totals: UsageTotals, row: ModelDailyUsage, *, usd: float, usd_per_eur: float) -> None:
    totals.calls += row.calls
    totals.prompt_tokens += row.prompt_tokens
    totals.completion_tokens += row.completion_tokens
    totals.cached_tokens += row.cached_prompt_tokens
    totals.cache_write_tokens += row.cache_write_tokens
    totals.total_tokens += row.total_tokens
    totals.usd += usd
    totals.eur += usd / usd_per_eur


class LlmUsageReportService:
    def __init__(
        self,
        repository: LlmUsageRepository,
        budget: LlmBudget,
        *,
        monthly_credits_usd: float,
        usd_per_eur: float = DEFAULT_USD_PER_EUR,
        inference_geo: str = DEFAULT_INFERENCE_GEO,
        clock: Callable[[], datetime] = utc_now,
    ) -> None:
        self._repository = repository
        self._budget = budget
        self._monthly_credits_usd = monthly_credits_usd
        self._usd_per_eur = usd_per_eur if usd_per_eur > 0 else DEFAULT_USD_PER_EUR
        self._inference_geo = inference_geo
        self._clock = clock

    def report(self) -> LlmUsageReport:
        now = self._clock().astimezone(UTC)
        today = now.date()
        month_start = today.replace(day=1)
        series_start = today - timedelta(days=SERIES_DAYS - 1)
        rows = self._repository.usage_for_days(min(month_start, series_start), today)

        usd_of = {id(row): self._usd(row) for row in rows}
        today_rows = [row for row in rows if row.day == today]
        month_rows = [row for row in rows if row.day >= month_start]

        today_usd = sum(usd_of[id(row)] for row in today_rows)
        today_eur = today_usd / self._usd_per_eur
        cap = self._budget.daily_cap_eur()
        month_usd = sum(usd_of[id(row)] for row in month_rows)
        days_in_month = calendar.monthrange(today.year, today.month)[1]

        return LlmUsageReport(
            generated_at=now,
            usd_per_eur=self._usd_per_eur,
            inference_geo=self._inference_geo,
            today=TodayUsage(
                date=today,
                spent_usd=today_usd,
                spent_eur=today_eur,
                cap_eur=cap,
                share_of_cap=(today_eur / cap) if cap else None,
                state=self._budget.euro_state(today_eur),
            ),
            month=MonthUsage(
                month=today.strftime("%Y-%m"),
                spent_usd=month_usd,
                spent_eur=month_usd / self._usd_per_eur,
                credits_usd=self._monthly_credits_usd,
                share_of_credits=month_usd / self._monthly_credits_usd,
                days_elapsed=today.day,
                days_in_month=days_in_month,
                projected_usd=month_usd / today.day * days_in_month,
            ),
            models=self._models(today_rows, month_rows, usd_of),
            daily=self._daily(rows, series_start, today, usd_of),
            sonnet_answers_today=sum(
                row.calls for row in today_rows if describe_model(row.model)[0].startswith("Sonnet")
            ),
            failed_calls_today=sum(r.calls for r in today_rows if _is_failure_row(r.model)),
            failed_calls_month=sum(r.calls for r in month_rows if _is_failure_row(r.model)),
        )

    # --- pieces -------------------------------------------------------------------

    def _usd(self, row: ModelDailyUsage) -> float:
        if _is_failure_row(row.model):
            return 0.0
        return spend_usd(
            price_for(row.model),
            prompt_tokens=row.prompt_tokens,
            completion_tokens=row.completion_tokens,
            cached_prompt_tokens=row.cached_prompt_tokens,
            cache_write_tokens=row.cache_write_tokens,
            inference_geo=self._inference_geo,
        )

    def _models(
        self,
        today_rows: list[ModelDailyUsage],
        month_rows: list[ModelDailyUsage],
        usd_of: dict[int, float],
    ) -> list[ModelUsage]:
        by_model: dict[str, ModelUsage] = {}
        for rows, period in ((today_rows, "today"), (month_rows, "month")):
            for row in rows:
                if _is_failure_row(row.model):
                    continue
                label, provider = describe_model(row.model)
                entry = by_model.setdefault(
                    row.model,
                    ModelUsage(
                        model=row.model,
                        label=label,
                        provider=provider,
                        paid=price_for(row.model).is_paid,
                        today=UsageTotals(),
                        month=UsageTotals(),
                    ),
                )
                _add(
                    getattr(entry, period),
                    row,
                    usd=usd_of[id(row)],
                    usd_per_eur=self._usd_per_eur,
                )
        # Dearest first: the paid models, then the old rows with no price.
        return sorted(by_model.values(), key=lambda m: (-m.month.eur, m.model))

    def _daily(
        self,
        rows: list[ModelDailyUsage],
        start: date,
        end: date,
        usd_of: dict[int, float],
    ) -> list[DayUsage]:
        days = {
            start + timedelta(days=offset): DayUsage(
                date=start + timedelta(days=offset),
                usd=0.0,
                eur=0.0,
                calls=0,
                paid_calls=0,
                reserve_calls=0,
            )
            for offset in range((end - start).days + 1)
        }
        for row in rows:
            entry = days.get(row.day)
            if entry is None or _is_failure_row(row.model):
                continue
            entry.usd += usd_of[id(row)]
            entry.eur += usd_of[id(row)] / self._usd_per_eur
            entry.calls += row.calls
            if price_for(row.model).is_paid:
                entry.paid_calls += row.calls
            else:
                entry.reserve_calls += row.calls
        return list(days.values())

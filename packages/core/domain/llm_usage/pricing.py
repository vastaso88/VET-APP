"""What a model call costs, in one place.

The daily spending guard (llm_budget.py) counts euros, not raw tokens: an
output token costs 5 times an input token and a token read back from the
prompt cache a tenth of one (docs/marketing/04_business_plan_costi_margini.md
§5: 4 million raw tokens of Haiku are about 0.62 EUR, not 1 EUR). This module
holds the prices and the arithmetic; nothing else in the code knows a price.

Prices are USD per million tokens, checked against Anthropic's pricing page
on 2026-11-10 (https://platform.claude.com/docs/en/about-claude/pricing).
Change a price here and nowhere else.

What is not modelled, on purpose:

* the higher tier of Haiku 5.5 for a single prompt over 100,000 tokens
  ($0.50 / $2.50, cache read $0.05): a chat prompt here is under 10,000, far
  from it. A call over the limit would be counted at the cheaper tier (and
  that tier carries the same inference-region multiplier);
* the 1-hour cache write ($0.20): the client uses the 5-minute cache;
* batch and fast-mode multipliers: neither is used.

Groq's free tier costs nothing, so its models are priced at zero and keep
their own token budgets. If the Groq account ever becomes paid, put its
prices here (the business plan lists gpt-oss-120b at 0.15 / 0.60 and
gpt-oss-20b at 0.075 / 0.30 USD per million) and they join the euro cap.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

logger = logging.getLogger("vetgpt.pricing")

# 1 EUR = 1.1165 USD (ECB reference rate, 6 November 2026). The real rate
# moves: the deployment overrides it with LLM_USD_PER_EUR.
DEFAULT_USD_PER_EUR = 1.1165


# Where the model runs. `inference_geo: "us"` (US-only inference, needed for
# the consent text v5) costs 1.1 times the standard price on EVERY token
# category: input, output, cache writes and cache reads. "global", the
# default, is the standard price. Only Claude 4.6 and later take the
# parameter, and only they carry the multiplier (ModelPrice.geo_priced).
# The value counted here must be the one the client sends: the deployment
# has ONE setting (ANTHROPIC_INFERENCE_GEO) for both.
INFERENCE_GEO_MULTIPLIERS: dict[str, float] = {"global": 1.0, "us": 1.1}
DEFAULT_INFERENCE_GEO = "global"


def geo_multiplier(inference_geo: str) -> float:
    """The factor on every token price for [inference_geo]. A region this table
    does not know is counted at the highest factor, never at the standard
    price: an unknown name must not make the cap too generous."""
    return INFERENCE_GEO_MULTIPLIERS.get(
        (inference_geo or "").strip().lower(), max(INFERENCE_GEO_MULTIPLIERS.values())
    )


@dataclass(frozen=True)
class ModelPrice:
    """USD per million tokens, at the standard (global) price."""

    input: float
    output: float
    cache_read: float
    cache_write: float
    # False for a model that predates `inference_geo` (Claude 4.5 and
    # earlier): it has one price whatever the region.
    geo_priced: bool = True

    @property
    def is_paid(self) -> bool:
        return max(self.input, self.output, self.cache_read, self.cache_write) > 0


FREE = ModelPrice(input=0.0, output=0.0, cache_read=0.0, cache_write=0.0)

# Claude models, 5-minute cache writes. The first is the one in production
# (owner decision 2026-11-07); the others are here so that switching the
# model by an environment variable never turns the spending guard blind.
PRICES_USD_PER_MILLION: dict[str, ModelPrice] = {
    "claude-haiku-5-5": ModelPrice(input=0.10, output=0.50, cache_read=0.01, cache_write=0.125),
    "claude-haiku-4-5": ModelPrice(
        input=1.00, output=5.00, cache_read=0.10, cache_write=1.25, geo_priced=False
    ),
    "claude-sonnet-5-5": ModelPrice(input=2.00, output=10.00, cache_read=0.10, cache_write=2.50),
    "claude-sonnet-5": ModelPrice(input=2.00, output=10.00, cache_read=0.20, cache_write=2.50),
    "claude-opus-5-5": ModelPrice(input=4.00, output=20.00, cache_read=0.20, cache_write=5.00),
}

# A Claude model this table does not know is counted at the dearest price
# listed, never as free: an unknown name must not switch the cap off.
UNKNOWN_CLAUDE_PRICE = ModelPrice(input=10.0, output=50.0, cache_read=1.0, cache_write=12.5)

_warned_unknown: set[str] = set()


def price_for(model: str) -> ModelPrice:
    """The price of [model]: listed, free (not a Claude model: Groq's free
    tier), or the conservative price of an unlisted Claude model."""
    price = PRICES_USD_PER_MILLION.get(model)
    if price is not None:
        return price
    if model.startswith("claude-"):
        if model not in _warned_unknown:
            _warned_unknown.add(model)
            logger.warning("pricing: no price listed for %s, counted at the dearest one", model)
        return UNKNOWN_CLAUDE_PRICE
    return FREE


def spend_usd(
    price: ModelPrice,
    *,
    prompt_tokens: int,
    completion_tokens: int,
    cached_prompt_tokens: int = 0,
    cache_write_tokens: int = 0,
    inference_geo: str = DEFAULT_INFERENCE_GEO,
) -> float:
    """The cost of the tokens of one or many calls (it is linear, so daily
    totals price exactly like the calls that made them).

    [prompt_tokens] is everything sent, as the clients report it: the plain
    input, the cache reads ([cached_prompt_tokens]) and the cache writes
    ([cache_write_tokens]) together. Each part is priced on its own;
    [completion_tokens] includes the model's reasoning. [inference_geo] is the
    region the calls ran in: its multiplier applies to every part."""
    reads = max(0, cached_prompt_tokens)
    writes = max(0, cache_write_tokens)
    plain = max(0, prompt_tokens - reads - writes)
    standard = (
        plain * price.input
        + reads * price.cache_read
        + writes * price.cache_write
        + max(0, completion_tokens) * price.output
    ) / 1_000_000
    return standard * (geo_multiplier(inference_geo) if price.geo_priced else 1.0)

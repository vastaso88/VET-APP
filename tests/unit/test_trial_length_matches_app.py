"""The free trial lasts the same number of days for the backend, the app's
trial reminders and the Italian texts that announce it."""

import json
import re
from pathlib import Path

from packages.core.domain.subscription.models import TRIAL_DURATION

ROOT = Path(__file__).resolve().parents[2]
TRIAL_RULE_DART = ROOT / "apps/mobile_app/lib/features/billing/domain/trial_reminder_rule.dart"
ARB_IT = ROOT / "apps/mobile_app/lib/l10n/app_it.arb"


def test_the_app_counts_the_same_trial_days_as_the_backend() -> None:
    match = re.search(
        r"static const trialLengthDays = (\d+);", TRIAL_RULE_DART.read_text(encoding="utf-8")
    )
    assert match is not None
    assert int(match.group(1)) == TRIAL_DURATION.days


def test_every_italian_text_about_the_trial_names_the_same_length() -> None:
    texts = json.loads(ARB_IT.read_text(encoding="utf-8"))
    # "Prova gratuita — 14 giorni", "provare tutto gratis per 14 giorni"...
    mentions = {
        f"{key}:{days}": int(days)
        for key, value in texts.items()
        if not key.startswith("@")
        and isinstance(value, str)
        and ("trial" in key.lower() or "prov" in value.lower())
        for days in re.findall(r"(\d+) giorni", value)
    }
    assert mentions, "no Italian text names the trial length any more: update this test"
    assert set(mentions.values()) == {TRIAL_DURATION.days}, mentions

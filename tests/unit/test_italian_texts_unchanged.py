"""The Italian texts are frozen: a merge or a translation pass must not reword them.

``tests/fixtures/italian_texts.json`` holds every Italian string of the app
(``app_it.arb``) and of the backend (``localization.py``) as approved. New keys
are free; changing or removing an approved one fails here until the snapshot is
updated on purpose:

    uv run python tests/unit/test_italian_texts_unchanged.py --update
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "tests" / "fixtures" / "italian_texts.json"
ARB_IT = ROOT / "apps" / "mobile_app" / "lib" / "l10n" / "app_it.arb"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from packages.core.domain.localization import _MESSAGES  # noqa: E402


def current_texts() -> dict[str, dict[str, str]]:
    arb = json.loads(ARB_IT.read_text(encoding="utf-8"))
    return {
        "app": {key: value for key, value in arb.items() if not key.startswith("@")},
        "backend": {key: values["it"] for key, values in _MESSAGES.items() if "it" in values},
    }


def test_approved_italian_texts_are_unchanged() -> None:
    approved = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    current = current_texts()
    differences = [
        f"{area}.{key}: {text!r} -> {current[area].get(key, '<removed>')!r}"
        for area, texts in approved.items()
        for key, text in texts.items()
        if current[area].get(key) != text
    ]
    assert not differences, (
        "Italian texts changed. If intended, update the snapshot (see module docstring):\n"
        + "\n".join(differences)
    )


if __name__ == "__main__" and "--update" in sys.argv:
    SNAPSHOT.write_text(
        json.dumps(current_texts(), ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {SNAPSHOT.relative_to(ROOT)}")

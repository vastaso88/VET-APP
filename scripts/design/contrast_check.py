"""WCAG contrast of the text/button pairs of the app palettes (60/30/10).

``python scripts/design/contrast_check.py`` prints a table for the proposed
palette and the alternative one and exits 1 when a pair that carries text
(or a control the user must see) is below its AA threshold: 4.5 for text, 3.0
for large text and UI components such as icons and borders of controls.

The values are the ones in ``apps/mobile_app/lib/design_system/tokens/app_colors.dart``
(``PALETTE_MAIN``); ``PALETTE_ALT`` is the alternative proposed to the owner and
only lives here and in docs/design/PALETTE_60_30_10.md.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKENS = ROOT / "apps/mobile_app/lib/design_system/tokens/app_colors.dart"

PALETTE_ALT = {
    # Same neutrals and sage secondary; the 10% accent is terracotta.
    "primary": "AA4730",
    "primaryStrong": "8A3623",
    "primarySoft": "F9E8E2",
    "onPrimary": "FFFFFF",
}


def parse_tokens(path: Path = TOKENS) -> dict[str, str]:
    """The ``static const name = Color(0xAARRGGBB);`` lines, as RRGGBB."""
    found: dict[str, str] = {}
    for match in re.finditer(
        r"static const (\w+) = Color\(0x([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})\);",
        path.read_text(encoding="utf-8"),
    ):
        name, alpha, rgb = match.groups()
        if alpha.upper() == "FF":
            found[name] = rgb.upper()
    return found


def luminance(hex_rgb: str) -> float:
    channels = [int(hex_rgb[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    light, dark = max(la, lb), min(la, lb)
    return (light + 0.05) / (dark + 0.05)


# (foreground, background, minimum ratio, what it is)
PAIRS: list[tuple[str, str, float, str]] = [
    ("text", "background", 4.5, "body text on the page"),
    ("text", "surface", 4.5, "body text on a card"),
    ("text", "surfaceElevated", 4.5, "body text on white"),
    ("secondaryText", "background", 4.5, "secondary text on the page"),
    ("secondaryText", "surface", 4.5, "secondary text on a card"),
    ("mutedText", "background", 4.5, "hints and captions on the page"),
    ("mutedText", "surface", 4.5, "hints and captions on a card"),
    ("mutedText", "surfaceElevated", 4.5, "hints on white inputs"),
    ("onPrimary", "primary", 4.5, "label of a primary button"),
    ("onPrimary", "primaryStrong", 4.5, "label of a dark button"),
    ("primary", "background", 4.5, "links and active text on the page"),
    ("primary", "surface", 4.5, "links and active text on a card"),
    ("primary", "secondarySoft", 4.5, "accent text on a soft panel"),
    ("primaryStrong", "secondarySoft", 4.5, "chip label on a soft panel"),
    ("secondaryStrong", "secondarySoft", 4.5, "text on a soft panel"),
    ("secondaryStrong", "background", 4.5, "section titles on the page"),
    ("secondary", "background", 3.0, "decorative icons and bars"),
    ("primary", "primarySoft", 4.5, "selected item"),
    ("danger", "background", 4.5, "error text"),
    ("danger", "surface", 4.5, "error text on a card"),
    ("onPrimary", "danger", 4.5, "label of a destructive button"),
    ("dangerStrong", "dangerSoft", 4.5, "error banner text"),
    ("warning", "background", 3.0, "warning icon"),
    ("warningStrong", "background", 4.5, "warning text"),
    ("success", "background", 3.0, "success icon"),
    ("successStrong", "background", 4.5, "success text"),
    ("info", "background", 3.0, "info icon"),
    ("infoStrong", "background", 4.5, "info text"),
    ("borderStrong", "background", 1.3, "separator (decorative, not required by AA)"),
]


def evaluate(palette: dict[str, str]) -> list[tuple[str, str, float, float, str, bool]]:
    rows = []
    for fg, bg, minimum, label in PAIRS:
        if fg not in palette or bg not in palette:
            rows.append((fg, bg, 0.0, minimum, label, False))
            continue
        ratio = contrast(palette[fg], palette[bg])
        rows.append((fg, bg, ratio, minimum, label, ratio >= minimum))
    return rows


def main() -> int:
    main_palette = parse_tokens()
    alt_palette = {**main_palette, **PALETTE_ALT}
    failed = False
    for name, palette in (
        ("PROPOSED  Petrolio e Salvia", main_palette),
        ("ALTERNATIVE  Salvia e Terracotta", alt_palette),
    ):
        print(f"\\n{name}")
        for fg, bg, ratio, minimum, label, ok in evaluate(palette):
            mark = "ok " if ok else "LOW"
            print(f"  {mark} {fg:>15} on {bg:<16} {ratio:5.2f} (min {minimum})  {label}")
            failed = failed or not ok
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

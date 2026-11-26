"""WCAG contrast of the text/button pairs of the app palettes (60/30/10).

``python scripts/design/contrast_check.py`` prints a table for the proposed
palette and the alternative one and exits 1 when a pair that carries text
(or a control the user must see) is below its AA threshold: 4.5 for text, 3.0
for large text and UI components such as icons and borders of controls.

The values are the ones in ``apps/mobile_app/lib/design_system/tokens/app_colors.dart``:
``parse_tokens()`` gives the light theme (``AppPalette.light`` and the fixed colours),
``parse_tokens(dark=True)`` the dark one (``AppPalette.dark``); ``PALETTE_ALT`` is the
alternative proposed to the owner and only lives here and in
docs/design/PALETTE_60_30_10.md. The dark theme is also checked for the colours
that are not in the palette: a pet's identity colour and the radar categories, as
drawn on the dark grounds (``AppIdentityColors.shown``, ``AppCategoryColors.shown``).
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
    "primarySoft": "F9E8E2",
    "onPrimary": "FFFFFF",
}


_COLOR = r"Color\(0x([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})\)"


def _opaque(pairs: list[tuple[str, str, str]]) -> dict[str, str]:
    return {name: rgb.upper() for name, alpha, rgb in pairs if alpha.upper() == "FF"}


def _block(source: str, opening: str) -> str:
    """The text from ``opening`` to the first line that closes it (``);`` or ``};``)."""
    start = source.index(opening)
    end = re.compile(r"^\s*[)}];", re.M).search(source, start)
    assert end is not None, opening
    return source[start : end.start()]


def _class(source: str, name: str) -> str:
    start = source.index(f"class {name} ")
    following = source.find("\nclass ", start + 1)
    return source[start : following if following != -1 else len(source)]


def parse_tokens(path: Path = TOKENS, *, dark: bool = False) -> dict[str, str]:
    """The colours of one theme, as RRGGBB: the fixed ``static const name =
    Color(0xAARRGGBB);`` lines of ``AppColors`` and the ``name: Color(...)``
    entries of ``AppPalette.light`` (or ``AppPalette.dark``)."""
    source = path.read_text(encoding="utf-8")
    fixed = re.findall(rf"static const (\w+) = {_COLOR};", _class(source, "AppColors"))
    block = _block(source, f"static const {'dark' if dark else 'light'} = AppPalette._(")
    return {**_opaque(fixed), **_opaque(re.findall(rf"(\w+): {_COLOR},", block))}


def parse_shown_on_dark(class_name: str, path: Path = TOKENS) -> dict[str, str]:
    """Each colour of ``AppIdentityColors`` or ``AppCategoryColors`` as drawn in the
    dark theme: its ``onDark`` value, or the constant itself when it has none."""
    source = _class(path.read_text(encoding="utf-8"), class_name)
    constants = _opaque(re.findall(rf"static const (\w+) = {_COLOR};", source))
    constants = {k: v for k, v in constants.items() if not k.startswith("tint")}
    lifted = _opaque(re.findall(rf"(\w+): {_COLOR},", _block(source, "onDark = <Color, Color>{")))
    return {name: lifted.get(name, rgb) for name, rgb in constants.items()}


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
    ("primary", "background", 4.5, "links and active text on the page"),
    ("primary", "surface", 4.5, "links and active text on a card"),
    ("primary", "secondarySoft", 4.5, "accent text on a soft panel"),
    ("primary", "surfaceElevated", 4.5, "label of an outlined button"),
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
    # The edge of a field, a pill or a card that opens (WCAG 1.4.11), on every ground
    # it sits on. "border" is decorative (hairlines, read-only cards) and not here.
    ("borderStrong", "background", 3.0, "edge of a field or of a pill on the page"),
    ("borderStrong", "backgroundDeep", 3.0, "edge of a field or of a pill, deep page"),
    ("borderStrong", "surface", 3.0, "edge of a field on a card"),
    ("borderStrong", "surfaceElevated", 3.0, "edge of a field against its own fill"),
    ("borderStrong", "secondarySoft", 3.0, "edge of a field or of a pill on a soft panel"),
    ("borderStrong", "primarySoft", 3.0, "edge of a field or of a pill on a chosen panel"),
    ("borderStrong", "warningSoft", 3.0, "edge of a field on a warning panel"),
    ("primary", "surfaceElevated", 3.0, "edge of the field being written"),
    ("danger", "surfaceElevated", 4.5, "edge and text of a field with an error"),
    ("text", "secondarySoft", 4.5, "initial in a calendar mark"),
    # The flat figures of the species, on their ground and in a pill (the paw, the reptile
    # and the fish are pairs already above).
    ("warningStrong", "warningSoft", 3.0, "figure of a mammal"),
    ("infoStrong", "infoSoft", 3.0, "figure of a bird"),
    ("warningStrong", "infoSoft", 3.0, "beak of a bird"),
    ("secondaryStrong", "surface", 3.0, "figure in a pill that is not chosen"),
    ("onWarning", "warning", 3.0, "mark of a place not yet confirmed"),
    ("onInverse", "primary", 4.5, "text of a chart tooltip"),
]


# Only in the dark theme: there the full status colours carry the dark ink of
# onPrimary (a button that deletes, a badge), and the accent sits on its own panel.
DARK_PAIRS: list[tuple[str, str, float, str]] = [
    *PAIRS,
    ("onPrimary", "warning", 4.5, "dark ink on a warning fill"),
    ("onPrimary", "success", 4.5, "dark ink on a success fill"),
    ("onPrimary", "info", 4.5, "dark ink on an info fill"),
    ("onPrimary", "secondaryStrong", 4.5, "dark ink on a strong sage fill"),
    ("mutedText", "secondarySoft", 4.5, "captions on a soft panel"),
    ("text", "primarySoft", 4.5, "text on a chosen panel (today in the calendar)"),
    ("secondaryText", "surfaceElevated", 4.5, "secondary text on a raised card"),
    ("dangerStrong", "background", 4.5, "error text on the page"),
    # The snack bar is light in the dark theme (its ground is the text colour).
    ("onInverse", "text", 3.0, "loader on a snack bar"),
]

# The dark grounds an identity ring, a calendar mark or a category icon sits on.
DARK_GROUNDS = ["background", "surface", "surfaceElevated", "secondarySoft", "primarySoft"]


def evaluate_shown_on_dark(dark: dict[str, str]) -> list[tuple[str, str, float, float, str, bool]]:
    """The identity and category colours, as drawn in the dark theme, on every dark
    ground: 3 to 1 (a ring, a mark, an icon: WCAG 1.4.11)."""
    rows = []
    for class_name, what in (
        ("AppIdentityColors", "identity colour of a pet"),
        ("AppCategoryColors", "icon of a radar category"),
    ):
        for name, rgb in parse_shown_on_dark(class_name).items():
            for ground in DARK_GROUNDS:
                ratio = contrast(rgb, dark[ground])
                rows.append((name, ground, ratio, 3.0, what, ratio >= 3.0))
    return rows


def evaluate(
    palette: dict[str, str], pairs: list[tuple[str, str, float, str]] | None = None
) -> list[tuple[str, str, float, float, str, bool]]:
    rows = []
    for fg, bg, minimum, label in PAIRS if pairs is None else pairs:
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
    dark_palette = parse_tokens(dark=True)
    for name, rows in (
        ("PROPOSED  Petrolio e Salvia", evaluate(main_palette)),
        ("ALTERNATIVE  Salvia e Terracotta", evaluate(alt_palette)),
        ("DARK THEME  Petrolio notte", evaluate(dark_palette, DARK_PAIRS)),
        ("DARK THEME  identity and category colours", evaluate_shown_on_dark(dark_palette)),
    ):
        print(f"\\n{name}")
        for fg, bg, ratio, minimum, label, ok in rows:
            mark = "ok " if ok else "LOW"
            print(f"  {mark} {fg:>15} on {bg:<16} {ratio:5.2f} (min {minimum})  {label}")
            failed = failed or not ok
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

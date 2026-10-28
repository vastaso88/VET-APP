import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location(
    "contrast_check", ROOT / "scripts/design/contrast_check.py"
)
assert _spec is not None and _spec.loader is not None
contrast_check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(contrast_check)


def test_the_proposed_palette_meets_wcag_aa() -> None:
    palette = contrast_check.parse_tokens()
    failed = [row for row in contrast_check.evaluate(palette) if not row[5]]
    assert not failed, failed


def test_the_alternative_palette_meets_wcag_aa_too() -> None:
    palette = {**contrast_check.parse_tokens(), **contrast_check.PALETTE_ALT}
    failed = [row for row in contrast_check.evaluate(palette) if not row[5]]
    assert not failed, failed


def test_the_ratio_formula_matches_the_known_extremes() -> None:
    assert round(contrast_check.contrast("000000", "FFFFFF"), 1) == 21.0
    assert round(contrast_check.contrast("777777", "777777"), 1) == 1.0

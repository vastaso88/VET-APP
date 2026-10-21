"""Builds the puppy growth bands shipped with the app from the raw data of

    Salt C, Morris PJ, German AJ, Wilson D, Lund EM, Cole TJ, Butterwick RF.
    Growth standard charts for monitoring bodyweight in dogs of different sizes.
    PLoS ONE 2017;12(9):e0182064. doi:10.1371/journal.pone.0182064
    Data: https://datacat.liverpool.ac.uk/377/ (CC BY 4.0), Final_Data_PLOS.zip

The output is NOT the official WALTHAM chart (GAMLSS model): it holds empirical
percentiles of body weight by age, per adult size class and sex, computed from
the visits that the authors released. The raw data is never copied into the
repository, only the compact result.

Usage (the zip is untrusted input: keep it outside the repo and run isolated):

    python -I scripts/growth/build_puppy_growth_bands.py \\
        --zip C:/path/Final_Data_PLOS.zip \\
        --out apps/mobile_app/assets/growth/puppy_growth_bands.json

Method, in short (all choices are also written to the JSON "method" field):
  * visits of healthy dogs (preventive-care visit or "healthy pet" diagnosis);
  * only dogs in ideal body condition (the paper used ideal-BCS dogs only).
    The released file has no usable prediction (BCS_PREDICTED is always
    "None") and most visits have no recorded condition, so a dog counts as
    ideal when at least one of its visits recorded "Normal" and none recorded
    "Thin" or "Heavy"; its visits with no recorded condition are kept. This
    keeps puppy visits (rarely scored) but may include some puppies that were
    not ideal at that age: a limitation of the data, not of the method;
  * age 12 weeks to 2 years (the range of the paper's charts);
  * adult size class from the breed's average adult weight (AV_BREED_WEIGHT)
    with the thresholds of the paper; class VI (40 kg and over) is not modelled
    because the breeds in it have widely different growth (as in the paper);
  * outliers: weights outside 2%..130% of the breed's adult average, and
    weights over 100 kg or under 0.3 kg, are dropped (data-entry errors);
  * weights are kept at 0.05 kg; percentiles (nearest rank) are taken over a
    window of +-2 weeks of age (up to 52 weeks) or +-4 weeks (after) and made
    non-decreasing with age (a running maximum);
  * a point is published only when its window holds at least MIN_N visits.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

CSV_NAME = "Final_Data_PLOS.csv"
WEEKS_PER_YEAR = 365.25 / 7
MIN_WEEK = 12
MAX_WEEK = 104
MIN_N = 200
PERCENTILES = (3, 10, 25, 50, 75, 90, 97)
WEIGHT_STEP = 0.05

# Adult size classes of the paper (Table 1): class -> (min kg inclusive, max kg exclusive).
CLASSES = {
    "I": (0.0, 6.5),
    "II": (6.5, 9.0),
    "III": (9.0, 15.0),
    "IV": (15.0, 30.0),
    "V": (30.0, 40.0),
}

SEX = {"M": "male", "MN": "male", "F": "female", "FS": "female"}

ATTRIBUTION = (
    "Derivato da dati CC BY 4.0 di Salt C. et al., PLOS ONE 2017;12(9):e0182064 "
    "(doi 10.1371/journal.pone.0182064); non sono le curve ufficiali WALTHAM."
)


def size_class(adult_kg: float) -> str | None:
    for name, (low, high) in CLASSES.items():
        if low <= adult_kg < high:
            return name
    return None


def open_rows(archive: zipfile.ZipFile):
    raw = archive.open(CSV_NAME)
    return csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig", newline=""))


def ideal_dogs(archive: zipfile.ZipFile) -> set[str]:
    """Dogs with at least one recorded "Normal" condition and no "Thin"/"Heavy"."""
    normal: set[str] = set()
    off: set[str] = set()
    for row in open_rows(archive):
        condition = row["BCS_RECORDED"]
        if condition == "Normal":
            normal.add(row["PET_ID"])
        elif condition in ("Thin", "Heavy"):
            off.add(row["PET_ID"])
    return normal - off


def read_cells(zip_path: Path):
    """week -> Counter(weight bucket) per (class, sex), plus the dogs and visits used."""
    cells: dict[tuple[str, str], dict[int, Counter[int]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    dogs: dict[str, set[str]] = defaultdict(set)
    visits: Counter[str] = Counter()
    seen = dropped_outlier = 0
    with zipfile.ZipFile(zip_path) as archive:
        ideal = ideal_dogs(archive)
        for row in open_rows(archive):
            seen += 1
            if row["PREVENTIVE_CARE_VISIT"] != "Y" and row["HEALTHY_PET_DIAGNOSIS"] != "Y":
                continue
            if row["PET_ID"] not in ideal:
                continue
            sex = SEX.get(row["GENDER"])
            try:
                age_weeks = float(row["VISIT_AGE"]) * WEEKS_PER_YEAR
                weight = float(row["WEIGHT"])
                adult = float(row["AV_BREED_WEIGHT"])
            except ValueError:
                continue
            week = round(age_weeks)
            klass = size_class(adult)
            if sex is None or klass is None or not MIN_WEEK <= week <= MAX_WEEK:
                continue
            if not (0.3 <= weight <= 100 and 0.02 * adult <= weight <= 1.3 * adult):
                dropped_outlier += 1
                continue
            cells[(klass, sex)][week][round(weight / WEIGHT_STEP)] += 1
            dogs[klass].add(row["PET_ID"])
            visits[klass] += 1
    return cells, dogs, visits, seen, dropped_outlier


def percentile(counter: Counter[int], total: int, q: float) -> float:
    """Nearest-rank percentile of a bucketed distribution, in kg."""
    target = q / 100 * (total - 1)
    running = 0
    for bucket in sorted(counter):
        running += counter[bucket]
        if running > target:
            return bucket * WEIGHT_STEP
    return max(counter) * WEIGHT_STEP


def build_series(weeks: dict[int, Counter[int]]):
    ages = [*range(MIN_WEEK, 53, 2), *range(56, MAX_WEEK + 1, 4)]
    series = {q: [] for q in PERCENTILES}
    used_ages: list[int] = []
    counts: list[int] = []
    for age in ages:
        half = 2 if age <= 52 else 4
        pooled: Counter[int] = Counter()
        for week in range(age - half, age + half + 1):
            pooled.update(weeks.get(week, ()))
        total = sum(pooled.values())
        if total < MIN_N:
            continue
        used_ages.append(age)
        counts.append(total)
        for q in PERCENTILES:
            series[q].append(percentile(pooled, total, q))
    # Growth never goes back: a running maximum removes sampling wiggles.
    for q in PERCENTILES:
        top = 0.0
        for index, value in enumerate(series[q]):
            top = max(top, value)
            series[q][index] = round(top, 2)
    return used_ages, series, counts


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--zip", required=True, type=Path, help="Final_Data_PLOS.zip")
    parser.add_argument("--out", required=True, type=Path, help="output JSON")
    args = parser.parse_args(argv)

    cells, dogs, visits, seen, dropped = read_cells(args.zip)

    bands: dict[str, dict[str, dict]] = {}
    for (klass, sex), weeks in sorted(cells.items()):
        ages, series, counts = build_series(weeks)
        if not ages:
            continue
        bands.setdefault(klass, {})[sex] = {
            "weeks": ages,
            "n": counts,
            **{f"p{q}": series[q] for q in PERCENTILES},
        }

    result = {
        "attribution": ATTRIBUTION,
        "licence": "CC BY 4.0",
        "source": {
            "article": "Salt C et al., PLoS ONE 2017;12(9):e0182064",
            "doi": "10.1371/journal.pone.0182064",
            "data": "https://datacat.liverpool.ac.uk/377/",
        },
        "unit": {"age": "weeks", "weight": "kg"},
        "percentiles": list(PERCENTILES),
        "classes": {
            name: {"minAdultKg": low, "maxAdultKg": high} for name, (low, high) in CLASSES.items()
        },
        "dogsUsed": {name: len(dogs[name]) for name in CLASSES},
        "visitsUsed": {name: visits[name] for name in CLASSES},
        "method": __doc__.split("Method, in short")[1].strip(),
        "bands": bands,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, separators=(",", ":"), ensure_ascii=False), "utf-8")

    print(f"rows read: {seen}; weights dropped as outliers: {dropped}")
    for name in CLASSES:
        print(f"class {name}: {len(dogs[name])} dogs, {visits[name]} visits")
    print(f"written {args.out} ({args.out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

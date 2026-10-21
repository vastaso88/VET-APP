"""Builds the kitten growth bands shipped with the app from the data of

    Salt C, German AJ, Henzel KS, Butterwick RF. Growth standard charts for
    monitoring bodyweight in intact domestic shorthair kittens from the USA.
    PLoS ONE 2022. https://pmc.ncbi.nlm.nih.gov/articles/PMC9678321/
    Data: https://datacat.liverpool.ac.uk/1456/ (Creative Commons Attribution
    3.0), KGC1_dataset.csv

Like the puppy bands, the output is NOT the official chart (a GAMLSS model)
but empirical percentiles of body weight by age and sex over the "Modelling"
data set (healthy cats in ideal body condition, the one the authors built the
charts from). Visits at 8 to 78 weeks; a point is published only when its
window of +-2 weeks (+-4 after 52 weeks) holds at least 200 visits; the
percentile curves are made non-decreasing with a running maximum.

Usage (the CSV is untrusted input: keep it outside the repo):

    python scripts/growth/build_kitten_growth_bands.py \\
        --csv C:/path/KGC1_dataset.csv \\
        --out apps/mobile_app/assets/growth/kitten_growth_bands.json
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

MIN_WEEK = 8
MAX_WEEK = 78
MIN_N = 200
PERCENTILES = (3, 10, 25, 50, 75, 90, 97)
WEIGHT_STEP = 0.05
WEEKS_PER_YEAR = 365.25 / 7
DATASET = "Modelling"

ATTRIBUTION = (
    "Derivato da dati CC BY 3.0 di Salt C. et al., PLOS ONE 2022 "
    "(https://pmc.ncbi.nlm.nih.gov/articles/PMC9678321/); "
    "non sono le curve ufficiali WALTHAM."
)


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
    series: dict[int, list[float]] = {q: [] for q in PERCENTILES}
    used: list[int] = []
    counts: list[int] = []
    for age in ages:
        half = 2 if age <= 52 else 4
        pooled: Counter[int] = Counter()
        for week in range(age - half, age + half + 1):
            pooled.update(weeks.get(week, ()))
        total = sum(pooled.values())
        if total < MIN_N:
            continue
        used.append(age)
        counts.append(total)
        for q in PERCENTILES:
            series[q].append(percentile(pooled, total, q))
    for q in PERCENTILES:
        top = 0.0
        for index, value in enumerate(series[q]):
            top = max(top, value)
            series[q][index] = round(top, 2)
    return used, series, counts


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--csv", required=True, type=Path, help="KGC1_dataset.csv")
    parser.add_argument("--out", required=True, type=Path, help="output JSON")
    args = parser.parse_args(argv)

    cells: dict[str, dict[int, Counter[int]]] = defaultdict(lambda: defaultdict(Counter))
    cats: dict[str, set[str]] = defaultdict(set)
    visits: Counter[str] = Counter()
    with args.csv.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            sex = {"M": "male", "F": "female"}.get(row["Sex"])
            if row["DataSet"] != DATASET or sex is None:
                continue
            try:
                week = round(float(row["Visit_Age_Yrs"]) * WEEKS_PER_YEAR)
                weight = float(row["Weight_kg"])
            except ValueError:
                continue
            if not MIN_WEEK <= week <= MAX_WEEK or not 0.2 <= weight <= 12:
                continue
            cells[sex][week][round(weight / WEIGHT_STEP)] += 1
            cats[sex].add(row["Cat_ID"])
            visits[sex] += 1

    bands = {}
    for sex, weeks in sorted(cells.items()):
        ages, series, counts = build_series(weeks)
        if ages:
            bands[sex] = {"weeks": ages, "n": counts, **{f"p{q}": series[q] for q in PERCENTILES}}

    result = {
        "attribution": ATTRIBUTION,
        "licence": "CC BY 3.0",
        "source": {
            "article": "Salt C et al., PLoS ONE 2022 (kittens)",
            "data": "https://datacat.liverpool.ac.uk/1456/",
        },
        "unit": {"age": "weeks", "weight": "kg"},
        "percentiles": list(PERCENTILES),
        "catsUsed": {sex: len(ids) for sex, ids in cats.items()},
        "visitsUsed": dict(visits),
        "method": f"Data set '{DATASET}' (healthy, ideal body condition), intact domestic "
        f"shorthair kittens; ages {MIN_WEEK}-{MAX_WEEK} weeks; weights outside 0.2-12 kg dropped; "
        f"weights kept at {WEIGHT_STEP} kg, nearest-rank percentiles over a window of +-2 weeks "
        "(+-4 after 52 weeks), at least 200 visits per point, running maximum.",
        "bands": bands,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, separators=(",", ":"), ensure_ascii=False), "utf-8")
    for sex in ("male", "female"):
        print(f"{sex}: {len(cats[sex])} cats, {visits[sex]} visits")
    print(f"written {args.out} ({args.out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

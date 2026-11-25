"""The pet's weighings (the "Monitoraggio" page of the app).

The chat reads the latest one instead of the free-text weight of the profile,
with its date, so it can tell how recent the figure is ("23 kg al 14 ottobre").
"""

from datetime import UTC, date, datetime, timedelta

from pydantic import BaseModel

_MONTHS_IT = (
    "gennaio",
    "febbraio",
    "marzo",
    "aprile",
    "maggio",
    "giugno",
    "luglio",
    "agosto",
    "settembre",
    "ottobre",
    "novembre",
    "dicembre",
)


# A weighing dated after today is not a weighing: refused when written (the database trigger in
# scripts/setup/weight_no_future_dates.sql) and ignored when read. One day of tolerance, for the
# phones whose time zone is ahead of the server's.
FUTURE_TOLERANCE_DAYS = 1


def latest_allowed_date(now: datetime | None = None) -> date:
    """The last date a weighing may carry: tomorrow in UTC."""
    return ((now or datetime.now(UTC)).date()) + timedelta(days=FUTURE_TOLERANCE_DAYS)


# The earliest date a weighing may carry (collaudo F33: 1900 was accepted). Far below any real
# record of a pet, far above anything that is an error. Refused when written (the database trigger
# in scripts/setup/weight_one_per_day.sql) and ignored when read.
EARLIEST_WEIGHT_DATE = date(1970, 1, 1)


class WeightMeasurement(BaseModel):
    pet_id: str
    measured_at: date
    weight_kg: float
    body_condition: int | None = None


def format_weight_kg(weight_kg: float) -> str:
    """ "23 kg", "10,25 kg" or, under a kilogram, "420 g"."""
    if weight_kg < 1:
        return f"{round(weight_kg * 1000)} g"
    text = f"{round(weight_kg, 2):.2f}".rstrip("0").rstrip(".")
    return f"{text.replace('.', ',')} kg"


def format_date_it(measured: date, today: date) -> str:
    """ "14 ottobre", with the year when it is not the current one."""
    when = f"{measured.day} {_MONTHS_IT[measured.month - 1]}"
    return when if measured.year == today.year else f"{when} {measured.year}"


def weight_label_with_date(measurement: WeightMeasurement, today: date) -> str:
    """ "23 kg al 14 ottobre" (with the year when it is not the current one).

    The body condition is not part of it: the chat states it once, see
    `SendChatMessageService._body_condition_context`."""
    when = format_date_it(measurement.measured_at, today)
    return f"{format_weight_kg(measurement.weight_kg)} al {when}"


def weight_history_for_prompt(measurements: list[WeightMeasurement], today: date) -> str | None:
    """The recorded weighings, oldest first, and the change from the first to the last (collaudo
    F06: the chat knew only the latest one and missed a fall of 22% in seven weeks). The sums are
    done here, not by the model: it only gets figures. None with fewer than two weighings.

    Two weighings of the same day: the later of the two (the repository keeps the order)."""
    by_day: dict[date, WeightMeasurement] = {}
    for measurement in measurements:
        by_day[measurement.measured_at] = measurement
    ordered = [by_day[day] for day in sorted(by_day)]
    if len(ordered) < 2:
        return None
    listed = "; ".join(
        f"{format_weight_kg(m.weight_kg)} ({format_date_it(m.measured_at, today)})" for m in ordered
    )
    first, last = ordered[0], ordered[-1]
    change = last.weight_kg - first.weight_kg
    percent = 100 * change / first.weight_kg
    days = (last.measured_at - first.measured_at).days
    sign = "+" if change > 0 else "-" if change < 0 else ""
    return (
        f"{listed}. From the first to the last: {sign}{format_weight_kg(abs(change))} "
        f"({sign}{abs(percent):.0f}%) in {days} days"
    )

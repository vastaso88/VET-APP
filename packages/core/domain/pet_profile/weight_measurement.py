"""The pet's weighings (the "Monitoraggio" page of the app).

The chat reads the latest one instead of the free-text weight of the profile,
with its date, so it can tell how recent the figure is ("23 kg al 14 ottobre").
"""

from datetime import date

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

# Body condition levels as the app stores them (1..5).
_BODY_CONDITION_IT = {
    1: "molto magro",
    2: "magro",
    3: "normale",
    4: "leggermente sovrappeso",
    5: "sovrappeso",
}


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


def weight_label_with_date(measurement: WeightMeasurement, today: date) -> str:
    """ "23 kg al 14 ottobre" (with the year when it is not the current one),
    followed by the body condition when the weighing recorded it."""
    measured = measurement.measured_at
    when = f"{measured.day} {_MONTHS_IT[measured.month - 1]}"
    if measured.year != today.year:
        when = f"{when} {measured.year}"
    label = f"{format_weight_kg(measurement.weight_kg)} al {when}"
    condition = _BODY_CONDITION_IT.get(measurement.body_condition or 0)
    if condition:
        label = f"{label}, corporatura: {condition}"
    return label

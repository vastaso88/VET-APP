from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Any


@dataclass(frozen=True)
class DemoSeedBundle:
    pet_profiles: tuple[dict[str, Any], ...]
    conversations: tuple[dict[str, Any], ...]
    reminders: tuple[dict[str, Any], ...]


def build_demo_seed(owner_id: str, *, today: date | None = None) -> DemoSeedBundle:
    seed_day = today or date.today()

    moka_pet_id = "demo-pet-moka"
    oliver_pet_id = "demo-pet-oliver"

    pet_profiles = (
        {
            "id": moka_pet_id,
            "owner_id": owner_id,
            "name": "Moka",
            "species": "dog",
            "breed": "Meticcio di taglia media",
            "age_years": 5,
            "notes": "Stomaco delicato, controllo periodico gia pianificato.",
        },
        {
            "id": oliver_pet_id,
            "owner_id": owner_id,
            "name": "Oliver",
            "species": "cat",
            "breed": "Europeo a pelo corto",
            "age_years": 6,
            "notes": "Vita in casa, attenzione ai controlli dentali.",
        },
    )

    conversations = (
        {
            "id": "demo-conv-moka-digestione",
            "owner_id": owner_id,
            "pet_id": moka_pet_id,
            "title": "Digestione Moka",
            "messages": [
                _message(
                    "user",
                    "Moka oggi mangia poco e ha un po' di nausea.",
                    seed_day,
                    hour=8,
                    minute=45,
                ),
                _message(
                    "assistant",
                    "Monitora appetito e idratazione per 24 ore e contatta il veterinario se "
                    "peggiora.",
                    seed_day,
                    hour=8,
                    minute=46,
                ),
            ],
        },
        {
            "id": "demo-conv-oliver-denti",
            "owner_id": owner_id,
            "pet_id": oliver_pet_id,
            "title": "Controllo dentale Oliver",
            "messages": [
                _message(
                    "user",
                    "Oliver ha alito pesante e mastica piano.",
                    seed_day - timedelta(days=1),
                    hour=18,
                    minute=10,
                ),
                _message(
                    "assistant",
                    "Programma un controllo dentale e tieni traccia dell'appetito nei "
                    "prossimi giorni.",
                    seed_day - timedelta(days=1),
                    hour=18,
                    minute=12,
                ),
            ],
        },
    )

    reminders = (
        {
            "id": "demo-reminder-moka-vaccino",
            "owner_id": owner_id,
            "pet_id": moka_pet_id,
            "title": "Vaccino richiamo Moka",
            "due_date": (seed_day + timedelta(days=12)).isoformat(),
            "notes": "Promemoria demo sincronizzato su Supabase.",
        },
        {
            "id": "demo-reminder-oliver-dentale",
            "owner_id": owner_id,
            "pet_id": oliver_pet_id,
            "title": "Controllo dentale Oliver",
            "due_date": (seed_day + timedelta(days=7)).isoformat(),
            "notes": "Portare ultimo referto e foto gengive.",
        },
    )

    return DemoSeedBundle(
        pet_profiles=pet_profiles,
        conversations=conversations,
        reminders=reminders,
    )


def _message(role: str, content: str, day: date, *, hour: int, minute: int) -> dict[str, str]:
    created_at = datetime.combine(day, time(hour=hour, minute=minute), tzinfo=UTC)
    return {
        "id": f"{role}-{day.isoformat()}-{hour:02d}{minute:02d}",
        "role": role,
        "content": content,
        "created_at": created_at.isoformat(),
    }

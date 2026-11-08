import os
from datetime import UTC, date, datetime

import pytest

from packages.bootstrap.container import get_container, reset_container
from packages.core.domain.age.models import AccountAge
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.shared.config.settings import reset_settings

os.environ["AUTH_BACKEND"] = "bootstrap"
os.environ["PERSISTENCE_BACKEND"] = "in_memory"
os.environ["BOOTSTRAP_USER_ID"] = "demo-user"
os.environ["BOOTSTRAP_USER_EMAIL"] = "demo@vetapp.local"
os.environ["LLM_PROVIDER"] = "echo"
os.environ["LLM_MODEL"] = "demo-model"
os.environ["LLM_API_KEY"] = "test-key"


@pytest.fixture(autouse=True)
def clear_container_state() -> None:
    reset_settings()
    reset_container()


class _EveryoneIsAdult(InMemoryAccountAgeRepository):
    """Stand-in for tests of features that are for adults only (Mercatino, paid
    plans): an owner with no declaration reads as a declared adult, while an
    explicit declaration (a test of the age rules) still wins."""

    def get(self, owner_id: str) -> AccountAge | None:
        return super().get(owner_id) or AccountAge(
            owner_id=owner_id,
            birth_date=date(1980, 1, 1),
            declared_at=datetime(2026, 1, 1, tzinfo=UTC),
        )


@pytest.fixture
def adult_everyone() -> None:
    """Opt-in: `pytestmark = pytest.mark.usefixtures("adult_everyone")`. The age
    gate itself is tested in tests/unit/test_age_gate.py and
    tests/integration/test_account_age_routes.py without this."""
    get_container().account_age_repository = _EveryoneIsAdult()

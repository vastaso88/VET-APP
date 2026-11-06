"""Device limit of a plan: how many installs can stay signed in to one
account, who gets signed out when a new one arrives, and that one owner's
devices never count against, or get revoked by, another owner."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError as PydanticValidationError

from apps.api.routes.devices import RegisterDeviceRequest
from packages.core.application.services.register_device import (
    RegisterDeviceInput,
    RegisterDeviceService,
)
from packages.core.domain.device.models import UserDevice
from packages.core.domain.subscription.limits import PlanLimits
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryUserDeviceRepository,
)

# Seeded devices are placed in the past of the real clock, which the service
# uses for "now", so the order of "last seen" is the one the test describes.
_NOON = datetime.now(UTC)


def _limits(max_devices: int) -> PlanLimits:
    return PlanLimits(max_pets=3, max_chats_per_pet=2, daily_questions=8, max_devices=max_devices)


def _service(
    repository: InMemoryUserDeviceRepository, limits: PlanLimits | None
) -> RegisterDeviceService:
    return RegisterDeviceService(repository, lambda _owner, _email: limits)


def _register(
    service: RegisterDeviceService, owner: str, device: str, *, claim: bool = False
) -> bool:
    return service.execute(
        RegisterDeviceInput(owner_id=owner, device_id=device, claim=claim)
    ).active


def _seed(repository: InMemoryUserDeviceRepository, owner: str, device: str, minutes: int) -> None:
    seen = _NOON - timedelta(minutes=minutes)
    repository.save(
        UserDevice(owner_id=owner, device_id=device, first_seen_at=seen, last_seen_at=seen)
    )


def _active_ids(repository: InMemoryUserDeviceRepository, owner: str) -> set[str]:
    return {d.device_id for d in repository.list_for_owner(owner) if d.is_active}


def test_a_new_device_is_registered_and_active() -> None:
    repository = InMemoryUserDeviceRepository()
    service = _service(repository, _limits(2))

    assert _register(service, "owner-a", "phone-aaaa") is True
    assert _active_ids(repository, "owner-a") == {"phone-aaaa"}


def test_an_ordinary_start_keeps_the_device_and_updates_last_seen() -> None:
    repository = InMemoryUserDeviceRepository()
    _seed(repository, "owner-a", "phone-aaaa", minutes=600)
    service = _service(repository, _limits(2))

    assert _register(service, "owner-a", "phone-aaaa") is True

    (device,) = repository.list_for_owner("owner-a")
    assert device.last_seen_at > _NOON - timedelta(minutes=600)


def test_when_the_places_are_full_the_oldest_device_is_revoked() -> None:
    repository = InMemoryUserDeviceRepository()
    _seed(repository, "owner-a", "phone-old1", minutes=300)
    _seed(repository, "owner-a", "phone-new1", minutes=10)
    service = _service(repository, _limits(2))

    assert _register(service, "owner-a", "tablet-new", claim=True) is True

    assert _active_ids(repository, "owner-a") == {"phone-new1", "tablet-new"}


def test_a_revoked_device_is_told_so_on_its_next_start() -> None:
    repository = InMemoryUserDeviceRepository()
    _seed(repository, "owner-a", "phone-old1", minutes=300)
    _seed(repository, "owner-a", "phone-new1", minutes=10)
    service = _service(repository, _limits(2))
    _register(service, "owner-a", "tablet-new", claim=True)

    assert _register(service, "owner-a", "phone-old1") is False


def test_signing_in_again_on_a_revoked_device_takes_a_place_back() -> None:
    repository = InMemoryUserDeviceRepository()
    _seed(repository, "owner-a", "phone-old1", minutes=300)
    _seed(repository, "owner-a", "phone-new1", minutes=10)
    service = _service(repository, _limits(2))
    _register(service, "owner-a", "tablet-new", claim=True)

    assert _register(service, "owner-a", "phone-old1", claim=True) is True

    active = _active_ids(repository, "owner-a")
    assert "phone-old1" in active
    assert len(active) == 2, "the limit still holds: someone else gave up a place"


def test_a_device_never_seen_before_is_registered_even_without_claim() -> None:
    # Sessions that were open before devices were tracked register on their
    # first start; they do not lock themselves out.
    repository = InMemoryUserDeviceRepository()
    service = _service(repository, _limits(1))

    assert _register(service, "owner-a", "phone-aaaa", claim=False) is True


def test_one_place_means_the_newest_device_replaces_the_previous_one() -> None:
    repository = InMemoryUserDeviceRepository()
    _seed(repository, "owner-a", "phone-aaaa", minutes=60)
    service = _service(repository, _limits(1))

    _register(service, "owner-a", "phone-bbbb", claim=True)

    assert _active_ids(repository, "owner-a") == {"phone-bbbb"}


def test_other_owners_devices_neither_count_nor_get_revoked() -> None:
    repository = InMemoryUserDeviceRepository()
    _seed(repository, "owner-b", "b-phone-1", minutes=500)
    _seed(repository, "owner-b", "b-phone-2", minutes=400)
    service = _service(repository, _limits(2))

    assert _register(service, "owner-a", "a-phone-1", claim=True) is True
    assert _register(service, "owner-a", "a-phone-2", claim=True) is True

    assert _active_ids(repository, "owner-b") == {"b-phone-1", "b-phone-2"}
    assert _active_ids(repository, "owner-a") == {"a-phone-1", "a-phone-2"}


def test_the_same_device_id_under_two_owners_stays_separate() -> None:
    repository = InMemoryUserDeviceRepository()
    service = _service(repository, _limits(1))

    _register(service, "owner-a", "shared-id-1", claim=True)
    _register(service, "owner-b", "shared-id-1", claim=True)

    assert _active_ids(repository, "owner-a") == {"shared-id-1"}
    assert _active_ids(repository, "owner-b") == {"shared-id-1"}


def test_no_limit_means_no_device_is_ever_revoked() -> None:
    repository = InMemoryUserDeviceRepository()
    service = _service(repository, None)

    for index in range(6):
        assert _register(service, "dev-owner", f"device-{index:04d}", claim=True) is True

    assert len(_active_ids(repository, "dev-owner")) == 6


def test_the_answer_tells_the_limit() -> None:
    service = _service(InMemoryUserDeviceRepository(), _limits(3))

    result = service.execute(RegisterDeviceInput(owner_id="owner-a", device_id="phone-aaaa"))

    assert result.max_devices == 3


@pytest.mark.parametrize("device_id", ["short", "has space in it", "x" * 65, "ünicode-id-1"])
def test_a_malformed_device_id_is_refused(device_id: str) -> None:
    with pytest.raises(PydanticValidationError):
        RegisterDeviceRequest(device_id=device_id)
    with pytest.raises(PydanticValidationError):
        RegisterDeviceInput(owner_id="owner-a", device_id=device_id)

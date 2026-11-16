from typing import Protocol


class PlanAccessStore(Protocol):
    """What the database needs to know to enforce the plan on the app's direct
    writes (scripts/setup/plan_access_rules.sql) and that only the backend
    knows: the public-test plan (SUBSCRIPTION_TEST_PLAN), the developer
    allowlist (DEVELOPER_EMAILS, by e-mail) and the cap on pets kept in Ricordi
    (MEMORIAL_PETS_MAX)."""

    def set_test_plan(self, plan: str | None) -> None:
        """The plan every account writes as during a public test; None = off."""
        ...

    def set_max_memorial_pets(self, cap: int) -> None:
        """How many pets one account may keep in Ricordi."""
        ...

    def set_unlimited(self, owner_id: str, unlimited: bool) -> None:
        """Whether this account (a developer) writes without plan limits."""
        ...

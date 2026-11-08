from typing import Protocol


class PlanAccessStore(Protocol):
    """What the database needs to know to enforce the plan on the app's direct
    writes (scripts/setup/plan_access_rules.sql) and that only the backend
    knows: the public-test plan (SUBSCRIPTION_TEST_PLAN) and the developer
    allowlist (DEVELOPER_EMAILS, by e-mail)."""

    def set_test_plan(self, plan: str | None) -> None:
        """The plan every account writes as during a public test; None = off."""
        ...

    def set_unlimited(self, owner_id: str, unlimited: bool) -> None:
        """Whether this account (a developer) writes without plan limits."""
        ...

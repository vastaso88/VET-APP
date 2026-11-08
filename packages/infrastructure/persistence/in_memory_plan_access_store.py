"""Local development and tests: what the backend would tell the database."""


class InMemoryPlanAccessStore:
    def __init__(self) -> None:
        self.test_plan: str | None = None
        self.unlimited: set[str] = set()
        self.writes = 0

    def set_test_plan(self, plan: str | None) -> None:
        self.writes += 1
        self.test_plan = plan

    def set_unlimited(self, owner_id: str, unlimited: bool) -> None:
        self.writes += 1
        if unlimited:
            self.unlimited.add(owner_id)
        else:
            self.unlimited.discard(owner_id)

from typing import Protocol


class ModelAvailability(Protocol):
    """The shared daily budget's view of the models (see LlmBudget)."""

    def order(self, models: list[str]) -> list[str]:
        """The models that may answer now; raises QuotaExhausted when none can."""
        ...

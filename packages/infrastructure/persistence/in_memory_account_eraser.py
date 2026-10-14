from packages.core.application.ports.account_eraser import ErasureReport


class InMemoryAccountEraser:
    """Local development without Supabase: the in-memory repositories vanish
    with the process and there is no sign-in identity to remove, so deleting
    an account has nothing to do. Never used when PERSISTENCE_BACKEND=supabase."""

    def erase_data(self, owner_id: str) -> ErasureReport:
        return ErasureReport()

    def delete_identity(self, owner_id: str) -> None:
        return None

from pydantic import BaseModel, Field


class AuthCredentialsRequest(BaseModel):
    email: str = Field(max_length=254)
    # Supabase accepts up to 72 bytes (bcrypt); anything longer is noise.
    password: str = Field(min_length=1, max_length=72)


class SignUpRequest(AuthCredentialsRequest):
    """Registration through the API. The app signs up with Supabase directly and
    records the acceptance itself; any client that comes through here must
    state it, and the server records it with the version and the date."""

    accept_terms: bool = False
    # "Quokka does not handle emergencies" (docs/compliance/22): a box of its own,
    # never implied by `accept_terms`.
    accept_emergency_notice: bool = False

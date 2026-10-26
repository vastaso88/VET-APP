from pydantic import BaseModel, Field


class AuthCredentialsRequest(BaseModel):
    email: str = Field(max_length=254)
    # Supabase accepts up to 72 bytes (bcrypt); anything longer is noise.
    password: str = Field(min_length=1, max_length=72)

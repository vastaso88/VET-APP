"""A refusal that carries its sentence as a TEXT KEY, so the API can write it in the language of
whoever asked (collaudo F24) while `detail` stays exactly what it was: the Italian sentence (or
the code an installed app reads).

`str(error)` is `detail`. The API handler adds `message` (the sentence in the request's language)
and `code` (the key); a client that is not the app shows `message`."""

from dataclasses import dataclass

from packages.core.domain.localization import translate
from packages.shared.errors.base import ValidationError


@dataclass(frozen=True)
class TextKey:
    """A parameter that is itself a text of the catalogue (a field's label), translated with
    the sentence that contains it."""

    key: str


class LocalizedValidationError(ValidationError):
    def __init__(self, key: str, *, detail: str | None = None, **params: object) -> None:
        self.key = key
        self.params = params
        super().__init__(detail if detail is not None else self.message("it"))

    def message(self, language: str | None) -> str:
        values = {
            name: translate(value.key, language) if isinstance(value, TextKey) else value
            for name, value in self.params.items()
        }
        return translate(self.key, language, **values)

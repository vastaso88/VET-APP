"""The page a sign-up confirmation link can land on.

An e-mail link opened on a computer, with no app to hand it to, must end on something a person
can read, not on the API's JSON, and not on an address the computer does not know. This is that
page: static text in the five app languages (chosen from the browser's language, Italian by
default), a button that opens the app, no script, no image, no external file, no form.

The page does not know whether the link worked: the confirmation happens before it, and the
answer for a link that was expired or already used is the same address with `error` in it. So
the text is neutral. Only the PRESENCE of an `error` parameter is looked at (to show the part
about an invalid link alone); nothing of the address is read, echoed or kept, and the page is
never cached because the address can carry a one-time code.
"""

from __future__ import annotations

from html import escape

from fastapi import APIRouter, Header, Request
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["auth-pages"])

_DEFAULT = "it"
APP_LINK = "vetapp://auth-callback"  # the app's own address, never with a code

# language: (title, if you just confirmed, if the link did not work, button, link not valid)
_TEXTS: dict[str, tuple[str, str, str, str, str]] = {
    "it": (
        "Torna all'app Quokka",
        "Se hai appena confermato l'indirizzo, accedi con e-mail e password.",
        "Se il link era scaduto o già usato, nell'app puoi chiederne uno nuovo.",
        "Apri Quokka",
        "Il link non è valido, è scaduto o è già stato usato. Nell'app puoi chiederne uno nuovo.",
    ),
    "en": (
        "Back to the Quokka app",
        "If you have just confirmed your address, sign in with your email and password.",
        "If the link had expired or was already used, you can ask for a new one in the app.",
        "Open Quokka",
        "The link is not valid, has expired or was already used. You can ask for a new one "
        "in the app.",
    ),
    "es": (
        "Vuelve a la app de Quokka",
        "Si acabas de confirmar tu dirección, inicia sesión con tu correo y tu contraseña.",
        "Si el enlace había caducado o ya se había usado, puedes pedir uno nuevo en la app.",
        "Abrir Quokka",
        "El enlace no es válido, ha caducado o ya se ha usado. Puedes pedir uno nuevo en la app.",
    ),
    "fr": (
        "Retour à l'application Quokka",
        "Si vous venez de confirmer votre adresse, connectez-vous avec votre e-mail et votre "
        "mot de passe.",
        "Si le lien avait expiré ou avait déjà été utilisé, vous pouvez en demander un nouveau "
        "dans l'application.",
        "Ouvrir Quokka",
        "Le lien n'est pas valide, a expiré ou a déjà été utilisé. Vous pouvez en demander un "
        "nouveau dans l'application.",
    ),
    "de": (
        "Zurück zur Quokka-App",
        "Wenn Sie Ihre Adresse gerade bestätigt haben, melden Sie sich mit E-Mail und Passwort an.",
        "Wenn der Link abgelaufen war oder schon verwendet wurde, können Sie in der App einen "
        "neuen anfordern.",
        "Quokka öffnen",
        "Der Link ist ungültig, abgelaufen oder wurde schon verwendet. Sie können in der App "
        "einen neuen anfordern.",
    ),
}


def pick_language(accept_language: str | None) -> str:
    """The first language of the browser's list that the app has; Italian when none is."""
    for part in (accept_language or "").split(","):
        code = part.split(";")[0].strip().lower().split("-")[0]
        if code in _TEXTS:
            return code
    return _DEFAULT


def render_page(language: str, link_failed: bool = False) -> str:
    title, confirmed, failed, button, invalid = _TEXTS[language]
    body = (
        f"<p>{escape(invalid)}</p>"
        if link_failed
        else f'<p>{escape(confirmed)}</p><p class="note">{escape(failed)}</p>'
    )
    return (
        f'<!doctype html><html lang="{language}"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<meta name="robots" content="noindex">'
        "<title>Quokka</title>"
        "<style>body{font-family:system-ui,sans-serif;margin:0;padding:48px 16px;"
        "background:#fbf7f1;color:#2b2b2b}main{max-width:480px;margin:0 auto}"
        "h1{font-size:1.5rem}p{line-height:1.5}.note{color:#6b6b6b;font-size:.9rem}"
        "a.open{display:inline-block;margin-top:8px;padding:12px 24px;border-radius:12px;"
        "background:#2e686a;color:#fff;text-decoration:none;font-weight:600}</style>"
        f"</head><body><main><h1>{escape(title)}</h1>{body}"
        f'<p><a class="open" href="{APP_LINK}">{escape(button)}</a></p></main></body></html>'
    )


@router.get("/auth/confirmed", response_class=HTMLResponse, include_in_schema=False)
def sign_up_landing(
    request: Request, accept_language: str | None = Header(default=None)
) -> HTMLResponse:
    # Only whether an error is there; its content is never read.
    link_failed = any(key in request.query_params for key in ("error", "error_code"))
    return HTMLResponse(
        render_page(pick_language(accept_language), link_failed),
        headers={
            # Nothing runs and nothing loads: only the inline style above.
            "Content-Security-Policy": (
                "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; "
                "form-action 'none'; frame-ancestors 'none'"
            ),
            # The address can carry a one-time code: never stored, never passed on.
            "Cache-Control": "no-store",
            "Referrer-Policy": "no-referrer",
            "Vary": "Accept-Language",
        },
    )

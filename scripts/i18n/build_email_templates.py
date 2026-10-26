#!/usr/bin/env python3
"""Builds the Supabase Auth e-mail templates (it/en/de/fr/es in one file each).

Supabase has ONE template per e-mail type for the whole project, so each
generated HTML picks the language from the user's metadata
(``preferred_locale``, written at sign-up by the app and kept up to date by
``PUT /account/preferences``) with Go template conditionals. Italian is the
fallback when the metadata is missing.

Output: ``supabase/email_templates/*.html`` and ``subjects.txt``, ready to paste
in Dashboard -> Authentication -> Email Templates (see
``supabase/email_templates/README.md``). Nothing here talks to Supabase.

Usage (repo root)::

    python scripts/i18n/build_email_templates.py          # rewrite the files
    python scripts/i18n/build_email_templates.py --check  # exit 1 if they are stale
"""

# ruff: noqa: E501  (long lines are translated e-mail copy)

from __future__ import annotations

import argparse
import sys
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "supabase" / "email_templates"

# Order matters only for readability; "it" is the {{ else }} branch.
LANGUAGES = ["en", "de", "fr", "es", "it"]

BRAND = "#2E686A"  # AppColors.primary
TEXT = "#213134"  # AppColors.text
MUTED = "#5E706E"  # AppColors.secondaryText
BACKGROUND = "#F6F1EA"  # AppColors.background

# Per template: subject, heading, body (HTML allowed, Go variables allowed),
# button label (None = no button), what to show under the button, footer.
# Tone follows the app: it "tu", en neutral, de "Sie", fr "vous", es "tú".
TEMPLATES: dict[str, dict] = {
    "confirm_signup": {
        "supabase_name": "Confirm signup",
        "link": "{{ .ConfirmationURL }}",
        "subject": {
            "en": "Confirm your VetApp account",
            "de": "Bestätigen Sie Ihr VetApp-Konto",
            "fr": "Confirmez votre compte VetApp",
            "es": "Confirma tu cuenta de VetApp",
            "it": "Conferma il tuo account VetApp",
        },
        "heading": {
            "en": "Confirm your email",
            "de": "E-Mail-Adresse bestätigen",
            "fr": "Confirmez votre adresse e-mail",
            "es": "Confirma tu correo",
            "it": "Conferma la tua email",
        },
        "body": {
            "en": "Thanks for signing up for VetApp. Tap the button to confirm your email address and get started.",
            "de": "Danke für Ihre Registrierung bei VetApp. Tippen Sie auf die Schaltfläche, um Ihre E-Mail-Adresse zu bestätigen und loszulegen.",
            "fr": "Merci de vous être inscrit sur VetApp. Appuyez sur le bouton pour confirmer votre adresse e-mail et commencer.",
            "es": "Gracias por registrarte en VetApp. Toca el botón para confirmar tu correo y empezar.",
            "it": "Grazie per esserti registrato a VetApp. Tocca il pulsante per confermare la tua email e iniziare.",
        },
        "button": {
            "en": "Confirm email",
            "de": "E-Mail bestätigen",
            "fr": "Confirmer l'e-mail",
            "es": "Confirmar correo",
            "it": "Conferma email",
        },
        "footer": {
            "en": "If you did not create a VetApp account, you can ignore this email.",
            "de": "Falls Sie kein VetApp-Konto erstellt haben, können Sie diese E-Mail ignorieren.",
            "fr": "Si vous n'avez pas créé de compte VetApp, vous pouvez ignorer cet e-mail.",
            "es": "Si no has creado una cuenta de VetApp, puedes ignorar este correo.",
            "it": "Se non hai creato un account VetApp, puoi ignorare questa email.",
        },
    },
    "recovery": {
        "supabase_name": "Reset Password",
        "link": "{{ .ConfirmationURL }}",
        "subject": {
            "en": "Reset your VetApp password",
            "de": "VetApp-Passwort zurücksetzen",
            "fr": "Réinitialisez votre mot de passe VetApp",
            "es": "Restablece tu contraseña de VetApp",
            "it": "Reimposta la tua password VetApp",
        },
        "heading": {
            "en": "Reset your password",
            "de": "Passwort zurücksetzen",
            "fr": "Réinitialisez votre mot de passe",
            "es": "Restablece tu contraseña",
            "it": "Reimposta la tua password",
        },
        "body": {
            "en": "You asked to reset the password of your VetApp account. Tap the button to choose a new one. The link works for a limited time.",
            "de": "Sie haben das Zurücksetzen des Passworts Ihres VetApp-Kontos angefordert. Tippen Sie auf die Schaltfläche, um ein neues zu wählen. Der Link ist nur begrenzt gültig.",
            "fr": "Vous avez demandé à réinitialiser le mot de passe de votre compte VetApp. Appuyez sur le bouton pour en choisir un nouveau. Le lien est valable pour une durée limitée.",
            "es": "Has pedido restablecer la contraseña de tu cuenta de VetApp. Toca el botón para elegir una nueva. El enlace es válido durante un tiempo limitado.",
            "it": "Hai chiesto di reimpostare la password del tuo account VetApp. Tocca il pulsante per sceglierne una nuova. Il link vale per un tempo limitato.",
        },
        "button": {
            "en": "Choose a new password",
            "de": "Neues Passwort wählen",
            "fr": "Choisir un nouveau mot de passe",
            "es": "Elegir una contraseña nueva",
            "it": "Scegli una nuova password",
        },
        "footer": {
            "en": "If you did not ask for this, ignore this email: your password stays the same.",
            "de": "Falls Sie das nicht angefordert haben, ignorieren Sie diese E-Mail: Ihr Passwort bleibt unverändert.",
            "fr": "Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail : votre mot de passe reste inchangé.",
            "es": "Si no lo has pedido tú, ignora este correo: tu contraseña no cambia.",
            "it": "Se non l'hai chiesto tu, ignora questa email: la tua password resta invariata.",
        },
    },
    "magic_link": {
        "supabase_name": "Magic Link",
        "link": "{{ .ConfirmationURL }}",
        "subject": {
            "en": "Your VetApp sign-in link",
            "de": "Ihr VetApp-Anmeldelink",
            "fr": "Votre lien de connexion VetApp",
            "es": "Tu enlace de acceso a VetApp",
            "it": "Il tuo link di accesso a VetApp",
        },
        "heading": {
            "en": "Sign in to VetApp",
            "de": "Bei VetApp anmelden",
            "fr": "Connectez-vous à VetApp",
            "es": "Inicia sesión en VetApp",
            "it": "Accedi a VetApp",
        },
        "body": {
            "en": "Tap the button to sign in. The link can be used once and expires after a short time.",
            "de": "Tippen Sie auf die Schaltfläche, um sich anzumelden. Der Link kann einmal verwendet werden und läuft nach kurzer Zeit ab.",
            "fr": "Appuyez sur le bouton pour vous connecter. Le lien ne peut être utilisé qu'une fois et expire rapidement.",
            "es": "Toca el botón para iniciar sesión. El enlace se puede usar una sola vez y caduca en poco tiempo.",
            "it": "Tocca il pulsante per accedere. Il link si può usare una sola volta e scade dopo poco.",
        },
        "button": {
            "en": "Sign in",
            "de": "Anmelden",
            "fr": "Se connecter",
            "es": "Iniciar sesión",
            "it": "Accedi",
        },
        "footer": {
            "en": "If you did not request this link, ignore this email.",
            "de": "Falls Sie diesen Link nicht angefordert haben, ignorieren Sie diese E-Mail.",
            "fr": "Si vous n'avez pas demandé ce lien, ignorez cet e-mail.",
            "es": "Si no has pedido este enlace, ignora este correo.",
            "it": "Se non hai chiesto tu questo link, ignora questa email.",
        },
    },
    "email_change": {
        "supabase_name": "Change Email Address",
        "link": "{{ .ConfirmationURL }}",
        "subject": {
            "en": "Confirm your new VetApp email address",
            "de": "Neue E-Mail-Adresse für VetApp bestätigen",
            "fr": "Confirmez votre nouvelle adresse e-mail VetApp",
            "es": "Confirma tu nuevo correo de VetApp",
            "it": "Conferma il nuovo indirizzo email di VetApp",
        },
        "heading": {
            "en": "Confirm your new email address",
            "de": "Neue E-Mail-Adresse bestätigen",
            "fr": "Confirmez votre nouvelle adresse e-mail",
            "es": "Confirma tu nuevo correo",
            "it": "Conferma il nuovo indirizzo email",
        },
        "body": {
            "en": "You asked to change the email of your VetApp account from {{ .Email }} to {{ .NewEmail }}. Tap the button to confirm.",
            "de": "Sie möchten die E-Mail-Adresse Ihres VetApp-Kontos von {{ .Email }} auf {{ .NewEmail }} ändern. Tippen Sie zur Bestätigung auf die Schaltfläche.",
            "fr": "Vous avez demandé à remplacer l'adresse e-mail de votre compte VetApp, {{ .Email }}, par {{ .NewEmail }}. Appuyez sur le bouton pour confirmer.",
            "es": "Has pedido cambiar el correo de tu cuenta de VetApp de {{ .Email }} a {{ .NewEmail }}. Toca el botón para confirmar.",
            "it": "Hai chiesto di cambiare l'email del tuo account VetApp da {{ .Email }} a {{ .NewEmail }}. Tocca il pulsante per confermare.",
        },
        "button": {
            "en": "Confirm new email",
            "de": "Neue E-Mail bestätigen",
            "fr": "Confirmer la nouvelle adresse",
            "es": "Confirmar nuevo correo",
            "it": "Conferma nuova email",
        },
        "footer": {
            "en": "If this was not you, do not tap the button and change your password.",
            "de": "Falls Sie das nicht waren, tippen Sie nicht auf die Schaltfläche und ändern Sie Ihr Passwort.",
            "fr": "Si ce n'était pas vous, n'appuyez pas sur le bouton et changez votre mot de passe.",
            "es": "Si no has sido tú, no toques el botón y cambia tu contraseña.",
            "it": "Se non sei stato tu, non toccare il pulsante e cambia la password.",
        },
    },
    "reauthentication": {
        "supabase_name": "Reauthentication",
        "link": None,
        "subject": {
            "en": "Your VetApp confirmation code",
            "de": "Ihr VetApp-Bestätigungscode",
            "fr": "Votre code de confirmation VetApp",
            "es": "Tu código de confirmación de VetApp",
            "it": "Il tuo codice di conferma VetApp",
        },
        "heading": {
            "en": "Confirm it is you",
            "de": "Bestätigen Sie, dass Sie es sind",
            "fr": "Confirmez que c'est bien vous",
            "es": "Confirma que eres tú",
            "it": "Conferma che sei tu",
        },
        "body": {
            "en": "Enter this code in the app to continue:",
            "de": "Geben Sie diesen Code in der App ein, um fortzufahren:",
            "fr": "Saisissez ce code dans l'application pour continuer :",
            "es": "Introduce este código en la app para continuar:",
            "it": "Inserisci questo codice nell'app per continuare:",
        },
        "button": None,
        "footer": {
            "en": "If you did not ask for this code, ignore this email.",
            "de": "Falls Sie diesen Code nicht angefordert haben, ignorieren Sie diese E-Mail.",
            "fr": "Si vous n'avez pas demandé ce code, ignorez cet e-mail.",
            "es": "Si no has pedido este código, ignora este correo.",
            "it": "Se non hai chiesto tu questo codice, ignora questa email.",
        },
    },
}


def condition(language: str) -> str:
    # `and` short-circuits (Go >= 1.18), so a user without metadata does not
    # make `eq` compare nil with a string.
    return f'and .Data.preferred_locale (eq .Data.preferred_locale "{language}")'


def switch(per_language: dict[str, str]) -> str:
    """Go-template if / else if / else over the languages; Italian is the default."""
    parts: list[str] = []
    for index, language in enumerate(LANGUAGES[:-1]):
        keyword = "if" if index == 0 else "else if"
        parts.append(f"{{{{ {keyword} {condition(language)} }}}}{per_language[language]}")
    parts.append(f"{{{{ else }}}}{per_language[LANGUAGES[-1]]}{{{{ end }}}}")
    return "".join(parts)


def esc(text: str) -> str:
    """HTML-escape but keep Go template actions ({{ .Email }}) intact."""
    out, rest = [], text
    while "{{" in rest:
        head, _, tail = rest.partition("{{")
        action, _, rest = tail.partition("}}")
        out.append(escape(head, quote=False) + "{{" + action + "}}")
    out.append(escape(rest, quote=False))
    return "".join(out)


def block(spec: dict, language: str) -> str:
    heading = esc(spec["heading"][language])
    body = esc(spec["body"][language])
    footer = esc(spec["footer"][language])
    lines = [
        f'<h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;color:{TEXT};">{heading}</h1>',
        f'<p style="margin:0 0 20px;font-size:16px;line-height:1.5;color:{TEXT};">{body}</p>',
    ]
    if spec["link"]:
        button = esc(spec["button"][language])
        lines += [
            f'<p style="margin:0 0 20px;"><a href="{spec["link"]}" '
            f'style="display:inline-block;padding:12px 24px;border-radius:12px;'
            f"background:{BRAND};color:#ffffff;font-size:16px;font-weight:600;"
            f'text-decoration:none;">{button}</a></p>',
            f'<p style="margin:0 0 20px;font-size:13px;line-height:1.4;color:{MUTED};'
            f'word-break:break-all;">{spec["link"]}</p>',
        ]
    else:
        lines.append(
            f'<p style="margin:0 0 20px;font-size:32px;letter-spacing:6px;font-weight:700;'
            f'color:{BRAND};">{{{{ .Token }}}}</p>'
        )
    lines.append(f'<p style="margin:0;font-size:13px;line-height:1.4;color:{MUTED};">{footer}</p>')
    return "\n".join(lines)


def render(name: str, spec: dict) -> str:
    content = switch({language: "\n" + block(spec, language) + "\n" for language in LANGUAGES})
    return f"""<!-- VetApp - Supabase "{spec["supabase_name"]}" template, generated by
     scripts/i18n/build_email_templates.py - edit the script, not this file.
     Language = user_metadata.preferred_locale (en/de/fr/es, anything else = Italian). -->
<!doctype html>
<html>
<body style="margin:0;padding:0;background:{BACKGROUND};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{BACKGROUND};">
    <tr><td align="center" style="padding:24px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
             style="max-width:480px;background:#ffffff;border-radius:16px;font-family:Arial,Helvetica,sans-serif;">
        <tr><td style="padding:24px 24px 0;font-size:20px;font-weight:700;color:{BRAND};">VetApp</td></tr>
        <tr><td style="padding:16px 24px 24px;">
{content}
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
"""


def subjects() -> str:
    lines = [
        "Supabase Auth subjects: paste ONE line per template in the 'Subject heading' field.",
        "A) conditional (language from user metadata) - try this first, check the preview;",
        "B) neutral fallback if the dashboard shows the template code instead of rendering it.",
        "",
    ]
    for name, spec in TEMPLATES.items():
        lines.append(f"## {spec['supabase_name']}  ({name}.html)")
        lines.append("A) " + switch({lang: spec["subject"][lang] for lang in LANGUAGES}))
        lines.append("B) " + " · ".join(spec["subject"][lang] for lang in ("it", "en")))
        lines.append("")
    return "\n".join(lines)


def outputs() -> dict[Path, str]:
    files = {OUT / f"{name}.html": render(name, spec) for name, spec in TEMPLATES.items()}
    files[OUT / "subjects.txt"] = subjects()
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the files are out of date")
    args = parser.parse_args()
    stale = []
    for path, text in outputs().items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current != text:
            stale.append(path)
            if not args.check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8", newline="\n")
    if args.check and stale:
        print("stale:", *(str(p.relative_to(ROOT)) for p in stale), sep="\n  ")
        return 1
    print(
        ("checked" if args.check else "written"), len(outputs()), "files in", OUT.relative_to(ROOT)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

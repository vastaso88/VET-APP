"""Who writes, at the end of every service e-mail: the signature and the small line under it.

Reviewed in five languages on 25 November 2026. The small line exists only when the company
and the contact are configured (they come from the environment, never from here).
"""

from packages.core.domain.localization import SupportedLocale

SIGNATURES: dict[SupportedLocale, str] = {
    "it": "Il team di Quokka",
    "en": "The Quokka team",
    "es": "El equipo de Quokka",
    "de": "Das Quokka-Team",
    "fr": "L'équipe Quokka",
}

SMALL_LINES: dict[SupportedLocale, str] = {
    "it": "Quokka è un servizio di {titolare} · {contatto}",
    "en": "Quokka is a service provided by {titolare} · {contatto}",
    "es": "Quokka es un servicio de {titolare} · {contatto}",
    "de": "Quokka ist ein Dienst von {titolare} · {contatto}",
    "fr": "Quokka est un service de {titolare} · {contatto}",
}


def small_line(language: SupportedLocale, company: str, contact: str) -> str:
    """The line, or nothing while the company or the contact is not configured."""
    company, contact = company.strip(), contact.strip()
    if not (company and contact):
        return ""
    return SMALL_LINES[language].format(titolare=company, contatto=contact)

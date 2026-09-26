"""Account-level consent copy (docs/compliance/04_termini_e_consensi.md).

DRAFT — reviewed by whoever owns AI Act / privacy copy for this project
(see docs/compliance/03_consenso_cartella_clinica.md for the precedent).
Bump the relevant entry in CURRENT_VERSIONS whenever its text changes
materially, so a stored ConsentRecord.version keeps meaning "the text the
owner actually saw", not just "the latest text".
"""

from packages.core.domain.consent.models import AccountConsentType, ConsentCatalogEntry

CURRENT_VERSIONS: dict[str, str] = {
    AccountConsentType.TERMS_OF_SERVICE: "v1",
    AccountConsentType.PRIVACY_POLICY: "v1",
    AccountConsentType.MARKETING_EMAIL: "v1",
    AccountConsentType.ANALYTICS: "v1",
}

CONSENT_TEXT_IT: dict[str, str] = {
    AccountConsentType.TERMS_OF_SERVICE: (
        "Utilizzando VetApp accetti i Termini di Servizio: le regole che "
        "disciplinano l'uso dell'app, i tuoi obblighi come utente e i limiti "
        "di responsabilità del servizio, incluso il fatto che i suggerimenti "
        "dell'assistente non sostituiscono il parere di un veterinario. "
        "Senza questa accettazione non è possibile creare un account."
    ),
    AccountConsentType.PRIVACY_POLICY: (
        "Ti informiamo su quali dati raccogliamo, perché li trattiamo (per "
        "gestire il tuo account, il profilo dei tuoi animali e le risposte "
        "dell'assistente) e quali diritti puoi esercitare, in conformità al "
        "GDPR. L'informativa completa resta consultabile in qualsiasi "
        "momento dalle Impostazioni."
    ),
    AccountConsentType.MARKETING_EMAIL: (
        "Con il tuo consenso, possiamo inviarti via email novità su VetApp "
        "e consigli per i tuoi animali. Puoi revocare il consenso in "
        "qualsiasi momento dalle Impostazioni, senza alcuna conseguenza "
        "sull'uso dell'app."
    ),
    AccountConsentType.ANALYTICS: (
        "Con il tuo consenso, raccogliamo dati statistici e anonimi sull'uso "
        "dell'app (es. schermate visitate, funzionalità usate) per capire "
        "come migliorarla. Puoi revocare il consenso in qualsiasi momento "
        "dalle Impostazioni, senza alcuna conseguenza sull'uso dell'app."
    ),
}


def build_consent_catalog() -> dict[str, ConsentCatalogEntry]:
    return {
        key: ConsentCatalogEntry(version=CURRENT_VERSIONS[key], text=CONSENT_TEXT_IT[key])
        for key in AccountConsentType.ALL
    }

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
    AccountConsentType.CONTRIBUTION_RULES: "v1",
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
    # Text agreed with docs/compliance/07_contributi_utenti.md.
    AccountConsentType.CONTRIBUTION_RULES: (
        "Regole per segnalazioni e voti\n"
        "1. Segnala solo ciò che hai verificato di persona o che sai con certezza.\n"
        "2. Per le attività scrivi solo il nome commerciale, come appare "
        "sull'insegna. Non inserire telefoni, indirizzi privati, email o dati "
        "di altre persone.\n"
        '3. Le segnalazioni restano "in attesa di conferma" finché altri '
        "utenti non le confermano. Non sono una garanzia: verifica sempre "
        "prima di recarti in un luogo.\n"
        "4. I voti sulle aree cani sono opinioni personali: un voto per area.\n"
        "5. Non segnalare come area cani proprietà private e non invitare "
        "altri a entrare in luoghi privati.\n"
        "6. Non usare le segnalazioni per danneggiare un'attività. "
        "Segnalazioni false o ripetute possono portare alla sospensione "
        "dell'account.\n"
        "7. Le attività possono chiedere una correzione o la rimozione di un "
        "dato: verifichiamo e rispondiamo entro 5 giorni lavorativi.\n"
        "8. Le tue segnalazioni e i tuoi voti sono pubblicati senza il tuo "
        "nome né i tuoi dati personali, che restano trattati come da "
        "informativa privacy."
    ),
}


def build_consent_catalog() -> dict[str, ConsentCatalogEntry]:
    return {
        key: ConsentCatalogEntry(version=CURRENT_VERSIONS[key], text=CONSENT_TEXT_IT[key])
        for key in AccountConsentType.ALL
    }

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
    # v2 (2026-10-06): v1 promised a full notice "consultabile dalle
    # Impostazioni" that does not exist; v2 says what is processed and that
    # the full notice is still being written.
    AccountConsentType.PRIVACY_POLICY: "v2",
    AccountConsentType.MARKETING_EMAIL: "v1",
    AccountConsentType.ANALYTICS: "v1",
    AccountConsentType.CONTRIBUTION_RULES: "v2",
}

CONSENT_TEXT_IT: dict[str, str] = {
    AccountConsentType.TERMS_OF_SERVICE: (
        "Utilizzando VetApp accetti i Termini di Servizio: le regole che "
        "disciplinano l'uso dell'app, i tuoi obblighi come utente e i limiti "
        "di responsabilità del servizio, incluso il fatto che i suggerimenti "
        "dell'assistente non sostituiscono il parere di un veterinario. "
        "Senza questa accettazione non è possibile creare un account."
    ),
    # A summary, not the full notice (art. 13 GDPR): it must stay true to what
    # the app does today (see docs/compliance/09_informativa_privacy_bozza.md)
    # and must not promise a page that does not exist.
    AccountConsentType.PRIVACY_POLICY: (
        "In sintesi: per farti usare VetApp trattiamo i dati dell'account "
        "(nome ed email), il profilo dei tuoi animali, i documenti e le foto "
        "che carichi, le conversazioni con l'assistente e, se li attivi, la "
        "tua posizione e i percorsi delle passeggiate. Quello che mandi "
        "all'assistente (domande, allegati, messaggi vocali) viene inviato a "
        "un fornitore esterno di intelligenza artificiale per scrivere le "
        "risposte; la cartella clinica solo se lo consenti. I dati sono "
        "conservati su servizi di terzi (hosting e database). Puoi chiedere "
        "accesso, correzione o cancellazione dei tuoi dati scrivendo da "
        "Impostazioni → Contattaci, e revocare in ogni momento i consensi "
        "facoltativi dalle Impostazioni. L'informativa completa è in "
        "preparazione."
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
        "5. Un'area cani mancante va segnalata solo se è pubblica e aperta al "
        "pubblico. Non segnalare proprietà private e non invitare altri a "
        "entrare in luoghi privati.\n"
        "6. Non usare le segnalazioni per danneggiare un'attività. "
        "Segnalazioni false o ripetute possono portare alla sospensione "
        "dell'account.\n"
        "7. Le attività possono chiedere una correzione o la rimozione di un "
        "dato: verifichiamo e rispondiamo appena possibile.\n"
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

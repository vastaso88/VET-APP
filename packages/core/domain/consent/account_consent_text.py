# ruff: noqa: E501
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


# Faithful translations of the existing draft; not a legal approval.
# Versions identify meaning, shared by all languages. Legal review is still
# required for these drafts before a public production release.
CONSENT_TEXT_EN: dict[str, str] = {
    "terms_of_service": "By using VetApp, you accept the Terms of Service: the rules governing use of the app, your obligations as a user and the service's limits of liability, including the fact that the assistant's suggestions do not replace a veterinarian's advice. You cannot create an account without accepting these terms.",
    "privacy_policy": "In brief: to let you use VetApp, we process account data (name and email), your pets' profiles, the documents and photos you upload, conversations with the assistant and, if you enable them, your location and walk routes. What you send to the assistant (questions, attachments, voice messages) is sent to an external artificial intelligence provider to write the answers; medical records are sent only with your consent. Data is stored on third-party services (hosting and database). You can request access to, correction or deletion of your data by writing through Settings → Contact us, and withdraw optional consents at any time from Settings. The full privacy notice is being prepared.",
    "marketing_email": "With your consent, we may email you VetApp news and advice for your pets. You may withdraw consent at any time from Settings, without affecting your use of the app.",
    "analytics": "With your consent, we collect statistical and anonymous app usage data (such as screens visited and features used) to understand how to improve it. You may withdraw consent at any time from Settings, without affecting your use of the app.",
    "contribution_rules": "Rules for reports and ratings\n1. Report only what you have verified personally or know for certain.\n2. For businesses, enter only the trading name as it appears on the sign. Do not enter phone numbers, private addresses, emails or other people's data.\n3. Reports remain “awaiting confirmation” until other users confirm them. They are not a guarantee: always check before visiting a place.\n4. Dog park ratings are personal opinions: one rating per park.\n5. Report a missing dog park only if it is public and open to the public. Do not report private property or invite others to enter private places.\n6. Do not use reports to harm a business. False or repeated reports may lead to account suspension.\n7. Businesses may request correction or removal of data: we check and respond as soon as possible.\n8. Your reports and ratings are published without your name or personal data, which continue to be processed as described in the privacy notice.",
}

CONSENT_TEXT_ES: dict[str, str] = {
    "terms_of_service": "Al usar VetApp aceptas los Términos de Servicio: las reglas que regulan el uso de la aplicación, tus obligaciones como usuario y los límites de responsabilidad del servicio, incluido que las sugerencias del asistente no sustituyen el consejo de un veterinario. Sin esta aceptación no es posible crear una cuenta.",
    "privacy_policy": "En resumen: para que puedas usar VetApp tratamos los datos de tu cuenta (nombre y correo electrónico), los perfiles de tus animales, los documentos y fotos que subes, las conversaciones con el asistente y, si los activas, tu ubicación y los recorridos de los paseos. Lo que envías al asistente (preguntas, adjuntos, mensajes de voz) se envía a un proveedor externo de inteligencia artificial para escribir las respuestas; el historial clínico solo se envía si lo consientes. Los datos se conservan en servicios de terceros (alojamiento y base de datos). Puedes solicitar acceso, corrección o eliminación de tus datos escribiendo desde Ajustes → Contáctanos y retirar los consentimientos opcionales en cualquier momento desde los Ajustes. El aviso completo de privacidad está en preparación.",
    "marketing_email": "Con tu consentimiento podemos enviarte por correo electrónico novedades de VetApp y consejos para tus animales. Puedes retirar el consentimiento en cualquier momento desde los Ajustes, sin consecuencias para el uso de la aplicación.",
    "analytics": "Con tu consentimiento recopilamos datos estadísticos y anónimos sobre el uso de la aplicación (por ejemplo, pantallas visitadas y funciones utilizadas) para saber cómo mejorarla. Puedes retirar el consentimiento en cualquier momento desde los Ajustes, sin consecuencias para el uso de la aplicación.",
    "contribution_rules": "Reglas para avisos y valoraciones\n1. Comunica solo lo que hayas comprobado personalmente o sepas con certeza.\n2. Para los establecimientos, escribe solo el nombre comercial tal como aparece en el letrero. No incluyas teléfonos, direcciones privadas, correos electrónicos ni datos de otras personas.\n3. Los avisos quedan “pendientes de confirmación” hasta que otros usuarios los confirmen. No son una garantía: comprueba siempre antes de acudir a un lugar.\n4. Las valoraciones de parques caninos son opiniones personales: una valoración por parque.\n5. Comunica un parque canino que falta solo si es público y está abierto al público. No comuniques propiedades privadas ni invites a otras personas a entrar en lugares privados.\n6. No uses los avisos para perjudicar a un establecimiento. Los avisos falsos o repetidos pueden provocar la suspensión de la cuenta.\n7. Los establecimientos pueden solicitar que se corrija o elimine un dato: lo comprobamos y respondemos lo antes posible.\n8. Tus avisos y valoraciones se publican sin tu nombre ni tus datos personales, que siguen tratándose según el aviso de privacidad.",
}

CONSENT_TEXTS_BY_LANGUAGE: dict[str, dict[str, str]] = {
    "it": CONSENT_TEXT_IT,
    "en": CONSENT_TEXT_EN,
    "es": CONSENT_TEXT_ES,
}


def served_consent_language(language: str | None) -> str:
    """The language the catalog is actually served in for [language]: the
    requested one when a reviewed translation exists, else Italian."""
    code = (language or "").strip().lower().replace("_", "-").split("-")[0]
    return code if code in CONSENT_TEXTS_BY_LANGUAGE else "it"


def build_consent_catalog(language: str | None = None) -> dict[str, ConsentCatalogEntry]:
    texts = CONSENT_TEXTS_BY_LANGUAGE[served_consent_language(language)]
    return {
        key: ConsentCatalogEntry(version=CURRENT_VERSIONS[key], text=texts[key])
        for key in AccountConsentType.ALL
    }

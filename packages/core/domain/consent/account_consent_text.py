# ruff: noqa: E501
"""Account-level consent copy (docs/compliance/04_termini_e_consensi.md).

DRAFT — reviewed by whoever owns AI Act / privacy copy for this project
(see docs/compliance/03_consenso_cartella_clinica.md for the precedent).
Bump the relevant entry in CURRENT_VERSIONS whenever its text changes
materially, so a stored ConsentRecord.version keeps meaning "the text the
owner actually saw", not just "the latest text".
"""

from packages.core.domain.common.language import DEFAULT_LANGUAGE
from packages.core.domain.consent.models import AccountConsentType, ConsentCatalogEntry

# A language that has no reviewed text yet is served in English, never in
# Italian: a person who does not read Italian cannot give an informed consent
# on an Italian text (GDPR arts. 7(2) and 12; docs/compliance/15, open point 7).
FALLBACK_LANGUAGE = "en"

CURRENT_VERSIONS: dict[str, str] = {
    # v2 (2026-11-22): the full clause "Quokka non gestisce le urgenze" (docs/compliance/22)
    # joins the summary shown in the app, in every language.
    AccountConsentType.TERMS_OF_SERVICE: "v2",
    # v2 (2026-10-06): v1 promised a full notice "consultabile dalle
    # Impostazioni" that does not exist; v2 says what is processed and that
    # the full notice is still being written.
    # v3 (2026-10-28): the account also holds the surname, an optional phone
    # number and an optional profile photo, and the Marketplace publishes
    # listings; v3 names them and the delete-account route. Renaming the
    # product to Quokka (2026-10-27) changed no meaning: no bump for that.
    AccountConsentType.PRIVACY_POLICY: "v3",
    AccountConsentType.MARKETING_EMAIL: "v1",
    AccountConsentType.ANALYTICS: "v1",
    AccountConsentType.DIAGNOSTICS: "v1",
    AccountConsentType.CONTRIBUTION_RULES: "v2",
    # v1 (2026-11-21): acceptance of the Mercatino rules (docs/compliance/24); not a
    # GDPR consent. Italian, English and the reviewed ES/DE/FR translations (the app's
    # own name for the feature in each language).
    AccountConsentType.MARKETPLACE_RULES: "v1",
    # v1 (2026-11-22): the short version of the clause, with its own box.
    AccountConsentType.EMERGENCY_NOTICE: "v1",
}

_MARKETPLACE_RULES_IT = "Regole del Mercatino\n1. Solo oggetti per animali. Gli animali non si possono vendere, regalare né scambiare, in nessun paese.\n2. Niente farmaci. Non si possono vendere né regalare farmaci o medicinali, anche veterinari, nemmeno senza ricetta. Cibo, integratori e accessori sono ammessi. L'app blocca molti annunci che nominano un medicinale, non tutti: se ne vedi uno, segnalalo.\n3. Solo privati. Vendi o regali oggetti usati come persona privata, non nell'ambito di un'attività commerciale o professionale. Quokka non verifica la dichiarazione.\n4. Annunci onesti. Descrivi l'oggetto com'è. Niente merci illecite, contraffatte o pericolose, niente dati personali di altre persone, niente telefoni, e-mail, siti o profili social nel testo.\n5. Quokka mette in contatto due privati e non è parte della compravendita. Prezzo, pagamento, consegna e garanzie riguardano solo te e l'altra persona. Non verifichiamo annunci, oggetti o persone. Non pagare in anticipo a chi non conosci; se scambi i contatti nei messaggi, lo fai sotto la tua responsabilità.\n6. Solo maggiorenni. Il Mercatino, messaggi compresi, è riservato a chi ha almeno 18 anni.\n7. Messaggi. Solo testo. Puoi bloccare una persona o segnalare una conversazione in ogni momento. Se una conversazione viene segnalata, da te o dall'altra persona, il team di Quokka può leggerla, solo per valutare la segnalazione.\n8. Dopo una segnalazione possiamo chiudere la conversazione, nascondere o rimuovere un annuncio o tenerti fuori dal Mercatino. Ti diciamo il motivo e la data, nella tua lingua, e come chiedere un riesame da Impostazioni → Contattaci.\nLe regole complete sono nei Termini di Servizio (§8)."

_MARKETPLACE_RULES_EN = "Marketplace rules\n1. Only items for animals. Animals cannot be sold, given away or exchanged, in any country.\n2. No medicines. Medicines, including veterinary ones, cannot be sold or given away, not even those that need no prescription. Food, supplements and accessories are allowed. The app blocks many listings that name a medicine, not all: if you see one, report it.\n3. Private sellers only. You sell or give away used items as a private person, not as part of a commercial or professional activity. Quokka does not verify the declaration.\n4. Honest listings. Describe the item as it is. No illegal, counterfeit or dangerous goods, no personal data of other people, no phone numbers, emails, websites or social profiles in the text.\n5. Quokka connects two private individuals and is not a party to the sale. Price, payment, delivery and warranties concern only you and the other person. We do not verify listings, items or people. Do not pay in advance to someone you do not know; if you exchange contacts in messages, you do so on your own responsibility.\n6. Adults only. The marketplace, messages included, is for people aged 18 or over.\n7. Messages. Text only. You can block a person or report a conversation at any time. If a conversation is reported, by you or by the other person, the Quokka team may read it, only to assess the report.\n8. After a report we may close the conversation, hide or remove a listing, or keep you out of the marketplace. We tell you the reason and the date, in your language, and how to ask for a review from Settings → Contact us.\nThe full rules are in the Terms of service (§8)."

_MARKETPLACE_RULES_ES = "Reglas del mercadillo\n1. Solo artículos para animales. Los animales no se pueden vender, regalar ni intercambiar, en ningún país.\n2. Sin medicamentos. No se pueden vender ni regalar medicamentos, tampoco veterinarios, ni siquiera los que no necesitan receta. Se admiten comida, suplementos y accesorios. La app bloquea muchos anuncios que nombran un medicamento, pero no todos: si ves alguno, denúncialo.\n3. Solo particulares. Vendes o regalas artículos usados como persona particular, no en el marco de una actividad comercial o profesional. Quokka no verifica esta declaración.\n4. Anuncios honestos. Describe el artículo tal como es. Nada de mercancías ilícitas, falsificadas o peligrosas, ni datos personales de otras personas, ni teléfonos, correos electrónicos, sitios web o perfiles de redes sociales en el texto.\n5. Quokka pone en contacto a dos particulares y no es parte de la compraventa. El precio, el pago, la entrega y las garantías conciernen solo a ti y a la otra persona. No verificamos anuncios, artículos ni personas. No pagues por adelantado a quien no conoces; si intercambias datos de contacto en los mensajes, lo haces bajo tu responsabilidad.\n6. Solo mayores de edad. El mercadillo, mensajes incluidos, está reservado a personas de al menos 18 años.\n7. Mensajes. Solo texto. Puedes bloquear a una persona o denunciar una conversación en cualquier momento. Si se denuncia una conversación, por ti o por la otra persona, el equipo de Quokka puede leerla, solo para evaluar la denuncia.\n8. Tras una denuncia podemos cerrar la conversación, ocultar o eliminar un anuncio o dejarte fuera del mercadillo. Te indicamos el motivo y la fecha, en tu idioma, y cómo pedir una revisión desde Ajustes → Contáctanos.\nLas reglas completas están en los Términos del servicio (§8)."

_MARKETPLACE_RULES_DE = "Regeln des Gebrauchtmarkts\n1. Nur Gegenstände für Tiere. Tiere dürfen in keinem Land verkauft, verschenkt oder getauscht werden.\n2. Keine Arzneimittel. Arzneimittel, auch Tierarzneimittel, dürfen weder verkauft noch verschenkt werden, auch nicht rezeptfreie. Futter, Nahrungsergänzungsmittel und Zubehör sind erlaubt. Die App blockiert viele Anzeigen, die ein Arzneimittel nennen, aber nicht alle: Wenn Sie eine sehen, melden Sie sie.\n3. Nur Privatpersonen. Sie verkaufen oder verschenken gebrauchte Gegenstände als Privatperson, nicht im Rahmen einer gewerblichen oder beruflichen Tätigkeit. Quokka überprüft diese Erklärung nicht.\n4. Ehrliche Anzeigen. Beschreiben Sie den Gegenstand so, wie er ist. Keine unerlaubten, gefälschten oder gefährlichen Waren, keine personenbezogenen Daten anderer Personen, keine Telefonnummern, E-Mail-Adressen, Websites oder Social-Media-Profile im Text.\n5. Quokka bringt zwei Privatpersonen in Kontakt und ist nicht Partei des Kaufs. Preis, Bezahlung, Übergabe und Garantien betreffen nur Sie und die andere Person. Wir prüfen weder Anzeigen noch Gegenstände oder Personen. Zahlen Sie nicht im Voraus an Personen, die Sie nicht kennen; wenn Sie in den Nachrichten Kontaktdaten austauschen, tun Sie das auf eigene Verantwortung.\n6. Nur Volljährige. Der Gebrauchtmarkt, einschließlich der Nachrichten, ist Personen ab 18 Jahren vorbehalten.\n7. Nachrichten. Nur Text. Sie können jederzeit eine Person blockieren oder eine Unterhaltung melden. Wird eine Unterhaltung gemeldet, von Ihnen oder von der anderen Person, kann das Quokka-Team sie lesen, ausschließlich um die Meldung zu prüfen.\n8. Nach einer Meldung können wir die Unterhaltung schließen, eine Anzeige ausblenden oder entfernen oder Sie vom Gebrauchtmarkt ausschließen. Wir teilen Ihnen den Grund und das Datum in Ihrer Sprache mit und erklären, wie Sie unter Einstellungen → Kontakt eine Überprüfung beantragen können.\nDie vollständigen Regeln stehen in den Nutzungsbedingungen (§ 8)."

_MARKETPLACE_RULES_FR = "Règles du marché de l'occasion\n1. Uniquement des objets pour animaux. Les animaux ne peuvent être ni vendus, ni donnés, ni échangés, dans aucun pays.\n2. Pas de médicaments. Il est interdit de vendre ou de donner des médicaments, y compris vétérinaires, même ceux qui ne nécessitent pas d'ordonnance. La nourriture, les compléments alimentaires et les accessoires sont autorisés. L'application bloque de nombreuses annonces qui mentionnent un médicament, mais pas toutes\u00a0: si vous en voyez une, signalez-la.\n3. Uniquement des particuliers. Vous vendez ou donnez des objets d'occasion en tant que particulier, et non dans le cadre d'une activité commerciale ou professionnelle. Quokka ne vérifie pas cette déclaration.\n4. Des annonces honnêtes. Décrivez l'objet tel qu'il est. Pas de marchandises illicites, contrefaites ou dangereuses, pas de données personnelles d'autres personnes, pas de numéros de téléphone, d'e-mails, de sites web ou de profils de réseaux sociaux dans le texte.\n5. Quokka met en relation deux particuliers et n'est pas partie à la vente. Le prix, le paiement, la remise et les garanties ne concernent que vous et l'autre personne. Nous ne vérifions ni les annonces, ni les objets, ni les personnes. Ne payez pas à l'avance quelqu'un que vous ne connaissez pas\u00a0; si vous échangez vos coordonnées dans les messages, c'est sous votre responsabilité.\n6. Réservé aux majeurs. Le marché de l'occasion, messages compris, est réservé aux personnes de 18 ans ou plus.\n7. Messages. Uniquement du texte. Vous pouvez bloquer une personne ou signaler une conversation à tout moment. Si une conversation est signalée, par vous ou par l'autre personne, l'équipe de Quokka peut la lire, uniquement pour examiner le signalement.\n8. Après un signalement, nous pouvons fermer la conversation, masquer ou retirer une annonce, ou vous exclure du marché de l'occasion. Nous vous indiquons le motif et la date, dans votre langue, ainsi que la façon de demander un réexamen depuis Paramètres → Nous contacter.\nLes règles complètes figurent dans les Conditions d'utilisation (§ 8)."

CONSENT_TEXT_IT: dict[str, str] = {
    AccountConsentType.MARKETPLACE_RULES: _MARKETPLACE_RULES_IT,
    AccountConsentType.EMERGENCY_NOTICE: (
        "Quokka non gestisce le urgenze: in emergenza rivolgiti subito a un veterinario, ai servizi di emergenza o a un servizio di ascolto del tuo Paese. Non aspettare la risposta dell'app."
    ),
    AccountConsentType.TERMS_OF_SERVICE: (
        "Utilizzando Quokka accetti i Termini di Servizio: le regole che "
        "disciplinano l'uso dell'app, i tuoi obblighi come utente e i limiti "
        "di responsabilità del servizio, incluso il fatto che i suggerimenti "
        "dell'assistente non sostituiscono il parere di un veterinario. "
        "Senza questa accettazione non è possibile creare un account. "
        "Quokka non gestisce le urgenze. L'app e la chat non sono un servizio di emergenza, di pronto soccorso, di ascolto o di soccorso, né per gli animali né per le persone: non sono fatte per valutare se una situazione è urgente, possono non riconoscere un'emergenza e non garantiscono una risposta in un tempo preciso. Se pensi che il tuo animale stia male in modo grave, o se tu o un'altra persona siete in pericolo, non usare l'app e non aspettare una risposta: rivolgiti subito a un veterinario o a una clinica veterinaria, ai servizi di emergenza o a un servizio di ascolto del tuo Paese. Se la chat non segnala un'urgenza, non vuol dire che non ci sia."
    ),
    # A summary, not the full notice (art. 13 GDPR): it must stay true to what
    # the app does today (see docs/compliance/09_informativa_privacy_bozza.md)
    # and must not promise a page that does not exist.
    AccountConsentType.PRIVACY_POLICY: (
        "In sintesi: per farti usare Quokka trattiamo i dati dell'account "
        "(nome, cognome ed email; facoltativi: telefono e foto profilo), il "
        "profilo dei tuoi animali, i documenti, le foto e gli annunci del "
        "Mercatino che pubblichi, le conversazioni con l'assistente e, se li "
        "attivi, la "
        "tua posizione e i percorsi delle passeggiate. Quello che mandi "
        "all'assistente (domande, allegati, messaggi vocali) viene inviato a "
        "un fornitore esterno di intelligenza artificiale per scrivere le "
        "risposte; la cartella clinica solo se lo consenti. I dati sono "
        "conservati su servizi di terzi (hosting e database). Puoi chiedere "
        "accesso, correzione o cancellazione dei tuoi dati scrivendo da "
        "Impostazioni → Contattaci, oppure eliminare l'account da "
        "Impostazioni → Elimina account, e revocare in ogni momento i consensi "
        "facoltativi dalle Impostazioni. L'informativa completa è in "
        "preparazione."
    ),
    AccountConsentType.MARKETING_EMAIL: (
        "Con il tuo consenso, possiamo inviarti via email novità su Quokka "
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
    # Error reports: wording proposed in docs/security/10_crash_reporting.md and
    # completed on 2026-10-28 (provider, purpose, exact data; still v1 because the
    # consent is new). The provider (Sentry, EU) is also in the privacy notice.
    AccountConsentType.DIAGNOSTICS: (
        "Se l'app si chiude per un errore, con il tuo consenso inviamo un rapporto "
        "tecnico a Sentry, un servizio di diagnostica con server in Germania, per "
        "correggere l'errore. Il rapporto contiene il tipo di errore, cosa stava "
        "facendo l'app, il modello del telefono, la versione di Android e dell'app, "
        "la lingua e il fuso orario. Non include mai messaggi, foto, posizione, dati "
        "dei tuoi animali, il tuo nome o la tua e-mail. Puoi revocare il consenso in "
        "qualsiasi momento da Impostazioni, senza conseguenze sull'uso dell'app."
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
    "marketplace_rules": _MARKETPLACE_RULES_EN,
    "terms_of_service": "By using Quokka, you accept the Terms of Service: the rules governing use of the app, your obligations as a user and the service's limits of liability, including the fact that the assistant's suggestions do not replace a veterinarian's advice. You cannot create an account without accepting these terms. Quokka does not handle emergencies. The app and the chat are not an emergency, first-aid, helpline or rescue service, whether for animals or for people: they are not designed to judge whether a situation is urgent, they may fail to recognize an emergency, and they do not promise a reply within any set time. If you think your animal is seriously unwell, or if you or someone else is in danger, do not use the app and do not wait for a reply: contact a vet or veterinary clinic, the emergency services or a helpline in your country right away. If the chat does not flag an emergency, that does not mean there is none.",
    "privacy_policy": "In brief: to let you use Quokka, we process account data (first name, last name and email; optional: phone number and profile photo), your pets' profiles, the documents, photos and Marketplace listings you publish, conversations with the assistant and, if you enable them, your location and walk routes. What you send to the assistant (questions, attachments, voice messages) is sent to an external artificial intelligence provider to write the answers; medical records are sent only with your consent. Data is stored on third-party services (hosting and database). You can request access to, correction or deletion of your data by writing through Settings → Contact us, or delete your account from Settings → Delete account, and withdraw optional consents at any time from Settings. The full privacy notice is being prepared.",
    "marketing_email": "With your consent, we may email you Quokka news and advice for your pets. You may withdraw consent at any time from Settings, without affecting your use of the app.",
    "analytics": "With your consent, we collect statistical and anonymous app usage data (such as screens visited and features used) to understand how to improve it. You may withdraw consent at any time from Settings, without affecting your use of the app.",
    "diagnostics": "If the app closes because of an error, with your consent we send a technical report to Sentry, a diagnostics service with servers in Germany, to fix the error. The report contains the type of error, what the app was doing, your phone model, the Android and app versions, and your language and time zone. It never includes messages, photos, location, your pets' data, your name or your email. You may withdraw consent at any time from Settings, without affecting your use of the app.",
    "contribution_rules": "Rules for reports and ratings\n1. Report only what you have verified personally or know for certain.\n2. For businesses, enter only the trading name as it appears on the sign. Do not enter phone numbers, private addresses, emails or other people's data.\n3. Reports remain “awaiting confirmation” until other users confirm them. They are not a guarantee: always check before visiting a place.\n4. Dog park ratings are personal opinions: one rating per park.\n5. Report a missing dog park only if it is public and open to the public. Do not report private property or invite others to enter private places.\n6. Do not use reports to harm a business. False or repeated reports may lead to account suspension.\n7. Businesses may request correction or removal of data: we check and respond as soon as possible.\n8. Your reports and ratings are published without your name or personal data, which continue to be processed as described in the privacy notice.",
    "emergency_notice": "Quokka does not handle emergencies: in an emergency, contact a vet, the emergency services or a helpline in your country right away. Do not wait for the app's reply.",
}

CONSENT_TEXT_ES: dict[str, str] = {
    "marketplace_rules": _MARKETPLACE_RULES_ES,
    "terms_of_service": "Al usar Quokka aceptas los Términos de Servicio: las reglas que regulan el uso de la aplicación, tus obligaciones como usuario y los límites de responsabilidad del servicio, incluido que las sugerencias del asistente no sustituyen el consejo de un veterinario. Sin esta aceptación no es posible crear una cuenta. Quokka no gestiona urgencias. La aplicación y el chat no son un servicio de emergencias, de primeros auxilios, de rescate ni una línea de ayuda, ni para animales ni para personas: no están diseñados para valorar si una situación es urgente, pueden no reconocer una emergencia y no garantizan una respuesta en un plazo determinado. Si crees que tu animal está gravemente enfermo, o si tú u otra persona están en peligro, no uses la aplicación ni esperes una respuesta: acude de inmediato a un veterinario o a una clínica veterinaria, a los servicios de emergencia o a una línea de ayuda de tu país. Si el chat no avisa de una urgencia, eso no significa que no la haya.",
    "privacy_policy": "En resumen: para que puedas usar Quokka tratamos los datos de tu cuenta (nombre, apellidos y correo electrónico; opcionales: teléfono y foto de perfil), los perfiles de tus animales, los documentos, fotos y anuncios del mercadillo que publicas, las conversaciones con el asistente y, si los activas, tu ubicación y los recorridos de los paseos. Lo que envías al asistente (preguntas, adjuntos, mensajes de voz) se envía a un proveedor externo de inteligencia artificial para escribir las respuestas; el historial clínico solo se envía si lo consientes. Los datos se conservan en servicios de terceros (alojamiento y base de datos). Puedes solicitar acceso, corrección o eliminación de tus datos escribiendo desde Ajustes → Contáctanos, o eliminar tu cuenta desde Ajustes → Eliminar cuenta, y retirar los consentimientos opcionales en cualquier momento desde los Ajustes. El aviso completo de privacidad está en preparación.",
    "marketing_email": "Con tu consentimiento podemos enviarte por correo electrónico novedades de Quokka y consejos para tus animales. Puedes retirar el consentimiento en cualquier momento desde los Ajustes, sin consecuencias para el uso de la aplicación.",
    "analytics": "Con tu consentimiento recopilamos datos estadísticos y anónimos sobre el uso de la aplicación (por ejemplo, pantallas visitadas y funciones utilizadas) para saber cómo mejorarla. Puedes retirar el consentimiento en cualquier momento desde los Ajustes, sin consecuencias para el uso de la aplicación.",
    "diagnostics": "Si la aplicación se cierra por un error, con tu consentimiento enviamos un informe técnico a Sentry, un servicio de diagnóstico con servidores en Alemania, para corregir el error. El informe contiene el tipo de error, qué estaba haciendo la aplicación, el modelo del teléfono, las versiones de Android y de la aplicación, y el idioma y la zona horaria. Nunca incluye mensajes, fotos, ubicación, datos de tus animales, tu nombre ni tu correo electrónico. Puedes retirar el consentimiento en cualquier momento desde los Ajustes, sin consecuencias para el uso de la aplicación.",
    "contribution_rules": "Reglas para avisos y valoraciones\n1. Comunica solo lo que hayas comprobado personalmente o sepas con certeza.\n2. Para los establecimientos, escribe solo el nombre comercial tal como aparece en el letrero. No incluyas teléfonos, direcciones privadas, correos electrónicos ni datos de otras personas.\n3. Los avisos quedan “pendientes de confirmación” hasta que otros usuarios los confirmen. No son una garantía: comprueba siempre antes de acudir a un lugar.\n4. Las valoraciones de parques caninos son opiniones personales: una valoración por parque.\n5. Comunica un parque canino que falta solo si es público y está abierto al público. No comuniques propiedades privadas ni invites a otras personas a entrar en lugares privados.\n6. No uses los avisos para perjudicar a un establecimiento. Los avisos falsos o repetidos pueden provocar la suspensión de la cuenta.\n7. Los establecimientos pueden solicitar que se corrija o elimine un dato: lo comprobamos y respondemos lo antes posible.\n8. Tus avisos y valoraciones se publican sin tu nombre ni tus datos personales, que siguen tratándose según el aviso de privacidad.",
    "emergency_notice": "Quokka no gestiona urgencias: ante una emergencia, acude de inmediato a un veterinario, a los servicios de emergencia o a una línea de ayuda de tu país. No esperes la respuesta de la aplicación.",
}

# German and French follow docs/compliance/de|fr/04_*: formal register ("Sie",
# "vous"), the app's own labels (Einstellungen → Konto löschen; Paramètres →
# Supprimer le compte) and the glossary terms (Krankenakte, dossier médical,
# Gebrauchtmarkt, marché de l'occasion; docs/i18n/GLOSSARIO_E_STILE.md). They are
# faithful to the Italian text, so they share its versions: the additions of
# those drafts (transfers outside the EU, the complaint authority) wait for the
# next version of the privacy summary, for every language together. The regional
# variants (de-AT, de-CH, fr-BE, fr-CH) differ only in wording and in the name
# of the authority and are not served separately (docs/compliance/15, point 7).
# French uses a no-break space (U+00A0) before ": ; ? !".
CONSENT_TEXT_DE: dict[str, str] = {
    "marketplace_rules": _MARKETPLACE_RULES_DE,
    "terms_of_service": "Mit der Nutzung von Quokka stimmen Sie den Nutzungsbedingungen zu: den Regeln für die Nutzung der App, Ihren Pflichten als Nutzerin oder Nutzer und den Grenzen unserer Haftung, einschließlich der Tatsache, dass die Vorschläge des Assistenten den Rat einer Tierärztin oder eines Tierarztes nicht ersetzen. Ohne diese Zustimmung können wir kein Konto anlegen. Quokka ist nicht für Notfälle zuständig. Die App und der Chat sind kein Notfall-, Erste-Hilfe-, Beratungs- oder Rettungsdienst, weder für Tiere noch für Menschen: Sie sind nicht dafür gedacht zu beurteilen, ob eine Situation dringend ist, erkennen einen Notfall womöglich nicht und versprechen keine Antwort innerhalb einer bestimmten Zeit. Wenn Sie glauben, dass es Ihrem Tier ernsthaft schlecht geht, oder wenn Sie oder eine andere Person in Gefahr sind, nutzen Sie die App nicht und warten Sie nicht auf eine Antwort: Wenden Sie sich sofort an eine Tierärztin, einen Tierarzt oder eine Tierklinik, an den Rettungsdienst oder an eine Beratungsstelle in Ihrem Land. Wenn der Chat keinen Notfall meldet, heißt das nicht, dass keiner vorliegt.",
    "privacy_policy": "Kurz gesagt: Damit Sie Quokka nutzen können, verarbeiten wir die Daten Ihres Kontos (Vor- und Nachname und E-Mail-Adresse; freiwillig: Telefonnummer und Profilfoto), die Profile Ihrer Tiere, die Dokumente, Fotos und Anzeigen im Gebrauchtmarkt, die Sie veröffentlichen, Ihre Gespräche mit dem Assistenten und, wenn Sie sie einschalten, Ihren Standort und die Strecken Ihrer Spaziergänge. Was Sie dem Assistenten senden (Fragen, Anhänge, Sprachnachrichten), wird an einen externen Anbieter künstlicher Intelligenz gesendet, damit er die Antworten schreibt; die Krankenakte Ihres Tieres nur, wenn Sie es erlauben. Ihre Daten werden bei Diensten Dritter (Hosting und Datenbank) gespeichert. Sie können Auskunft, Berichtigung oder Löschung Ihrer Daten verlangen, indem Sie uns über Einstellungen → Kontakt schreiben, oder Ihr Konto selbst löschen (Einstellungen → Konto löschen), und freiwillige Einwilligungen jederzeit in den Einstellungen widerrufen. Die vollständige Datenschutzerklärung ist in Vorbereitung.",
    "marketing_email": "Mit Ihrer Einwilligung dürfen wir Ihnen per E-Mail Neuigkeiten zu Quokka und Tipps für Ihre Tiere senden. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App hat das keine Folgen.",
    "analytics": "Mit Ihrer Einwilligung erfassen wir anonyme statistische Daten zur Nutzung der App (zum Beispiel aufgerufene Bildschirme und genutzte Funktionen), um zu verstehen, wie wir sie verbessern können. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App hat das keine Folgen.",
    "diagnostics": "Wenn die App wegen eines Fehlers beendet wird, senden wir mit Ihrer Einwilligung einen technischen Bericht an Sentry, einen Diagnosedienst mit Servern in Deutschland, um den Fehler zu beheben. Der Bericht enthält die Art des Fehlers, was die App gerade getan hat, das Telefonmodell, die Android- und die App-Version sowie Sprache und Zeitzone. Er enthält nie Nachrichten, Fotos, Standort, Daten Ihrer Tiere, Ihren Namen oder Ihre E-Mail-Adresse. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App hat das keine Folgen.",
    "contribution_rules": "Regeln für Meldungen und Stimmen\n1. Melden Sie nur, was Sie selbst geprüft haben oder sicher wissen.\n2. Schreiben Sie bei Betrieben nur den Namen, wie er am Schild steht. Tragen Sie keine Telefonnummern, privaten Anschriften, E-Mail-Adressen oder Daten anderer Personen ein.\n3. Meldungen bleiben „in Bestätigung“, bis andere Nutzende sie bestätigen. Sie sind keine Garantie: Prüfen Sie immer, bevor Sie zu einem Ort fahren.\n4. Stimmen zu Hundeauslaufflächen sind persönliche Meinungen: eine Stimme pro Fläche.\n5. Melden Sie eine fehlende Hundeauslauffläche nur, wenn sie öffentlich und für die Allgemeinheit zugänglich ist. Melden Sie keine Privatgrundstücke und fordern Sie niemanden auf, private Flächen zu betreten.\n6. Nutzen Sie Meldungen nicht, um einem Betrieb zu schaden. Falsche oder wiederholte Meldungen können zur Sperrung Ihres Kontos führen.\n7. Betriebe können die Berichtigung oder Entfernung einer Angabe verlangen: Wir prüfen das und antworten so bald wie möglich.\n8. Ihre Meldungen und Stimmen werden ohne Ihren Namen und ohne Ihre persönlichen Daten veröffentlicht; diese werden wie in der Datenschutzerklärung beschrieben behandelt.",
    "emergency_notice": "Quokka ist nicht für Notfälle zuständig: Wenden Sie sich in einem Notfall sofort an eine Tierärztin oder einen Tierarzt, an den Rettungsdienst oder an eine Beratungsstelle in Ihrem Land. Warten Sie nicht auf die Antwort der App.",
}

CONSENT_TEXT_FR: dict[str, str] = {
    "marketplace_rules": _MARKETPLACE_RULES_FR,
    "terms_of_service": "En utilisant Quokka, vous acceptez les conditions d'utilisation : les règles d'usage de l'application, vos obligations d'utilisateur et les limites de notre responsabilité, y compris le fait que les suggestions de l'assistant ne remplacent pas l'avis d'un vétérinaire. Sans cette acceptation, nous ne pouvons pas créer de compte. Quokka ne gère pas les urgences. L'application et le chat ne sont pas un service d'urgence, de premiers secours, d'écoute ou de secours, ni pour les animaux ni pour les personnes\u00a0: ils ne sont pas conçus pour évaluer si une situation est urgente, peuvent ne pas reconnaître une urgence et ne promettent aucune réponse dans un délai précis. Si vous pensez que votre animal est gravement malade, ou si vous ou une autre personne êtes en danger, n'utilisez pas l'application et n'attendez pas de réponse\u00a0: adressez-vous immédiatement à un vétérinaire ou à une clinique vétérinaire, aux services d'urgence ou à un service d'écoute de votre pays. Si le chat ne signale pas d'urgence, cela ne veut pas dire qu'il n'y en a pas.",
    "privacy_policy": "En bref : pour que vous puissiez utiliser Quokka, nous traitons les données de votre compte (prénom, nom et adresse e-mail ; facultatifs : numéro de téléphone et photo de profil), les fiches de vos animaux, les documents, les photos et les annonces du marché de l'occasion que vous publiez, vos conversations avec l'assistant et, si vous les activez, votre localisation et les parcours de vos promenades. Ce que vous envoyez à l'assistant (questions, pièces jointes, messages vocaux) est transmis à un prestataire externe d'intelligence artificielle pour rédiger les réponses ; le dossier médical de votre animal n'est transmis que si vous l'autorisez. Vos données sont conservées chez des prestataires tiers (hébergement et base de données). Vous pouvez demander l'accès, la rectification ou l'effacement de vos données en nous écrivant depuis Paramètres → Nous contacter, ou supprimer vous-même votre compte depuis Paramètres → Supprimer le compte, et retirer à tout moment vos consentements facultatifs dans les Paramètres. La politique de confidentialité complète est en cours de préparation.",
    "marketing_email": "Avec votre accord, nous pouvons vous envoyer par e-mail des nouveautés sur Quokka et des conseils pour vos animaux. Vous pouvez retirer votre accord à tout moment dans les Paramètres ; cela n'a aucune incidence sur votre utilisation de l'application.",
    "analytics": "Avec votre accord, nous recueillons des statistiques anonymes sur l'usage de l'application (par exemple, les écrans consultés et les fonctions utilisées) pour comprendre comment l'améliorer. Vous pouvez retirer votre accord à tout moment dans les Paramètres ; cela n'a aucune incidence sur votre utilisation de l'application.",
    "diagnostics": "Si l'application se ferme à cause d'une erreur, avec votre accord, nous envoyons un rapport technique à Sentry, un service de diagnostic dont les serveurs sont en Allemagne, pour corriger l'erreur. Le rapport contient le type d'erreur, ce que faisait l'application, le modèle du téléphone, les versions d'Android et de l'application, la langue et le fuseau horaire. Il n'inclut jamais de messages, de photos, de position, de données sur vos animaux, ni votre nom ou votre adresse e-mail. Vous pouvez retirer votre accord à tout moment dans les Paramètres ; cela n'a aucune incidence sur votre utilisation de l'application.",
    "contribution_rules": "Règles pour les signalements et les votes\n1. Ne signalez que ce que vous avez vérifié vous-même ou que vous savez avec certitude.\n2. Pour un établissement, indiquez uniquement son nom tel qu'il figure sur l'enseigne. N'indiquez ni numéros de téléphone, ni adresses privées, ni adresses e-mail, ni données d'autres personnes.\n3. Les signalements restent « en cours de confirmation » tant que d'autres utilisateurs ne les ont pas confirmés. Ils ne sont pas une garantie : vérifiez toujours avant de vous déplacer.\n4. Les votes sur les parcs canins sont des avis personnels : un vote par parc.\n5. Ne signalez l'absence d'un parc canin que s'il est public et accessible à tous. Ne signalez pas de propriétés privées et n'incitez personne à entrer dans des espaces privés.\n6. N'utilisez pas les signalements pour nuire à un établissement. Des signalements faux ou répétés peuvent entraîner la suspension de votre compte.\n7. Les établissements peuvent demander la rectification ou le retrait d'une information : nous l'examinons et répondons dès que possible.\n8. Vos signalements et vos votes sont publiés sans votre nom et sans vos données personnelles ; celles-ci sont traitées comme indiqué dans la politique de confidentialité.",
    "emergency_notice": "Quokka ne gère pas les urgences\u00a0: en cas d'urgence, adressez-vous immédiatement à un vétérinaire, aux services d'urgence ou à un service d'écoute de votre pays. N'attendez pas la réponse de l'application.",
}

CONSENT_TEXTS_BY_LANGUAGE: dict[str, dict[str, str]] = {
    "it": CONSENT_TEXT_IT,
    "en": CONSENT_TEXT_EN,
    "es": CONSENT_TEXT_ES,
    "de": CONSENT_TEXT_DE,
    "fr": CONSENT_TEXT_FR,
}


def served_consent_language(language: str | None) -> str:
    """The language the catalog is actually served in for [language]: the
    requested one when a reviewed translation exists; Italian (the product's
    language) when no language was asked for at all; English for any other
    language that has no text yet, so a new language never falls back to Italian."""
    code = (language or "").strip().lower().replace("_", "-").split("-")[0]
    if not code:
        return DEFAULT_LANGUAGE
    return code if code in CONSENT_TEXTS_BY_LANGUAGE else FALLBACK_LANGUAGE


def build_consent_catalog(language: str | None = None) -> dict[str, ConsentCatalogEntry]:
    texts = CONSENT_TEXTS_BY_LANGUAGE[served_consent_language(language)]
    return {
        key: ConsentCatalogEntry(version=CURRENT_VERSIONS[key], text=texts[key])
        for key in AccountConsentType.ALL
    }

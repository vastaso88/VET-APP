"""The consent copy shown to the owner before the chat may access a pet's
clinical record (spec v3 §18).

The wording has to say what the system really does with the record. v1 told
the owner that only the relevant information was used, "mai l'intera
cartella", while the chat reads the three most recent records whatever the
question is: the text promised a selection the code never made (see
docs/compliance/03_consenso_cartella_clinica.md). v2 describes the real
behaviour, and tests/unit/test_consent_texts_match_behaviour.py ties the
numbers in it to the limits of MedicalRecordContextRetriever, so changing one
forces a look at the other.

v3 (2026-10-14, "Cartella clinica per categorie"): the entries the chat reads
now carry their category and the date of the event, and the chat also reads
the illnesses still ongoing (name and start date, at most five). A decision
taken under v2 therefore no longer counts (see `effective_decision`): the
owner decides again on the wording that says so.

v4 (2026-11-07, registro rischi R25, decisione del proprietario): the
profile's free notes and the active reminders, therapies included, leave
for the provider only with this consent (send_chat_message.py,
vet_summary.py), and the text now says so. A decision under v3 counts as
no decision: nothing of the record, the notes or the reminders goes until
the owner decides again. The regulatory session gave its opinion on
2026-11-08 (docs/compliance/03_consenso_cartella_clinica.md): right in
substance, two points to fix in a v5 (purpose and recipients).

v5 (2026-11-10, to ship only with the switch to Anthropic): the recipients
are named (Anthropic, and Groq when Anthropic cannot answer), the transfer
to the United States and its safeguards are stated, the removal of
identifying data before sending is described with its limit, and the
purpose includes the summary for the vet. The United States are true
because every request to Anthropic carries inference_geo="us"
(anthropic_llm_client.INFERENCE_GEO). A decision under v1-v4 counts as no
decision: every owner decides again, once. Text from
docs/compliance/03_consenso_cartella_clinica.md, "Che cosa dirà la v5".

Bump CURRENT_VERSION whenever the wording changes materially, so
`MedicalRecordConsentRecord.version` keeps meaning "the text the owner
actually saw", not just "the latest text".
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from packages.core.domain.consent.models import ConsentRecord

CURRENT_VERSION = "v5"

# Copied verbatim into the app, in medical_record_consent_card.dart
# (`_approvedConsentText`): a test checks that the two match.
CONSENT_TEXT_IT = (
    "Per darti un consiglio più preciso, l'assistente può leggere la "
    "cartella clinica del tuo animale. Quando fai una domanda può leggere "
    "le tre voci più recenti, con titolo, categoria (visita, esame, "
    "vaccino, terapia o documento), data dell'evento, descrizione e testo "
    "dei documenti allegati, anche se non c'entrano con la domanda. Può "
    "leggere anche le malattie pregresse ancora in corso, con il nome e la "
    "data di inizio, al massimo cinque. Legge anche le note che hai scritto"
    " nella scheda dell'animale e i promemoria attivi, terapie comprese. Se"
    " chiedi di spiegare un esame, può leggere i documenti che lo "
    "riguardano, al massimo due. Di un documento molto lungo legge solo "
    "l'inizio. Ciò che legge viene inviato ai fornitori esterni di "
    "intelligenza artificiale che scrivono la risposta: Anthropic e, quando"
    " Anthropic non può rispondere, Groq. Sono società statunitensi e "
    "trattano i dati negli Stati Uniti, fuori dall'Unione europea: l'invio "
    "è vincolato da un contratto e protetto dalle garanzie che la legge "
    "europea prevede per questi trasferimenti. Prima dell'invio togliamo "
    "nomi, recapiti e altri dati che ti identificano, ma non possiamo "
    "riconoscerli tutti. Quokka lo usa solo per risponderti e per preparare"
    " il riepilogo per il veterinario che puoi chiedere. Puoi revocare il "
    "consenso in qualsiasi momento dalla scheda dell'animale o dalle "
    "Impostazioni: vale per le richieste successive."
)

# The question the chat asks inline the first time it would like to read the
# record: the same facts as CONSENT_TEXT_IT, in the chat's voice. Format it
# with `pet_name`. One source for both, so the question the owner answers and
# the text on record cannot drift apart again.
INLINE_QUESTION_IT = (
    "Vuoi che consulti la cartella clinica di {pet_name} per darti un "
    "consiglio più preciso? Leggerò le tre voci più recenti, compreso il "
    "testo dei documenti allegati, le malattie pregresse ancora in corso, "
    "le note della scheda e i promemoria attivi, terapie comprese, e le "
    "invierò ai servizi di intelligenza artificiale che scrivono la "
    "risposta: Anthropic e, di riserva, Groq, con server negli Stati Uniti."
    " Puoi cambiare idea in qualsiasi momento dalla scheda di {pet_name}."
)


def effective_decision(record: ConsentRecord | None) -> bool | None:
    """The owner's decision as it counts today: None when there is none or
    when it was taken under an earlier text (v1 promised a selection the
    code never made; v2 did not mention the categories and the ongoing
    illnesses; v3 did not mention the profile notes and the reminders; v4
    did not name the providers and the transfer to the United States),
    so the owner sees the current wording
    and decides again. Only a decision under CURRENT_VERSION is a decision."""
    if record is None or record.version != CURRENT_VERSION:
        return None
    return record.granted

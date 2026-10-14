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

Bump CURRENT_VERSION whenever the wording changes materially, so
`MedicalRecordConsentRecord.version` keeps meaning "the text the owner
actually saw", not just "the latest text".
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from packages.core.domain.consent.models import ConsentRecord

CURRENT_VERSION = "v3"

# Copied verbatim into the app, in medical_record_consent_card.dart
# (`_approvedConsentText`): a test checks that the two match.
CONSENT_TEXT_IT = (
    "Per darti un consiglio più preciso, l'assistente può leggere la "
    "cartella clinica del tuo animale. Quando fai una domanda può leggere "
    "le tre voci più recenti, con titolo, categoria (visita, esame, "
    "vaccino, terapia o documento), data dell'evento, descrizione e testo "
    "dei documenti allegati, anche se non c'entrano con la domanda. Può "
    "leggere anche le malattie pregresse ancora in corso, con il nome e la "
    "data di inizio, al massimo cinque. Se chiedi di spiegare un esame, può "
    "leggere i documenti che lo riguardano, al massimo due. Di un documento "
    "molto lungo legge solo l'inizio. Ciò che "
    "legge viene inviato al fornitore esterno di intelligenza artificiale "
    "che scrive la risposta. VetApp lo usa solo per risponderti. Puoi "
    "revocare il consenso in qualsiasi momento dalla scheda dell'animale o "
    "dalle Impostazioni: vale per le richieste successive."
)

# The question the chat asks inline the first time it would like to read the
# record: the same facts as CONSENT_TEXT_IT, in the chat's voice. Format it
# with `pet_name`. One source for both, so the question the owner answers and
# the text on record cannot drift apart again.
INLINE_QUESTION_IT = (
    "Vuoi che consulti la cartella clinica di {pet_name} per darti un "
    "consiglio più preciso? Leggerò le tre voci più recenti, compreso il "
    "testo dei documenti allegati, e le malattie pregresse ancora in corso, "
    "e le invierò al servizio di intelligenza artificiale che scrive la "
    "risposta. Puoi cambiare idea in qualsiasi momento dalla scheda di "
    "{pet_name}."
)


def effective_decision(record: ConsentRecord | None) -> bool | None:
    """The owner's decision as it counts today: None when there is none or
    when it was taken under an earlier text (v1 promised a selection the
    code never made; v2 did not mention the categories and the ongoing
    illnesses the chat now reads), so the owner sees the current wording
    and decides again. Only a decision under CURRENT_VERSION is a decision."""
    if record is None or record.version != CURRENT_VERSION:
        return None
    return record.granted

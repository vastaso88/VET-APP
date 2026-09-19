"""The consent copy shown to the owner before the chat may access a pet's
clinical record (spec v3 §18).

Reviewed and approved by the team owning AI Act/privacy compliance (see
docs/compliance/03_consenso_cartella_clinica.md) — communicates purpose,
data minimization ("mai l'intera cartella") and revocability, consistent
with GDPR informed consent. Bump CURRENT_VERSION whenever the wording
changes materially, so `MedicalRecordConsentRecord.version` keeps meaning
"the text the owner actually saw", not just "the latest text".
"""

CURRENT_VERSION = "v1"

CONSENT_TEXT_IT = (
    "Per darti un consiglio più preciso, l'assistente può consultare le "
    "informazioni cliniche già registrate per il tuo animale (es. visite, "
    "esami, vaccinazioni). Verranno usate solo le informazioni rilevanti "
    "per la domanda in corso, mai l'intera cartella. Puoi revocare questo "
    "consenso in qualsiasi momento dalle impostazioni."
)

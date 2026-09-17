# Termini di servizio, consensi opt-in e permessi

Risposta alla domanda: "è utile una sezione impostazioni con le autorizzazioni concesse? Meglio negare l'accesso o limitare le funzioni? Va costruita una pagina di accettazione T&C?"

## Tre cose legalmente distinte

Le app tendono a confondere tutto questo in un'unica schermata "accetta tutto". Sono in realtà tre basi giuridiche diverse, con regole diverse:

### 1. Contratto (Termini di Servizio)
Base giuridica: libertà contrattuale. Può legittimamente bloccare l'accesso — senza contratto accettato non c'è servizio. Il divieto di *tying* dell'art. 7(4) GDPR riguarda il consenso al trattamento dati, **non** la formazione del contratto: non si applica qui.

Serve però una vera cattura del consenso, non solo una schermata scenica: testo versionato, azione esplicita, **registrazione server-side** di versione e timestamp. Prima di questa modifica, VetApp aveva esattamente il problema opposto: un bottone "Accetto e continua" nell'onboarding che non scriveva nulla, e una checkbox in registrazione mai inviata al backend — nessuna prova legale che il consenso fosse mai stato dato.

### 2. Basi giuridiche del trattamento dati (art. 6 GDPR)
Il trattamento "core" — account, profilo pet, la risposta della chat alla domanda posta, i promemoria richiesti — può appoggiarsi alla necessità contrattuale (art. 6(1)(b)): niente consenso separato, solo informativa (art. 13), e può restare obbligatorio per usare l'app.

Serve consenso opt-in vero (art. 6(1)(a)) solo per trattamenti che vanno **oltre** il minimo necessario alla richiesta specifica. Quel consenso deve essere:
- **Libero**: mai condizione per l'uso dell'app (art. 7(4)).
- **Granulare**: un toggle per finalità, mai un "accetta tutto" bundlato.
- **Revocabile con la stessa facilità con cui è dato** (art. 7(3)) — da qui la sezione Impostazioni.

Esempi concreti in VetApp: email di marketing e analisi d'uso sono consenso opt-in vero (`packages/core/domain/consent/models.py`, chiavi `marketing_email`/`analytics`). L'accesso della chat alla cartella clinica completa di un pet (vedi [03_consenso_cartella_clinica.md](03_consenso_cartella_clinica.md)) è correttamente opt-in per lo stesso motivo: va oltre il minimo necessario a rispondere alla domanda del momento.

### 3. Permessi OS (fotocamera, notifiche, posizione, ecc.)
Regolati dalle policy Apple/Play Store, non dal GDPR direttamente. L'evento di consenso autorevole è il dialog nativo dell'OS, non testo scritto dall'app. Entrambi gli store impongono:
- **Graceful degradation**: negare un permesso disabilita solo la funzione che lo richiede, mai l'intera app.
- **Richiesta just-in-time**: al momento dell'uso della funzione, mai in una schermata iniziale generica.

Dettaglio in [05_permessi_dispositivo_os.md](05_permessi_dispositivo_os.md).

## Le tre risposte dirette

1. **Sezione impostazioni con le autorizzazioni concesse**: sì, è vicino a un requisito (art. 7(3)) per i consensi opt-in, oltre che buona prassi per i permessi OS quando esisteranno. Implementata in Impostazioni → "Permessi e consensi".
2. **Negare accesso vs. limitare funzioni al rifiuto**: limitare, quasi sempre. Il blocco totale dell'accesso è legittimo solo per il rifiuto dei Termini di Servizio (è un contratto, senza il quale non c'è servizio). Non è mai legittimo per un consenso opt-in rifiutato o un permesso OS negato.
3. **Pagina di accettazione T&C all'accesso**: sì, ma tenuta separata da qualunque consenso opt-in — un solo step obbligatorio per contratto + informativa (in pratica: registrazione, dove la checkbox ora scrive davvero sul backend), mai bundlato con marketing/analytics, che vivono solo in Impostazioni, disattivati di default.

## Implementazione

- `packages/core/domain/consent/models.py`: `ConsentRecord` (forma condivisa, già usata anche da `MedicalRecordConsentRecord`), `AccountConsentType` (chiavi + insiemi `MANDATORY`/`OPTIONAL`), `AccountConsents`.
- `packages/core/domain/consent/account_consent_text.py`: testo e versione di ciascun consenso.
- `packages/core/application/services/set_account_consent.py`: applica la regola "obbligatorio non è un toggle" lato server, non solo in UI.
- Endpoint `GET/POST /account/consents` (`apps/api/routes/account_consents.py`).
- Mobile: registrazione ([register_page.dart](../../apps/mobile_app/lib/features/auth/presentation/pages/register_page.dart)) registra ToS/Privacy dopo la creazione account; Impostazioni ([settings_page.dart](../../apps/mobile_app/lib/features/settings/presentation/pages/settings_page.dart)) mostra stato e permette di gestire marketing/analytics.

> **BOZZA — non è consulenza legale; da rivedere da un avvocato abilitato negli USA prima della pubblicazione**

# Domande per il proprietario (USA)

Raggruppate per tema, con la mia raccomandazione. Le 5 più importanti sono in cima. Ogni risposta cambia i testi 02–06.

## Le 5 principali

1. **Lanciamo negli USA con una sola entità italiana, e con quale indirizzo/contatto?** I testi USA richiedono un indirizzo postale (CAN-SPAM per le email, CalOPPA, contatto privacy) e la scelta della legge applicabile/foro (03, sez. 15). Un'entità italiana che serve utenti USA resta soggetta anche al GDPR (art. 3(1)) [N], quindi la policy USA non può peggiorare le garanzie. *Raccomandazione:* far decidere al legale; nel frattempo usare indirizzi segnaposto e non pubblicare.
2. **Età minima: 18 anni, o la maggiore età di ogni stato?** *Raccomandazione:* 18+ (come in Italia), e dichiararlo; evitare i 13–17 (COPPA e leggi sui minori).
3. **IA di terzi: accettiamo il consenso esplicito prima di usare la chat (nuovo id `ai_provider_sharing`)?** Apple 5.1.2(i) (13 nov 2025) richiede permesso esplicito prima di inviare dati personali a IA di terzi (01, sez. 8). *Raccomandazione:* sì, schermata al primo uso della chat; se rifiutato la chat resta spenta, il resto funziona. Va deciso insieme alla sessione backend/consensi.
4. **Arbitrato e rinuncia alle class action nei Termini: sì o no?** Sono proposte con alta incertezza (03, sez. 14). *Raccomandazione:* all'inizio **no** (più semplice, meno rischio di scontro con tribunali e store); riconsiderare quando ci sono utenti paganti; se sì, con opt-out di 30 giorni e spese a carico nostro.
5. **Prezzi in dollari e tasse:** i valori Plus/Pro in $ sono segnaposto (03). Quali sono i prezzi USA, si includono le tasse di vendita, e si usano solo gli store (Apple/Google) o anche pagamenti diretti? Dal primo addebito reale servono ROSCA + leggi statali sui rinnovi (CA dal 2025-07-01) (01, sez. 4.4). *Raccomandazione:* partire solo con gli store e un unico prezzo, e rimandare la decisione finché non c'è fatturazione.

## Legali e di prodotto

6. **Il servizio è "pratica veterinaria"?** Non ho trovato né casi né pareri specifici; le leggi statali definiscono la pratica in modo ampio (01, sez. 6). Raccomando: informazione + triage, mai diagnosi né dosaggi (05). *Decidere:* accettate un assistente più restrittivo negli USA (rifiuta diagnosi e dosaggi) anche se meno "utile"?
7. **Contratti con i fornitori di IA/hosting (Groq, Supabase, Vercel, Google):** servono accordi di trattamento ("service provider/processor") coerenti con CCPA e altre leggi; verificare paese e garanzie (09 italiana, punto 4 delle note). *Chi li verifica?*
8. **Imposte:** sales tax su abbonamenti digitali: va verificata da un commercialista USA se si incassa direttamente; con gli store è gestita da Apple/Google nella maggior parte dei casi [N].
9. **Analytics:** oggi non risulta alcuno strumento attivo; lasciamo la voce `analytics` visibile per gli USA o la nascondiamo finché non c'è? (Apple 5.1.1(ii) richiede comunque il consenso se si raccoglie.)
10. **Dati clinici dell'animale:** includiamo nell'informativa che possono contenere dati personali e sanitari dell'utente? Non ho trovato fonti sul fatto se la sola cartella dell'animale sia "dato sanitario" in qualche stato (01, sez. 1.4 e 4.3). *Chiedere al legale.*
11. **Retention:** periodi di conservazione per chat, percorsi di passeggiata, log (campi [TBD] in 02, sez. 7). La posizione GPS è sensibile in molti stati; raccomando di eliminare i punti dopo il termine della passeggiata o dopo un periodo breve.
12. **Cancellazione account:** Apple (5.1.1(v)) e Google (in-app **e** link web) la richiedono. Esiste già nell'app? Dalla mia ricerca non l'ho verificata nel codice (fuori incarico).
13. **DMCA / contenuti degli utenti:** vogliamo registrare un "designated agent" presso l'US Copyright Office per foto e segnalazioni? Domanda per il legale (03, sez. 9).
14. **Dichiarazioni di mercato e sponsor:** lo store/sito non dirà "AI vet" o "diagnosi" (05, sez. 3). Esistono accordi con ASPCA o Pet Poison Helpline? Se sì, vanno dichiarati (06).
15. **Chi rivede?** Serve un avvocato abilitato negli USA (privacy e consumer) prima della pubblicazione; tutti i testi sono bozze. Budget e tempi?

## Verifiche tecniche collegate (per la sessione backend)

- Chiave per locale nel catalogo consensi (`en-US` ≠ `en-GB` ≠ `en-AU`) e campo `locale` nel `ConsentRecord` (04, sez. 1).
- Estensione del filtro PII a formati USA (numero civico + via, ZIP, telefono, SSN) (07).
- Un link "Your Privacy Choices" **non** è richiesto finché non vendiamo/condividiamo dati: ricontrollare ad ogni nuovo SDK.

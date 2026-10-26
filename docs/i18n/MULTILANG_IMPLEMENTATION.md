# IT / EN / ES — integrazione sulla build 30

## Architettura

Il ramo MULTILANG parte da main `69f6c45` della repository `vastaso88/VET-APP`.
La precedente lavorazione è conservata negli stash di recupero: non applicarli
integralmente, perché contengono schermate superate dalla build 30.

- 1.355 chiavi in ciascun catalogo Flutter; IT è sorgente e fallback.
- Un solo `LanguageSelector` per Login, Registrazione e Impostazioni.
  Il menu compatto propone Italiano / English / Español, senza duplicare EN
  per ciascuna variante regionale.
- `LanguageStore` è il controller esistente: si riusa senza introdurre un
  secondo gestore globale. La UI cambia senza ricreare le pagine o i campi.
- Le varianti inglesi UK/US/Australia già previste dall'app restano disponibili:
  condividono EN, ma conservano i rispettivi formati e le unità di misura.
- Precedenza: scelta esplicita nella sessione > account > dispositivo salvato >
  lingua supportata del telefono > IT. Una lettura account arrivata in ritardo
  non annulla una scelta più recente; i problemi di rete non bloccano la UI.

## Preferenze account e compatibilità

Questa repository non ha `OwnerProfile` né una tabella `owner_profiles`.
Il profilo proprietario esistente è Supabase Auth: la preferenza viene salvata
nei metadata `preferred_locale` (it/en/es) e `preferred_locale_variant`.
Non è un dato di autorizzazione. Nessuna tabella duplicata o migrazione distruttiva.
Il modello API `AuthenticatedUser` espone `preferred_locale`, default IT per
gli account precedenti. L'API valida i valori e aggiorna esclusivamente
l'identità autenticata, conservando gli altri metadata:

- GET `/account/preferences`
- PUT `/account/preferences` con `{"preferred_locale":"es"}`

Flutter usa gli endpoint autenticati Supabase `getUser` / `updateUser` per
mantenere anche la variante regionale. Gli endpoint applicativi possono essere
usati da altri client senza gestire direttamente Supabase.

## Chat, sicurezza e testi legali

POST `/chat` accetta `response_locale` it/en/es; questo campo prevale sul vecchio
`language`, che rimane compatibile. Chat modificata e riepilogo veterinario usano
anch'essi la lingua corrente. L'istruzione al modello prevale sulla lingua del
messaggio e della cronologia. Anche sintesi delle evidenze e domande di colloquio
ricevono la lingua della richiesta, senza mutare un'istanza condivisa.

`packages/core/domain/localization.py` centralizza messaggi deterministici:
triage, dosaggi, errori provider, evidenze insufficienti, consensi, documenti,
limitazioni, suggerimento peso e riepilogo veterinario. Codici clinici, stati e
dati salvati restano invariati. I segnali urgenti e gli intent sono ampliati
a IT/EN/ES; i test coprono tutte le nove combinazioni input/lingua selezionata.

I consensi account hanno traduzioni fedeli della bozza corrente; il consenso
cartella clinica conserva i fatti della versione v2 (tre voci, massimo due
documenti spiegati, invio al fornitore AI). L'italiano del catalogo Flutter viene
confrontato automaticamente con il testo backend. Le traduzioni **non sono una
revisione o approvazione legale**: prima del rilascio pubblico serve tale revisione.

Android ha risorse IT/EN/ES per widget e servizio passeggiata; il contesto delle
risorse native legge la preferenza Flutter, non soltanto la lingua del telefono.
I testi si aggiornano al successivo ridisegno del widget/notifica.

## Controlli e prova della branch

La CI viene eseguita su MULTILANG e sulle pull request, senza deploy o merge:
generazione cataloghi, controllo chiavi/valori/placeholder, guardia dei testi UI,
analisi e test Flutter, compilazione APK debug e artifact `vetapp-test-apk`.
SDK Flutter fissato a 3.47.6, compatibile con le dipendenze della build 30.
Le risorse native hanno un controllo separato di chiavi e formati `%`.

La guardia UI copre literal italiani e literal passati ai widget anche in altre
lingue, inclusi quelli su più righe. È una verifica euristica: le eccezioni
devono essere motivate in `scripts/i18n/allowlist.txt`, non aggiunte per eludere
un errore. Nomi propri, documenti, dati utente e fonti esterne non vengono tradotti.

L'APK artifact è una build di verifica, non una pubblicazione Firebase. Per una
prova con App Tester occorre distribuirne una build della branch con le normali
credenziali e configurazione di test. Nessuna distribuzione è stata effettuata
da questa lavorazione. Il test fisico Android e la verifica della sincronizzazione
su un account di prova reale restano passaggi di rilascio; i test automatici
non sostituiscono la verifica dell'ambiente remoto.

## Verifica locale finale — 13 ottobre 2026

- Cataloghi: IT/EN/ES completi, 1.355 chiavi; guardia testi UI superata.
- Backend: 941 test superati, 1 saltato; lint superato.
- Flutter: 709 test superati, 7 saltati; analisi senza problemi.
- Build web della versione finale completata.
- Typecheck Python: superato su 355 file con `--ignore-missing-imports`;
  il controllo standard locale richiede i pacchetti opzionali Presidio,
  non installati su questo computer. La CI installa tutti gli extra.
- APK locale non compilato: Android SDK assente. Compilazione nativa prevista
  dalla nuova CI, ma non ancora eseguita su GitHub.
- Controllo layout automatizzato a 360 px per Login, Registrazione e selettore
  Impostazioni in IT/EN/ES; nessun overflow. Il browser integrato non era
  disponibile per una sessione visiva manuale.
- Sincronizzazione account verificata con adapter/client simulati, senza
  modificare dati Supabase reali. Nessun merge, commit, push o deploy effettuato.

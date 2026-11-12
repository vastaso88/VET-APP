# Test Android MULTILANG con Firebase App Distribution

## Cosa fa il workflow

Il workflow `CI` conserva i controlli su push e pull request. Un avvio manuale
con `distribute_firebase` attivo, selezionando la branch `MULTILANG`, esegue i
controlli Flutter, backend e portale admin e solo dopo crea un APK release firmato,
lo salva tra gli artifact e lo distribuisce al gruppo Firebase configurato.
I push non distribuiscono build. Un avvio su `main` non distribuisce build.
Non modifica `main`, non distribuisce il backend e non aggiorna database.

## Stato e prima attivazione

Le modifiche locali devono essere committate e pubblicate su `MULTILANG` prima
che GitHub possa compilarle. Il workflow non legge i file sul tuo computer.

GitHub richiede che un workflow con `workflow_dispatch` sia presente anche sulla
branch predefinita per abilitarne l'avvio manuale. Se `main` non contiene ancora
questo trigger, serve una modifica separata e approvata del solo workflow su
`main`, senza mergiare il codice multilingua. Poi da Actions si seleziona
`MULTILANG`: il codice compilato resta quello di questa branch. Non e stato
eseguito alcun merge automatico per aggirare questo requisito.

## Configurazione GitHub

Configurare l'environment `firebase-testing`, preferibilmente con approvazione
prima della distribuzione e limitazione alla branch `MULTILANG` se disponibili
nel piano GitHub. Non sono necessarie installazioni amministrative sul PC.
Usare accessi gia autorizzati; non assegnare ruoli Owner/Editor per questo flusso.

Variables dell'environment:

| Nome | Valore |
| --- | --- |
| `FIREBASE_ANDROID_APP_ID` | App ID Firebase Android, formato `1:numero:android:identificatore`; non il package name |
| `FIREBASE_TESTER_GROUPS` | Alias del gruppo gia esistente, ad esempio `internal-testers`; piu alias separati da virgola senza spazi |
| `TEST_API_BASE_URL` | URL HTTPS del backend scelto per i test, raggiungibile dal telefono |
| `TEST_SUPABASE_URL` | URL HTTPS del progetto di autenticazione scelto per i test |

Secrets dell'environment:

| Nome | Contenuto |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | JSON completo di un service account gia autorizzato alla distribuzione sul progetto Firebase |
| `TEST_SUPABASE_PUBLISHABLE_KEY` | Chiave pubblica `sb_publishable_...`; compatibilita anche con una legacy `anon` |
| `ANDROID_KEYSTORE_BASE64` | Keystore di firma persistente codificato Base64, senza spazi o a capo |
| `ANDROID_KEYSTORE_PASSWORD` | Password del keystore |
| `ANDROID_KEY_ALIAS` | Alias della chiave contenuta nel keystore |
| `ANDROID_KEY_PASSWORD` | Password della chiave |

Il service account deve avere il ruolo Firebase App Distribution Admin sul solo
progetto interessato, non privilegi amministrativi del PC o ruolo Owner del
progetto. Se questi accessi non esistono, fermarsi e usare il caricamento manuale
dell'APK da un account gia autorizzato: non ampliare automaticamente i permessi.
Non incollare credenziali nella chat, nel codice o nelle release notes.

La chiave Supabase pubblica finisce intenzionalmente nell'APK. Non usare
`service_role` o `sb_secret_...`: il validatore le blocca. Nome Dart esistente
`SUPABASE_ANON_KEY` mantenuto per compatibilita anche per chiavi publishable.
Il workflow non crea ne modifica risorse Supabase.

## Firma e compatibilita con App Tester

Il package attuale e `com.vetapp.vetapp`: deve coincidere con l'app Android
registrata su Firebase. Usare la stessa chiave dell'APK gia installato per
aggiornarlo senza disinstallazione. Non utilizzare una nuova chiave debug
generata ogni volta dal runner GitHub.

Con una firma diversa Android rifiuta l'aggiornamento. Non disinstallare alla
cieca: la disinstallazione puo cancellare i dati locali. Questo workflow non
introduce un package separato, quindi l'APK di test sostituisce l'installazione
esistente se firma e version code sono compatibili; non si installa a fianco.
Un package separato richiederebbe una distinta app Firebase e verifiche sui deep
link, fuori dallo scopo di questa configurazione.

## Avvio manuale

1. In GitHub aprire `vastaso88/VET-APP` → Actions → CI → Run workflow.
2. Selezionare `MULTILANG`.
3. Attivare `distribute_firebase`.
4. Inserire `build_number`, intero superiore al version code dell'ultima build
   installata/distribuita. GitHub non controlla quel numero su Firebase: va scelto
   considerando anche le build pubblicate da Francesco o da altri workflow.
5. Inserire note di test; branch, commit e version code vengono aggiunti automaticamente.
6. Avviare e, se configurata, approvare la distribuzione nell'environment.
7. Installare la release da Firebase App Tester sul telefono.

L'APK release resta scaricabile dagli artifact GitHub per 7 giorni anche se
l'upload Firebase fallisce. Le credenziali temporanee vengono eliminate a fine
job; non sono caricate negli artifact. Le release notes non contengono chiavi.
La CLI Firebase e fissata a `15.33.0` per rendere la distribuzione ripetibile.

## Ambiente e verifica multilingua

Una branch separata NON isola i dati. Verificare che URL backend e progetto di
autenticazione siano coerenti. Preferire un ambiente di test; se si sceglie
produzione, usare account e animali fittizi e considerare che le operazioni
modificano i dati reali di quell'ambiente. Il workflow non sceglie produzione
come default e rifiuta URL mancanti, HTTP, localhost e indirizzi IP privati.

Il backend raggiunto dall'APK deve includere gli aggiornamenti multilingua:
`response_locale` e `/account/preferences`. Distribuire solo il client non
aggiorna le risposte deterministiche della chat o la sincronizzazione account.

Testare Login, Registrazione e Impostazioni in IT/EN/ES; cambio immediato senza
perdere lo stato; persistenza dopo riavvio e login; sottoschermate, notifiche e
widget Android; risposte chat nella lingua scelta anche con input in un'altra
lingua. Usare scenari di sicurezza fittizi per le risposte deterministiche.

## Riferimenti

- [Firebase CLI e distribuzione APK](https://firebase.google.com/docs/app-distribution/android/distribute-cli)
- [Autenticazione con service account](https://firebase.google.com/docs/app-distribution/authenticate-service-account)
- [GitHub: workflow manuali e branch predefinita](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [Supabase: chiavi pubbliche e private](https://supabase.com/docs/guides/getting-started/api-keys)

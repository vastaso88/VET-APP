# Screenshot degli store: elenco per lingua

Le immagini si generano dopo; qui c'è cosa fotografare, con quali testi e quali dati. Una serie per lingua di scheda
(`it`, `en-GB`, `en-US`, `en-AU`, `de`, `fr`, `es`).

## Regole

- **Dati sintetici**: animali di fantasia ("Luna", "Milo"), nessun nome, indirizzo, foto o mappa riconoscibili di una persona reale.
  Account di prova creato in locale (`SUPABASE_URL` vuoto: l'app usa i dati finti, non tocca la produzione; vedi la nota "local web
  builds hit production" nel registro del progetto).
- **App nella lingua della serie** e **variante del paese**: la serie en-US mostra `$`, `MM/dd/yyyy`, libbre e °F; en-GB `£`, `dd/MM/yyyy`,
  libbre e miglia; en-AU `A$`, `dd/MM/yyyy`, kg e km; de `€`, `dd.MM.yyyy`; fr e es `€`, `dd/MM/yyyy`; it `€`, `dd/MM/yyyy`.
  Le unità cambiano da sole con la variante (Impostazioni → Layout), il resto dal modulo `lib/l10n/regional_defaults.dart`.
- Nessun prezzo vero nei piani: lo schermo "Piani" **non** va nelle schermate finché i prezzi sono segnaposto.
- Mappe: usare una zona di prova con luoghi reali di OpenStreetMap ma senza abitazioni (centro di una città, un parco); in
  attribuzione devono restare visibili i crediti OSM (obbligo ODbL, `docs/compliance/06_radar_mappe_sponsorizzazioni.md`).
- La didascalia sta sopra o sotto lo schermo, non dentro l'app. Massimo ~35 caratteri, stesso significato in tutte le lingue.
- Nessuna schermata di Mercatino, notizie, eventi (vedi `README.md`).
- Controllare a occhio l'overflow del testo tradotto (de e fr sono i più lunghi): una schermata tagliata nelle immagini dello store
  è un difetto visibile a tutti.

## Le schermate (stesso ordine in ogni lingua)

| # | Schermata | Cosa deve vedersi |
|---|---|---|
| 1 | Home / elenco animali | Due profili (cane e gatto), prossimo promemoria |
| 2 | Profilo di un animale | Foto, razza, data di nascita nel formato del paese, peso nell'unità del paese |
| 3 | Cartella clinica | Un referto, una vaccinazione, il consenso all'assistente per quell'animale |
| 4 | Promemoria | Vaccino e cura in scadenza, data nel formato del paese |
| 5 | Assistente IA | Una domanda e una risposta con fonti, **badge "generato dall'IA"** visibile |
| 6 | Urgenza | Risposta che rimanda al veterinario (mostra che l'app non sostituisce il veterinario) |
| 7 | Passeggiata | Percorso sulla mappa, tempo e distanza nell'unità del paese |
| 8 | Servizi vicini | Mappa con veterinari e negozi, scheda di un luogo |
| 9 (facoltativa) | Lingua e unità | Selettore lingua con le bandiere, Impostazioni → Layout |

Play: da 2 a 8 immagini per dispositivo (le prime 3 pesano di più nella pagina); App Store: fino a 10. Si consiglia la serie 1-8.

## Didascalie

| # | it | en (GB/US/AU) | de | fr | es |
|---|---|---|---|---|---|
| 1 | Tutti i tuoi animali, in un'app | All your pets in one app | Alle Ihre Tiere in einer App | Tous vos animaux, une seule app | Todas tus mascotas en una app |
| 2 | Il profilo di ogni animale | A profile for every pet | Ein Profil für jedes Tier | Un profil pour chaque animal | Un perfil para cada mascota |
| 3 | La cartella clinica sempre con te | Health records, always with you | Die Gesundheitsakte immer dabei | Le carnet de santé toujours là | Historial clínico siempre contigo |
| 4 | Mai più un vaccino dimenticato | Never miss a vaccine | Keine Impfung mehr vergessen | Plus aucun vaccin oublié | Ni una vacuna olvidada |
| 5 | Risposte con fonti e limiti | Answers with sources and limits | Antworten mit Quellen und Grenzen | Réponses avec sources et limites | Respuestas con fuentes y límites |
| 6 | Per le urgenze, il veterinario | In an emergency, call your vet | Im Notfall: Ihre Tierarztpraxis | En urgence, votre vétérinaire | En urgencias, tu veterinario |
| 7 | Le passeggiate, passo dopo passo | Dog walks, step by step | Gassirunden, Schritt für Schritt | Vos promenades, pas à pas | Tus paseos, paso a paso |
| 8 | Servizi per animali vicino a te | Pet services near you | Tierservices in Ihrer Nähe | Services pour animaux près de vous | Servicios para mascotas cerca |
| 9 | L'app nella tua lingua | In your language, your units | Ihre Sprache, Ihre Einheiten | Votre langue, vos unités | Tu idioma, tus unidades |

Per en-US la didascalia 6 può dire "your veterinarian" se c'è spazio. Le didascalie sono bozze: stessa revisione dei testi delle schede.

## Dimensioni (da riconfermare nelle console al momento del caricamento: cambiano)

- Google Play: telefono, PNG/JPEG 24 bit, lato corto ≥ 320 px e lato lungo ≤ 3840 px, rapporto non oltre 2:1. Consigliato 1080×1920
  o 1080×2340. Icona 512×512. Immagine in evidenza 1024×500.
- App Store: schermo iPhone da 6,9″ (1320×2868 o 1290×2796) obbligatorio quando l'app è per iPhone; gli altri formati si ricavano da
  quello. iPad da 13″ (2064×2752) solo se l'app supporta iPad.
- Una serie per lingua: l'App Store usa la serie della lingua primaria se manca quella localizzata, ma per en-GB/US/AU conviene
  caricarle tutte e tre perché cambiano valuta, date e unità.

## Come produrle

1. Build locale con dati finti: `cd apps/mobile_app && flutter run -d chrome --dart-define=SUPABASE_URL=` (o l'emulatore Android), poi
   scegliere la lingua dal selettore.
2. Per le serie di tutte le lingue c'è già materiale riusabile: `side-session-notes/…/multilingua_coordinatrice/stress/st_area2_tests`
   (harness schermate con dati finti, `tools/prepare_fonts.sh`). **Non committare** i font né modifiche a `pubspec.yaml`.
3. Aggiungere le didascalie con uno strumento di design o uno script esterno al repository; le immagini finali non si versionano qui.

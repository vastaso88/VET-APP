> **BOZZA — non è consulenza legale; da rivedere da un solicitor australiano prima della pubblicazione**

# Differenze Australia rispetto all'Italia

Per la sessione coordinatrice e per chi implementa le regioni. Le righe «legale» rimandano a `01_ricerca_normativa.md`. Quelle di «formato» sono standard comuni, non ricerca legale: dove non ho una fonte lo scrivo.

## Legale

| Tema | Italia / UE | Australia | Effetto su VetApp |
|---|---|---|---|
| Legge privacy | GDPR + Garante | Privacy Act 1988 + APP; regolatore OAIC | Informativa diversa (file 02): niente «basi giuridiche» art. 6; sì APP 1/5/8; elenco Paesi esteri |
| Soglia | Nessuna | Esenzione sotto A$3 mln di fatturato (con eccezioni) | Scrivere come se si applicassero gli APP (consigliato) |
| Consenso trattamento | Art. 6/7 GDPR, opt-in granulare | Consenso richiesto per usi non attesi e per dati sensibili; marketing: APP 7 + Spam Act | Stesse chiavi di consenso (file 04) con testi propri |
| Marketing email | GDPR + ePrivacy | Spam Act 2003: consenso, mittente, disiscrizione senza login, effetto entro 5 giorni lavorativi | Link disiscrizione in ogni email commerciale |
| Notifica violazioni | 72 ore (GDPR art. 33) | NDB: «serious harm», notifica a OAIC e interessati (valutazione entro 30 giorni, da verificare) | Procedura interna diversa |
| Trasferimenti estero | Clausole contrattuali, adeguatezza | APP 8 + responsabilità s 16C (da verificare) | Nominare i Paesi (Groq, Vercel) |
| IA | AI Act art. 50 (trasparenza) | Nessun obbligo specifico; linee guida OAIC/DISR volontarie; Piano IA 02/12/2025 | Badge IA mantenuto per coerenza |
| Minori | Maggiorenni (bozza) | Codice minori OAIC (bozza, entro 10/12/2026); social min. 16 (non riguarda VetApp) | App 18+ |
| Contenuti utenti | DSA (piccole imprese: obblighi ridotti) | Online Safety Act 2021 / eSafety (codici Phase 2 dal 09/03/2026) | Segnalazione contenuti; valutazione (incertezza) |
| Consumo | Codice del consumo | Australian Consumer Law: garanzie non escludibili; prezzo unico con GST; abbonamenti (dal 01/07/2027) | Termini e piani (file 03) |
| Veterinaria | Regole nazionali/regionali italiane | Otto giurisdizioni: board separati (file 01, sez. 6) | Solo informazioni generali (file 05) |
| Autorità reclami | Garante | OAIC (privacy), ACCC/consumer agency statale (consumo), eSafety (online), ACMA (spam) | Indicare nei testi |

## Formato e locale

| Aspetto | Italia | Australia | Nota |
|---|---|---|---|
| Data | gg/mm/aaaa | **dd/mm/yyyy** (`13/10/2026`) | Stesso ordine dell'Italia. Mese in lettere in inglese: «13 October 2026». Non usare mm/dd |
| Valuta | € (euro) | **A$** — dollaro australiano (AUD); simbolo «$», nei testi cross-regione «A$» | Prezzi **comprensivi di GST** (10%). Verificare i livelli prezzo A$ negli store |
| Distanze | km | **km** (stesso) | Nessun cambio |
| Peso | kg | **kg** (stesso). Pesi dei pet in kg | |
| Temperatura | °C | **°C** (stesso) | |
| Ora | 24 h | più comune 12 h («9:30 am»); 24 h per orari tecnici | Preferire il formato del dispositivo |
| Telefono | +39 … | **+61**; mobile 04xx xxx xxx; fisso (0x) xxxx xxxx; 1300 xxx xxx; 13 xx xx | Prefisso paese +61 senza lo 0 iniziale. I numeri 1300/13 non si chiamano dall'estero |
| Emergenza | 112 | **000** | Per le persone. Veterinari: nessun numero nazionale (file 06) |
| Indirizzi | via, civico, CAP 5 cifre | numero + via, suburb, **stato**, **postcode 4 cifre** | Campo «stato/territorio» obbligatorio: NSW, VIC, QLD, WA, SA, TAS, ACT, NT |
| Fusi orari | uno (+DST UE) | più fusi (AEST/ACST/AWST), DST diverso per stato: QLD, NT e WA **senza** DST | Promemoria locali: usare il fuso dell'utente, non un offset fisso |
| Stagioni | Emisfero nord | **Emisfero sud**: estate dicembre–febbraio | Contenuti stagionali (caldo, zecche, serpenti, ecc.) invertiti rispetto all'Italia. Questo è un'inferenza, non una fonte |
| Ortografia inglese | — | **britannica/australiana**: colour, centre, organise, programme, licence (nome) | Decisione del 13/10: inglese neutro, dove serve britannico |
| Terminologia | veterinario | *vet*, *veterinarian*; *suburb*; *dog park* / *off-leash area* | |
| Microchip e registrazione | Anagrafe canina | Regole per stato/territorio e consigli locali | Non ricercato; fuori ambito |
| Enti (radar luoghi) | Overture/OSM | Stesse fonti aperte; dataset municipali non c'è equivalente trovato | Fuori ambito di questo documento |

## Cosa cambia nei file prodotti

- **Termini:** prezzi in A$ con GST; clausola ACL (non escludibile); legge di uno stato [da scegliere].
- **Privacy:** APP al posto di GDPR; OAIC al posto del Garante.
- **Consensi:** testi e versione propri `en-AU v1`; registrare lingua/regione mostrata.
- **Numeri utili:** 000, Animal Poisons Helpline, WIRES, RSPCA statali; nessun elenco di cliniche.

# 18 - "Around the world": viaggiare e spostarsi con un animale

Data: 2026-11-16 (versione 3, dopo il parere della Normativa `docs/compliance/17_nuove_sezioni_around_the_world_e_ricordi.md`, parte A, anche §A.11-A.14: risposte, testi A-I, bozze di richiesta, note sulla privacy). Fase 1 (progetto, nessun codice). **Bozza da approvare**: la fase 2 (costruzione) parte solo dopo il sì del proprietario. Il nome resta «Around the world», come l'ha scritto lui.

Riusa lo schema delle schede salute (`data/manuale/`, `scripts/manuale/check_manuale.py`), il catalogo delle fonti (`docs/product/15_catalogo_fonti_approvate.md`) e il semaforo della Normativa.

## 0. In breve (per il proprietario)

- **Cos'è**: una funzione dentro «Attività». Scrivi «da dove parti» e «dove vai», scegli «chi porti con te» e ottieni una scheda: cosa chiedono le regole ufficiali, con quali tempi, quali malattie e protezioni contano, comportamenti da seguire, rientro.
- **Cosa NON è**: non invita a spostare animali né a importarli (§3).
- **Prima versione (decisione della Normativa)**: solo spostamenti **non commerciali** di **cani, gatti e furetti** con il proprietario. Altre specie, vendita, adozione, trasferimento da rifugio: scheda generica con il collegamento all'autorità competente, senza dettagli.
- **Fonti, la notizia importante**: le regole UE sono **cambiate**. L'atto di riferimento è oggi il Regolamento delegato (UE) 2026/131; il 576/2013 vale solo in via transitoria (microchip prima del 22/4/2026, passaporti fino al 1/1/2028). Quindi si parte dalla pagina della Commissione (fonte verde, lettura automatica) e dai testi su EUR-Lex (fonte rossa: **lettura a mano**). WOAH è rosso (solo collegamento), salute.gov.it e Australia sono rossi, USDA APHIS giallo. Dunque la copertura avanza al ritmo della lettura a mano, tranne dove c'è una fonte verde (Commissione UE, GOV.UK).
- **Schede in «bozza»** finché non le approvi tu. Fino ad allora in produzione non si vedono.
- **Nessun dato di viaggio sul server**: l'app scarica **tutte** le schede approvate (contenuto nostro, uguale per tutti) e sceglie **sul telefono**. Il server non vede mai la coppia di paesi né l'animale. Nessuna tabella, nessun viaggio salvato, nessun permesso Android.
- **Decisioni che servono da te**: §9.

## 1. La schermata (dentro «Attività»)

Nuova riga in `activities_page.dart`: «Around the world» (sottotitolo: «Regole, vaccini e protezioni per spostarti con un animale»). Apre una pagina con tre campi e un pulsante.

```
Around the world
[ avvertenza fissa (testo della Normativa, §3) ]

Da dove parti      [ cerca un paese…      ]   (predefinito: il paese della Località, se impostata)
Dove vai           [ cerca un paese…      ]
Chi porti con te   [ Luna (cane) ] [ Micio (gatto) ] [ + una specie: cane / gatto / furetto ]

                        [ Mostra le informazioni ]
```

- **Cerca paese**: barra di ricerca con suggerimenti (nome in italiano, anche senza accenti; sinonimi tipo «USA», «Regno Unito»). Elenco dei paesi con codice ISO in un file dati dell'app (non nell'ARB).
- **Chi porti con te**: (a) tra i **propri animali** (leggo solo specie e data di nascita **sul telefono**, per dire per esempio «è troppo piccolo per il vaccino antirabbico»; l'identità non va mai al server); (b) per **specie**, senza animale registrato. Specie ammesse in v1: cane, gatto, furetto; per le altre (coniglio, uccelli, rettili…) compare la scheda generica «per questo caso valgono regole diverse».
- **Quando parti**: non c'è in v1 (niente date né viaggi salvati, regola della Normativa). Il calendario dei tempi è un'idea per dopo (§9).
- **Risultato**, in ordine cronologico, con i blocchi della §2. Ogni scheda mostra in fondo la riga della fonte («Fonte: ente, titolo, collegamento. Verificato il …») e «Segnala un errore».
- **Nessuna scheda per quella coppia**: lo diciamo e mostriamo la **via ufficiale**: l'autorità veterinaria del paese di destinazione (solo collegamento), il Servizio veterinario della ASL, e «le regole ufficiali prevalgono».
- **Avvertenze, Info, Termini** (§3): testi A-I della Normativa (A.12), da usare come sono. Alla prima apertura il riquadro è anche un avviso breve con «Ho capito» (non è un consenso: schema di `compliance/15`).

## 2. La scheda: paese × specie

### 2.1 Cosa serve per comporre una risposta

Le regole dipendono da **dove si va**, **da dove si parte** e **quale specie**. Per non moltiplicare le schede:

| Pezzo | Dipende da | Dove sta |
|---|---|---|
| **Scheda destinazione** (entrata, comportamenti e norme, rientro) | paese di destinazione × specie; le frasi che cambiano con l'origine hanno `origine` | `data/manuale/viaggi/VIA-<ISO2>-<SPE>.json` |
| **Salute del posto** (malattie presenti, vaccini consigliati, protezioni) | paese o regione × specie | stessi file, blocchi propri |
| **Scheda UE** (entrata in UE e spostamenti dentro la UE, rientro in Italia) | specie | `data/manuale/viaggi/VIA-UE-<SPE>.json` |

**Origine in v1: solo due valori**, `UE` e `fuori_UE`. Non si costruisce un elenco di paesi terzi «elencati» o «non elencati» copiato da un atto (la Normativa non vuole elenchi copiati, A.4): chi parte da fuori UE e va in UE vede la regola generale e il rimando all'autorità. Se la Normativa permetterà un elenco ricavato dall'atto, si aggiunge dopo.

L'app unisce i pezzi in base alla coppia scelta. Quando la destinazione è un paese con regole proprie (per esempio il trattamento contro la tenia previsto per alcuni paesi), le ha nella sua scheda.

### 2.2 Blocchi (stesso schema delle schede salute, più i blocchi di viaggio)

Resta lo schema: `codice`, `specie`, `titolo`, `stato`, `ultimo_controllo`, `scadenza`, `revisione`, `parole_chiave`, `riassunto_per_chat`, `blocchi` → `frasi` → `testo` + `fonti` (`id`, `punto` esatto) + `nostro` (consiglio nostro, al massimo 3). **Un fatto, una fonte**; senza fonte non si scrive. Cambiano solo tre cose:

1. blocchi in più (oggi lo script ne ammette 6 fissi; si aggiungono quelli di viaggio);
2. campo facoltativo `origine` sulla frase (`UE`, `fuori_UE`; vuoto = tutte);
3. campo facoltativo `tipo_viaggio` della scheda (`non_commerciale`; le altre forme non hanno dettagli).

| Blocco | Cosa contiene |
|---|---|
| `documenti` | passaporto o certificato, chi lo rilascia, dichiarazione, permessi di ingresso, limite di animali per veicolo; **«quando non è un viaggio»**: la frase fissa «per questo caso valgono regole diverse, rivolgiti all'autorità» (nessun dettaglio su adozione, vendita o rifugi) |
| `microchip` | tipo richiesto; va impiantato prima del vaccino antirabbico |
| `vaccini_obbligatori` | quali, età minima, **tempi** (giorni di attesa, validità, richiami), come requisiti di legge e con la fonte; nessun consiglio sanitario. **Nessun numero (giorni, settimane, ore) si scrive finché non è letto a mano nell'atto in vigore**; le voci con tempi portano il testo I (§3) |
| `test_sierologici` | titolo anticorpale: quando, quanto si aspetta |
| `vaccini_consigliati` | facoltativi o consigliati secondo dove si va; fonti ufficiali; WSAVA 2024 (giallo, già controllata) solo per il principio «dipende da dove vivi e viaggi» |
| `malattie_presenti` | «Secondo {fonte}…»; niente mappe copiate; fonti di società scientifiche (per esempio le mappe dei parassiti) sono a diritti riservati e non si usano come fonte di questo blocco |
| `farmaci_e_protezioni` | **cosa chiedono le regole** (per esempio il trattamento contro la tenia prima dell'ingresso in alcuni paesi, con la finestra di ore); **mai prodotti, marchi né dosi**; decide il veterinario; nessun collegamento commerciale |
| `comportamenti_e_norme` | **solo regole e usanze con fonte ufficiale**: guinzaglio, museruola, razze vietate, locali, mezzi, spiagge, parchi. Niente generalizzazioni su popoli o religioni, nessun giudizio su come «si trattano gli animali» in un paese; senza fonte non si scrive |
| `rientro` | cosa serve per tornare (rimando alla scheda UE) e i documenti di uscita del paese |
| `non_diffondere` | un animale può portare parassiti o agenti di malattia dove non ci sono; cosa fare (trattamenti previsti dalla legge, controllo al rientro) |
| `quando_andare_dal_veterinario` | parlarne con il veterinario **prima** di partire (età, salute, razza, caldo, durata) e cosa osservare al ritorno |
| `limiti` | cosa non copre, con il rimando alla fonte ufficiale |

La **cultura locale** (richiesta del proprietario) segue la Normativa A.6: si scrive solo ciò che una fonte ufficiale dice; quello che non ha fonte non c'è, e il blocco `limiti` lo dice. Questa decisione è già presa, non serve più chiederla.

## 3. Il messaggio: informare senza incoraggiare

Tono (Normativa A.1 e A.7), valido per tutta la funzione:

1. **Tre livelli di avviso** (Normativa A.11-A.12): **1** riquadro fisso in cima (testo A: «non incoraggia a spostare né a importare animali»); **2** su ogni scheda: fonte, «verificato il…», «se la fonte ufficiale dice altro, vale la fonte» (testo B), «Segnala un errore», avviso di scheda vecchia (oltre 90 giorni) o nascosta (oltre 180) o non coperta (testo C); **3** sulle voci con tempi o conseguenze gravi (vaccini, titolo anticorpale, trattamenti, microchip, attese): testo I («fissali con il tuo veterinario con largo anticipo»). Più dell'avviso conta il **metodo** (§7): lettura umana della fonte, approvazione, registro di chi ha verificato e quando, scadenze.
2. **Niente promozione**: nessuna classifica delle destinazioni, niente «porta il tuo cane a…», niente collegamenti commerciali (agenzie di trasporto, servizi di trasferimento animali, prodotti veterinari).
3. **Altre specie, vendita, adozione, rifugio, più animali insieme**: scheda generica con il collegamento all'autorità, senza dettagli (testo D «non è un viaggio»).
4. **«Si può essere vettori»**: il blocco `non_diffondere`, con fonti ufficiali.
5. **Compagnie di trasporto e alloggi**: testo E (non le riportiamo, non siamo un'agenzia). **Usanze locali**: testo H. **Info**: testo F.
6. **Termini §10**: testo G; entra in it/03 solo quando la sezione esiste nel codice (lo inserisce la Normativa).
7. **Chat**: in v1 la chat non usa le schede di viaggio. Risposta fissa a una domanda di viaggio (A.7): «Le regole per viaggiare cambiano da paese a paese e non posso garantirtele: guarda la sezione Around the world oppure la fonte ufficiale del paese di arrivo» (approvata dalla Normativa, A.14). Si usa solo quando la domanda è di viaggio. È una modifica piccola alla chat: la segnalo alla sessione Chat LLM, non la faccio io.

## 4. Cosa NON facciamo

- Dosi, prodotti, marchi di farmaci.
- Copia di testi, tabelle o elenchi delle fonti; **nessun testo di terzi nel repository né nell'archivio della chat** (solo i nostri riassunti con la fonte).
- Regole delle compagnie aeree, navi, treni (non sono fonti ufficiali: avviso e rimando).
- Specie diverse da cane, gatto, furetto e spostamenti per vendita o adozione (solo scheda generica).
- Viaggi o date salvati, tabelle nuove, invio dei paesi scelti a fornitori, **calcolatori di date** («ultima data utile»: serve un parere a parte, Normativa A.11). Il server non riceve mai la coppia di paesi; nei log non compaiono paesi legati a un utente; nessuna statistica senza il consenso alle statistiche.

## 5. Le fonti e il semaforo (controlli della Normativa, 16/11/2026)

«Ufficiale» non vuol dire «riutilizzabile». **Verde** = lettura automatica, un documento alla volta; **giallo** = prima i 4 controlli e la registrazione; **rosso** = solo lettura a mano (o permesso scritto), **mai** il testo incollato in un modello. Ogni scheda: fonte e data di verifica.

| Fonte | Per cosa | Semaforo | Come si usa |
|---|---|---|---|
| **Commissione europea** (commission.europa.eu, food.ec.europa.eu): pagina sugli spostamenti di cani, gatti, furetti | regole UE di oggi (atto di riferimento: Reg. delegato (UE) 2026/131) | **verde** (CC BY 4.0, Decisione 2011/833/UE) | lettura automatica, attribuzione, controllo di parti di terzi; la pagina non ha data di aggiornamento: si annota la data di lettura |
| **EUR-Lex**: Reg. delegato (UE) 2026/131; Reg. 576/2013 e 577/2013 (transitori); Reg. delegato 2020/688 all. VII e Reg. di esecuzione 2021/620 all. XIX (tenia); Reg. di esecuzione 2026/705 (modelli di passaporto) | testi degli atti | **rosso** (risposta vuota ai lettori automatici) | **lettura a mano**; i testi degli atti ufficiali sono liberi, riassunti nostri ⚖️ |
| **GOV.UK** (Regno Unito) | entrata in GB e Irlanda del Nord | **verde** a livello di sito (OGL v3.0) | controllare la licenza di ogni pagina; la pagina di guida sui viaggi non è ancora stata letta |
| **USDA APHIS** (USA) | regole USA | **giallo** | controllo in 4 punti; opera federale, pubblico dominio (17 U.S.C. §105) salvo terzi e loghi ⚖️: nessun permesso da chiedere, si registra la dichiarazione con la data |
| **WOAH** | malattie presenti | **rosso** (data mining e robot vietati) | **solo collegamento**; per riprodurre serve il permesso |
| **Ministero della Salute** (salute.gov.it) | regole italiane | **rosso** (verifica anti-robot) | lettura a mano |
| **Australia, Dipartimento dell'agricoltura** | regole australiane | **rosso** (non verificata) | lettura a mano |
| **ECDC** | malattie con vettori | **verde** (controllo del 15/11/2026, catalogo 15) | da riverificare per ogni pagina |
| **WSAVA** 2024 | vaccini non essenziali secondo la zona | **giallo** (già controllata) | come nel catalogo; la Normativa non la considera «ufficiale» per le malattie presenti |
| **CDC** (USA) | rabbia, importazione di cani negli USA | **rosso per blocco tecnico** (catalogo 15): non è un divieto; dopo il controllo a mano di termini e robots.txt in un browser passa a verde o giallo (pubblico dominio, come APHIS) | lettura a mano finché il controllo non è fatto |
| CFIA (Canada), MPI (Nuova Zelanda), MAFF (Giappone), EFSA, autorità dei singoli paesi | | **non verificate**: rosso finché la Normativa non le controlla | ogni nuova fonte: **dico l'ente alla Normativa e lei controlla la licenza prima di qualunque lettura automatica** |

Cosa significa in pratica:

- **Automatico**: la pagina della Commissione (UE) e GOV.UK. Con queste due si costruiscono le basi UE e Regno Unito.
- **A mano** (una persona apre la pagina e scrive i fatti con parole sue, io controllo solo la struttura): gli atti su EUR-Lex (per i punti precisi e le eccezioni), salute.gov.it, Australia, e ogni altro paese.
- **Permessi scritti**: WOAH (bozza nel parere 13, A.5); altri se serve.
- **Dove non c'è una fonte consentita**, il blocco resta vuoto e lo diciamo.

Ogni fonte va registrata in `fonti.json` (licenza, esito del controllo, data, come è stata letta), con i campi già ammessi dallo script (tipo `norma` per gli atti) e **due campi nuovi** chiesti dalla Normativa (A.11): `motivo_semaforo` (`licenza_aperta`, `nessuna_riserva_trovata`, `riserva_presente`, `blocco_tecnico`, `non_verificata`) e `controllo_a_mano_il` (data; vuoto se non fatto). Un rosso per blocco tecnico o non verificata vuol dire «lettura a mano finché una persona non controlla termini e robots.txt in un browser»; fatto il controllo la fonte passa a verde o giallo, con la data. Lo script di controllo li verifica.

**Regole sui testi dei regolamenti UE** (Normativa A.11): si può citare un passo con numero di articolo e fonte, senza alterarne il senso, ma solo la Gazzetta ufficiale è autentica (la riga di fonte lo dice); i regolamenti 576/2013 e 577/2013 sono transitori e non si riproducono come regola di oggi; **gli elenchi** negli allegati (paesi, gruppi di origine) hanno effetto di legge e non si copiano: si cita l'allegato e si scrive la regola.

## 6. Ordine di copertura (proposta)

Non abbiamo dati reali sui viaggi da e verso l'Italia: è una proposta ragionata da correggere con i numeri.

| Ondata | Cosa | Fonti |
|---|---|---|
| 0 | `VIA-UE-<specie>` (cane, gatto, furetto): regole comuni UE, tenia, passaporto, rientro in Italia | pagina della Commissione (auto) + atti su EUR-Lex (a mano per i punti esatti) |
| 1 | **Regno Unito** (GB e Irlanda del Nord) | GOV.UK (auto) |
| 2 | Paesi UE con regole in più (per la tenia: Finlandia, Irlanda, Malta, Norvegia e Irlanda del Nord secondo la Commissione) e i più frequenti: Germania, Francia, Spagna, Austria, Grecia, Croazia: norme locali (guinzaglio, museruola, razze) | autorità nazionali (da controllare una per una; a mano) |
| 3 | Paesi vicini con molti rientri: Svizzera, Albania, Romania, Turchia, Marocco, Tunisia | a mano |
| 4 | USA, Canada, Giappone, Australia e Nuova Zelanda, Emirati, Brasile | APHIS (giallo), altre a mano o con permesso |

Cane, gatto, furetto per tutte le ondate. Quanto va veloce dipende dalla lettura a mano dall'ondata 2 in poi.

## 7. Come si aggiornano le schede (invecchiano)

1. **Scadenza** (la Normativa suggerisce, decido io: la adotto): **dopo 90 giorni** dal controllo la scheda mostra «Potrebbe essere cambiata: controlla la fonte»; **dopo 180 giorni** il contenuto si nasconde finché non è ricontrollato e resta il collegamento alla fonte. `scadenza` = controllo + 90 giorni (le schede salute sono a 12 mesi).
2. **Registro di chi ha verificato e quando** (campo `revisione` della scheda: chi, data, cosa ha riletto): dimostra la diligenza. Nessuna scheda pubblicata senza lettura umana della fonte e approvazione; le segnalazioni su quarantene, respingimenti e vaccini si correggono per prime. **Responsabile della manutenzione**: da nominare (§9). Promemoria con l'elenco delle schede in scadenza (lo script `check_manuale.py` esteso, elenco «scadono entro 30 giorni»).
3. **Controllo dei cambi**: solo su fonti verdi, solo metadati (data di ultima modifica, `Last-Modified`/`ETag`), richieste rare e con il nostro nome; se cambia, la scheda diventa «da ricontrollare». **Non si riscrive da sola.** Per EUR-Lex e le altre fonti rosse c'è solo il promemoria per la rilettura a mano.
4. **Segnala un errore** su ogni scheda; se una regola cambia si corregge e si annota la data. Eventi (nuovo regolamento, focolaio): scheda subito «da ricontrollare».
5. **Misura dei vuoti**: solo in v2 e solo con consenso agli analytics (conteggio anonimo delle coppie cercate senza scheda).

## 8. Cosa costruirò nella fase 2 (dopo il tuo sì)

- **Prima di tutto**: i controlli della Normativa sono già fatti (A.3). Io posso scrivere la **struttura** delle schede UE e Regno Unito leggendo in automatico la pagina della Commissione (verde) e GOV.UK (verde). Ma **nessun numero** (giorni, settimane, ore) né nessuna eccezione si approva finché una persona non l'ha letto a mano nell'atto in vigore su EUR-Lex: quelle voci restano «da verificare a mano» nella bozza.
- **Fonti**: `fonti.json` con `motivo_semaforo` e `controllo_a_mano_il` (e lo script che li controlla).
- **Dati e controllo**: `data/manuale/viaggi/`; `scripts/manuale/check_manuale.py` esteso (blocchi di viaggio, `origine`, scadenza a 90 giorni, nessun nome di prodotto né dose, `--approvazione` per «schede viaggio da approvare» come il doc 16); registro fonti in `fonti.json`. Le schede di viaggio **non** finiscono in `health_cards.json`: export separato `travel_cards.json`.
- **Backend**: `TravelGuideService` e **una sola rotta senza parametri** `GET /travel/cards` (login richiesto): restituisce **tutte** le schede approvate (per scelta del 16/11: così la coppia di paesi non compare mai negli indirizzi né nei registri del server; la scelta e il filtro per origine e specie si fanno sul telefono, con copia locale; la scadenza 90/180 giorni si applica sul telefono e sul server). Le bozze solo con un'impostazione di sviluppo. Test: solo approvate, scadenza, nessuna dose o parola vietata o prodotto, rotta senza login rifiutata, nessun parametro di viaggio accettato. Test Flutter: scelta per paese, origine UE/fuori UE, scheda mancante, scheda generica per altre specie, scheda vecchia (90) e nascosta (180). **Nessuna tabella, nessun permesso Android, nessun nuovo fornitore.**
- **App**: `features/travel_guide/` (pagina con tre campi, ricerca paese, scelta animali, risultato, scheda generica e «nessuna scheda»), una riga nel menu `activities_page.dart`. Testi in italiano nell'ARB (le avvertenze della Normativa tali e quali); chiavi nuove segnalate a «Revisione traduzioni EN ES DE FR».
- **Schede**: ondata 0 e 1 in stato `bozza`, con la data di verifica; quando sono pronte ti do il percorso per il Gestore Social.
- **Controlli prima di unire a main**: pytest, ruff, mypy, `flutter analyze`, test Flutter, `check_manuale.py`, `check_i18n`.

## 9. Decisioni che servono da te

1. **Chi legge a mano** gli atti su EUR-Lex (e salute.gov.it, Australia, altri paesi): tu, o chi indichi? Una persona apre la pagina e scrive i fatti con parole sue nel file della scheda (io controllo solo la struttura e non vedo il testo della fonte).
2. **Ordine** delle ondate (§6): lo confermi o lo cambi? Hai idea dei paesi più richiesti?
3. **Responsabile della manutenzione** delle schede (scadenza a 90 giorni): chi?
4. **Richieste di permesso** (WOAH, autorità e ministeri): le bozze sono pronte (Normativa A.13); partono solo se servono e dopo l'approvazione della fase 2; il nome e la firma li metti tu fuori dal repository. Le vuoi inviare?

Già deciso (da te o dalla Normativa, non più da chiedere): perimetro (cane, gatto, furetto, non commerciale); cultura locale solo con fonte ufficiale; farmaci senza prodotti né dosi; nessun viaggio salvato; **riga del menu nascosta finché non c'è almeno una scheda approvata** (consiglio condiviso con la Normativa; se vuoi diversamente dimmelo); nome «Around the world» in inglese in tutte le lingue (nome proprio, nessun problema legale); **nessun calcolatore di date nella v1** (serve un parere a parte).

## 10. Per la Normativa

Ho preso i suoi testi A-I (A.12) così come sono e ho seguito le sue risposte (A.11) e le sue note sulla privacy (A.14: schede scaricate e filtrate sul telefono). Restano a lei: il controllo di ogni nuova fonte prima della lettura automatica (le dico l'ente), il controllo a mano di CDC e APHIS e la registrazione con la data, e la clausola in it/03 §10 quando la sezione esiste nel codice.

## 11. Cosa non so ancora

- Il testo esatto del Reg. delegato (UE) 2026/131 e le sue eccezioni: nessun dettaglio è stato letto da me; i numeri (12 settimane, 21 giorni, 24-120 ore) nell'esempio A.9 della Normativa **non sono verificati** e non si usano finché non sono letti a mano.
- Quali paesi hanno regole proprie in più oltre a quelli citati dalla Commissione.
- Se la pagina di GOV.UK sui viaggi con animali è sotto licenza OGL (va controllata pagina per pagina).

# 18 - "Around the world": viaggiare e spostarsi con un animale

Data: 2026-11-16. Fase 1 (progetto, nessun codice). Richiesta del proprietario, girata dall'Orchestratore. **Bozza da approvare**: la fase 2 (costruzione) parte solo dopo il suo sì. Il nome resta «Around the world», come l'ha scritto lui.

Riusa, senza inventare niente di nuovo dove non serve: lo schema delle schede salute (`data/manuale/`, `scripts/manuale/check_manuale.py`), il catalogo delle fonti (`docs/product/15_catalogo_fonti_approvate.md`) e il semaforo della Normativa (§5.1 di quel documento).

## 0. In breve (per il proprietario)

- **Cos'è**: una funzione dentro «Attività». Scrivi «da dove parti» e «dove vai», scegli «chi porti con te» e ottieni una scheda che spiega cosa chiedono le regole ufficiali, in che ordine e con che tempi, quali malattie e protezioni contano, e come si rientra.
- **Cosa NON è**: non invita a spostare animali. Informa chi ha già deciso di farlo e, con una frase fissa in alto, ricorda che spostarsi non è sempre la scelta migliore per l'animale (§3).
- **Fonti**: solo ufficiali di livello 1, con il semaforo. **Verità scomoda** (§5): molte delle fonti che hai indicato (WOAH, CDC, USDA APHIS, Ministero della Salute) oggi sono **rosse** nel nostro catalogo, cioè bloccano i programmi: non le posso leggere in automatico e non si incolla il loro testo in un modello. Quindi la copertura dei paesi avanzerà **al ritmo della lettura a mano**, tranne UE e Regno Unito (fonti verdi o da controllare) che si possono leggere in automatico. Per questo l'ordine di copertura (§6) parte da lì.
- **Schede in «bozza»** finché non le approvi tu, come le schede salute. Fino ad allora in produzione non si vedono.
- **Nessuna tabella nuova** nel database, nessun permesso Android nuovo, nessun dato personale verso l'esterno: le schede sono contenuto generale, uguale per tutti.
- **Decisioni che servono da te**: §9.

## 1. La schermata (dentro «Attività»)

Nuova riga in `activities_page.dart`: «Around the world» (sottotitolo: «Regole, vaccini e protezioni per spostarti con un animale»). Apre una pagina con tre campi e un pulsante.

```
Around the world
[ riquadro fisso: «Spostare un animale è una scelta importante per lui. Qui trovi
  cosa dicono le regole ufficiali, se hai già deciso. Non ti consigliamo di partire
  né di portarlo con te.» ]

Da dove parti      [ cerca un paese…      ]   (predefinito: il paese della Località, se impostata)
Dove vai           [ cerca un paese…      ]
Chi porti con te   [ Luna (cane) ] [ Micio (gatto) ] [ + una specie: cane / gatto / furetto … ]
Quando parti       [ data, facoltativa ]   (solo per avvisare se la scheda è scaduta o se i tempi sono stretti, v2)

                        [ Mostra le informazioni ]
```

- **Cerca paese**: barra di ricerca con suggerimenti (nome in italiano, anche senza accenti; sinonimi tipo «USA», «Regno Unito»). Lista dei paesi con codice ISO in un file dati dell'app (non nell'ARB).
- **Chi porti con te**: due modi. (a) Tra i **propri animali** dell'app: leggo solo la specie e la data di nascita **sul telefono** (serve a dire «è troppo piccolo per la vaccinazione antirabbica»); l'identità dell'animale non va mai al server. (b) Per **specie**, senza animale registrato (anche chi non ha ancora inserito il suo animale, o ne porta uno di altri). Si può scegliere più di un animale: la pagina mostra una sezione per ognuno.
- **Risultato**, in ordine cronologico, con i blocchi della §2. Ogni blocco mostra la **fonte e la data di verifica**; in fondo il rimando alla fonte ufficiale e l'invito a controllarla prima di partire.
- **Se non abbiamo la scheda** per quella coppia di paesi o specie: lo diciamo senza fingere («non abbiamo ancora questa scheda») e mostriamo la **via ufficiale**: l'autorità veterinaria del paese di destinazione (solo un collegamento a un sito ufficiale), il Servizio veterinario della ASL per l'Italia, e la frase «le regole ufficiali prevalgono».
- Disclaimers e «come funziona»: livelli della Normativa (`docs/compliance/11`): riquadro nella prima schermata, pagina «Come funziona» (Info), sezione dei Termini. Testi scritti dalla sessione MARKETING e NORMATIVA (§8).

## 2. La scheda: paese × specie

### 2.1 Cosa serve davvero per comporre una risposta

Le regole non dipendono da un paese solo, ma da tre cose: **dove si va**, **da dove si parte** (l'Italia verso la Germania non è come l'Albania verso l'Italia: contano i «gruppi di origine» del Reg. UE 576/2013: UE, paesi terzi elencati, paesi terzi non elencati) e **quale specie**. Per non moltiplicare le schede in modo ingestibile:

| Pezzo | Dipende da | Dove sta |
|---|---|---|
| **Scheda destinazione** (entrata nel paese, comportamenti e norme, rientro) | paese di destinazione × specie; le frasi che cambiano con l'origine portano l'etichetta `origine` | `data/manuale/viaggi/VIA-<ISO2>-<SPE>.json` |
| **Scheda salute del posto** (malattie presenti, vaccini consigliati, antiparassitari e protezioni) | paese o regione × specie (non dipende da dove si parte) | stesso file, blocchi propri |
| **Scheda rientro UE/Italia** (come si torna a casa) | gruppo di origine × specie (valida per tutti i paesi di quel gruppo) | `data/manuale/viaggi/VIA-UE-<SPE>.json` |
| **Elenco gruppi** (paese → UE / terzo elencato / terzo non elencato) | testo dei regolamenti (atto ufficiale, riuso libero ⚖️) | `data/manuale/viaggi/gruppi_origine.json` |

L'app unisce i pezzi in base alla coppia scelta. Un paese di destinazione con regole proprie in più (esempio da verificare: trattamento contro il verme *Echinococcus* per alcuni paesi, titolo anticorpale, quarantena) le ha nella sua scheda.

### 2.2 Blocchi (stesso schema delle schede salute, più i blocchi di viaggio)

Lo schema resta quello delle schede salute: `codice`, `specie`, `titolo`, `stato`, `ultimo_controllo`, `scadenza`, `revisione`, `parole_chiave`, `riassunto_per_chat`, `blocchi` → `frasi` → `testo` + `fonti` (`id` e `punto` esatto) + `nostro` (consiglio nostro, al massimo 3). Ogni frase ha la sua fonte; senza fonte non si scrive (come per le schede salute). Cambiano solo tre cose:

1. **blocchi in più** (oggi `check_manuale.py` ne ammette 6 fissi; si aggiungono quelli di viaggio, vedi sotto);
2. un campo facoltativo `origine` sulla frase (elenco di gruppi a cui si applica; vuoto = tutti);
3. un campo facoltativo `tempi` sulla frase, con la regola in forma leggibile da una macchina (per esempio `{"minimo_giorni_dopo_vaccino": 21}`), usato **solo** in v2 per il calendario; in v1 il testo basta.

| Blocco | Cosa contiene | Fonte tipica |
|---|---|---|
| `documenti` | passaporto o certificato sanitario, chi lo rilascia, per quanto vale, dichiarazione del proprietario, permessi di importazione, limite di animali per viaggio senza fini commerciali, **quando le regole sono quelle del commercio e non del viaggio** (adozione o spostamento di più animali, vedi §3) | Reg. UE 576/2013 e atti collegati; autorità del paese |
| `microchip` | tipo di microchip richiesto, **va impiantato prima** della vaccinazione antirabbica | Reg. UE; autorità del paese |
| `vaccini_obbligatori` | quali, a che età minima, **con quali tempi** (giorni di attesa, validità, richiami), per specie | Reg. UE; autorità del paese; DEFRA/APHA |
| `test_sierologici` | titolo anticorpale antirabbico: quando va fatto, quanto si aspetta dopo, in quali laboratori | Reg. UE; autorità del paese |
| `vaccini_consigliati` | facoltativi o consigliati in base a dove si va e come (cuccioli, zone con leishmaniosi, cinofilo da lavoro…) | WSAVA 2024 (giallo, già controllata) e fonti ufficiali del posto |
| `malattie_presenti` | malattie che riguardano il viaggio dell'animale (rabbia, leishmaniosi, filariosi, babesiosi, ehrlichiosi, *Echinococcus*, ecc.) | WOAH, ECDC, autorità del posto |
| `farmaci_e_protezioni` | **categorie**, non dosi né nomi commerciali: antiparassitario contro zecche e pulci, prevenzione della filariosi, trattamento antiparassitario **imposto per legge** con la finestra di giorni; cosa portare in valigia e cosa chiedere al veterinario | norme; fonti verdi o gialle (§5) |
| `comportamenti_e_norme` | regole in vigore: guinzaglio, museruola, razze con restrizioni, mezzi pubblici, spiagge, locali, registrazione locale, tasse | leggi e siti ufficiali |
| `rientro` | cosa serve per tornare: per l'UE il rinvio alla scheda `VIA-UE-<SPE>`, più i documenti di uscita del paese | Reg. UE; autorità del paese |
| `non_diffondere` | come non portare malattie e non riportarne: controllo di zecche e parassiti, trattamenti, cosa NON fare (portare cibo animale, lasciare animali in giro), rabbia | ECDC, WSAVA, fonti ufficiali |
| `quando_andare_dal_veterinario` | quando parlare con il veterinario **prima** di partire (sempre) e cosa chiedergli; i segni da osservare al ritorno | nostro o fonte |
| `limiti` | cosa la scheda non copre, e il rimando alla fonte ufficiale | – |

**Cultura locale.** Il proprietario ha scritto «comportamenti da seguire per cultura di dove si va». Una **consuetudine** (come viene vista la presenza dei cani, cosa è considerato maleducato) quasi mai ha una fonte ufficiale di livello 1: le guide turistiche e i blog sono escluse. Proposta: nei blocchi `comportamenti_e_norme` scriviamo **solo ciò che una norma o un sito ufficiale dice** (obblighi, divieti, razze, mezzi, registrazione). Dove non c'è una fonte ufficiale, **lo diciamo** nel blocco `limiti` («le abitudini locali non sono coperte»). Decisione tua, §9.

### 2.3 Esempio di frase (formato reale, contenuto inventato solo per mostrare i campi)

```json
{
  "testo": "…",
  "origine": ["terzo_non_elencato"],
  "fonti": [{"id": "reg_ue_576_2013", "punto": "art. 10 e allegato…"}]
}
```

I contenuti veri si scrivono solo dopo aver letto la fonte, mai a memoria.

## 3. Il messaggio: informare senza incoraggiare

Regole di tono, valide per tutta la funzione (testi in italiano nell'ARB, da far rivedere alla Normativa):

1. **Riquadro fisso in cima** (§1): spostare un animale non è sempre la scelta migliore per lui; qui ci sono le regole ufficiali per chi ha già deciso; non invitiamo a partire né a importare animali.
2. **Mai verbi di spinta**: niente «parti con lui», «portalo con te», «l'avventura»; niente foto promozionali di animali in viaggio; il nome è un titolo, non uno slogan.
3. **Prima domanda sempre «parlane con il tuo veterinario»** (età, salute, razza, durata, temperature). Le valutazioni sul benessere sono consigli nostri (massimo 3 per scheda) o frasi di fonte.
4. **Il diverso è nominato**: se la persona sta cercando di far arrivare in Italia un animale da un altro paese (adozione, salvataggio, acquisto, più di un animale), la scheda `documenti` dice che **non è un «viaggio con l'animale da compagnia» ma uno spostamento con altre regole** (commerciali o di adozione) e rimanda all'autorità veterinaria. Non spieghiamo come aggirare niente né come farlo in modo più comodo.
5. **«Si può essere vettori»**: il blocco `non_diffondere` dice, con fonti, che un animale può portare con sé parassiti e agenti di malattie in zone dove non ci sono, e come ridurre il rischio (trattamenti previsti dalla legge, controllo al rientro, non lasciare animali sul posto).
6. Tre livelli di avviso (Normativa): riquadro, pagina Info, Termini. Frase finale su ogni scheda: «Le regole cambiano. Prima di partire controlla la fonte ufficiale e parlane con il Servizio veterinario della tua ASL e con la compagnia di viaggio».

## 4. Cosa NON facciamo

- Non diamo **dosi** né nomi commerciali di farmaci (le schede non ne hanno, regola già nello script).
- Non copiamo testi, tabelle o elenchi interi delle fonti (solo i fatti con parole nostre; la lista dei gruppi di origine viene dall'atto ufficiale e va chiarita con la Normativa §5, ⚖️).
- Non copriamo: regole delle compagnie aeree, delle navi, dei treni (sono private, non livello 1: avviso e rimando); salute delle persone in viaggio; specie esotiche protette (CITES) finché non sono ammesse tra le specie.
- Non salviamo i viaggi dell'utente sul server né li inviamo a un fornitore: la ricerca è una richiesta di una scheda pubblica, senza id dell'animale; nei log niente paesi legati all'utente.

## 5. Le fonti (livello 1) e il semaforo

Regola della Normativa (`docs/product/15` §5.1): **verde** = lettura automatica, un documento alla volta; **giallo** = prima i 4 controlli (robots.txt, termini, segnali per macchine, avviso nel PDF) e la registrazione, poi un documento alla volta; **rosso** = solo a mano da una persona o con permesso scritto; **mai** il testo di una fonte incollato in un modello. Ogni scheda riporta fonte e data di verifica; nel catalogo ogni fonte ha `semaforo`, `riserva_estrazione_automatica` e `lettura_eseguita`.

| Fonte | Per cosa | Semaforo oggi |
|---|---|---|
| Reg. (UE) 576/2013 e Reg. di esecuzione (UE) 577/2013, atti collegati (EUR-Lex) | documenti, microchip, vaccino antirabbico, tempi, gruppi di origine | **da controllare** (mai fatto il controllo in 4 punti; atto ufficiale, riuso da chiarire con la Normativa ⚖️) |
| EUR-Lex, testo consolidato | aggiornamenti, data dell'ultima versione | come sopra |
| commission.europa.eu, ecdc.europa.eu | pagine della Commissione e malattie con vettori | **verde** (CC BY 4.0, già controllati) |
| DEFRA / APHA, gov.uk (Regno Unito) | regole di entrata in Gran Bretagna e Irlanda del Nord, rischi | **verde** (Open Government Licence v3.0) |
| WSAVA, linee guida vaccini 2024 | vaccini essenziali e non essenziali, per zona | **giallo** (controllato 2026-11-10) |
| Autorità veterinarie e ministeri dei paesi di destinazione | regole di entrata, razze, norme locali | **da controllare uno per uno**; fino ad allora si tratta come rosso |
| Ministero della Salute (Italia), IZS, ISS | regole italiane, malattie in Italia | **rosso** (verifica anti-robot, blocco); solo a mano |
| WOAH (WAHIS) | malattie presenti per paese | **rosso** (controllo impossibile) |
| CDC (USA), USDA APHIS | regole USA, rabbia | **rosso** (controllo impossibile) |
| canada.ca | regole del Canada | **rosso** |
| CITES (cites.org) | specie protette, solo per esotici | non controllato, rimandato |

Conseguenza pratica, onesta:

- Quello che si può leggere **in automatico** oggi: UE (dopo i 4 controlli su EUR-Lex), Regno Unito, WSAVA, ECDC. Con questo si costruisce **tutta la parte europea** e quella britannica.
- Per USA, Canada, WOAH e quasi tutti gli altri paesi la strada è **la lettura a mano**: una persona (tu, o chi indichi) apre la pagina ufficiale e **scrive lei i fatti con parole sue** nel file della scheda, indicando indirizzo e punto; io controllo la struttura (campi, tempi coerenti, parole vietate) ma **non vedo il testo della fonte**. Più lento, e il secondo controllo indipendente lo fa una persona.
- In parallelo, **tre richieste scritte di permesso** (WOAH, CDC/USDA, ministeri chiave) con le bozze della Normativa (`compliance/13` A.5): se arrivano, la fonte passa a verde. Domanda alla Normativa: CDC e APHIS sono enti federali USA (opere dell'amministrazione federale: normalmente senza copyright negli USA); il nostro «rosso» è nato dal **blocco tecnico**, non dalla licenza. Il blocco tecnico resta e non si aggira, quindi cambia poco in pratica, ma va registrato bene (⚖️).
- **Dove una fonte ufficiale consentita non c'è, il blocco resta vuoto e lo diciamo** (come per la scheda del vomito del cane: tolta). Esempio probabile: «malattie presenti» per tanti paesi.

Nuove fonti da registrare in `fonti.json` (campi già esistenti: `ente_autori`, `titolo`, `anno`, `url`, `url_letto`, `diritti`, `semaforo`, `controllata_il`, `come_aperta`). Per i regolamenti il tipo è `norma`. I campi sono già tutti ammessi dallo script.

## 6. Ordine di copertura (proposta)

Non ho i dati reali sui viaggi da e verso l'Italia: l'elenco è una **proposta ragionata**, da correggere con i numeri che avrai dal lancio (§7, schede richieste e non trovate).

| Ondata | Cosa | Perché | Fonti |
|---|---|---|---|
| 0 | `VIA-UE-<specie>` (cane, gatto, furetto): regole comuni UE, rientro, gruppi di origine; `gruppi_origine.json` | base di tutto, fonte verde/da controllare | Reg. UE 576/2013 e collegati |
| 1 | **Regno Unito** (GB e Irlanda del Nord), **Svizzera**, **Norvegia** | regole proprie e molti viaggi; fonte verde per UK | gov.uk, autorità svizzere e norvegesi (da controllare) |
| 2 | **Paesi UE con regole in più** (esempio da verificare: Finlandia, Irlanda, Malta) e i più frequenti: **Germania, Francia, Spagna, Austria, Grecia, Croazia** | regole di salute (leishmaniosi, zecche, caldo) e norme locali; stessi atti UE | EUR-Lex, autorità nazionali (da controllare) |
| 3 | **Albania, Romania, Turchia, Marocco, Tunisia** | molti rientri di animali da paesi non UE (anche adozioni): serve la sezione «non è un viaggio» (§3, punto 4) | autorità; Reg. UE; a mano se bloccate |
| 4 | **USA, Canada, Giappone, Australia e Nuova Zelanda, Emirati, Brasile** | mete lontane con regole severe e lunghe | a mano o con permesso |
| 5 | Altre specie: **coniglio e piccoli mammiferi, uccelli, rettili** (solo dopo la scelta delle fonti: cambiano le regole, l'influenza aviaria, CITES) | prima cane, gatto e furetto: sono quelli del Reg. 576/2013 | da stabilire |

Specie: **cane, gatto, furetto** per tutte le ondate fino alla 4. Le altre specie: «non abbiamo ancora la scheda, ecco dove informarti». Quanto ci mette: l'ondata 0 e 1 si fanno in automatico; dalla 3 in poi dipende dalla tua lettura.

## 7. Come si aggiornano le schede (invecchiano)

Le regole di viaggio cambiano più delle schede salute: scadenza **a 6 mesi** per le schede paese (le salute sono a 12), a 12 mesi per `VIA-UE`.

1. **Scadenza visibile**: ogni scheda mostra «Verificata il …». Passata la scadenza la scheda mostra un riquadro («potrebbe non essere aggiornata, controlla la fonte»); **30 giorni dopo la scadenza l'app non mostra più il contenuto** ma solo il rimando alla fonte ufficiale. Più sicuro: una data sbagliata può costare quarantena o rifiuto all'imbarco.
2. **Controllo automatico dei cambi** (solo fonti verdi/gialle): uno script settimanale legge **solo i metadati** (data dell'ultima versione consolidata su EUR-Lex, `Last-Modified`/`ETag`) con richieste rare e firmate col nostro nome; se cambia, la scheda passa a «da ricontrollare» e **non si riscrive da sola**.
3. **Fonti rosse**: promemoria ogni 6 mesi (lista scritta, con la pagina da riaprire) a te o a chi indichi.
4. **Eventi** (focolai, nuove regole, un paese che cambia gruppo): scheda segnata «da ricontrollare» subito.
5. **Segnalazioni** di errori dagli utenti: collegamento «segnala un errore» su ogni scheda; non salviamo dati dell'utente oltre il testo scritto.
6. **Misura dei vuoti** (v2, solo se c'è il consenso agli analytics): conteggio anonimo di quante volte si cerca una coppia senza scheda, senza id utente, per decidere cosa fare dopo.
7. Il `check_manuale.py` esteso segnala già schede scadute; si aggiunge l'elenco «scadono entro 30 giorni».

## 8. Cosa costruirò nella fase 2 (dopo il tuo sì)

- **Dati e controllo**: cartella `data/manuale/viaggi/`, estensione di `scripts/manuale/check_manuale.py` (blocchi di viaggio, `origine`, scadenza a 6 mesi, `--approvazione` per un documento «schede viaggio da approvare» come il 16), registro fonti in `fonti.json`; **le schede di viaggio non finiscono nell'archivio della chat** (`health_cards.json`) per ora: un export separato `travel_cards.json`.
- **Backend**: servizio `TravelGuideService` e rotta `GET /travel/guides?from=IT&to=DE&species=dog` (login richiesto come ogni rotta, nessun dato dell'utente; solo schede `rivista` o `pubblicata`; in bozza solo con un'impostazione di sviluppo). Test: scelta delle schede, gruppo di origine, scheda mancante, scadenza, nessuna dose o parola vietata nei testi, rotta senza login rifiutata. **Nessuna tabella nuova, nessun nuovo fornitore, nessun permesso Android.**
- **App**: `apps/mobile_app/lib/features/travel_guide/` (pagina con i tre campi, ricerca paese, scelta animali, pagina risultato, scheda mancante), una riga nel menu `activities_page.dart`. Testi in italiano nell'ARB: elenco delle chiavi nuove da mandare a «Revisione traduzioni EN ES DE FR». Nomi dei paesi in un file dati in italiano.
- **Schede**: ondata 0 (e 1 se le fonti si aprono) in stato `bozza`, con la data di verifica. Quando sono pronte ti do il percorso per il Gestore Social.
- **Controlli prima di unire a main**: `.venv/Scripts/python.exe -m pytest`, ruff, mypy, `flutter analyze`, test Flutter, `check_manuale.py` e `check_i18n`.

## 9. Decisioni che servono da te

1. **Cultura locale**: va bene scrivere solo ciò che dicono norme e siti ufficiali, e dire «non coperto» per il resto? (§2.2)
2. **Ordine** delle ondate (§6): lo confermi o lo cambi? Hai dati (o un'idea) sui paesi più richiesti?
3. **Fonti rosse**: chi legge a mano? Vuoi che prepari le **richieste di permesso** (WOAH, CDC/USDA, qualche ministero) con la Normativa?
4. **Menu prima delle approvazioni**: finché nessuna scheda è approvata, la riga «Around the world» resta **nascosta** (consiglio) o appare con solo la via ufficiale per ogni paese (autorità e ASL)?
5. **Scadenza** a 6 mesi e contenuto nascosto 30 giorni dopo: ti va bene?
6. **Calendario dei tempi** («ultima data utile per il vaccino») e promemoria nell'app: dopo la prima versione (v2)?
7. **Nome**: «Around the world» resta in inglese in tutte le lingue (senza traduzione)?

## 10. Per la Normativa (disclaimer, ⚖️)

Testi da scrivere o rivedere: riquadro in cima («non incitiamo a spostare animali»), frase finale («le regole ufficiali prevalgono; controlla con la ASL e la compagnia»), avviso «scheda scaduta» e «non coperta», sezione «non è un viaggio» (adozioni e commerciale), esclusione delle compagnie di trasporto, pagina Info e clausola nei Termini. Domande: riuso del testo dei regolamenti UE e dei suoi elenchi (EUR-Lex: avviso di riuso); trattamento di CDC/APHIS (§5); dove ci si ferma sulla «cultura locale»; rischio concreto di un'indicazione sbagliata (quarantena, rifiuto all'imbarco, danno all'animale).

## 11. Cosa non so ancora (verificherò in fase 2)

- Gli estremi esatti degli atti collegati al Reg. 576/2013 e le versioni consolidate oggi in vigore.
- Quali paesi UE hanno regole proprie in più (gli esempi nominati sono da verificare).
- Se i siti delle autorità di ogni paese passano il controllo in 4 punti.
- Quali pagine ufficiali del Regno Unito trattano anche le malattie dell'animale all'estero.

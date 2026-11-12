# Prezzi per paese: studio e proposta

Stato: proposta del 2026-11-06, da approvare. I prezzi di riferimento sono quelli decisi per l'Italia ([02_brief](02_brief_app_per_analisi_pricing.md) §5): mensili Plus 4,59 €, Pro 8,59 €, Ultra 15,59 €; annuali a 10 mensilità (sconto circa 16,6%): 45,99 €, 85,99 €, 155,99 €.

Domanda del proprietario: prezzi diversi in base al paese, più alti dove il potere d'acquisto è maggiore, in proporzione.

## In breve

- **Metodo proposto:** moltiplicatore = radice quadrata del rapporto tra il PIL pro capite a parità di potere d'acquisto (PPA) del paese e quello dell'Italia, con limiti da 0,60 a 1,40. Nei paesi più ricchi sale poco (Germania ×1,09, Stati Uniti ×1,20, Svizzera ×1,27), nei più poveri scende poco (Spagna ×0,95).
- **Perché non proporzionale pieno:** darebbe prezzi poco credibili (Svizzera ×1,61, Stati Uniti ×1,44, Irlanda ×2,26, falsato dalle multinazionali). Che la disponibilità a pagare cresca meno del reddito è un'ipotesi mia, non una misura: va verificata con i primi dati.
- **Il prezzo lo decidono gli store, non l'app.** Per ogni paese si imposta il prezzo in App Store Connect e Google Play Console; l'app mostra il prezzo che le restituisce lo store. Oggi l'app mostra prezzi in euro scritti nel codice (dati di prova): vanno sostituiti quando arriveranno gli abbonamenti reali.
- **Mercati in ordine di arrivo** (`docs/social/05`): Italia, Regno Unito, DACH, Stati Uniti e Australia, poi Spagna e Francia. Con questo metodo solo la Spagna scende, e di poco.

## Come funziona nei negozi 🟡

Dati da verificare nelle console prima di usarli:
- Il prezzo segue il **paese dell'account Apple o Google** dell'utente, non il luogo del download. Cambiare paese di account richiede in genere un metodo di pagamento di quel paese, quindi l'aggirare il prezzo con una VPN è limitato.
- Apple e Google permettono di fissare un prezzo base e lasciare che il resto sia convertito in automatico, oppure di fissare il prezzo di ogni paese. Una fonte secondaria ([AppsOps](https://appsops.store/blog/ios-pricing-western-europe-2026)) scrive che in zona euro esiste un solo livello per tutti i negozi e che Germania e Spagna non si possono distinguere: da controllare in App Store Connect, perché cambierebbe la proposta per la Spagna.
- In UE, Regno Unito, Svizzera e Australia il prezzo mostrato include IVA o GST; negli Stati Uniti di norma no (imposta aggiunta al pagamento). Le fonti lette non lo confermano.

## Dati usati

- **Reddito:** PIL pro capite a PPA, stima FMI per il 2026 ([Wikipedia, elenco dei paesi](https://en.wikipedia.org/wiki/List_of_countries_by_GDP_(PPP)_per_capita)). Fonte secondaria: i valori vanno ricontrollati sul sito dell'FMI.
- **Livello dei prezzi (Eurostat):** non sono riuscito a leggere la tabella, quindi non è usato. Dai risultati di ricerca risulta solo che Paesi Bassi, Austria e Belgio sono circa il 18–20% sopra la media UE.
- **Costo IA:** circa 0,0035 € a domanda nel caso prudente (stima della sessione chat × 4), uguale in tutto il mondo.

## Moltiplicatori

| Paese | PIL pro capite PPA ($) | Rapporto con l'Italia | Puro proporzionale | Proposto (radice, limiti 0,60–1,40) |
|---|---|---|---|---|
| Italia | 66.221 | 1,00 | 1,00 | 1,00 |
| Spagna | 60.106 | 0,91 | 0,91 | 0,95 |
| Portogallo | 52.980 | 0,80 | 0,80 | 0,89 |
| Polonia | 60.051 | 0,91 | 0,91 | 0,95 |
| Grecia | 47.365 | 0,72 | 0,72 | 0,85 |
| Francia | 68.852 | 1,04 | 1,04 | 1,02 |
| Regno Unito | 68.476 | 1,03 | 1,03 | 1,02 |
| Canada | 70.374 | 1,06 | 1,06 | 1,03 |
| Australia | 75.039 | 1,13 | 1,13 | 1,06 |
| Germania | 78.664 | 1,19 | 1,19 | 1,09 |
| Austria | 78.828 | 1,19 | 1,19 | 1,09 |
| Belgio | 78.906 | 1,19 | 1,19 | 1,09 |
| Irlanda | 149.642 | 2,26 | 2,26 | 1,09 (come la Germania) |
| Paesi Bassi | 88.202 | 1,33 | 1,33 | 1,15 |
| Stati Uniti | 95.212 | 1,44 | 1,44 | 1,20 |
| Svizzera | 106.944 | 1,61 | 1,61 | 1,27 |
| Turchia | 46.679 | 0,70 | 0,70 | 0,84 |
| Messico | 26.743 | 0,40 | 0,40 | 0,64 |
| Brasile | 24.594 | 0,37 | 0,37 | 0,61 |
| India | 12.998 | 0,20 | 0,20 | 0,60 (limite) |

L'Irlanda è trattata come la Germania perché il suo PIL è gonfiato dai profitti delle multinazionali e non rappresenta il reddito delle famiglie.

## Prezzi consigliati nei mercati di lancio

Mensile / annuale, in euro. Per le altre valute si fissa un prezzo vicino all'equivalente al cambio del giorno. Le differenze sotto il 2% (Francia, Regno Unito) sono effetto dell'arrotondamento.

| Paese | Moltiplicatore | Plus | Pro | Ultra |
|---|---|---|---|---|
| Italia | 1,00 | 4,59 / 45,99 | 8,59 / 85,99 | 15,59 / 155,99 |
| Spagna | 0,95 | 4,39 / 43,99 | 8,19 / 81,99 | 14,89 / 148,99 |
| Francia | 1,02 | 4,69 / 46,99 | 8,79 / 87,99 | 15,89 / 158,99 |
| Regno Unito | 1,02 | 4,69 / 46,99 | 8,69 / 86,99 | 15,89 / 158,99 |
| Germania, Austria | 1,09 | 4,99 / 49,99 | 9,39 / 93,99 | 16,99 / 169,99 |
| Australia | 1,06 | 4,89 / 48,99 | 9,09 / 90,99 | 16,59 / 165,99 |
| Stati Uniti | 1,20 | 5,49 / 54,99 | 10,29 / 102,99 | 18,69 / 186,99 |
| Svizzera | 1,27 | 5,79 / 57,99 | 10,89 / 108,99 | 19,79 / 197,99 |

Regole di arrotondamento: il mensile finisce in ,x9; l'annuale è il valore intero più vicino sopra le 10 mensilità meno 0,01 €, quindi lo sconto resta entro il 16,67% in ogni paese.

## Margine

I margini per piano, con il costo misurato per domanda e i costi fissi, sono nel [business plan](04_business_plan_costi_margini.md) e cambiano con i limiti (domande al giorno 9/16/30 dall'8 novembre). Questa sezione usava una stima prudenziale di 0,0035 € a domanda su limiti precedenti: non va più letta come margine.

Regola che resta valida: il costo dell'IA è uguale in ogni paese, quindi un prezzo scontato riduce il margine di quel paese in proporzione. Prima di scontare, controllare il moltiplicatore contro il margine del business plan nel caso peggiore (limite pieno ogni giorno); per i mercati molto più poveri (Brasile, India, Messico) servirebbe un minimo più alto o limiti più bassi.

## Cosa dicono le fonti

- **Nessuna fonte letta dà moltiplicatori per paese.** Gli esempi sono aneddoti di singole app: [RevenueCat](https://www.revenuecat.com/blog/growth/5-quick-fixes-for-bad-default-global-pricing-on-app-stores) cita un'app di meditazione che ha raddoppiato gli abbonamenti in America Latina in 14 giorni e un'app di benessere con +38% di conversioni nel Sud-est asiatico dopo aver adattato i prezzi. Sono casi di prezzi abbassati in mercati poveri, non alzati in quelli ricchi, e vengono da un fornitore di strumenti.
- **Gli indici di Adapty** (rapporto di ricerca 2026, letto solo nel riassunto del motore di ricerca): India 0,6× e Turchia 0,7× rispetto al prezzo statunitense; i grandi mercati europei circa 1,2× in cifra nominale. Dice cosa fanno gli sviluppatori, non cosa converte meglio. La mia proposta ha lo stesso orientamento per i paesi poveri e un orientamento opposto per l'Europa rispetto agli Stati Uniti.
- **Fasce di prezzo per app di produttività e fitness** ([AppsOps](https://appsops.store/blog/ios-pricing-western-europe-2026), fonte secondaria che vende uno strumento di prezzi): mensile 7,99–11,99 € in Germania, 6,99–9,99 € in Francia, 5,99–7,99 € in Spagna, 6,99–9,99 £ nel Regno Unito. I nostri prezzi sono più bassi; non è la stessa categoria, ma c'è spazio per provare prezzi più alti dopo i primi dati.

## Rischi e punti da verificare

1. ⚖️ **Parere legale** (sessione MARKETING e NORMATIVA): regole europee contro la discriminazione geografica (regolamento 2018/302) e sulla trasparenza dei prezzi; lo sconto annuale dichiarato ("2 mesi gratis") deve essere esatto in ogni paese. Non ho verificato fonti giuridiche.
2. **Stesso livello nelle due piattaforme** da evitare (indicazione di RevenueCat): fissare i prezzi separatamente in App Store e Play, perché i punti prezzo non coincidono.
3. **Cambi.** Rivedere i prezzi in valuta estera ogni trimestre; una fonte suggerisce di intervenire se lo scarto supera il 10%.
4. **Modifiche ai prezzi.** Chi è già abbonato può dover accettare un aumento negli store; decidere in anticipo se mantenere il prezzo di chi è già dentro (grandfathering).
5. **Recensioni.** Un importo addebitato diverso da quello mostrato è la causa tipica di recensioni a una stella: l'app deve mostrare il prezzo restituito dallo store, mai uno suo.
6. **Irlanda.** Il PIL pro capite non è un buon indicatore del reddito; servirebbe un dato alternativo (reddito nazionale lordo).

## Decisioni per il proprietario

1. Metodo: radice quadrata con limiti 0,60–1,40 (proposto) oppure proporzionale puro (con tetto per Svizzera, Stati Uniti e Irlanda).
2. Mercati da configurare al lancio: solo Italia, oppure anche Regno Unito, Germania e Austria con i valori sopra.
3. Chi chiede il parere legale sul punto 1 dei rischi.

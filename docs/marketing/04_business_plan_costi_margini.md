# Business plan: costi e margini di Quokka

Stato: proposta dell'8 novembre 2026, da approvare. Nessuna modifica al codice: le decide il proprietario e le applica la sessione Pricing.

Obiettivi fissati dal proprietario:
1. **Tetto di spesa per l'IA** tra il 4% e il 6% del fatturato dei soli clienti paganti, con un minimo di 1 € al giorno.
2. **Margine minimo del 60%** sul fatturato, al netto di IVA, commissioni degli store e costi dei servizi (modello, database, hosting, eventuale RevenueCat), con limiti per piano proporzionali al prezzo.

Dati di partenza: [02_brief](02_brief_app_per_analisi_pricing.md), [03_prezzi_per_paese](03_prezzi_per_paese.md), `packages/core/domain/subscription/limits.py`, `packages/shared/config/settings.py` e le misure in `.local/chat_eval/`.

---

## In breve

- **I limiti di oggi non reggono il 60% nel caso peggiore.** Se un abbonato usa ogni giorno tutto quello che il piano consente (12/25/50 domande più 10 letture, 30 dettature e 5 riepiloghi), il margine scende al 31% sul Plus, al 39% sul Pro e al 42% sull'Ultra. Con il costo misurato senza riserva prudenziale arriva al 39, 48 e 52%. Il 53/47/42% calcolato prima considerava solo le domande e non i costi fissi, lo spazio e le altre funzioni.
- **Proposta: domande 6 / 11 / 20 al giorno** (Plus / Pro / Ultra), letture di foto e documenti 2 / 4 / 6, dettature 10 / 20 / 40, riepiloghi 1 / 2 / 3, e un nuovo limite di spazio per i file di 1 / 3 / 6 GB. Così il 60% regge anche nel caso peggiore e i limiti sono proporzionali al prezzo (circa 1 : 1,8 : 3,3).
- **Il tetto del 4–6% può valere solo sul totale, non sul singolo abbonato nel caso peggiore.** Per tenere ogni abbonato sotto il 6% anche quando usa tutto, servirebbero 3 / 6 / 11 domande al giorno, troppo poche per il prodotto. La proposta quindi è questa: il tetto giornaliero protegge la spesa complessiva, mentre i limiti per piano proteggono il margine di ogni abbonato.
- **Tetto proposto:** `tetto del giorno = il più alto tra 1 € e il 6% del fatturato mensile dei paganti diviso 30`. Dal 4% (due terzi del tetto) le prove gratuite e chi usa molto passano prima a Groq. Esempi: 1 € al giorno con 0, 10 e 100 paganti (1,13 € con 100) e 11,28 € con 1000.
- **Nell'uso tipico l'IA pesa circa il 2,8% del fatturato**, sotto la soglia del 4%. Il tetto scatta solo nelle giornate anomale.
- **I costi fissi decidono la partenza.** Supabase Pro, Vercel Pro e Apple insieme costano circa 48 € al mese. Si va in pari con 11 paganti e il 60% si raggiunge con circa 39 paganti (uso tipico).
- **Tre sorprese nel codice di oggi**, da correggere a cura della sessione Pricing:
  1. Il tetto attuale di 4 milioni di token vale circa 0,62 €, non 1 €.
  2. La lettura delle foto passa da Groq gratuito, che regge circa 80 foto al giorno per tutta l'app. A pagamento su Groq costa circa 9 volte quello che costerebbe su Haiku.
  3. Oltre il tetto, Groq gratuito regge circa 214 risposte al giorno in tutto. È una rete di sicurezza sottile.

---

## 1. Definizioni usate

| Termine | Significato in questo documento |
|---|---|
| **Fatturato** | Prezzo pagato dai clienti paganti **senza IVA** (IVA italiana 22%), prima della commissione dello store. Prove gratuite, periodo di test e account sviluppatore non contano. Per l'annuale si conta un dodicesimo al mese |
| **Margine** | (fatturato − commissione store − costi dei servizi) ÷ fatturato. Deve essere almeno il 60% |
| **Costi dei servizi** | IA (Anthropic, Groq), database e file (Supabase), hosting (Vercel), RevenueCat, quote annuali degli store (Apple). **Esclusi**: società, commercialista, tasse sul reddito, marketing, legale, dominio |
| **Caso tipico** | Uso medio ipotizzato (§8): Plus 1 domanda al giorno, Pro 2, Ultra 3, poche letture e dettature |
| **Caso peggiore** | L'abbonato usa **ogni giorno** tutto quello che il piano consente, paga il piano **annuale** (il prezzo mensile più basso) e riempie lo spazio file una volta al mese |

Se il proprietario intende il 60% calcolato su quanto incassiamo dopo la commissione dello store, e non sul prezzo senza IVA, i servizi possono arrivare al 34% invece che al 25%, e i limiti proposti si possono alzare di circa un terzo.

## 2. Prezzi dei fornitori (verificati l'8 novembre 2026)

| Fornitore | Voce | Prezzo | Fonte |
|---|---|---|---|
| Anthropic, Claude Haiku 5.5 (domande fino a 100.000 token) | entrata / uscita / lettura dalla cache | 0,10 $ / 0,50 $ / 0,01 $ per milione di token | [platform.claude.com/docs/en/about-claude/pricing](https://platform.claude.com/docs/en/about-claude/pricing) |
| Groq, gpt-oss-120b / gpt-oss-20b | entrata / uscita | 0,15 / 0,60 $ e 0,075 / 0,30 $ per milione | [console.groq.com/docs/models](https://console.groq.com/docs/models) |
| Groq, qwen3.8-27b (lettura foto, modello "preview") | entrata / uscita; ogni immagine vale 2048 token | 0,80 / 4,00 $ per milione | [console.groq.com/docs/model/qwen/qwen3.8-27b](https://console.groq.com/docs/model/qwen/qwen3.8-27b) |
| Groq, whisper-large-v3-turbo (dettatura) | audio | 0,04 $ all'ora | [console.groq.com/docs/models](https://console.groq.com/docs/models) |
| Groq gratuito | per modello di testo; dettatura | 200.000 token e 1.000 richieste al giorno; 28.800 secondi di audio e 2.000 richieste al giorno | [console.groq.com/docs/rate-limits](https://console.groq.com/docs/rate-limits) 🟡 la pagina ha due schede (gratuito e Developer): da confermare in console |
| Supabase Pro | canone | 25 $ al mese: 8 GB di database, 100 GB di file, 250 GB di traffico in uscita, 100.000 utenti attivi al mese | [supabase.com/pricing](https://supabase.com/pricing) |
| Supabase Pro | oltre le soglie | 0,0213 $ per GB di file, 0,09 $ per GB di traffico, 0,125 $ per GB di database | stessa pagina |
| Supabase Free | limiti | 1 GB di file, 500 MB di database, progetto messo in pausa dopo una settimana senza attività | stessa pagina |
| Vercel Pro | canone | 20 $ al mese per sviluppatore, con 20 $ di consumi inclusi | [vercel.com/pricing](https://vercel.com/pricing) |
| Vercel Hobby | regola | "per uso personale, non commerciale": con abbonamenti a pagamento serve il Pro | stessa pagina |
| RevenueCat | costo | gratis fino a 2.500 $ di ricavi tracciati al mese, poi l'1% (la pagina non chiarisce se sul totale o sulla parte oltre: qui sul totale) | [revenuecat.com/pricing](https://www.revenuecat.com/pricing) |
| Apple | commissione | 15% per chi è iscritto allo Small Business Program (fino a 1 milione di $ l'anno). Senza iscrizione è il 30% nel primo anno di ogni abbonamento | [developer.apple.com/app-store/small-business-program](https://developer.apple.com/app-store/small-business-program/), [/subscriptions](https://developer.apple.com/app-store/subscriptions/) |
| Apple | quota | 99 $ l'anno | [developer.apple.com/programs](https://developer.apple.com/programs/) |
| Google Play | commissione abbonamenti | in UE (dal 30 giugno 2026) 10% + 5% per la fatturazione, cioè 15%. La commissione si calcola sul prezzo senza IVA | [support.google.com/…/112622](https://support.google.com/googleplay/android-developer/answer/112622), [/138000](https://support.google.com/googleplay/android-developer/answer/138000) |
| Google Play | quota | 25 $ una volta sola | [support.google.com/…/6112435](https://support.google.com/googleplay/android-developer/answer/6112435) |
| Cambio | BCE | 1 € = 1,1165 $ (6 novembre 2026) | [ecb.europa.eu](https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/eurofxref-graph-usd.en.html) |

Le pagine di Anthropic non dicono se il ragionamento interno del modello si paga come uscita. Le misure (§3) lo includono comunque, perché vengono dai conteggi reali.

## 3. Costi unitari

| Operazione | Costo | Come è calcolato |
|---|---|---|
| **Una domanda in chat (misurato)** | **0,00134 €** (1,50 $ ogni 1000 risposte) | `haiku-wide.usage.csv`: 251 chiamate reali per 79 risposte (classificatore d'urgenza + parole chiave + risposta), circa 8.700 token per risposta. `haiku-finale` dà 0,00119 €. Se la colonna della cache fosse una scrittura e non una lettura, il costo sale a 0,00158 € |
| **Una domanda in chat (usato nei calcoli)** | **0,002 €** | Misurato + 50% di riserva: conversazioni più lunghe di quelle del test, risposte ripetute, cambio dell'euro |
| Lettura di un PDF (Haiku) | 0,0011 € | Stima: testo tagliato a 12.000 caratteri ≈ 5.000 token in entrata, 900 + 600 in uscita (`document_summarizer.py`) |
| Lettura di una foto su Haiku | 0,0004 € | Stima: circa 2.100 token in entrata e 400 in uscita. 🟡 Da verificare che Haiku 5.5 accetti immagini |
| Lettura di una foto su Groq a pagamento | 0,0033 € | 2048 token per immagine + richiesta, 400 in uscita, ai prezzi di qwen3.8-27b |
| Riepilogo per il veterinario (Haiku) | 0,0015 € | Stima: 7.500 token in entrata, 1.200 + 600 in uscita (`vet_summary.py`) |
| Dettatura di 20 secondi (Groq a pagamento) | 0,0002 € | 0,04 $ all'ora. Non so se Groq fattura un minimo di secondi per richiesta |
| 1 GB di file tenuto per un mese e scaricato una volta | 0,10 € | 0,0213 $ + 0,09 $, oltre le soglie incluse in Supabase Pro |

Nei calcoli le letture di foto e documenti sono contate tutte al prezzo del PDF (0,0011 €), per prudenza.

## 4. Quanto resta per piano

Prezzi italiani IVA inclusa; commissione store del 15% sul prezzo senza IVA.

| Piano | Prezzo | Senza IVA (fatturato) | Commissione store | Ci arriva | Massimo per i servizi (25% del fatturato) |
|---|---|---|---|---|---|
| Plus mensile | 4,59 € | 3,76 € | 0,56 € | 3,20 € | 0,94 € |
| Plus annuale (al mese) | 3,83 € | 3,14 € | 0,47 € | 2,67 € | **0,79 €** |
| Pro mensile | 8,59 € | 7,04 € | 1,06 € | 5,99 € | 1,76 € |
| Pro annuale (al mese) | 7,17 € | 5,87 € | 0,88 € | 4,99 € | **1,47 €** |
| Ultra mensile | 15,59 € | 12,78 € | 1,92 € | 10,86 € | 3,19 € |
| Ultra annuale (al mese) | 13,00 € | 10,65 € | 1,60 € | 9,06 € | **2,66 €** |

Il 60% richiesto più il 15% dello store lasciano ai servizi il 25% del fatturato. Se il tetto per l'IA è il 5%, restano il 20% per database, hosting e RevenueCat.

## 5. Obiettivo 1: il tetto di spesa per l'IA

### La formula

```
fatturato mensile dei paganti (MRR) = somma, sugli abbonamenti pagati attivi oggi,
                                      di (prezzo mensile, oppure annuale ÷ 12) ÷ (1 + IVA)

tetto rigido del giorno  = il più alto tra 1 €  e  6% × MRR ÷ 30
soglia di attenzione     = due terzi del tetto rigido  (= 4% quando si è sopra il minimo)
```

- Si ricalcola una volta al giorno, a mezzanotte, ora italiana. Contano solo gli abbonamenti pagati: le prove, il periodo di test (`SUBSCRIPTION_TEST_PLAN`) e la lista sviluppatori non contano.
- Il minimo di 1 € resta sempre. Senza il minimo, con 10 paganti il tetto sarebbe di 0,11 € al giorno, cioè meno di quando non paga nessuno.
- La soglia dei due terzi c'è già nel codice: è `LLM_BUDGET_RESERVE_SHARE`, oggi a 0,8. Portandola a 0,67, il 4% e il 6% corrispondono alle due soglie del codice attuale.

### Esempi

Ipotesi per il fatturato medio di un pagante: metà Plus, 35% Pro e 15% Ultra; 60% annuali e 40% mensili. Ne viene un fatturato medio di 5,64 € al mese senza IVA. Nella colonna "spesa tipica" sono comprese le prove gratuite in corso, stimate come il 30% dei paganti.

| Paganti | Fatturato al mese (senza IVA) | Soglia 4% al giorno | Tetto rigido al giorno | Domande Haiku al tetto (a 0,002 €) | Token al tetto (misura di oggi) | Spesa tipica al giorno |
|---|---|---|---|---|---|---|
| 0 | 0 € | 0,67 € | **1,00 €** | ~500 (~750 al costo misurato) | 6,5 milioni | dipende da chi è in prova o in test |
| 10 | 56 € | 0,67 € | **1,00 €** | ~500 | 6,5 milioni | 0,05 € |
| 100 | 564 € | 0,75 € | **1,13 €** | ~560 | 7,3 milioni | 0,53 € |
| 1000 | 5.640 € | 7,52 € | **11,28 €** | ~5.600 | 73 milioni | 5,30 € |

Il tetto supera il minimo di 1 € da circa 89 paganti al 6%.

**Il tetto di oggi non vale 1 €.** `claude-haiku-5-5=4000000` conta tutti i token allo stesso modo, ma un token in uscita costa 5 volte uno in entrata e 50 volte uno letto dalla cache. Con il mix misurato, 1 € corrisponde a circa 6,5 milioni di token, quindi i 4 milioni di oggi valgono circa 0,62 €. Proposta per la sessione Pricing: contare la spesa in euro (token × prezzo del tipo di token) invece dei token grezzi. In attesa di questa modifica, si imposta il valore in token della tabella.

### Cosa succede oltre il tetto

Oggi, oltre il tetto risponde Groq gratuito fino a mezzanotte; quando finisce anche quello, l'utente legge "riprova tra…". Groq gratuito regge circa **71 risposte al giorno sul modello principale e 214 con i modelli di riserva**, per tutta l'app (`token_budget_fonti-dopo3.json`). Groq a pagamento **non costa meno di Haiku** (gpt-oss-120b costa 0,15/0,60 $ contro 0,10/0,50 $), quindi oltre il tetto non esiste un'alternativa a pagamento più economica: si può solo passare a un modello gratuito o bloccare.

Proposta a scaglioni:

| Stato | Chi usa Haiku | Chi passa a Groq gratuito |
|---|---|---|
| Sotto il 4% | tutti | nessuno |
| Tra il 4% e il 6% | i paganti con uso normale | chi è in prova o in test, e chi oggi ha già usato più di un terzo delle domande del suo piano |
| Oltre il 6% | solo le emergenze (testo fisso + modello, come oggi) | tutti gli altri, fino a mezzanotte |
| Groq gratuito esaurito | solo le emergenze | blocco con "riprova tra…" (come oggi) |

In più:
- **Avviso al proprietario** quando si passa il 4% per 3 giorni di fila: vuol dire che i limiti o i prezzi vanno rivisti.
- **Variante da valutare:** un tetto mensile invece che giornaliero. Il budget non speso nei giorni tranquilli resterebbe disponibile per quelli affollati (per esempio fino a 3 volte il tetto del giorno), senza mai superare il 6% del mese. Gli utenti avrebbero meno cadute su Groq e la spesa del mese sarebbe la stessa. Il codice è un po' più complesso.
- Con le misure di oggi lo scaglione tra 4% e 6% resta spento: l'uso tipico arriva a circa il 56% del 5%.

**Durante il test con il pubblico** non paga nessuno, quindi vale il minimo di 1 € al giorno per tutti: circa 500–750 risposte di Haiku al giorno, poi circa 214 su Groq, poi il blocco. Con più di circa 250 tester attivi nello stesso giorno, il tetto si fa sentire.

## 6. Obiettivo 2: il margine del 60%

### Costi fissi (dal lancio a pagamento)

| Voce | Al mese |
|---|---|
| Supabase Pro | 22,39 € (25 $) |
| Vercel Pro, 1 sviluppatore | 17,91 € (20 $) |
| Apple Developer | 7,39 € (99 $ l'anno) |
| Google Play | 25 $ una volta sola, non conteggiati |
| **Totale** | **47,69 €** |

Oggi l'inventario fornitori (`docs/security/06`) indica Vercel Hobby e Supabase Free, cioè 0 €. Il passaggio ai piani a pagamento serve appena ci sono abbonamenti: Hobby vieta l'uso commerciale e Supabase Free ha solo 1 GB di file. Il portale admin `vet-app-34xp` è su un altro account Vercel e non è conteggiato.

### Margine complessivo nell'uso tipico

| Paganti | Fatturato (senza IVA) | Store | Costi fissi | IA | Spazio oltre le soglie | RevenueCat | **Margine** |
|---|---|---|---|---|---|---|---|
| 10 | 56 € | 8 € | 48 € | 2 € | 0 € | 0 € | **−2%** |
| 39 | 220 € | 33 € | 48 € | 6 € | 0 € | 0 € | **60%** |
| 100 | 564 € | 85 € | 48 € | 16 € | 0 € | 0 € | **74%** |
| 500 | 2.820 € | 423 € | 48 € | 80 € | 1 € | 34 € | **79%** |
| 1000 | 5.640 € | 846 € | 48 € | 159 € | 8 € | 69 € | **80%** |

Si va in pari con **11 paganti** e si arriva al **60% con circa 39 paganti**. Con le funzioni a pagamento ma senza paganti (prove e test), la perdita è di circa 48 € al mese più l'IA, fino a 30 € al mese con il tetto minimo. RevenueCat diventa a pagamento sopra i 2.500 $ di ricavi al mese, cioè circa 325 paganti.

### Per piano: limiti di oggi e limiti proposti

La quota di costi fissi per abbonato è calcolata con 500 paganti (0,10 € al mese). Con meno paganti i costi fissi pesano di più e il caso peggiore scende sotto il 60% per tutti i piani: è il motivo della soglia dei 39 paganti indicata sopra.

| | Plus oggi | **Plus proposto** | Pro oggi | **Pro proposto** | Ultra oggi | **Ultra proposto** |
|---|---|---|---|---|---|---|
| Domande al giorno | 12 | **6** | 25 | **11** | 50 | **20** |
| Foto e documenti letti al giorno | 10 | **2** | 10 | **4** | 10 | **6** |
| Dettature al giorno | 30 | **10** | 30 | **20** | 30 | **40** |
| Riepiloghi per il vet al giorno | 5 | **1** | 5 | **2** | 5 | **3** |
| Spazio per i file (nuovo) | nessun limite | **1 GB** | nessun limite | **3 GB** | nessun limite | **6 GB** |
| IA al mese, caso peggiore | 1,46 € | 0,53 € | 2,24 € | 1,00 € | 3,74 € | 1,77 € |
| IA sul fatturato, caso peggiore | 46% | 17% | 38% | 17% | 35% | 17% |
| **Margine, caso peggiore, annuale** | **31%** | **60,7%** | **39%** | **60,0%** | **42%** | **60,6%** |
| Margine, caso peggiore, mensile | — | 64,5% | — | 63,9% | — | 64,5% |
| IA sul fatturato, caso tipico | 2,3% | 2,3% | 2,4% | 2,4% | 2,0% | 2,0% |
| **Margine, caso tipico** | 77% | **77,5%** | 79% | **79,3%** | 81% | **80,6%** |

Animali (4/8/15), chat per animale e dispositivi restano come sono: incidono poco sui costi.

Note:
- Nella colonna "oggi" lo spazio è calcolato come se il limite fosse già 1/3/6 GB. Senza limite, il caso peggiore non ha un tetto.
- Con i limiti proposti, nel caso peggiore il singolo abbonato spende in IA circa il 17% del suo fatturato. Il 4–6% resta garantito **sul totale** dal tetto del §5: il 60% complessivo regge anche se tutti usano il massimo, ma in quel caso molti riceverebbero risposte da Groq.
- **Variante con il costo misurato** (0,00134 € a domanda, senza riserva): **9 / 16 / 30** domande al giorno con le stesse altre voci. La consiglio dopo il primo mese di dati reali, se confermano la misura.
- **Variante rigida** (ogni abbonato sotto il 6% anche nel caso peggiore): 3 / 6 / 11 domande al giorno e nient'altro. Non la consiglio.
- **Variante "B"** (tenere 12/25/50 e affidarsi solo al tetto): il margine totale reggerebbe, ma nei giorni pieni l'app non manterrebbe la promessa di 25 domande al Pro. Groq gratuito regge circa 214 risposte al giorno in tutto, e una promessa non mantenuta porta recensioni negative e un rischio legale per la pubblicità ingannevole. Non la consiglio.

## 7. Cose da correggere emerse dai numeri

1. **Lettura delle foto.** Passa da `VISION_MODEL=qwen/qwen3.8-27b` su Groq gratuito, che ha 200.000 token al giorno condivisi con il modello leggero di riserva: circa 80 foto al giorno per tutta l'app. A pagamento costa 0,0033 € a foto, contro circa 0,0004 € su Haiku, ed è un modello "preview" che Groq può ritirare con poco preavviso. Proposta: leggere le foto con Haiku, dopo aver verificato che accetti immagini. Se restano su Groq a pagamento, le letture proposte vanno dimezzate.
2. **Il tetto in token di oggi vale 0,62 €**, non 1 € (§5).
3. **Dettatura.** Groq gratuito regge 2.000 dettature e 8 ore di audio al giorno per tutta l'app. A pagamento costa pochissimo (circa 0,0002 € a dettatura): conviene attivare il pagamento a consumo su Groq prima del lancio, con un tetto in console.
4. **Apple Small Business Program.** Senza iscrizione la commissione è il 30% nel primo anno e il 60% non si raggiunge con nessun limite. L'iscrizione va fatta prima del primo abbonamento.
5. **Spazio per i file.** Oggi non c'è un limite per piano: nel caso peggiore lo spazio è l'unico costo senza tetto. Propongo 1/3/6 GB (circa 3.000 foto compresse o 50 video da 20 MB per ogni GB).

## 8. Ipotesi dichiarate

| Ipotesi | Valore | Su cosa si basa |
|---|---|---|
| Costo per domanda | 0,002 € (misurato 0,00134 € + 50%) | 79 risposte di test, non traffico reale |
| Uso tipico al giorno | Plus 1 domanda, Pro 2, Ultra 3; letture 0,2/0,3/0,5; dettature 0,5/1/1,5; riepiloghi 0,05/0,1/0,15 | **mia stima, nessun dato reale**: da sostituire con il primo mese di traffico |
| Composizione dei paganti | 50% Plus, 35% Pro, 15% Ultra; 60% annuali | mia stima |
| Prove in corso | 30% dei paganti, con un uso da Pro tipico | mia stima |
| Spazio tipico | 0,3 GB per abbonato | mia stima |
| Commissione store | 15% sul prezzo senza IVA | Google lo dichiara; per Apple la pagina non dice su quale base si calcola, ma dice che il ricavo è il prezzo meno IVA e commissione |
| IVA | 22% (Italia) | per gli altri paesi vedi [03](03_prezzi_per_paese.md) |
| Cambio | 1,1165 $ per € | un euro più debole del 10% fa salire l'IA del 10% |
| Quota dei costi fissi nel caso peggiore | 500 paganti | scelta per separare il margine del piano dalla fase di avvio |
| RevenueCat | 1% su tutto il ricavo tracciato, oltre i 2.500 $ | la pagina non è chiara |

## 9. Decisioni per il proprietario

1. **Tetto per l'IA:** rigido al 6% con soglia di attenzione al 4% (proposto), oppure rigido al 5%. In ogni caso con il minimo di 1 € al giorno, sempre attivo.
2. **Oltre il tetto:** scaglioni del §5 (proposto), oppure tutto subito a Groq come oggi. Da decidere anche se adottare il tetto mensile con riporto dei giorni tranquilli.
3. **Limiti per piano:** 6/11/20 domande con il resto della tabella del §6 (proposto), oppure la variante 9/16/30 da adottare dopo un mese di dati.
4. **Limite di spazio** 1/3/6 GB: nuovo, da approvare.
5. **Come si calcola il 60%:** sul prezzo senza IVA (usato qui) oppure su quanto arriva dopo lo store (più permissivo).
6. **Azioni del proprietario prima del lancio:** iscrizione all'Apple Small Business Program; passaggio a Supabase Pro e Vercel Pro; pagamento a consumo su Groq per dettatura e riserva; scelta tra RevenueCat e il codice nostro.
7. **Test con il pubblico:** 1 € al giorno basta per circa 250 tester attivi al giorno. Se se ne attendono di più, decidere un minimo più alto per la sola durata del test.

## 10. Per la sessione Pricing (solo dopo l'approvazione)

- `limits.py`: aggiungere a `PlanLimits` le letture, le dettature, i riepiloghi e lo spazio, con i valori approvati. Oggi sono uguali per tutti in `settings.py` (`CHAT_DAILY_*_LIMIT_PER_USER`).
- `llm_budget.py`: tetto calcolato ogni giorno dal fatturato dei paganti con la formula del §5; spesa contata in euro e non in token grezzi; `LLM_BUDGET_RESERVE_SHARE` a 0,67; precedenza ai paganti con uso normale tra il 4% e il 6%; avviso al proprietario.
- Lettura delle foto su Haiku, se accetta immagini.
- Ricalcolare questo documento con il primo mese di dati reali (costo per domanda, uso tipico, composizione dei piani).

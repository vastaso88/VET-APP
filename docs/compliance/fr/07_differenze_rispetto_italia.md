> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**

# Differenze Francia rispetto all'Italia

Data: 2026-10-14. Le voci «conoscenza generale» sono da verificare; quelle con ✅ sono confermate sul sito di un'autorità in `01`/`06` (Légifrance non leggibile: quasi tutti gli articoli di codice sono 🟡). Per Belgio e Svizzera romanda vedi `../be/07_*` e `../ch-fr/07_*`; per il quadro UE comune vedi `../de/07_*`.

## Legale

| Tema | Italia | Francia | Effetto su VetApp |
|---|---|---|---|
| Legge sui dati | GDPR + Codice privacy; Garante | GDPR + **loi Informatique et Libertés**; **CNIL** | Informativa francese propria (doc 02, 04); reclamo alla CNIL o al Garante (capofila) |
| Rappresentante UE | — | Non serve: titolare italiano è nell'UE | Nessun segnaposto di rappresentante |
| Età digitale | 14 anni | **15 anni** (art. 45 LIL ✅ CNIL) | App 18+; nessun consenso parentale |
| Cookie / dispositivo | Codice privacy / Provvedimento Garante | **art. 82 LIL**; CNIL: «rifiutare facile quanto accettare» ✅; raccomandazione app mobili (🟡) | Consenso solo per strumenti non necessari; pulsanti di pari rilievo |
| Diritti post-mortem | — | Direttive sul destino dei dati dopo il decesso (art. 85 LIL 🟡) | Menzione nell'informativa (doc 02 §8) |
| Identificazione dell'editore | art. 7 D.Lgs. 70/2003 (🟡) | **«Mentions légales» — art. 6-III LCEN** (🟡): editore, direttore della pubblicazione, **hébergeur** | Voce raggiungibile in app e store; nomina del directeur de la publication |
| Prezzi | Codice del consumo | Prezzo **TTC** (🟡) | «TTC»; vedi doc 03 §4 |
| Recesso | 14 giorni | 14 giorni (L221-18); esecuzione anticipata del servizio (L221-25, L221-28); **bottone «renoncer au contrat ici» dal 19/06/2026** (🟡 ordonnance 2026-2) | Funzione nella web app + accuse di ricezione su supporto durevole |
| Pulsante d'ordine | art. 49 Codice del consumo (🟡) | **«commande avec obligation de paiement»** (L221-14 🟡) | Dicitura del pulsante in doc 03 §5 |
| Risoluzione online | — | **«Résiliation en trois clics»** (loi 2022-1158 + décret 2023-417, in vigore dal 01/06/2023, 🟡) | Funzione di risoluzione in Impostazioni → Abbonamento |
| Rinnovo tacito | Codice del consumo | **L215-1: avviso 3–1 mesi prima** (🟡) | E-mail dedicata prima di rinnovi/fine prova |
| Conciliazione | ADR/ODR | **Médiateur de la consommation obbligatorio** (L612-1 🟡); piattaforma ODR UE chiusa 20/07/2025 (🟡) | Designare un mediatore e citarlo (doc 03 §14) |
| Prodotti digitali | D.Lgs. 173/2021 (🟡) | Garanzia di conformità dei contenuti/servizi digitali (L224-25-1 ss. 🟡) | Aggiornamenti e conformità |
| IA | AI Act art. 50 | idem; **DGCCRF** punto di contatto, **DGE** supporto (🟡); CNIL per l'art. 50 ❓ | Etichetta «Généré par IA» obbligatoria dal 02/08/2026 |
| Accessibilità | D.Lgs. 82/2022 | **Loi 2023-171 + décret 2023-931**, dal 28/06/2025; microimprese esonerate per i servizi (🟡); controllo DGCCRF | ⚖️ quale legge e se si è esonerati |
| Veterinari | FNOVI, albi regionali; ricetta elettronica veterinaria | **Ordre national des vétérinaires** ✅; **L243-1** (esercizio abusivo: consulti, diagnosi, prescrizioni 🟡) | Nessuna diagnosi/prescrizione; **nessun consiglio personalizzato basato su anamnesi** (più severo del DE) |
| Telemedicina veterinaria | normativa italiana | **Nessuna base legale oggi** (décret 2020-526 caduco dal 06/11/2021 ✅ Ordre) | L'app non è e non deve apparire «téléconsultation» |
| Animali (vendita) | Legge e Regioni | I privati **non possono pubblicare online annunci di vendita di cani/gatti** ✅ justice.fr (28/04/2026); cessione gratuita con requisiti; **CEC dal 01/10/2022**; animalerie senza cani/gatti dal 01/01/2024 (🟡) | Mercatino senza animali, in ogni paese (decisione del proprietario, 2026-10-26) |
| Identificazione | Anagrafe canina regionale | **I-CAD** nazionale; cani da 4 mesi, gatti da 7 mesi ✅ justice.fr | Contenuti informativi |
| Giurisdizione | Una | Foro del consumatore (Bruxelles I bis, 🟡) | Clausola di legge applicabile (doc 03 §15) |

## Formati e linguaggio

| Voce | Italia | Francia | Note |
|---|---|---|---|
| Lingua | it | **fr-FR** (francese, **vouvoiement**) | Termini: «vétérinaire», «cabinet vétérinaire», «clinique vétérinaire», «carnet de santé»; «animal de compagnie». Una sola traduzione di UI per FR/BE/CH, ma testi **legali** con versione propria per regione |
| Data | `gg/mm/aaaa` | **`jj/mm/aaaa`** (14/10/2026) | Mese esteso: «14 octobre 2026» (mesi minuscoli). Il formato inviato al backend non cambia |
| Ora | 24 ore | 24 ore (`14 h 30`) | Spazio prima e dopo «h» |
| Primo giorno della settimana | lunedì | lunedì | Uguale |
| Valuta | € (1.234,56 €) | **€** (`1 234,56 €`) | Separatore delle migliaia: spazio (sottile, non spezzabile); virgola decimale; simbolo dopo il numero; ❓ conferma con l'i18n |
| Prezzi | IVA inclusa | **TTC** | «TTC»; IVA ordinaria 20% (🟡 conoscenza generale; servizi digitali ai consumatori seguono il luogo del consumatore, OSS: ⚖️) |
| Distanza / peso / temperatura | km, kg, °C | km, kg, °C | Uguale |
| Telefono | `+39 3xx xxx xxxx` | `+33 6 12 34 56 78` (cellulare), `01 23 45 67 89` (fisso); prefisso nazionale 0 | Esempio fittizio: `01 99 00 12 34` (ARCEP riserva intervalli alla finzione, ❓ non verificato) |
| Indirizzo | via, civico, CAP, città | **numéro + rue, code postal (5 cifre), ville** (`12 rue Exemple, 75001 Paris`) | Campo «code postal» invece di CAP; il «numéro» precede la via; «Cedex» facoltativo |
| Numero d'emergenza persone | 112 | 112 (SAMU 15, polizia 17, pompieri 18) | Non confondere con animali: doc 06 |
| Veterinario | «veterinario» | «vétérinaire», «cabinet vétérinaire», «clinique vétérinaire» | |
| Microchip | obbligatorio per i cani | **obbligatorio per cani e gatti, registrato in I-CAD** (✅ justice.fr) | Contenuti informativi |
| Passaporto animali | Passaporto europeo | Passeport européen (UE) | Uguale |
| Autorità animali | ASL, Comune | **DDPP** (🟡); fourrière comunale | Doc 06 |
| Razze | ENCI | **SCC / LOF** (conoscenza generale) | Dati razze: non toccati |
| Termini d'uso | «Termini di Servizio» | «Conditions générales d'utilisation (et de vente)» | |
| Politica privacy | «Informativa» | «Politique de confidentialité» | |
| Avviso IA | — | «Avis sur l'IA» | |
| Titolo di cortesia | — | vouvoiement, «Madame, Monsieur» solo in testi formali | Niente «tu» |

## Cosa cambiare nell'app (indicativo, per la sessione Formati e store)

1. Voce «Mentions légales» nelle Impostazioni e nello store.
2. Campo indirizzo: «code postal» (5 cifre), «numéro + rue».
3. Numeri utili per paese (doc 06); banner di emergenza solo con numeri confermati.
4. Consensi per `fr-FR` (doc 04); lingua mostrata salvata.
5. Etichette IA e disclaimer (doc 05) — in particolare la linea «informazioni generali».
6. Pulsanti di ordine, risoluzione, recesso e avvisi di rinnovo sulla web app (doc 03 §5).
7. Mercatino: nessun animale in nessun paese (decisione del proprietario, 2026-10-26); non è più una regola della Francia.

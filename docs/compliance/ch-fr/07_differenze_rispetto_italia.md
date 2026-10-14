> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**

# Differenze Svizzera romanda rispetto all'Italia (e a `ch/`)

Data: 2026-10-14. **Non duplica** `../ch/07_differenze_rispetto_italia.md` (tabella legale svizzera completa, valida identica per i cantoni francofoni). Qui: solo formati e linguaggio per `fr-CH` e le differenze con `fr-FR`/`fr-BE`. Voci «conoscenza generale» da verificare.

## Legale (richiamo)

Vale tutto `../ch/07` (nLPD, PFPDT senza potere di multa, DPF Swiss–US dal 15/09/2024, nessun recesso legale, niente DSA/AI Act nazionali, TAMV, TSchV, rappresentanza art. 14). In francese: **nLPD / PFPDT / LCD / LTC / CO / OIP** (`01` §1). Confronto rapido:

| Tema | fr-FR | fr-BE | fr-CH |
|---|---|---|---|
| Autorità dati | CNIL | APD | **PFPDT** (nLPD, non UE) |
| Recesso | 14 giorni + bottone dal 19/06/2026 | 14 giorni + funzione 2 passaggi dal 14/08/2026 | **nessun recesso legale** (volontario) |
| Risoluzione online | obbligatoria («3 clic») | non obbligatoria (proposta) | non obbligatoria |
| Mediatore | obbligatorio | servizio federale | non obbligatorio |
| Telemedicina vet. | nessuna base legale (✅) | nessun quadro (❓) | Rx solo se si conosce l'animale (🟡) |
| Annunci animali | privati non vendono cani/gatti online (✅) | regionale ❓ | TSchV / AMICUS 🟡 |
| Numero avvelenamenti animali | CNITV / CAPAE | Centre Antipoisons 070 245 245 | **145** ❓ |

## Formati e linguaggio

| Voce | Italia | Svizzera romanda (fr-CH) | Note |
|---|---|---|---|
| Lingua | it | **fr-CH** (francese, **vouvoiement**) | Termini: «vétérinaire», «cabinet vétérinaire», «clinique vétérinaire», «hôpital vétérinaire»; Svizzera: «septante», «huitante» (VD, FR, VS)/«quatre-vingts» (GE, NE, JU) in testi numerici non rilevanti per il legale. Una traduzione UI per FR/BE/CH, testi **legali** con versione propria |
| Data | `gg/mm/aaaa` | **`jj.mm.aaaa`** (14.10.2026) | In Svizzera il punto come separatore è comune (come nel de-CH); il formato `jj/mm/aaaa` è usato in Francia. ❓ confermare con i18n/CLDR |
| Ora | 24 ore | 24 ore (`14 h 30` o `14:30`) | ❓ |
| Primo giorno della settimana | lunedì | lunedì | Uguale |
| Valuta | € (1.234,56 €) | **CHF** (prefisso o suffisso, separatori da definire) | Francia: `1 234,56 €`; Svizzera tedesca: `CHF 1’234.50`. Per il fr-CH le fonti (CLDR, Cancelleria federale) non sono state verificate: scegliere **un** formato e testarlo (domanda 4). Non usare l'apostrofo tipografico del de-CH senza verificarlo |
| Prezzi | IVA inclusa | **TVA comprise** (OIP 🟡) | |
| Distanza / peso / temperatura | km, kg, °C | km, kg, °C | Uguale |
| Telefono | `+39 3xx xxx xxxx` | `+41 7x xxx xx xx` (cellulare), `0xx xxx xx xx` (fisso); prefisso nazionale 0 | Esempio fittizio non verificato ❓ |
| Indirizzo | via, civico, CAP, città | **rue + numéro, NPA (4 cifre), localité** (`Rue Exemple 12, 1204 Genève`); **canton** con sigla | In Romandia «NPA» (numéro postal d'acheminement) al posto di «code postal»; campo «canton» opzionale |
| Numero d'emergenza persone | 112 | 112 (144 ambulanza, 117 polizia, 145 Tox Info Suisse) | Non confondere con animali: doc 06 |
| Veterinario | «veterinario» | «vétérinaire», «cabinet vétérinaire», «hôpital vétérinaire» | |
| Microchip / registro | obbligatorio per i cani | **cani: chip e AMICUS**; gatti: ANIS (❓) | Contenuti informativi |
| Autorità animali | ASL, Comune | **vétérinaire cantonal** (service vétérinaire cantonal) | |
| Razze | ENCI | SCS / FCI | |
| Termini d'uso | «Termini di Servizio» | «Conditions d'utilisation» | |
| Politica privacy | «Informativa» | «Politique de confidentialité» | |
| Avviso IA | — | «Avis sur l'IA» | |
| Virgolette | « » | « » con spazio | Svizzera: spazi attorno a «:», «;», «!», «?» (uso federale ❓) |

## Cosa cambiare nell'app (indicativo)

1. Valuta CHF (formato fr-CH da decidere), campo «NPA» a 4 cifre, «canton» opzionale.
2. Consensi `fr-CH` (doc 04), avviso IA (doc 05), numeri utili (doc 06; 145 solo dopo conferma).
3. Mercatino: tolto «animali vivi».
4. Decidere se `fr-CH` si apre insieme a `de-CH` (domanda 1 in `08`).

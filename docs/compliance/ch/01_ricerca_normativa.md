> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**

# Svizzera — ricerca normativa per VetApp

Sessione: Legale DE (sezione Svizzera). Data di consultazione di tutte le fonti: **2026-10-14**. Lingua dei testi destinati agli utenti: tedesco svizzero (`de-CH`, Sie-Form, **«ss» al posto di «ß»**). La Svizzera **non è nell'UE**: il GDPR non è la legge di riferimento per gli utenti svizzeri (resta applicabile a VetApp come titolare UE per i trattamenti nell'UE), quindi qui contano nDSG/revDSG, UWG, OR, TSchV. Il quadro UE comune è in `../de/01` §1, §6; qui solo il diverso.

## Come leggere questo documento

Stessa legenda di `de/01`: ✅ primaria · 🟡 secondaria/parziale · ❓ non verificato · ⚖️ da decidere con l'avvocato. Primarie usate: EDÖB/FDPIC (edoeb.admin.ch), SECO (seco.admin.ch). Il sito Fedlex non è stato letto: i riferimenti ad articoli sono da fonti secondarie e da verificare su fedlex.admin.ch. Nessuna norma inventata.

Premessa di fatto: titolare **italiano** (UE), utenti in Svizzera → per la Svizzera il titolare è **estero**.

## 0. Quadro in una pagina

| Tema | Cosa serve in Svizzera | Priorità |
|---|---|---|
| nDSG (revDSG, SR 235.1) | Informativa svizzera; EDÖB; **rappresentanza in Svizzera (art. 14)** solo se tutte le condizioni sono soddisfatte | Alta |
| Trasferimenti | Italia/Irlanda (SEE): adeguati (🟡); USA: **Swiss–US DPF dal 15/09/2024** ✅ per aziende certificate | Alta |
| FMG art. 45c (cookie) | Informare e dare diritto di rifiuto; guida EDÖB più severa (🟡) | Media |
| UWG art. 3 Abs. 1 lit. s (Impressum, e-commerce) | Identità e contatto chiari, e-mail; conferma d'ordine | Alta |
| **Nessun diritto di recesso legale online** | Il recesso di 14 giorni UE non esiste; offerta volontaria | Alta |
| PBV (prezzi) | Prezzi in CHF finali con IVA nel marketing; servizi nel catalogo art. 10 | Media |
| IA | Nessuna legge generale; Bundesrat 12/02/2025; AI Act vale comunque per VetApp (UE) | Media |
| Veterinari | HMG/TAMV: Rx solo se si conosce l'animale; diagnosi riservata a veterinari (🟡) | Alta |
| Tierschutz | Annunci di cani: nome, indirizzo, origine; Mercatino senza animali vivi | Alta |
| Età | 18 anni | Bassa |
| IVA svizzera sui servizi digitali di fornitori esteri | Registrazione MWST oltre soglia ❓ | Media ⚖️ |

## 1. nDSG (nuova legge federale sulla protezione dei dati)

- ✅ **Swiss–US Data Privacy Framework** — l'EDÖB conferma che dal **15/09/2024** esiste un livello di protezione adeguato per i dati scambiati tra Svizzera e **aziende USA certificate**; l'elenco è su dataprivacyframework.gov. Fonte primaria: [EDÖB 15/08/2024](https://www.edoeb.admin.ch/en/15082024-new-swiss-us-data-privacy-framework). Nota: per i dati svizzeri **non basta** la certificazione al DPF UE–USA: l'azienda deve aderire anche alla **estensione svizzera** (conoscenza generale ❓ da verificare per Groq).
- 🟡 **Rappresentanza (art. 14 DSG):** i titolari privati con sede all'estero devono designare una rappresentanza in Svizzera se il trattamento (1) è collegato all'offerta di beni/servizi o all'osservazione del comportamento di persone in Svizzera, (2) è **esteso e regolare**, (3) comporta un **rischio elevato**. Condizioni cumulative; l'[Onlinekommentar](https://onlinekommentar.ch/de/kommentare/dsg14) ritiene che l'obbligo valga in pratica per pochi titolari (e che la soglia dei 250 dipendenti non vale per questo obbligo). La rappresentanza è un punto di contatto, tiene un registro e rende pubblici nome e indirizzo (art. 15). L'EDÖB può ordinare di designarla. Fonti: [foraus](https://www.foraus.ch/fr/posts/brauchen-auslaendische-it-unternehmen-wirklich-botschafterinnen-in-der-schweiz), [activemind](https://www.activemind.legal/?p=15194). ⚖️ **Un'app piccola con GPS e IA, quanti utenti in CH?** → domanda al proprietario.
- 🟡 **Decisioni automatizzate (art. 21):** obbligo di informare per decisioni interamente automatizzate con effetti giuridici o significativi; diritto di far valere la propria posizione e revisione umana ([Onlinekommentar](https://onlinekommentar.ch/de/kommentare/dsg21)). VetApp non decide su di te.
- 🟡 **Sanzioni:** l'EDÖB **non può infliggere multe** (può emettere provvedimenti correttivi, art. 51); le multe penali (fino a **CHF 250.000** per persone private che violano intenzionalmente obblighi informativi, di accesso e collaborazione, art. 60) sono perseguite dai **Cantoni** sulla persona responsabile; nei casi minori fino a CHF 50.000 contro l'impresa (art. 64). Fonti: [recordinglaw](https://www.recordinglaw.com/de/switzerland/data-privacy/ndsg-overview/), [Onlinekommentar art. 60](https://onlinekommentar.ch/de/kommentare/dsg60). Da verificare su Fedlex.
- ❓ **Consenso (art. 6)**, **obbligo informativo (art. 19)**, **diritto di accesso (art. 25, 30 giorni?)**, **DPIA (art. 22)**: conosco la struttura ma **non ho riletto i testi in questa sessione**; nella bozza di informativa uso termini prudenti e segno «[bestätigen]».
- 🟡 Trasferimenti verso l'UE/SEE: considerati adeguati dalla lista del Consiglio federale (Anhang 1 DSV, conoscenza generale ❓). Supabase (Irlanda), Vercel (Dublino) → non servono garanzie ulteriori.
- ❓ **Svizzera → Italia:** il titolare è in Italia, quindi i dati svizzeri vanno a un paese UE, ma ⚖️ da confermare sul DSV.
- **DPIA:** la stessa raccomandazione di `de/01`; per la CH vale l'art. 22 DSG (❓ non riletto).

## 2. Cookie e dispositivo: FMG art. 45c

- 🟡 **Art. 45c FMG** (Fernmeldegesetz): il trattamento di dati su dispositivi altrui via telecomunicazione è lecito se gli utenti sono informati su trattamento e scopo e **sul diritto di rifiutare**; non richiede consenso preventivo. La lettera è citata come «b» o «c» da fonti diverse ❓. Multe fino a CHF 5.000 secondo una fonte ❓. Fonti: [consentmanager](https://www.consentmanager.net/en/knowledge/legal/cookie-consent-for-switzerland/), [captain.legal](https://www.captain.legal/ch-de/cookies.html).
- 🟡 Una guida dell'EDÖB (indicata come del **gennaio 2025** da un fornitore di CMP ❓) richiederebbe un consenso esplicito per cookie non necessari: **fonte commerciale, da verificare sul sito EDÖB**. Linea prudente: consenso per gli strumenti non necessari.
- Effetto: oggi nessuno strumento di analisi; token e preferenze sono necessari.

## 3. Impressum e commercio elettronico: UWG art. 3 Abs. 1 lit. s

- 🟡 È sleale (UWG, SR 241) nel commercio elettronico **non indicare in modo chiaro e completo l'identità e l'indirizzo di contatto (compresa la e-mail)**; non rendere chiari i passaggi tecnici fino alla conclusione del contratto; non dare strumenti per correggere errori di inserimento; non **confermare l'ordine senza ritardo per e-mail**. Vale per chi opera sul mercato svizzero **anche dall'estero**. Fonti: [Handelsverband.swiss](https://handelsverband.swiss/swiss-online-garantie-zertifizierung-impressum/), [law.ch](https://law.ch/lawinfo/ict-law-informations-und-kommunikationstechnologie/impressumspflicht-e-commerce/), [IT-Recht-Kanzlei](https://www.it-recht-kanzlei.de/schweiz-impressum.html?print=1). Indirizzo con via, **non solo casella postale** (prassi consigliata).
- Raccomandazione: Impressum «Anbieterin» con i dati del titolare italiano e indirizzo e-mail; per CH aggiungere eventuale rappresentante.

## 4. Consumatori: nessun recesso legale, PBV, IVA

- 🟡 **Nessun diritto di recesso legale per gli acquisti online in Svizzera** (UWG non lo prevede; il recesso esiste per vendite porta a porta e simili, art. 40a ss. OR, conoscenza generale ❓). Fonte secondaria: [onlinemarktplatz.de](https://onlinemarktplatz.de/270913/verkaufen-in-die-schweiz-rechtliche-anforderungen-fuer-onlinehaendler-im-ueberblick/) e commento di Simsa (2013). Nessuna riforma trovata ❓. **Effetto:** la prova gratuita + l'obbligo di scegliere un piano restano; il recesso di 14 giorni sarebbe un'offerta **volontaria** (domanda 2 di `ch/08`). Il titolare UE, offrendo ai consumatori svizzeri, deve comunque rispettare le norme UE per i propri clienti UE; per la CH il diritto applicabile può essere scelto ⚖️ (Art. 114 IPRG, conoscenza generale ❓).
- ✅ **PBV (Preisbekanntgabeverordnung):** SECO FAQ — la PBV si applica quando le offerte si rivolgono a clienti svizzeri; il prezzo è l'importo finale in CHF con le imposte (MWST) incluse; **non c'è un obbligo generale di indicare i prezzi su Internet**, ma se si può ordinare direttamente un servizio coperto va mostrato il prezzo. **Catalogo dei servizi (art. 10)**: abbraccia, tra l'altro, veterinari, telecom, banche, corsi… **non risulta un abbonamento a un'app**. La **pubblicità con prezzi** è soggetta alla PBV per tutti i servizi. Fonte primaria: [SECO – FAQ PBV](https://www.seco.admin.ch/de/faq-pbv) (data non indicata; ultima Wegleitung citata: 01/09/2025). Dunque: i prezzi che pubblicizziamo vanno in CHF **inkl. MWST**.
- 🟡 **IVA svizzera sui servizi digitali di fornitori esteri:** un fornitore estero con fatturato mondiale oltre una soglia (CHF 100.000 di servizi in Svizzera) deve registrarsi (conoscenza generale, **non verificato**) ❓⚖️. Domanda al proprietario.
- ❓ Condizioni generali: controllo dei contenuti di AGB nel UWG art. 8 (vessatorietà), conoscenza generale ❓.

## 5. Intelligenza artificiale

- 🟡 La Svizzera non ha una legge generale sull'IA. **Bundesrat 12/02/2025:** priorità alla ratifica della Convenzione quadro del Consiglio d'Europa sull'IA e adeguamenti settoriali; l'AI Act UE non viene ripreso «tel quel». Convenzione firmata il **27/03/2025**. Una proposta in consultazione è attesa **entro fine 2026** e non è ancora pubblicata. Le fonti divergono sullo stato della ratifica. Fonti: [Blick](https://www.blick.ch/politik/regulierung-bundesrat-will-ki-konventionen-des-europarates-uebernehmen-id20583692.html), [law.ch](https://law.ch/lawnews/2025/03/schweiz-unterzeichnet-europaratskonvention-zu-kuenstlicher-intelligenz-ki/), [BJ](https://www.bj.admin.ch/de/kuenstliche-intelligenz).
- Effetto: nessun obbligo svizzero analogo all'art. 50 AI Act; ma **VetApp è un sistema offerto nell'UE** e quindi vale l'art. 50 (vedi `de/01` §6): per coerenza lo stesso avviso IA anche per gli utenti svizzeri.

## 6. Veterinari: HMG e TAMV

- 🟡 **Tierarzneimittelverordnung (TAMV, art. 10):** un medicinale soggetto a prescrizione può essere prescritto o dispensato per animali **solo se chi lo prescrive conosce l'animale o la mandria**; per gli animali da reddito serve una visita (o una convenzione scritta «TAM-Vereinbarung» con visite periodiche). Fonti: [BLV – Verschreibung](https://www.blv.admin.ch/blv/de/home/tiere/tierarzneimittel/fachgerechter-umgang-mit-tierarzneimitteln/verschreibung--abgabe-und-anwendung.html), sentenza del Kantonsgericht SG (via [entscheidsuche](https://entscheidsuche.ch/docs/SG_Gerichte/SG_KG_001_ST-2014-111--ST-2014_2015-10-22.pdf)); TAMV versione 18/08/2004, stato 01/09/2023, **non riletta su Fedlex**.
- 🟡 **Diagnosi:** secondo Swissmedic la diagnosi fondata e la scelta del trattamento spettano a un veterinario; **esiste una pagina Swissmedic su «Unauthorized practice of veterinary medicine»** (esercizio abusivo), non letta ([Swissmedic](https://www.swissmedic.ch/swissmedic/en/home/legal/penal-law/publications/unauthorized-practice-of-veterinary-medicine.html)). Quindi stessa linea di UK/US/AU/AT: **nessuna diagnosi né ipotesi, nessun dosaggio**.
- 🟡 In Svizzera esistono servizi di telemedicina per cani e gatti (articoli 2020–2021), per lo più a base di documenti e rapporti scritti ([netzwoche](https://www.netzwoche.ch/news/2021-03-17/jetzt-gibt-es-telemedizin-auch-fuer-hund-und-katze)); nessuna norma federale esplicita trovata sulla telemedicina per animali ❓. I Cantoni regolano l'esercizio ❓.

## 7. Tierschutz e Mercatino

- 🟡 **Annunci di cani** (Tierschutzverordnung, in vigore da 03/2018): obbligo di indicare dati di contatto del venditore (nome e indirizzo) e paese di allevamento/origine; multe fino a CHF 10.000 ([SRF](https://www.srf.ch/news/schweiz/untersuchung-des-sts-viele-online-hundeinserate-verstossen-gegen-das-gesetz)); la norma per i gatti non vale. Non ho letto il numero dell'articolo ❓.
- 🟡 **Cani:** chip obbligatorio e registro **AMICUS** (Identitas AG, dal 2016); commercio professionale di animali domestici soggetto a autorizzazione e formazione (BLV). Fonti: [Identitas/Amicus via flyer](https://www.wuerenlos.ch/fileadmin/00_website/pdf/AMICUS_flyer.pdf), [Beobachter](https://www.beobachter.ch/natur/flora-fauna/arten-tierschutz/artikel/tierschutz_unserioeser-tierhandel-im-internet/).
- **Decisione del proprietario (2026-10-26):** nel Mercatino non si vendono, regalano né scambiano animali, in nessun paese: la regola non dipende più dalla Svizzera. Questa sezione resta come motivazione giuridica.

## 8. Altri aspetti

- **Età:** 18 anni (maggiore età, ZGB art. 14, conoscenza generale ❓). App 18+.
- **Lingue:** la Svizzera è multilingue (DE, FR, IT, RM). I testi legali per utenti svizzeri con interfaccia francese/italiana: **testi per paese+lingua**; qui solo `de-CH` (domanda 6 in `de/08`).
- **Store:** come in `de/01` §10; non esiste in CH l'obbligo di trader status DSA ma gli store lo chiedono per il mercato UE.

## 9. Cosa va fatto (sintesi operativa)

1. Valutare se serve una rappresentanza svizzera (art. 14 nDSG) e IVA svizzera.
2. Informativa `de-CH` (doc 02) con EDÖB; consensi `de-CH` v1 (doc 04).
3. Impressum con indirizzo e e-mail; prezzi in CHF inkl. MWST.
4. Decidere recesso volontario (doc 03 §5).
5. Avviso IA e disclaimer prudenti (doc 05).
6. Mercatino senza animali vivi.
7. Numeri utili (doc 06): Tox Info Suisse 145 per persone; per animali ❓.

## 10. Incertezze

- Fedlex non letto: DSG, DSV, UWG, PBV, FMG, TAMV, TSchV, OR, ZGB.
- Se Groq ha l'estensione svizzera del DPF.
- Se esiste la guida EDÖB sui cookie di gennaio 2025 nei termini riportati.
- Obbligo di rappresentanza in concreto; soglia IVA.
- Esistenza di norme cantonali sulla telemedicina veterinaria.
- Stato dell'IA (convenzione e consultazione 2026).
- Se il servizio 145 consiglia i proprietari di animali.

## Fonti consultate (2026-10-14)

Primarie: [EDÖB – Swiss-US DPF 15/08/2024](https://www.edoeb.admin.ch/en/15082024-new-swiss-us-data-privacy-framework) · [SECO – FAQ PBV](https://www.seco.admin.ch/de/faq-pbv).
Secondarie: Onlinekommentar (art. 14, 15, 21, 60), foraus, activemind, recordinglaw, consentmanager, captain.legal, Handelsverband.swiss, law.ch, IT-Recht-Kanzlei, onlinemarktplatz, BLV, Swissmedic, SRF, Beobachter, Blick, netzwoche.
Non raggiungibili: `toxinfo.ch/299_en` (404).

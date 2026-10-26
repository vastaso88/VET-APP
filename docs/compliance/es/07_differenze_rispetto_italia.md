> **BOZZA — non è consulenza legale, da far rivedere a un legale locale**

# Differenze Spagna rispetto all'Italia

Data: 2026-10-14. Le voci con ✅ sono confermate nei doc 01/06; le altre sono «conoscenza generale» da verificare. Per i paesi dell'America Latina vedi `09_america_latina.md`.

## Legale

| Tema | Italia | Spagna | Effetto su VetApp |
|---|---|---|---|
| Legge sui dati | GDPR + Codice privacy; Garante | GDPR + **LOPDGDD 3/2018**; **AEPD** | Politica de privacidad propria (doc 02, 04); reclamo all'AEPD o al Garante (capofila) |
| Rappresentante UE | — | Non serve: titolare italiano nell'UE | Nessun rappresentante |
| DPO | art. 37 GDPR | art. 37 GDPR + **art. 34 LOPDGDD** (🟡 non riletto) | ⚖️ dipende dal titolare |
| Età digitale | 14 anni | **14 anni** ✅ (art. 7 LOPDGDD); progetto di legge per 16 (🟡, in esame) | App 18+; nessuna differenza pratica |
| Cookie / dispositivo | Codice privacy / Provv. Garante | **Art. 22.2 LSSI-CE** ✅; guida AEPD 11/07/2023 ✅ (rifiuto nel primo strato, pari rilievo) | Consenso solo per strumenti non necessari |
| Informazione del prestatore | art. 7 D.Lgs. 70/2003 (🟡) | **Art. 10 LSSI-CE** ✅ (denominazione, domicilio, e-mail, registro, NIF, prezzi con imposte) | Voce «Información legal» (≈ Impressum) |
| Pubblicità per e-mail | D.Lgs. 196/2003 art. 130 (🟡) | **Art. 21 LSSI-CE** ✅ (consenso previo; eccezione clienti) | Consenso `marketing_email` + link di disiscrizione |
| Recesso | 14 giorni | **14 giorni naturali** ✅; contenuto digitale/servizi: perdita con consenso espresso (art. 103 a, m ✅ estratto); pagamento proporzionale (art. 108.4) | Funzione «Desistir del contrato» nella web app |
| Pulsante d'ordine | art. 49 Codice del consumo (🟡) | **«Pedido con obligación de pago»** (art. 98.2 TRLGDCU ✅ estratto) | Etichetta del pulsante |
| Abbonamenti | Codice del consumo (🟡) | **Ley 10/2025**: preavviso 15 giorni, disdetta semplice (✅ nota ministeriale; ambito ❓) | Avviso di rinnovo e disdetta in un tocco |
| Prodotti digitali | D.Lgs. 173/2021 (🟡) | TRLGDCU artt. 115 bis ss. ✅ estratto | Conformità e aggiornamenti |
| Clausole | Clausole vessatorie | Cláusulas abusivas, art. 82 ss. TRLGDCU (🟡) | Responsabilità: doc 03 §11 |
| Conciliazione | ADR/ODR | Junta Arbitral de Consumo (🟡); ODR UE chiusa 20/07/2025 (🟡) | Informativa ADR nei termini |
| Reclami | — | Hojas de reclamaciones: obbligo regionale per stabilimenti fisici (❓ online) | ⚖️ |
| IA | AI Act art. 50 | idem; **AESIA**; legge di governance in Parlamento (BOCG 12/06/2026, 🟡) | Etichetta IA obbligatoria dal 02/08/2026 |
| Accessibilità | D.Lgs. 82/2022 | Ley 11/2023 (❓ non verificata) | ⚖️ |
| Piattaforme | DSA + AGCOM | DSA + CNMC (❓) | Segnalazioni, motivazione delle rimozioni |
| Veterinari | FNOVI, ricetta elettronica | Colegios + Consejo General; **Ley 44/2003** ✅; **RD 666/2023** ✅ | Nessuna diagnosi/prescrizione |
| Ricetta | Ricetta elettronica veterinaria | Solo dopo **esame clinico** (art. 32.2 ✅); vendita a distanza Rx **vietata** ✅ | Nessun rimando a shop Rx |
| Animali (vendita) | Legge e Regioni | **Ley 7/2023**: vendita online di animali da compagnia **vietata** (art. 57.1 ✅); cani/gatti/furetti solo da allevatore registrato (art. 55.1 ✅); cessione gratuita con contratto (art. 58.2 ✅) | Mercatino senza animali vivi |
| Obblighi del proprietario | Anagrafe canina | Corso per tenere cani e assicurazione RC (art. 30 ✅, regolamento ❓); microchip (art. 51) | Contenuti informativi, non obbligo dell'app |
| Giurisdizione | Una | Comunidades Autónomas con norme proprie su animali e consumo | Clausola di legge applicabile (doc 03 §15) |

## Formati e linguaggio

| Voce | Italia | Spagna | Note |
|---|---|---|---|
| Lingua | it | **es-ES** (spagnolo, **«usted»** nei testi legali) | La UI su MULTILANG (`app_es.arb`) usa «tú»: decidere (doc 08 d.6). Una sola traduzione UI per tutta l'area ispanofona; i testi **legali** hanno versione propria per paese |
| Data | `gg/mm/aaaa` | **`dd/MM/yyyy`** (14/10/2026) | Mese esteso: «14 de octubre de 2026». Formato salvato al backend invariato |
| Ora | 24 ore | 24 ore (`14:30`) | Uguale |
| Primo giorno della settimana | lunedì | lunedì | Uguale |
| Valuta | € (1.234,56 €) | **€** (1.234,56 €) | Stesso formato; IVA ordinaria 21% (🟡), servizi digitali a consumatori UE: OSS ⚖️ |
| Prezzi | IVA inclusa | **IVA incluida** (LSSI art. 10 ✅ chiede di indicare se includono imposte) | «IVA incluido» |
| Distanza | km | km | Uguale |
| Peso | kg | kg | Uguale |
| Temperatura | °C | °C | Uguale |
| Telefono | `+39 3xx xxx xxxx` | `+34 6xx xx xx xx` (cellulare), `91 xxx xx xx` (Madrid) | Numero fittizio di esempio: ❓ non verificato che sia riservato a finzione |
| Indirizzo | via, civico, CAP, città | **Calle + número, código postal (5 cifre), localidad, provincia** | Campo «Provincia» (in Spagna è parte standard dell'indirizzo) |
| Emergenza persone | 112 | 112 | Per animali: doc 06 |
| Veterinario | «veterinario» | «veterinario/a», «clínica veterinaria», «urgencias veterinarias» | Preferire forma neutra |
| Microchip | obbligatorio per cani | obbligatorio per cani, gatti, furetti (Ley 7/2023 art. 51 ✅) | Contenuti informativi |
| Passaporto | europeo | europeo | Uguale |
| Autorità animali | ASL, Comune | Ayuntamiento, CCAA, SEPRONA | Doc 06 |
| Termini d'uso | «Termini di Servizio» | «Condiciones de uso» (o «Términos y condiciones») | |
| Politica privacy | «Informativa» | «Política de privacidad» | |
| Avviso IA | — | «Aviso sobre la IA» | |
| Aree cani | «area cani» | «área para perros» / «pipicán» / «parque canino» | Scegliere un termine ❓ |

## Cosa cambiare nell'app (indicativo, per la sessione Formati e store)

1. Voce «Información legal» nelle Impostazioni e nello store.
2. Campo indirizzo: «Código postal» (5 cifre), «Provincia».
3. Numeri utili per paese (doc 06): SIT 91 562 04 20 con la frase «orienta, no sustituye al veterinario».
4. Consensi per `es-ES` (doc 04); lingua mostrata salvata.
5. Etichette IA e disclaimer (doc 05).
6. Pulsanti «Pedido con obligación de pago», «Darme de baja», «Desistir del contrato» sulla web app; avviso di rinnovo a 15 giorni (doc 03 §5).
7. Mercatino: togliere «animali vivi» nella UI della Spagna.

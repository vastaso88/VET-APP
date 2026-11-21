# Regole del Mercatino (v1): testo da mostrare con la casella di accettazione

Data: 2026-11-21. Richiesta della UI/UX dopo il parere [23](23_consensi_in_contesto_e_regole_mercatino.md). Proposta della Normativa, in attesa del sì del proprietario ai testi. Non è consulenza legale; ⚖️ per un legale. Il testo ricalca i Termini ([it/03](it/03_termini_di_servizio_it.md) §8): se uno cambia, cambia anche l'altro.

**Natura**: è un'**accettazione** (condizione per usare il Mercatino), non un consenso GDPR. Chiave proposta: `marketplace_rules`, versione `v1`, versione e data registrate come per `contribution_rules`. La spunta si mostra al primo accesso; pubblicare un annuncio e scrivere un messaggio vanno bloccati **anche lato server** finché non c'è l'accettazione della versione attuale. Se il testo cambia in modo sostanziale: versione nuova e nuova accettazione.

**Casella** (non pre-spuntata, con il collegamento alle regole): «Ho letto e accetto le regole del Mercatino».

## Testo (italiano, v1)

**Regole del Mercatino**

1. **Solo oggetti per animali.** Gli animali non si possono vendere, regalare né scambiare, in nessun paese.
2. **Niente farmaci.** Non si possono vendere né regalare farmaci o medicinali, anche veterinari, nemmeno senza ricetta. Cibo, integratori e accessori sono ammessi. L'app blocca molti annunci che nominano un medicinale, non tutti: se ne vedi uno, segnalalo.
3. **Solo privati.** Vendi o regali oggetti usati come persona privata, non nell'ambito di un'attività commerciale o professionale. Quokka non verifica la dichiarazione.
4. **Annunci onesti.** Descrivi l'oggetto com'è. Niente merci illecite, contraffatte o pericolose, niente dati personali di altre persone, niente telefoni, e-mail, siti o profili social nel testo.
5. **Quokka mette in contatto due privati e non è parte della compravendita.** Prezzo, pagamento, consegna e garanzie riguardano solo te e l'altra persona. Non verifichiamo annunci, oggetti o persone. Non pagare in anticipo a chi non conosci; se scambi i contatti nei messaggi, lo fai sotto la tua responsabilità.
6. **Solo maggiorenni.** Il Mercatino, messaggi compresi, è riservato a chi ha almeno 18 anni.
7. **Messaggi.** Solo testo. Puoi bloccare una persona o segnalare una conversazione in ogni momento. **Se una conversazione viene segnalata, da te o dall'altra persona, il team di Quokka può leggerla, solo per valutare la segnalazione.**
8. **Dopo una segnalazione** possiamo chiudere la conversazione, nascondere o rimuovere un annuncio o tenerti fuori dal Mercatino. Ti diciamo il motivo e la data, nella tua lingua, e come chiedere un riesame da Impostazioni → Contattaci.

Le regole complete sono nei Termini di Servizio (§8).

## Stato

- **Controllo del 21 novembre sera sul codice** (`account_consent_text.py`, main 9ae05bc): il testo italiano coincide **parola per parola** con questo documento (chiave `marketplace_rules`, versione `v1`). La bozza inglese nel codice è fedele, con due correzioni: (1) nel testo inglese dell'app la funzione si chiama «marketplace» (titolo «Second-hand marketplace»), non «Mercatino»: vale anche per il titolo e la casella («Marketplace rules», «I have read and accept the marketplace rules»); (2) «at your own risk» diventa «on your own responsibility», perché «at your own risk» si legge come un esonero di responsabilità, che il testo italiano («sotto la tua responsabilità») evita. ES, DE e FR: servite in inglese finché non ci sono le traduzioni riviste, mai in italiano.
- Il blocco lato server (`MARKETPLACE_RULES_REQUIRED`) resta spento fino al sì del proprietario ai testi. Se in futuro il testo cambia in modo sostanziale: `v2` e nuova accettazione. Nelle Impostazioni **non** come interruttore: al massimo una riga informativa («Regole del Mercatino accettate, v1, il …»).
- Il rinvio «(§8)» è la sezione del Mercatino nei Termini italiani: controllare che nei Termini mostrati in app nelle altre lingue resti lo stesso numero.
- ⚖️ Se la casella, con il punto 7, basta come accettazione specifica della lettura delle conversazioni segnalate ([23](23_consensi_in_contesto_e_regole_mercatino.md) §4).

### Testo inglese rivisto (v1)

**Marketplace rules**

1. **Only items for animals.** Animals cannot be sold, given away or exchanged, in any country.
2. **No medicines.** Medicines, including veterinary ones, cannot be sold or given away, even without a prescription. Food, supplements and accessories are allowed. The app blocks many listings that name a medicine, not all: if you see one, report it.
3. **Private sellers only.** You sell or give away used items as a private person, not as part of a commercial or professional activity. Quokka does not verify the declaration.
4. **Honest listings.** Describe the item as it is. No illegal, counterfeit or dangerous goods, no personal data of other people, no phone numbers, emails, websites or social profiles in the text.
5. **Quokka connects two private individuals and is not a party to the sale.** Price, payment, delivery and warranties concern only you and the other person. We do not verify listings, items or people. Do not pay in advance to someone you do not know; if you exchange contacts in messages, you do so on your own responsibility.
6. **Adults only.** The marketplace, messages included, is for people aged 18 or over.
7. **Messages.** Text only. You can block a person or report a conversation at any time. **If a conversation is reported, by you or by the other person, the Quokka team may read it, only to assess the report.**
8. **After a report** we may close the conversation, hide or remove a listing, or keep you out of the marketplace. We tell you the reason and the date, in your language, and how to ask for a review from Settings → Contact us.

The full rules are in the Terms of Service (§8).

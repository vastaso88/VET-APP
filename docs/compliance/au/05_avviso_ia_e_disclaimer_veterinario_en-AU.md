> **BOZZA — non è consulenza legale; da rivedere da un solicitor australiano prima della pubblicazione**

# Avviso IA e disclaimer veterinario (en-AU)

Testi per gli utenti in inglese australiano. Base: `docs/compliance/01_ai_disclosure.md` (badge `AiDisclosureBadge`, campo `ai_generated`) e il filone «anamnesi prima della risposta» della chat. Ricerca: `01_ricerca_normativa.md` sez. 5 e 6.

## Principi (italiano)

1. **In Australia non c'è un obbligo di legge generale come l'art. 50 dell'AI Act.** Il badge IA resta per coerenza, per la guida OAIC sulla trasparenza e per le pratiche volontarie DISR. Le affermazioni sull'accuratezza devono essere vere (ACL, pratiche ingannevoli).
2. **Quokka non è un veterinario.** Le leggi statali regolano i veterinari registrati; la diagnosi a distanza è un atto riservato (almeno in NSW). Quindi: informazioni generali, orientamento, mai diagnosi né prescrizione, mai dosaggi di farmaci su prescrizione per un animale specifico.
3. **Emergenza → veterinario subito.** Nei sintomi gravi la chat dice «vai da un veterinario ora» prima di ogni altra cosa. Questo è il comportamento già descritto dal triage di sicurezza italiano (risposte rule-based, `ai_generated=False`).
4. I numeri in questo testo (000, Animal Poisons Helpline) sono verificati nel file 06 con la data di consultazione. Se cambiano, aggiornare qui.

## 1. Etichetta breve sul messaggio (badge)

> **AI-generated.** This reply was written by an AI system and may be wrong.

## 2. Schermata di benvenuto (una volta)

> **About the assistant**
> Quokka's assistant uses artificial intelligence (AI) to write general information about your pet's health and care. It is not a veterinarian. It cannot examine your animal, diagnose a condition or prescribe medicine.
>
> It can make mistakes, and its replies are always labelled as AI-generated. Use them as a starting point and check anything important with a registered veterinarian, especially if your pet seems unwell.
>
> **If it's an emergency, don't wait: call your nearest veterinary clinic or emergency hospital now.**

## 3. Nota sotto il campo chat (sempre visibile)

> General information only. Not a vet. In an emergency, call a vet now.

## 4. Quando la chat riconosce un'emergenza (risposta fissa, non generata da IA)

> This could be serious. Please **call a veterinarian or your nearest emergency veterinary clinic now**. Don't wait to see if it improves.
>
> If your pet may have eaten something poisonous, call the **Animal Poisons Helpline on 1300 869 738** [confirm hours — see file 06] while you are on your way.
>
> I can't diagnose or treat your pet, but I can help you note down what happened so you can tell the vet.

## 5. Dosaggi e farmaci (risposta tipo)

> I can't tell you what dose of a medicine to give. The right dose depends on your pet's weight, health and other medicines, and some human medicines are dangerous for pets. Please ask a registered veterinarian or a pharmacist who treats animals. If you have already given something, call a vet or the Animal Poisons Helpline on **1300 869 738** now.

*(Nota per la sessione Chat: è la traduzione in spirito del «dosage-safety-gate» italiano; il testo italiano ha una nota aperta sulla frase illogica. Non toccare codice qui.)*

## 6. Disclaimer completo (Impostazioni → Informazioni → Assistente)

> **AI and vet advice notice**
>
> **What the assistant is.** Quokka's assistant is an artificial intelligence (AI) system. It gives general information about pets. It does not know your animal, examine it or see its full history, unless you share it.
>
> **What it is not.** It is not a veterinarian or a veterinary service. It does not diagnose, treat or prescribe. A reply is not a substitute for care from a veterinarian registered in your state or territory.
>
> **It can be wrong.** AI can give information that is incomplete, out of date or incorrect. Replies are labelled as AI-generated so you can tell.
>
> **Emergencies.** If your pet is collapsed, having trouble breathing, bleeding, in a seizure, has been in a hot car, bitten by a snake or tick-paralysed, or may have eaten something toxic: **contact a vet immediately.** Don't use the app to decide whether to wait.
>
> **Your health records.** If you allow it, the assistant can read your pet's recent records to give more accurate advice. You can withdraw that permission at any time.
>
> **Privacy.** What you send to the assistant is processed by an external AI provider, which may be outside Australia. See our Privacy Policy.
>
> **Your rights.** Nothing here limits your rights under the Australian Consumer Law.

## 7. Note per il revisore (da eliminare prima della pubblicazione)

1. **Esempi di emergenza** nel testo (serpente, paralisi da zecca, auto calda): sono specifici del contesto australiano. Il solicitor/veterinario consulente confermi l'elenco. Non sono parte delle regole italiane.
2. **«Not a vet»**: l'espressione non deve far credere che l'app abbia un rapporto veterinario–cliente. In SA, senza VCPR i consigli devono restare **generali, non su un animale specifico, senza diagnosi né trattamento** (fonte: [VSRBSA](https://vsrb.sa.gov.au/information-sheet/telemedicine/)). Il comportamento reale della chat (dare una raccomandazione sul sintomo di *quel* pet) va confrontato con questo limite → decisione di prodotto (domanda 5 al proprietario).
3. **Se in futuro si collegano veterinari registrati** (teleconsulto), serve una valutazione separata per ogni stato/territorio: registrazione nello stato dell'animale, consenso, VCPR, prescrizioni.
4. **IA companion/eSafety:** il testo non presenta l'assistente come «amico» o «compagno»; mantenere così per restare fuori dai codici sui chatbot compagni (incertezza in `01`, sez. 4).

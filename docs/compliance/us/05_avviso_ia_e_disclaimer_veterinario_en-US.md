> **BOZZA — non è consulenza legale; da rivedere da un avvocato abilitato negli USA prima della pubblicazione**

# Avviso IA e disclaimer veterinario (en-US)

Testi per l'app USA, in inglese americano semplice. Coerenti con `docs/compliance/01_ai_disclosure.md` (badge `ai_generated`) e con la ricerca in `01_ricerca_normativa.md` (sez. 4.1, 6, 7). Principio guida: **informazione e triage, non diagnosi né prescrizione**. Non scrivere in nessun punto che l'assistente "è un veterinario", "diagnostica", "sostituisce la visita" o è "accurato/sicuro" senza prove (FTC Section 5).

## 1. AI and Veterinary Notice (pagina completa, richiamata da Termini e Impostazioni)

```
AI and Veterinary Notice

Quokka's assistant is powered by artificial intelligence (AI). Here is what that means for you and your pet.

1. It's AI, not a person. Answers are written by an AI system run by an outside provider. Answers from the AI are labeled "AI-generated" in the app. Some messages (for example, safety warnings) are written by Quokka, not by the AI.

2. It's not a veterinarian. Quokka and its assistant are not veterinarians and do not provide veterinary care. The assistant gives general information to help you understand your pet's situation and decide what to do next. It does not diagnose conditions, prescribe medicine, or tell you the right dose of a drug for your pet. No veterinarian-client-patient relationship is created by using Quokka.

3. It can be wrong. AI can give answers that are incomplete, out of date, or incorrect. It may not know everything about your pet, your region, or the medicines you have. Don't rely on it alone for decisions about your pet's health.

4. Always see a veterinarian when it matters. Contact a veterinarian if your pet is sick, hurt, or just "not right," if symptoms last or get worse, before giving any medicine, supplement, or home remedy, and before changing food or treatment.

5. Emergencies. If you think your pet may be in an emergency, don't wait for the assistant: call your veterinarian or the nearest 24-hour emergency animal hospital now. If your pet may have eaten something toxic, call an animal poison control service right away. Numbers are in the app under Emergency numbers.
   Emergency signs can include trouble breathing, collapse, seizures, severe bleeding, a swollen or hard belly, repeated vomiting, inability to urinate, suspected poisoning, heatstroke, or serious injury. This list is not complete.

6. Your information. What you type, upload, or record in the chat is sent to the AI provider to write the answer. Some personal details may be removed first, but not all. See the Privacy Policy. Your pet's health record is shared with the assistant only if you allow it.

7. Medicines and amounts. The assistant will not give you a dose for your pet. Ask your veterinarian or pharmacist. Never give your pet human medicine unless a veterinarian tells you to.
```

## 2. Microcopy per le superfici dell'app

| Dove | Testo (en-US) |
|---|---|
| Badge sulle risposte `ai_generated = true` | `AI-generated` |
| Sotto il campo di scrittura della chat (sempre visibile) | `AI can make mistakes. Not veterinary advice. In an emergency, call a vet.` |
| Prima apertura della chat (schermata singola) | `Meet your AI assistant. It gives general pet information and helps you decide what to do next. It's not a veterinarian and can't diagnose or prescribe. If your pet may be in an emergency, call a vet or poison control now.` — pulsanti: `Got it` / `See emergency numbers` |
| Risposta di triage "urgente" (templata, `ai_generated = false`) | `This may be urgent. Please contact a veterinarian or an emergency animal hospital now. We can show you nearby clinics and emergency numbers.` |
| Risposta di triage "possibile veleno" | `If your pet may have swallowed something harmful, call an animal poison control service right away — don't wait for symptoms. We can show you the numbers.` |
| Quando l'utente chiede una diagnosi | `I can't diagnose your pet. I can share general information and help you prepare questions for your vet. Would you like to describe what you've noticed?` |
| Quando l'utente chiede un dosaggio | `I can't give you a dose for your pet. Please ask your veterinarian or pharmacist.` (verificare che il *dosage safety gate* esistente usi una frase coerente) |
| Spiegazione di un referto | `This is general information about what this kind of test usually measures. It is not an interpretation of your pet's results. Please go over them with your vet.` |
| Footer di ogni risposta a tema salute (opzionale, se la UI lo permette) | `General information only — talk to your veterinarian.` |
| Schermata del consenso cartella clinica | vedi 04 (`medical_record_consent`) |
| Scheda dello store (descrizione) | `[app name] organizes your pet's information and offers an AI assistant for general pet information. It is not a veterinarian and doesn't replace professional veterinary care.` |
| Scheda dello store, note per Apple/Google | `AI assistant for pet owners. Not a medical device. Not veterinary advice.` (verificare con Apple 1.4.1 e con la categoria dell'app) |

## 3. Cose da NON dire (marketing, store, sito)

- "Diagnose your pet," "your AI vet," "virtual veterinarian," "vet-approved" (a meno di prova reale), "100% accurate," "safe dosage," "replaces expensive vet visits."
- Titoli professionali ("Dr.", "DVM") per l'assistente o per account non reali.
- Testimonianze o recensioni non vere o incentivate senza dichiarazione (FTC Endorsement Guides / regola sulle recensioni false).
- "HIPAA compliant" (HIPAA riguarda dati di persone e non si applica automaticamente; non è un claim da fare).

## 4. Punti da far valutare al legale

- Se il disclaimer debba avere una forma specifica per stato (alcuni stati: California AB 1399 per la telehealth; non per le app informative — non verificato).
- Se la parola "triage" sia accettabile in marketing o vada evitata in alcuni stati.
- Se l'assistente debba rifiutare più rigidamente le richieste di dosaggio e prescrizione (il *dosage safety gate* già esistente lo fa in parte; revisione necessaria con termini USA: lb, farmaci americani).
- Se serva un pulsante "Report this answer" per la policy Google sull'IA (segnalazione in-app dei contenuti IA problematici).

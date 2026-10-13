> **BOZZA — non è consulenza legale; da rivedere da un solicitor del Regno Unito prima della pubblicazione**
> DRAFT — not legal advice; to be reviewed by a UK solicitor before publication.

# Avviso IA e disclaimer veterinario — en-GB (v1 bozza)

Data: 2026-10-13. Base normativa: Veterinary Surgeons Act 1966 ss. 19 e 27 (diagnosi e consulenza basata sulla diagnosi sono atti di «veterinary surgery»), RCVS Supporting Guidance (cap. 3 e 4), consumer law e ASA/CAP (non promettere ciò che l'IA non fa). Dettagli e incertezze in `01_ricerca_normativa.md` §7–§9. Il UK non ha un obbligo generale di etichettare i contenuti IA come l'art. 50 dell'AI Act UE; l'etichetta è mantenuta per coerenza e buona prassi.

**Linee guida di redazione (italiano)**

- Mai le parole «diagnosis», «diagnose», «prescribe», «replaces your vet» riferite a ciò che l'app *fa*. Sì a «general information», «helps you prepare», «talk to your vet».
- L'assistente non indica dosaggi di farmaci né suggerisce farmaci per uso su animali. Per i farmaci su prescrizione (POM-V) serve un veterinario che abbia l'animale in cura (RCVS cap. 4).
- In caso di segnali di emergenza, il messaggio indirizza al veterinario *subito*, con i numeri del doc 06.
- Chiavi consigliate per l'ARB (prefisso `legalAi…`), uno per frase.

---

## 1. Primo utilizzo (schermata una tantum)

**Title:** About the assistant

```
VetApp's assistant is an artificial intelligence (AI). Its answers are written by an AI system and are always marked as "AI-generated".

It gives general information to help you look after your pet. It does not diagnose, prescribe or treat, and it is not a substitute for a veterinary surgeon. It can make mistakes.

If your pet is unwell, in pain or you are unsure, contact your vet. In an emergency, go to a vet straight away.
```

Buttons: **I understand** · **Read the AI Notice**

## 2. Etichetta sulle risposte generate da IA

```
AI-generated
```

Tooltip / accessibility label:

```
This answer was written by an AI system. It may contain mistakes.
```

(Come oggi: risposte templated/rule-based, come il triage di sicurezza, non portano il badge. Vedi `docs/compliance/01_ai_disclosure.md`.)

## 3. Piè di pagina della chat (sotto il campo di scrittura)

```
VetApp gives general information, not veterinary advice. Always speak to your vet about your pet's health.
```

## 4. Banner di emergenza (mostrato quando il triage rileva segnali gravi)

```
This could be an emergency.
Contact a vet now. If you cannot reach your own vet, call an out-of-hours emergency vet.
If your pet may have eaten something poisonous, call Animal PoisonLine on 01202 509 000 (24 hours, there is a fee) or your vet.
```

Il numero e la tariffa vanno confermati prima della pubblicazione (doc 06). Se un utente può essere fuori dal UK (viaggi), il banner mostra i numeri del *paese impostato nell'app*.

## 5. Avviso sui farmaci

```
VetApp does not recommend medicines or doses. Never give your pet human medicines, or any medicine that was not prescribed for that animal, unless your vet tells you to. Some are poisonous to animals.
```

## 6. Avviso sulla lettura di analisi e documenti («spiegami questo esame»)

```
This explanation is general and may be incomplete. Only your vet, who knows your pet, can say what a result means for them.
```

## 7. Avviso sull'analisi di foto o video

```
A photo or video cannot show everything. The assistant can describe what it sees in general terms, but it cannot tell you what is wrong. If something worries you, see your vet.
```

## 8. AI Notice (pagina completa, richiamata dalle Impostazioni)

**AI Notice — how VetApp uses AI**

```
How the assistant works
When you ask the assistant a question, we send your message, and anything you attach, to an external AI provider that writes the answer. Answers are marked "AI-generated". Before sending text, we automatically remove some personal details, such as email addresses and phone numbers. This does not catch everything, so please do not type information you do not want shared.

Your pet's health record
The assistant can read your pet's health record only if you allow it, for each pet. You can withdraw this at any time. See "Permissions and consents" in Settings.

What the assistant does not do
It does not diagnose illness or injury, prescribe medicines, tell you which medicine or dose to give, or replace an examination by a veterinary surgeon. Only a registered veterinary surgeon can do those things in the UK.

Mistakes
AI can be wrong, out of date, or miss something important. Check what it tells you with your vet, especially about symptoms, food, medicines or behaviour that is getting worse.

Emergencies
The assistant is not an emergency service. If you think your pet is in danger, contact a vet immediately.

Decisions about you
We do not use the assistant to make decisions that have legal or similarly significant effects on you.

Your information
See our Privacy Notice for how we handle your information, including the AI provider.

Questions or concerns
Email [privacy/support address]. You can also complain to the Information Commissioner's Office.
```

## 9. Scheda dello store e testi marketing (indicazioni)

- Sì: «Keep your pet's records, reminders and walks in one place», «AI assistant for general pet care information», «Find pet-friendly places near you».
- No: «virtual vet», «diagnose your pet», «instant vet advice», «AI vet», «replaces a vet visit», «for emergencies».
- Motivo: ASA/CAP sulle app di salute con IA (non suggerire che sostituisca un professionista) e VSA s. 27.

## 10. Punti per il solicitor

1. Confermare che il comportamento descritto (informazioni generali, nessuna diagnosi/prescrizione) resta fuori da s. 27 VSA 1966. In particolare: la chat può formulare *ipotesi* sulle cause di un sintomo? E dire «probabilmente è X»? La linea più prudente è no.
2. Verificare le eccezioni per i proprietari (Schedule 3 del VSA, non letta) e se un veterinario *che usa* VetApp cambia il quadro (RCVS telemedicina).
3. Confermare che le schede dello store non violano i codici ASA/CAP.
4. Verificare se il «triage di sicurezza» (domande a risposta chiusa → «go to a vet now») conta come consulenza e come va formulato.

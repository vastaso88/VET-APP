> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> ENTWURF — keine Rechtsberatung; vor der Veröffentlichung von einer Rechtsanwältin oder einem Rechtsanwalt in Deutschland prüfen zu lassen.

# Avviso IA e disclaimer veterinario — de-DE (v1 bozza)

Data: 2026-10-14. Base normativa: **AI Act art. 50 par. 1** (in vigore dal 02/08/2026; l'etichetta qui non è solo buona prassi ma un obbligo), BTK Empfehlungen Telemedizin 01/04/2020 (diagnosi finale solo dopo visita, nessuna prescrizione Rx a distanza), TAMG § 30, HWG § 10 (nessun nome commerciale di farmaci Rx), UWG/HWG su pubblicità ingannevole. Dettagli e incertezze in `01_ricerca_normativa.md` §6–§7.

**Linee guida di redazione (italiano)**

- Mai «Diagnose», «diagnostizieren», «verschreiben», «ersetzt Ihre Tierärztin / Ihren Tierarzt» riferiti a ciò che l'app *fa*. Sì a «allgemeine Informationen», «hilft Ihnen, sich vorzubereiten», «sprechen Sie mit Ihrer Tierarztpraxis».
- L'assistente non indica dosaggi di farmaci né suggerisce farmaci per uso su animali e **non cita nomi commerciali di medicinali soggetti a prescrizione** (HWG § 10 secondo la BTK). Per i Rx serve un veterinario che conosce l'animale (BTK).
- In caso di segnali di emergenza il messaggio indirizza al veterinario *subito*, con i riferimenti del doc 06.
- Chiavi consigliate per l'ARB (prefisso `legalAi…`), una per frase.
- Il titolo dell'etichetta deve riconoscere la natura dell'IA in modo chiaro: la sola parola «Assistent» non basta (linee guida art. 50, fonte secondaria, doc 01 §6).

---

## 1. Primo utilizzo (schermata una tantum)

**Title:** Über den Assistenten

```
Der Assistent von VetApp ist eine künstliche Intelligenz (KI). Seine Antworten werden von einem KI-System geschrieben und sind immer als „KI-generiert“ gekennzeichnet.

Er gibt allgemeine Informationen, damit Sie Ihr Tier gut versorgen können. Er stellt keine Diagnosen, verschreibt nichts und behandelt nicht, und er ersetzt keine Tierärztin und keinen Tierarzt. Er kann sich irren.

Wenn Ihr Tier krank wirkt, Schmerzen hat oder Sie unsicher sind, wenden Sie sich an Ihre Tierarztpraxis. Im Notfall gehen Sie sofort zu einer Tierärztin oder einem Tierarzt.
```

Buttons: **Verstanden** · **KI-Hinweis lesen**

## 2. Etichetta sulle risposte generate da IA

```
KI-generiert
```

Tooltip / accessibility label:

```
Diese Antwort wurde von einem KI-System geschrieben. Sie kann Fehler enthalten.
```

(Risposte templated/rule-based, come il triage di sicurezza, non portano il badge. Vedi `docs/compliance/01_ai_disclosure.md`. Per l'art. 50 il badge su ogni risposta + la schermata del primo uso soddisfano l'esempio «avviso all'inizio della sessione / indicatore permanente», 🟡 fonte secondaria.)

## 3. Piè di pagina della chat (sotto il campo di scrittura)

```
VetApp gibt allgemeine Informationen, keinen tierärztlichen Rat. Sprechen Sie bei Fragen zur Gesundheit Ihres Tieres immer mit Ihrer Tierarztpraxis.
```

## 4. Banner di emergenza (mostrato quando il triage rileva segnali gravi)

```
Das könnte ein Notfall sein.
Wenden Sie sich jetzt an eine Tierärztin oder einen Tierarzt. Wenn Sie Ihre Praxis nicht erreichen, suchen Sie den tierärztlichen Notdienst oder die nächste Tierklinik auf.
Wenn Ihr Tier möglicherweise etwas Giftiges gefressen hat, rufen Sie sofort Ihre Tierarztpraxis oder den tierärztlichen Notdienst an.
```

Nota: in Germania **non esiste** un numero nazionale per avvelenamenti di animali (doc 06). Il banner non mostra alcun numero finché il proprietario non ne conferma uno verificato; mostra «Tierarzt/Notdienst» e il link dell'ordine dei veterinari del Land. Se un utente può essere fuori dalla Germania (viaggi), il banner mostra i riferimenti del *paese impostato nell'app*.

## 5. Avviso sui farmaci

```
VetApp empfiehlt keine Arzneimittel und keine Dosierungen. Geben Sie Ihrem Tier niemals Humanarzneimittel oder Arzneimittel, die nicht für dieses Tier verordnet wurden, es sei denn, Ihre Tierärztin oder Ihr Tierarzt rät dazu. Manche sind für Tiere giftig.
```

## 6. Avviso sulla lettura di analisi e documenti («spiegami questo esame»)

```
Diese Erklärung ist allgemein und kann unvollständig sein. Nur Ihre Tierärztin oder Ihr Tierarzt, die oder der Ihr Tier kennt, kann sagen, was ein Ergebnis für Ihr Tier bedeutet.
```

## 7. Avviso sull'analisi di foto o video

```
Ein Foto oder Video zeigt nicht alles. Der Assistent kann beschreiben, was er sieht, aber nicht sagen, was Ihrem Tier fehlt. Wenn Sie etwas beunruhigt, gehen Sie zu Ihrer Tierarztpraxis.
```

## 8. KI-Hinweis (pagina completa, richiamata dalle Impostazioni)

**KI-Hinweis – wie VetApp KI einsetzt**

```
So funktioniert der Assistent
Wenn Sie dem Assistenten eine Frage stellen, senden wir Ihre Nachricht und alles, was Sie anhängen, an einen externen KI-Anbieter, der die Antwort schreibt. Antworten sind als „KI-generiert“ gekennzeichnet. Bevor wir Text senden, entfernen wir automatisch einige persönliche Angaben, etwa E-Mail-Adressen und Telefonnummern. Das erfasst nicht alles; bitte geben Sie keine Informationen ein, die nicht weitergegeben werden sollen.

Die Gesundheitsakte Ihres Tieres
Der Assistent darf die Gesundheitsakte Ihres Tieres nur lesen, wenn Sie es für jedes Tier erlauben. Sie können das jederzeit widerrufen. Siehe „Berechtigungen und Einwilligungen“ in den Einstellungen.

Was der Assistent nicht tut
Er stellt keine Diagnosen für Krankheiten oder Verletzungen, verschreibt keine Arzneimittel, nennt keine Dosierungen und ersetzt keine tierärztliche Untersuchung. Das darf in Deutschland nur eine Tierärztin oder ein Tierarzt nach Untersuchung Ihres Tieres.

Fehler
KI kann sich irren, veraltet sein oder etwas Wichtiges übersehen. Klären Sie das, was sie Ihnen sagt, mit Ihrer Tierarztpraxis, besonders bei Symptomen, Futter, Arzneimitteln oder Verhalten, das schlimmer wird.

Notfälle
Der Assistent ist kein Notdienst. Wenn Sie glauben, dass Ihr Tier in Gefahr ist, wenden Sie sich sofort an eine Tierärztin oder einen Tierarzt.

Entscheidungen über Sie
Wir nutzen den Assistenten nicht, um Entscheidungen zu treffen, die Ihnen gegenüber rechtliche Wirkung entfalten oder Sie in ähnlicher Weise erheblich beeinträchtigen.

Ihre Daten
In der Datenschutzerklärung steht, wie wir mit Ihren Daten umgehen, einschließlich des KI-Anbieters.

Fragen oder Bedenken
Schreiben Sie an [Datenschutz-/Support-Adresse]. Sie können sich auch bei einer Datenschutz-Aufsichtsbehörde beschweren.
```

## 9. Scheda dello store e testi marketing (indicazioni)

- Sì: «Akten, Erinnerungen und Spaziergänge für Ihr Tier an einem Ort», «KI-Assistent für allgemeine Informationen zur Tierpflege», «Tierfreundliche Orte in Ihrer Nähe finden».
- No: «virtueller Tierarzt», «Diagnose für Ihr Tier», «Tierarzt per App», «KI-Tierarzt», «ersetzt den Tierarztbesuch», «für Notfälle», nomi commerciali di farmaci Rx.
- Motivo: UWG (pratiche ingannevoli), HWG (§ 10 secondo BTK), art. 50 AI Act, e rischio di essere considerati offerta telemedica (BTK: legata a un veterinario in sede). ⚖️ da far confermare.

## 10. Punti per l'avvocato

1. Confermare che il comportamento descritto (informazioni generali, nessuna diagnosi/prescrizione) resta fuori dalle norme professionali dei Länder e dalla pubblicità sanitaria (HWG, UWG). In particolare: la chat può formulare *ipotesi* («wahrscheinlich ist es X»)? La BTK ammette al massimo diagnosi di sospetto *a un veterinario*; la linea prudente per VetApp è no.
2. Verificare se il «triage di sicurezza» (domande chiuse → «jetzt zur Tierärztin/zum Tierarzt») conta come consulenza e come va formulato.
3. Confermare ruolo (fornitore) e testo definitivo dell'art. 50 AI Act, e se «KI-generiert» + schermata del primo uso bastano.
4. Verificare che le schede dello store non violino UWG/HWG.
5. Verificare se un veterinario che *usa* VetApp (o lo raccomanda) cambia il quadro (Berufsordnung del Land, pubblicità).

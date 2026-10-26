> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> ENTWURF — keine Rechtsberatung; vor der Veröffentlichung von einer Rechtsanwältin oder einem Rechtsanwalt in der Schweiz prüfen zu lassen.

# Avviso IA e disclaimer veterinario — de-CH (v1 bozza)

Data: 2026-10-14. Base normativa: nessuna legge svizzera generale sull'IA (Bundesrat 12/02/2025; consultazione attesa entro fine 2026, 🟡 `ch/01` §5); l'avviso è mantenuto perché **VetApp è un sistema offerto nell'UE** (AI Act art. 50, obbligo dal 02/08/2026) e per coerenza; TAMV art. 10 (Rx solo se si conosce l'animale, 🟡), Swissmedic (diagnosi fondata = veterinario, 🟡), UWG (non promettere ciò che l'IA non fa). Dettagli e incertezze in `ch/01` §5–§6.

**Linee guida di redazione (italiano)**

- Mai «Diagnose», «diagnostizieren», «verschreiben», «ersetzt Ihre Tierärztin / Ihren Tierarzt», «Tierarzt per App», riferiti a ciò che l'app *fa*. Sì a «allgemeine Informationen», «hilft Ihnen, sich vorzubereiten», «sprechen Sie mit Ihrer Tierarztpraxis».
- Nessun dosaggio, nessun farmaco consigliato, nessuna ipotesi diagnostica.
- Chiavi per l'ARB: prefisso `legalAi…`, una per frase.
- Testo come `de-DE` con **ortografia svizzera** e il rimando alla **Tierarztpraxis / zum Tierspital**.

---

## 1. Primo utilizzo (schermata una tantum)

**Title:** Über den Assistenten

```
Der Assistent von VetApp ist eine künstliche Intelligenz (KI). Seine Antworten werden von einem KI-System geschrieben und sind immer als «KI-generiert» gekennzeichnet.

Er gibt allgemeine Informationen, damit Sie Ihr Tier gut versorgen können. Er stellt keine Diagnosen, verschreibt nichts und behandelt nicht, und er ersetzt keine Tierärztin und keinen Tierarzt. Er kann sich irren.

Wenn Ihr Tier krank wirkt, Schmerzen hat oder Sie unsicher sind, wenden Sie sich an Ihre Tierarztpraxis. Im Notfall gehen Sie sofort zu einer Tierärztin oder einem Tierarzt oder in ein Tierspital.
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

## 3. Piè di pagina della chat

```
VetApp gibt allgemeine Informationen, keinen tierärztlichen Rat. Sprechen Sie bei Fragen zur Gesundheit Ihres Tieres immer mit Ihrer Tierarztpraxis.
```

## 4. Banner di emergenza (triage rileva segnali gravi)

```
Das könnte ein Notfall sein.
Wenden Sie sich jetzt an eine Tierärztin oder einen Tierarzt. Wenn Sie Ihre Praxis nicht erreichen, suchen Sie den tierärztlichen Notfalldienst oder das nächste Tierspital auf.
Wenn Ihr Tier möglicherweise etwas Giftiges gefressen hat, rufen Sie sofort Ihre Tierarztpraxis oder den tierärztlichen Notfalldienst an.
```

Nota: **Tox Info Suisse (145)** è il servizio nazionale per avvelenamenti, 24 h, ma i risultati letti non confermano che consigli i **proprietari di animali** (la pagina «Poisoning in animals» esiste ma la pagina è stata 404 in questa sessione, `ch/06`). Non mostrarlo nel banner finché non è confermato con una telefonata.

## 5. Avviso sui farmaci

```
VetApp empfiehlt keine Arzneimittel und keine Dosierungen. Geben Sie Ihrem Tier niemals Humanarzneimittel oder Arzneimittel, die nicht für dieses Tier verordnet wurden, es sei denn, Ihre Tierärztin oder Ihr Tierarzt rät dazu. Manche sind für Tiere giftig.
```

## 6. Avviso sulla lettura di analisi e documenti

```
Diese Erklärung ist allgemein und kann unvollständig sein. Nur Ihre Tierärztin oder Ihr Tierarzt, die oder der Ihr Tier kennt, kann sagen, was ein Ergebnis für Ihr Tier bedeutet.
```

## 7. Avviso sull'analisi di foto o video

```
Ein Foto oder Video zeigt nicht alles. Der Assistent kann beschreiben, was er sieht, aber nicht sagen, was Ihrem Tier fehlt. Wenn Sie etwas beunruhigt, gehen Sie zu Ihrer Tierarztpraxis.
```

## 8. KI-Hinweis (pagina completa)

**KI-Hinweis – wie VetApp KI einsetzt**

```
So funktioniert der Assistent
Wenn Sie dem Assistenten eine Frage stellen, senden wir Ihre Nachricht und alles, was Sie anhängen, an einen externen KI-Anbieter, der die Antwort schreibt. Antworten sind als «KI-generiert» gekennzeichnet. Bevor wir Text senden, entfernen wir automatisch einige persönliche Angaben, etwa E-Mail-Adressen und Telefonnummern. Das erfasst nicht alles; bitte geben Sie keine Informationen ein, die nicht weitergegeben werden sollen.

Die Gesundheitsakte Ihres Tieres
Der Assistent darf die Gesundheitsakte Ihres Tieres nur lesen, wenn Sie es für jedes Tier erlauben. Sie können das jederzeit widerrufen. Siehe «Berechtigungen und Einwilligungen» in den Einstellungen.

Was der Assistent nicht tut
Er stellt keine Diagnosen für Krankheiten oder Verletzungen, verschreibt keine Arzneimittel, nennt keine Dosierungen und ersetzt keine tierärztliche Untersuchung. Eine fundierte Diagnose und die Wahl der Behandlung gehören in die Hände einer Tierärztin oder eines Tierarztes.

Fehler
KI kann sich irren, veraltet sein oder etwas Wichtiges übersehen. Klären Sie das, was sie Ihnen sagt, mit Ihrer Tierarztpraxis, besonders bei Symptomen, Futter, Arzneimitteln oder Verhalten, das schlimmer wird.

Notfälle
Der Assistent ist kein Notfalldienst. Wenn Sie glauben, dass Ihr Tier in Gefahr ist, wenden Sie sich sofort an eine Tierärztin oder einen Tierarzt.

Entscheide über Sie
Wir nutzen den Assistenten nicht, um Entscheide zu treffen, die Ihnen gegenüber eine Rechtsfolge haben oder Sie erheblich beeinträchtigen.

Ihre Daten
In der Datenschutzerklärung steht, wie wir mit Ihren Daten umgehen, einschliesslich des KI-Anbieters.

Fragen oder Bedenken
Schreiben Sie an [Datenschutz-/Support-Adresse]. Sie können sich auch an den EDÖB wenden.
```

## 9. Scheda dello store e testi marketing (indicazioni)

- Sì: «Akten, Erinnerungen und Spaziergänge für Ihr Tier an einem Ort», «KI-Assistent für allgemeine Informationen zur Tierpflege», «Tierfreundliche Orte in Ihrer Nähe finden».
- No: «virtueller Tierarzt», «Diagnose für Ihr Tier», «Tierarzt per App», «KI-Tierarzt», «ersetzt den Tierarztbesuch», «für Notfälle».
- Motivo: UWG (pubblicità ingannevole), Swissmedic (esercizio abusivo), art. 50 AI Act. ⚖️

## 10. Punti per l'avvocato

1. Confermare che informazioni generali + triage non sono esercizio della medicina veterinaria secondo il diritto cantonale e il HMG/MedBG.
2. Verificare se esiste una norma cantonale che vieta la consulenza veterinaria a distanza.
3. Confermare che «KI-generiert» + schermata del primo uso bastano per l'AI Act (applicabile all'offerta UE) e che nessun obbligo svizzero ulteriore esiste.
4. Chiarire se le schede dello store violano il UWG.

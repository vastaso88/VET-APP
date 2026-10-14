> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> ENTWURF — keine Rechtsberatung; vor der Veröffentlichung von einer Rechtsanwältin oder einem Rechtsanwalt in Österreich prüfen zu lassen.

# Avviso IA e disclaimer veterinario — de-AT (v1 bozza)

Data: 2026-10-14. Base normativa: **AI Act art. 50 par. 1** (obbligo dal 02/08/2026), **TÄG § 15 Abs. 1** (Unmittelbarkeitsgebot) e Erläuterungen (Distanzbehandlung vietata), **TeleVetRL 24/05/2024** ✅, TÄG § 31 (pubblicità), § 4 TÄG (attività riservate, 🟡). Dettagli e incertezze in `at/01 §5`. In Austria la linea è **più severa che in Germania**: l'assistente non deve formulare ipotesi diagnostiche; l'informazione generale sulla salute non riferita a un caso specifico non è telemedicina secondo la TeleVetRL, il triage senza diagnosi è ammesso.

**Linee guida di redazione (italiano)**

- Mai «Diagnose», «diagnostizieren», «verschreiben», «Tierarzt per App», «ersetzt Ihre Tierärztin / Ihren Tierarzt» riferiti a ciò che l'app *fa*. Sì a «allgemeine Informationen», «hilft Ihnen, sich vorzubereiten», «sprechen Sie mit Ihrer Tierarztpraxis».
- Nessun dosaggio, nessun farmaco consigliato, nessun nome commerciale di Rx.
- Triage: «dringend zum Tierarzt» sì; «wahrscheinlich ist es X» no.
- Chiavi per l'ARB: prefisso `legalAi…`, una per frase.
- Il testo è identico al `de-DE` tranne i punti segnati *(AT)*.

---

## 1. Primo utilizzo (schermata una tantum)

**Title:** Über den Assistenten

```
Der Assistent von VetApp ist eine künstliche Intelligenz (KI). Seine Antworten werden von einem KI-System geschrieben und sind immer als „KI-generiert“ gekennzeichnet.

Er gibt allgemeine Informationen, damit Sie Ihr Tier gut versorgen können. Er stellt keine Diagnosen, verschreibt nichts und behandelt nicht, und er ersetzt keine Tierärztin und keinen Tierarzt. Diagnose und Behandlung sind in Österreich Tierärztinnen und Tierärzten vorbehalten. Er kann sich irren.

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

## 3. Piè di pagina della chat

```
VetApp gibt allgemeine Informationen, keinen tierärztlichen Rat. Sprechen Sie bei Fragen zur Gesundheit Ihres Tieres immer mit Ihrer Tierarztpraxis.
```

## 4. Banner di emergenza (triage rileva segnali gravi) *(AT)*

```
Das könnte ein Notfall sein.
Wenden Sie sich jetzt an eine Tierärztin oder einen Tierarzt. Wenn Sie Ihre Praxis nicht erreichen, suchen Sie den tierärztlichen Notdienst oder die nächste Tierklinik auf.
Wenn Ihr Tier möglicherweise etwas Giftiges gefressen hat, rufen Sie sofort Ihre Tierarztpraxis oder den tierärztlichen Notdienst an.
```

Nota: la Vergiftungsinformationszentrale (VIZ) di Vienna `01 406 43 43` (24 h, ✅ [gesundheit.gv.at](https://www.gesundheit.gv.at/service/notruf/vergiftungsinformationszentrale.html), aggiornata al 23/02/2026) elenca «Tiere (z. B. Schlangenbisse)» come **origine** dell'avvelenamento, **non** come pazienti: *non* risulta che consigli i proprietari di animali avvelenati. Non mostrarla nel banner finché non è confermata telefonicamente (doc 06).

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
Wenn Sie dem Assistenten eine Frage stellen, senden wir Ihre Nachricht und alles, was Sie anhängen, an einen externen KI-Anbieter, der die Antwort schreibt. Antworten sind als „KI-generiert“ gekennzeichnet. Bevor wir Text senden, entfernen wir automatisch einige persönliche Angaben, etwa E-Mail-Adressen und Telefonnummern. Das erfasst nicht alles; bitte geben Sie keine Informationen ein, die nicht weitergegeben werden sollen.

Die Gesundheitsakte Ihres Tieres
Der Assistent darf die Gesundheitsakte Ihres Tieres nur lesen, wenn Sie es für jedes Tier erlauben. Sie können das jederzeit widerrufen. Siehe „Berechtigungen und Einwilligungen“ in den Einstellungen.

Was der Assistent nicht tut
Er stellt keine Diagnosen für Krankheiten oder Verletzungen, verschreibt keine Arzneimittel, nennt keine Dosierungen und ersetzt keine tierärztliche Untersuchung. Diagnose und Behandlung von Tieren sind in Österreich Tierärztinnen und Tierärzten vorbehalten.

Fehler
KI kann sich irren, veraltet sein oder etwas Wichtiges übersehen. Klären Sie das, was sie Ihnen sagt, mit Ihrer Tierarztpraxis, besonders bei Symptomen, Futter, Arzneimitteln oder Verhalten, das schlimmer wird.

Notfälle
Der Assistent ist kein Notdienst. Wenn Sie glauben, dass Ihr Tier in Gefahr ist, wenden Sie sich sofort an eine Tierärztin oder einen Tierarzt.

Entscheidungen über Sie
Wir nutzen den Assistenten nicht, um Entscheidungen zu treffen, die Ihnen gegenüber rechtliche Wirkung entfalten oder Sie in ähnlicher Weise erheblich beeinträchtigen.

Ihre Daten
In der Datenschutzerklärung steht, wie wir mit Ihren Daten umgehen, einschließlich des KI-Anbieters.

Fragen oder Bedenken
Schreiben Sie an [Datenschutz-/Support-Adresse]. Sie können sich auch bei der Datenschutzbehörde beschweren.
```

## 9. Scheda dello store e testi marketing (indicazioni)

- Sì: «Akten, Erinnerungen und Spaziergänge für Ihr Tier an einem Ort», «KI-Assistent für allgemeine Informationen zur Tierpflege», «Tierfreundliche Orte in Ihrer Nähe finden».
- No: «virtueller Tierarzt», «Diagnose für Ihr Tier», «Tierarzt per App», «KI-Tierarzt», «ersetzt den Tierarztbesuch», «für Notfälle».
- Motivo: UWG austriaco (pratiche ingannevoli), § 4 e § 31 TÄG (pubblicità di attività riservate / trattamento vietato), art. 50 AI Act. ⚖️

## 10. Punti per l'avvocato

1. Confermare che l'informazione generale + triage resta fuori dalle attività riservate ai veterinari (§ 4 TÄG) e dal divieto di Fernbehandlung; in particolare se la **risposta a una domanda su sintomi specifici** diventa «Diagnose».
2. Verificare se un veterinario austriaco che *usa* VetApp o lo raccomanda cade nelle regole sulla pubblicità (§ 31 TÄG).
3. Confermare che «KI-generiert» + schermata del primo uso soddisfano l'art. 50.
4. Chiarire un eventuale nuovo Tierärztegesetz e se cambia la linea.

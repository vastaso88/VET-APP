> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> ENTWURF — keine Rechtsberatung; vor der Veröffentlichung von einer Rechtsanwältin oder einem Rechtsanwalt in der Schweiz prüfen zu lassen.

# Testi dei consensi per il catalogo backend — de-CH (v1)

Data: 2026-10-14. Stesso schema e **stesse regole di registrazione** di `../de/04_einwilligungen_de-DE.md` (chiave per lingua+regione `de-CH`, versione propria `v1` indipendente da `de-DE`/`de-AT`, `locale` mostrata salvata nel `ConsentRecord`, hash del testo, nessun ripiego silenzioso `de-CH → de-DE`; problema A6 in `docs/i18n/REVISIONE_MULTILANG.md`). Differenze svizzere: **EDÖB** al posto di Datenschutzbehörde, «Personendaten», «Bekanntgabe ins Ausland», **ortografia svizzera (ss)**. Virgolette « » per le citazioni.

```python
CURRENT_VERSIONS_BY_LOCALE["de-CH"] = {
    "terms_of_service": "v1",
    "privacy_policy": "v1",
    "marketing_email": "v1",
    "analytics": "v1",
    "contribution_rules": "v1",
}  # illustrativo
```

| Id catalogo | Tipo | Versione de-CH |
|---|---|---|
| `terms_of_service` | obbligatorio | v1 |
| `privacy_policy` | obbligatorio | v1 |
| `marketing_email` | facoltativo | v1 |
| `analytics` | facoltativo | v1 |
| `contribution_rules` | facoltativo | v1 |
| *(per animale)* `medical_record_consent` | facoltativo, per pet | v1 (propria) |

---

## 1. `terms_of_service` — de-CH v1

```
Mit der Nutzung von Quokka stimmen Sie den Nutzungsbedingungen zu: den Regeln für die Nutzung der App, Ihren Pflichten als Nutzerin oder Nutzer und den Grenzen unserer Haftung, einschliesslich der Tatsache, dass die Vorschläge des Assistenten den Rat einer Tierärztin oder eines Tierarztes nicht ersetzen. Ohne diese Zustimmung können wir kein Konto anlegen.
```

## 2. `privacy_policy` — de-CH v1

```
Kurz gesagt: Damit Sie Quokka nutzen können, bearbeiten wir Ihre Kontodaten (Name und E-Mail-Adresse), die Profile Ihrer Tiere, die Dokumente und Fotos, die Sie hochladen, Ihre Gespräche mit dem Assistenten und, wenn Sie sie einschalten, Ihren Standort und Ihre Spaziergang-Strecken. Was Sie dem Assistenten senden (Fragen, Anhänge, Sprachnachrichten), wird an einen externen Anbieter künstlicher Intelligenz gesendet, damit er die Antworten schreibt, und zwar teilweise in Länder ausserhalb der Schweiz; die Gesundheitsakte Ihres Tieres nur, wenn Sie es erlauben. Ihre Daten werden bei Hosting- und Datenbank-Diensten Dritter gespeichert. Sie können Auskunft, Berichtigung oder Löschung Ihrer Daten verlangen, indem Sie uns über Einstellungen → Kontakt schreiben, und freiwillige Einwilligungen jederzeit in den Einstellungen widerrufen. Sie können sich ausserdem an den Eidgenössischen Datenschutz- und Öffentlichkeitsbeauftragten (EDÖB) wenden. Die vollständige Datenschutzerklärung ist in Vorbereitung.
```

Quando la Datenschutzerklärung (doc 02) sarà pubblicata, sostituire l'ultima frase con un link e passare a `v2`.

## 3. `marketing_email` — de-CH v1

```
Mit Ihrer Einwilligung dürfen wir Ihnen per E-Mail Neuigkeiten zu Quokka und Tipps für Ihre Tiere senden. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App macht das keinen Unterschied.
```

(UWG art. 3 Abs. 1 lit. o: la pubblicità di massa via telecomunicazione richiede il **consenso preventivo** e l'indicazione del mittente e di un modo semplice per rifiutare — conoscenza generale, ❓ non riletta in questa sessione.)

## 4. `analytics` — de-CH v1

```
Mit Ihrer Einwilligung erfassen wir anonyme Statistiken darüber, wie die App genutzt wird (zum Beispiel, welche Bildschirme aufgerufen und welche Funktionen genutzt werden), um zu verstehen, wie wir sie verbessern können. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App macht das keinen Unterschied.
```

Nota: oggi nessuno strumento di analisi è attivo; o si attiva, o si toglie la voce. Con uno strumento attivo, FMG art. 45c (`ch/01` §2): informare e dare diritto di rifiutare; la linea più prudente (EDÖB, 🟡) è il consenso.

## 5. `contribution_rules` — de-CH v1

```
Regeln für Meldungen und Stimmen
1. Melden Sie nur, was Sie selbst geprüft haben oder sicher wissen.
2. Schreiben Sie bei Betrieben nur den Namen, wie er am Schild steht. Tragen Sie keine Telefonnummern, privaten Adressen, E-Mail-Adressen oder Daten anderer Personen ein.
3. Meldungen bleiben «in Bestätigung», bis andere Nutzende sie bestätigen. Sie sind keine Garantie: Prüfen Sie immer, bevor Sie zu einem Ort fahren.
4. Stimmen zu Hundeauslaufflächen sind persönliche Meinungen: eine Stimme pro Fläche.
5. Melden Sie eine fehlende Hundeauslauffläche nur, wenn sie öffentlich und für die Allgemeinheit zugänglich ist. Melden Sie keine Privatgrundstücke und fordern Sie niemanden auf, private Flächen zu betreten.
6. Nutzen Sie Meldungen nicht, um einem Betrieb zu schaden. Falsche oder wiederholte Meldungen können zur Sperrung Ihres Kontos führen.
7. Betriebe können die Berichtigung oder Entfernung einer Angabe verlangen: Wir prüfen das und antworten so bald wie möglich.
8. Ihre Meldungen und Stimmen werden ohne Ihren Namen und ohne Ihre persönlichen Daten veröffentlicht; diese werden wie in der Datenschutzerklärung beschrieben bearbeitet.
```

## 6. Consenso per animale: lettura della cartella clinica — de-CH v1

Vive in `packages/core/domain/medical_record/consent_text.py`. Stesse regole di locale e versione; cifre (tre voci, due documenti, 1.200 / 3.500 caratteri) da vincolare con un test come per l'italiano.

```
Damit Ihnen der Assistent genauer raten kann, darf er die Gesundheitsakte Ihres Tieres lesen. Wenn Sie eine Frage stellen, kann er die drei neuesten Einträge mit Titel, Datum, Beschreibung und dem Text angehängter Dokumente lesen, auch wenn sie nichts mit Ihrer Frage zu tun haben. Wenn Sie ihn bitten, einen Befund zu erklären, kann er die Dokumente zu diesem Befund lesen, höchstens zwei. Von einem sehr langen Dokument liest er nur den Anfang. Was er liest, wird an den externen Anbieter künstlicher Intelligenz gesendet, der die Antwort schreibt. Quokka verwendet es nur, um Ihnen zu antworten. Sie können Ihre Einwilligung jederzeit auf der Seite Ihres Tieres oder in den Einstellungen widerrufen; das gilt für spätere Anfragen.
```

Frage im Chat (mit `pet_name` zu formatieren):

```
Soll ich mir die Gesundheitsakte von {pet_name} ansehen, um Ihnen genauer zu raten? Ich lese die drei neuesten Einträge, einschliesslich des Textes angehängter Dokumente, und sende sie an den KI-Dienst, der die Antwort schreibt. Sie können Ihre Meinung jederzeit auf der Seite von {pet_name} ändern.
```

## Note per l'avvocato

1. Consensi facoltativi separati e mai condizione per usare l'app.
2. Il consenso `privacy_policy` è una presa visione; la giustificazione è il contratto.
3. I testi non dichiarano anonimizzazione né pagamenti attivi.
4. Ortografia svizzera: «ss» (einschliesslich, ausserhalb, ausserdem). La verifica ortografica nei file ARB/Python deve evitare di «correggere» in «ß».
5. «Personendaten» e «bearbeiten» (non «verarbeiten») sono i termini del DSG svizzero.

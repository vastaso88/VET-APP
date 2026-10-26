> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> ENTWURF — keine Rechtsberatung; vor der Veröffentlichung von einer Rechtsanwältin oder einem Rechtsanwalt in Deutschland prüfen zu lassen.

# Testi dei consensi per il catalogo backend — de-DE (v1)

Data: 2026-10-14. Base: `packages/core/domain/consent/account_consent_text.py` (testi IT: ToS v1, Privacy v2, Marketing v1, Analytics v1, Contribution rules v2) e `packages/core/domain/medical_record/consent_text.py` (v2). I testi qui sotto sono **equivalenti nel contenuto** a quelli italiani e restano coerenti con ciò che l'app fa oggi. Stesso schema di `docs/compliance/uk|us|au/04_*`. Testo tedesco in Sie-Form.

## Regole di registrazione (da implementare lato backend: non l'ho toccato)

Decisione dell'Orchestratore: **versione propria v1 per lingua/regione** e **lingua mostrata salvata** con il consenso (problema A6 in `docs/i18n/REVISIONE_MULTILANG.md`).

1. **Chiave di catalogo.** Oggi `CONSENT_TEXTS_BY_LANGUAGE` usa il codice lingua primario (`de`) e `CURRENT_VERSIONS` è condiviso da tutte le lingue. Per la Germania, l'Austria e la Svizzera servono tre testi diversi (autorità, trasferimenti, valuta, diritto) quindi una chiave per **lingua + regione**: `CONSENT_TEXTS_BY_LOCALE["de-DE"]`, `["de-AT"]`, `["de-CH"]` con `CURRENT_VERSIONS_BY_LOCALE` indipendenti. Ripiego `de-XX → it` solo se il locale non esiste; **mai** un ripiego silenzioso `de-AT → de-DE`.
2. **Versione.** Tutti i consensi `de-DE` partono da **`v1`**. Una modifica sostanziale a un singolo testo porta solo quella voce a `v2`. La `v1` di `de-DE` **non** equivale alla `v1` italiana, né a quella `de-AT`/`de-CH`: sequenze indipendenti.
3. **Campo da salvare in `ConsentRecord`:** `locale` (es. `"de-DE"`, lingua+regione dei testi *mostrati*, non quella del dispositivo), opzionale per compatibilità con i record IT. La coppia `(locale, version)` prova quale testo ha visto l'utente. Meglio salvare anche un **hash del testo**.
4. **Cambio lingua o regione dopo il consenso.** Il consenso resta valido per il testo visto; non si riscrive in silenzio. In Impostazioni lo stato è «Akzeptiert de-DE v1». I consensi *obbligatori* (ToS, Privacy) si riconfermano solo se la sostanza cambia.
5. **Utente tedesco con app in un'altra lingua.** Un utente in Germania con interfaccia EN o IT: quale testo legale si mostra? Raccomandazione: il testo legale segue la **regione** impostata nell'app (qui `de-DE`) e viene mostrato in tedesco (domanda 7 in doc 08); la traduzione dell'interfaccia non è la traduzione del consenso.
6. **Revisione.** I testi sono bozze; `ConsentCatalogEntry` non ha un flag «bozza». Finché l'avvocato non li approva, `de-DE` non va servita in produzione (o va servita dietro un flag).

Esempio di forma dati (illustrativo, non è codice del repo):

```python
CURRENT_VERSIONS_BY_LOCALE = {
    "de-DE": {
        "terms_of_service": "v1",
        "privacy_policy": "v1",
        "marketing_email": "v1",
        "analytics": "v1",
        "contribution_rules": "v1",
    }
}
```

## Tabella degli id

| Id catalogo | Tipo | Equivalente IT | Versione de-DE |
|---|---|---|---|
| `terms_of_service` | obbligatorio | `TERMS_OF_SERVICE` (IT v1) | v1 |
| `privacy_policy` | obbligatorio | `PRIVACY_POLICY` (IT v2) | v1 |
| `marketing_email` | facoltativo | `MARKETING_EMAIL` (IT v1) | v1 |
| `analytics` | facoltativo | `ANALYTICS` (IT v1) | v1 |
| `contribution_rules` | facoltativo | `CONTRIBUTION_RULES` (IT v2) | v1 |
| *(consenso per animale)* `medical_record_consent` | facoltativo, per pet | `MedicalRecordConsentRecord` (IT v2) | v1 (propria) |

---

## 1. `terms_of_service` — de-DE v1

```
Mit der Nutzung von VetApp stimmen Sie den Nutzungsbedingungen zu: den Regeln für die Nutzung der App, Ihren Pflichten als Nutzerin oder Nutzer und den Grenzen unserer Haftung, einschließlich der Tatsache, dass die Vorschläge des Assistenten den Rat einer Tierärztin oder eines Tierarztes nicht ersetzen. Ohne diese Zustimmung können wir kein Konto anlegen.
```

## 2. `privacy_policy` — de-DE v1

Sintesi, non l'informativa completa. Va tenuta vera rispetto all'app (come l'IT v2).

```
Kurz gesagt: Damit Sie VetApp nutzen können, verarbeiten wir Ihre Kontodaten (Name und E-Mail-Adresse), die Profile Ihrer Tiere, die Dokumente und Fotos, die Sie hochladen, Ihre Gespräche mit dem Assistenten und, wenn Sie sie einschalten, Ihren Standort und Ihre Spaziergang-Strecken. Was Sie dem Assistenten senden (Fragen, Anhänge, Sprachnachrichten), wird an einen externen Anbieter künstlicher Intelligenz gesendet, damit er die Antworten schreibt, und zwar teilweise in Länder außerhalb der EU; die Gesundheitsakte Ihres Tieres nur, wenn Sie es erlauben. Ihre Daten werden bei Hosting- und Datenbank-Diensten Dritter gespeichert. Sie können Auskunft, Berichtigung oder Löschung Ihrer Daten verlangen, indem Sie uns über Einstellungen → Kontakt schreiben, und freiwillige Einwilligungen jederzeit in den Einstellungen widerrufen. Sie können sich außerdem bei einer Datenschutz-Aufsichtsbehörde beschweren. Die vollständige Datenschutzerklärung ist in Vorbereitung.
```

Quando la Datenschutzerklärung (doc 02) sarà pubblicata, sostituire l'ultima frase con un link e passare a `v2`.

## 3. `marketing_email` — de-DE v1

```
Mit Ihrer Einwilligung dürfen wir Ihnen per E-Mail Neuigkeiten zu VetApp und Tipps für Ihre Tiere senden. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App macht das keinen Unterschied.
```

(Prassi in Germania: **Double-Opt-in** con e-mail di conferma, perché l'onere della prova spetta all'inviante; § 7 UWG, conoscenza generale, da verificare. Ogni e-mail deve contenere un modo semplice di disiscriversi.)

## 4. `analytics` — de-DE v1

```
Mit Ihrer Einwilligung erfassen wir anonyme Statistiken darüber, wie die App genutzt wird (zum Beispiel, welche Bildschirme aufgerufen und welche Funktionen genutzt werden), um zu verstehen, wie wir sie verbessern können. Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen; für die Nutzung der App macht das keinen Unterschied.
```

Nota: oggi non c'è alcuno strumento di analisi attivo. Se il testo resta nel catalogo, o si attiva uno strumento, o si toglie la voce. Con uno strumento che legge/scrive sul dispositivo vale anche il § 25 TDDDG (doc 01 §2): il consenso deve avere «accetta» e «rifiuta» di pari rilievo.

## 5. `contribution_rules` — de-DE v1

```
Regeln für Meldungen und Stimmen
1. Melden Sie nur, was Sie selbst geprüft haben oder sicher wissen.
2. Schreiben Sie bei Betrieben nur den Namen, wie er am Schild steht. Tragen Sie keine Telefonnummern, privaten Anschriften, E-Mail-Adressen oder Daten anderer Personen ein.
3. Meldungen bleiben „in Bestätigung“, bis andere Nutzende sie bestätigen. Sie sind keine Garantie: Prüfen Sie immer, bevor Sie zu einem Ort fahren.
4. Stimmen zu Hundeauslaufflächen sind persönliche Meinungen: eine Stimme pro Fläche.
5. Melden Sie eine fehlende Hundeauslauffläche nur, wenn sie öffentlich und für die Allgemeinheit zugänglich ist. Melden Sie keine Privatgrundstücke und fordern Sie niemanden auf, private Flächen zu betreten.
6. Nutzen Sie Meldungen nicht, um einem Betrieb zu schaden. Falsche oder wiederholte Meldungen können zur Sperrung Ihres Kontos führen.
7. Betriebe können die Berichtigung oder Entfernung einer Angabe verlangen: Wir prüfen das und antworten so bald wie möglich.
8. Ihre Meldungen und Stimmen werden ohne Ihren Namen und ohne Ihre persönlichen Daten veröffentlicht; diese werden wie in der Datenschutzerklärung beschrieben behandelt.
```

Adattamenti rispetto all'IT: «area cani» → «Hundeauslauffläche» (termine d'uso in Germania: Hundewiese, Hundeauslaufplatz, Hundefreilaufgebiet; scegliere uno nell'UI e mantenerlo ❓); «nome commerciale» → «Name … am Schild»; «in attesa di conferma» → «in Bestätigung».

## 6. Consenso per animale: lettura della cartella clinica da parte della chat — de-DE v1

Non è un consenso di account (non è in `AccountConsentType`): vive in `packages/core/domain/medical_record/consent_text.py`. Valgono le stesse regole di locale e versione. Il testo deve restare coerente con ciò che il codice legge (tre voci recenti, due documenti per «spiegami l'esame», 1.200 e 3.500 caratteri); il test `tests/unit/test_consent_texts_match_behaviour.py` ne vincola le cifre per l'italiano: va esteso alla versione tedesca.

```
Damit Ihnen der Assistent genauer raten kann, darf er die Gesundheitsakte Ihres Tieres lesen. Wenn Sie eine Frage stellen, kann er die drei neuesten Einträge mit Titel, Datum, Beschreibung und dem Text angehängter Dokumente lesen, auch wenn sie nichts mit Ihrer Frage zu tun haben. Wenn Sie ihn bitten, einen Befund zu erklären, kann er die Dokumente zu diesem Befund lesen, höchstens zwei. Von einem sehr langen Dokument liest er nur den Anfang. Was er liest, wird an den externen Anbieter künstlicher Intelligenz gesendet, der die Antwort schreibt. VetApp verwendet es nur, um Ihnen zu antworten. Sie können Ihre Einwilligung jederzeit auf der Seite Ihres Tieres oder in den Einstellungen widerrufen; das gilt für spätere Anfragen.
```

Frage im Chat (mit `pet_name` zu formatieren), Entsprechung von `INLINE_QUESTION_IT`:

```
Soll ich mir die Gesundheitsakte von {pet_name} ansehen, um Ihnen genauer zu raten? Ich lese die drei neuesten Einträge, einschließlich des Textes angehängter Dokumente, und sende sie an den KI-Dienst, der die Antwort schreibt. Sie können Ihre Meinung jederzeit auf der Seite von {pet_name} ändern.
```

## Note per l'avvocato

1. «Freiwillige Einwilligungen sind getrennt und nie Bedingung für die Nutzung der App»: coerente con art. 7 (4) GDPR e con il § 25 TDDDG.
2. Il consenso `privacy_policy` è una presa visione, non una base giuridica; la base è il contratto (doc 02 §3).
3. I testi non dichiarano anonimizzazione né pagamenti attivi.
4. «Teilweise in Länder außerhalb der EU» nella sintesi privacy: serve perché il fornitore IA è negli USA.
5. Ortografia: «ß» in Germania e Austria; in Svizzera «ss» (vedi `ch/04`).
6. «Nutzende» (forma neutra) e «Tierärztin oder Tierarzt» sono scelte di stile da confermare con il proprietario.

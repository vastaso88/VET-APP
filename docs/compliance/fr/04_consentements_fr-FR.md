> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> PROJET — ne constitue pas un conseil juridique ; à faire relire avant publication par un avocat en France.

# Testi dei consensi per il catalogo backend — fr-FR (v1)

Data: 2026-10-14. Base: `packages/core/domain/consent/account_consent_text.py` (testi IT: ToS v1, Privacy v2, Marketing v1, Analytics v1, Contribution rules v2) e `packages/core/domain/medical_record/consent_text.py` (v2). I testi qui sotto sono **equivalenti nel contenuto** a quelli italiani e restano coerenti con ciò che l'app fa oggi. Stesso schema di `../de/04_*` e `uk|us|au/04_*`. Testo francese in vouvoiement.

## Regole di registrazione (da implementare lato backend: non l'ho toccato)

Valgono le **stesse regole 1–6 di `../de/04_einwilligungen_de-DE.md`** (decisione dell'Orchestratore: versione propria per lingua/regione, lingua mostrata salvata, problema A6 in `docs/i18n/REVISIONE_MULTILANG.md`). In sintesi, per la Francia:

1. **Chiave di catalogo per lingua + regione:** `CONSENT_TEXTS_BY_LOCALE["fr-FR"]`, `CURRENT_VERSIONS_BY_LOCALE["fr-FR"]`. **Mai** un ripiego silenzioso `fr-BE → fr-FR` o `fr-CH → fr-FR` (autorità, diritto e prezzi diversi).
2. **Versione:** tutti i consensi `fr-FR` partono da **`v1`**, sequenza indipendente da IT, DE, `fr-BE`, `fr-CH`.
3. **Campo da salvare in `ConsentRecord`:** `locale` (es. `"fr-FR"`, lingua+regione dei testi *mostrati*, non quella del dispositivo); meglio anche un hash del testo.
4. **Cambio lingua/regione dopo il consenso:** il consenso resta valido per il testo visto; stato in Impostazioni «Accepté fr-FR v1».
5. **Utente in Francia con app in un'altra lingua (EN, IT):** il testo legale segue la **regione** impostata (`fr-FR`) ed è mostrato in francese (stessa raccomandazione di `de/04` regola 5; domanda in doc 08).
6. **Revisione:** finché l'avvocato non li approva, `fr-FR` non va servita in produzione (o dietro un flag).

Regola specifica Francia: l'età del consenso digitale è **15 anni** (art. 45 LIL, `01` §1); poiché il servizio è 18+, nessun testo di consenso parentale.

Esempio di forma dati (illustrativo, non è codice del repo):

```python
CURRENT_VERSIONS_BY_LOCALE = {
    "fr-FR": {
        "terms_of_service": "v1",
        "privacy_policy": "v1",
        "marketing_email": "v1",
        "analytics": "v1",
        "contribution_rules": "v1",
    }
}
```

## Tabella degli id

| Id catalogo | Tipo | Equivalente IT | Versione fr-FR |
|---|---|---|---|
| `terms_of_service` | obbligatorio | `TERMS_OF_SERVICE` (IT v1) | v1 |
| `privacy_policy` | obbligatorio | `PRIVACY_POLICY` (IT v2) | v1 |
| `marketing_email` | facoltativo | `MARKETING_EMAIL` (IT v1) | v1 |
| `analytics` | facoltativo | `ANALYTICS` (IT v1) | v1 |
| `contribution_rules` | facoltativo | `CONTRIBUTION_RULES` (IT v2) | v1 |
| *(consenso per animale)* `medical_record_consent` | facoltativo, per pet | `MedicalRecordConsentRecord` (IT v2) | v1 (propria) |

---

## 1. `terms_of_service` — fr-FR v1

```
En utilisant VetApp, vous acceptez les conditions d'utilisation : les règles d'usage de l'application, vos obligations d'utilisateur et les limites de notre responsabilité, y compris le fait que les suggestions de l'assistant ne remplacent pas l'avis d'un vétérinaire. Sans cette acceptation, nous ne pouvons pas créer de compte.
```

## 2. `privacy_policy` — fr-FR v1

Sintesi, non l'informativa completa. Va tenuta vera rispetto all'app (come l'IT v2).

```
En bref : pour que vous puissiez utiliser VetApp, nous traitons les données de votre compte (nom et adresse e-mail), les fiches de vos animaux, les documents et photos que vous importez, vos conversations avec l'assistant et, si vous les activez, votre localisation et le parcours de vos promenades. Ce que vous envoyez à l'assistant (questions, pièces jointes, messages vocaux) est transmis à un prestataire externe d'intelligence artificielle pour rédiger les réponses, en partie vers des pays situés hors de l'Union européenne ; le carnet de santé de votre animal n'est transmis que si vous l'autorisez. Vos données sont conservées chez des prestataires d'hébergement et de base de données. Vous pouvez demander l'accès, la rectification ou l'effacement de vos données en nous écrivant via Réglages → Contact, et retirer à tout moment vos consentements facultatifs dans les réglages. Vous pouvez aussi introduire une réclamation auprès de la CNIL. La politique de confidentialité complète est en cours de préparation.
```

Quando la politique de confidentialité (doc 02) sarà pubblicata, sostituire l'ultima frase con un link e passare a `v2`.

## 3. `marketing_email` — fr-FR v1

```
Avec votre accord, nous pouvons vous envoyer par e-mail des nouveautés sur VetApp et des conseils pour vos animaux. Vous pouvez retirer votre accord à tout moment dans les réglages ; cela n'a aucune incidence sur votre utilisation de l'application.
```

(Prassi: consenso preventivo per la prospezione B2C via e-mail, con modo semplice di disiscriversi in ogni messaggio; art. L34-5 CPCE, conoscenza generale, da verificare; prevedere conferma dell'iscrizione (double opt-in) come prova.)

## 4. `analytics` — fr-FR v1

```
Avec votre accord, nous recueillons des statistiques anonymes sur l'usage de l'application (par exemple, les écrans consultés et les fonctions utilisées) pour comprendre comment l'améliorer. Vous pouvez retirer votre accord à tout moment dans les réglages ; cela n'a aucune incidence sur votre utilisation de l'application.
```

Nota: oggi non c'è alcuno strumento di analisi attivo. Se il testo resta nel catalogo, o si attiva uno strumento o si toglie la voce. Con uno strumento che legge/scrive sul dispositivo vale l'art. 82 LIL: pulsanti «Tout accepter» e «Tout refuser» di pari rilievo sullo stesso schermo (CNIL, `01` §1). Alcuni strumenti di misura d'audience possono essere esentati dal consenso a condizioni stringenti della CNIL (non verificato qui ❓): la linea prudente resta il consenso.

## 5. `contribution_rules` — fr-FR v1

```
Règles pour les signalements et les votes
1. Ne signalez que ce que vous avez vérifié vous-même ou que vous savez avec certitude.
2. Pour un établissement, indiquez uniquement son nom tel qu'il figure sur l'enseigne. N'indiquez ni numéros de téléphone, ni adresses privées, ni adresses e-mail, ni données d'autres personnes.
3. Les signalements restent « en cours de confirmation » tant que d'autres utilisateurs ne les ont pas confirmés. Ils ne sont pas une garantie : vérifiez toujours avant de vous déplacer.
4. Les votes sur les parcs canins sont des avis personnels : un vote par parc.
5. Ne signalez l'absence d'un parc canin que s'il est public et accessible à tous. Ne signalez pas de propriétés privées et n'incitez personne à entrer dans des espaces privés.
6. N'utilisez pas les signalements pour nuire à un établissement. Des signalements faux ou répétés peuvent entraîner la suspension de votre compte.
7. Les établissements peuvent demander la rectification ou le retrait d'une information : nous l'examinons et répondons dès que possible.
8. Vos signalements et vos votes sont publiés sans votre nom et sans vos données personnelles ; celles-ci sont traitées comme indiqué dans la politique de confidentialité.
```

Adattamenti rispetto all'IT: «area cani» → «parc canin» (termini d'uso in Francia: «parc canin», «espace canin», «canisite»; scegliere uno nell'UI ❓); «nome commerciale» → «nom tel qu'il figure sur l'enseigne»; «in attesa di conferma» → «en cours de confirmation».

## 6. Consenso per animale: lettura della cartella clinica da parte della chat — fr-FR v1

Non è un consenso di account (non è in `AccountConsentType`): vive in `packages/core/domain/medical_record/consent_text.py`. Valgono le stesse regole di locale e versione. Il testo deve restare coerente con ciò che il codice legge (tre voci recenti, due documenti per «spiegami l'esame», 1.200 e 3.500 caratteri); il test `tests/unit/test_consent_texts_match_behaviour.py` ne vincola le cifre per l'italiano: va esteso alla versione francese.

```
Pour vous conseiller plus précisément, l'assistant peut lire le carnet de santé de votre animal. Lorsque vous posez une question, il peut lire les trois entrées les plus récentes, avec leur titre, leur date, leur description et le texte des documents joints, même si elles n'ont aucun lien avec votre question. Lorsque vous lui demandez d'expliquer un résultat d'examen, il peut lire les documents liés à cet examen, deux au maximum. D'un document très long, il ne lit que le début. Ce qu'il lit est envoyé au prestataire externe d'intelligence artificielle qui rédige la réponse. VetApp l'utilise uniquement pour vous répondre. Vous pouvez retirer votre accord à tout moment sur la page de votre animal ou dans les réglages ; cela vaut pour les demandes suivantes.
```

Question dans la discussion (à formater avec `pet_name`), équivalent de `INLINE_QUESTION_IT` :

```
Souhaitez-vous que je consulte le carnet de santé de {pet_name} pour vous conseiller plus précisément ? Je lis les trois entrées les plus récentes, y compris le texte des documents joints, et je les envoie au service d'IA qui rédige la réponse. Vous pouvez changer d'avis à tout moment sur la page de {pet_name}.
```

## Note per l'avvocato

1. «Les consentements facultatifs sont distincts et ne conditionnent jamais l'utilisation de l'application»: coerente con art. 7 par. 4 GDPR e con l'art. 82 LIL.
2. Il consenso `privacy_policy` è una presa visione, non una base giuridica; la base è il contratto (doc 02 §3).
3. I testi non dichiarano anonimizzazione né pagamenti attivi.
4. «En partie vers des pays situés hors de l'Union européenne» serve perché il fornitore IA è negli USA.
5. Il testo `medical_record_consent` dice «conseiller plus précisément»: nel contesto francese (rischio «téléconseil personnalisé», `01` §6) l'avvocato valuta se sostituire con «répondre plus précisément» e se la lettura della cartella clinica sia compatibile con la linea «informazioni generali».
6. Stile: «utilisateurs» (generico) e «vétérinaire» (maschile generico) sono scelte da confermare con il proprietario; il vouvoiement è la linea della traduzione dell'app (PR #19/#21).

> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> PROJET — ne constitue pas un conseil juridique ; à faire relire avant publication par un avocat en Suisse.

# Testi dei consensi per il catalogo backend — fr-CH (v1)

Data: 2026-10-14. Stesso schema e **stesse regole di registrazione** di `../de/04_einwilligungen_de-DE.md` e `../ch/04_einwilligungen_de-CH.md` (chiave per lingua+regione `fr-CH`, versione propria `v1` indipendente da `de-CH`/`fr-FR`/`fr-BE`, `locale` mostrata salvata nel `ConsentRecord`, hash del testo, **nessun ripiego silenzioso** `fr-CH → fr-FR` né `fr-CH → de-CH`; problema A6 in `docs/i18n/REVISIONE_MULTILANG.md`). Differenze svizzere: **PFPDT** al posto di CNIL/APD, «données personnelles», «communication à l'étranger». Testo equivalente nel contenuto a `de-CH` e agli italiani. Francese in vouvoiement.

```python
CURRENT_VERSIONS_BY_LOCALE["fr-CH"] = {"terms_of_service": "v1", "privacy_policy": "v1",
    "marketing_email": "v1", "analytics": "v1", "contribution_rules": "v1"}  # illustrativo
```

| Id catalogo | Tipo | Versione fr-CH |
|---|---|---|
| `terms_of_service` | obbligatorio | v1 |
| `privacy_policy` | obbligatorio | v1 |
| `marketing_email` | facoltativo | v1 |
| `analytics` | facoltativo | v1 |
| `contribution_rules` | facoltativo | v1 |
| *(per animale)* `medical_record_consent` | facoltativo, per pet | v1 (propria) |

**Utente in Svizzera con app in un'altra lingua:** il testo legale segue la **regione** (`fr-CH`) *oppure* la lingua del Cantone: un utente di Ginevra con interfaccia tedesca/inglese/italiana — quale testo? Domanda 2 in `08` (collegata a `ch/08` n. 5 e `de/08` n. 6). Finché non è deciso: non mostrare `fr-CH` a un'interfaccia `de` senza decisione esplicita.

---

## 1. `terms_of_service` — fr-CH v1

```
En utilisant VetApp, vous acceptez les conditions d'utilisation : les règles d'usage de l'application, vos obligations d'utilisateur et les limites de notre responsabilité, y compris le fait que les suggestions de l'assistant ne remplacent pas l'avis d'un vétérinaire. Sans cette acceptation, nous ne pouvons pas créer de compte.
```

## 2. `privacy_policy` — fr-CH v1

```
En bref : pour que vous puissiez utiliser VetApp, nous traitons les données de votre compte (nom et adresse e-mail), les fiches de vos animaux, les documents et photos que vous importez, vos conversations avec l'assistant et, si vous les activez, votre localisation et le parcours de vos promenades. Ce que vous envoyez à l'assistant (questions, pièces jointes, messages vocaux) est transmis à un prestataire externe d'intelligence artificielle pour rédiger les réponses, en partie vers des pays situés hors de Suisse ; le carnet de santé de votre animal n'est transmis que si vous l'autorisez. Vos données sont conservées chez des prestataires d'hébergement et de base de données. Vous pouvez demander l'accès, la rectification ou l'effacement de vos données en nous écrivant via Réglages → Contact, et retirer à tout moment vos consentements facultatifs dans les réglages. Vous pouvez aussi vous adresser au Préposé fédéral à la protection des données et à la transparence (PFPDT). La politique de confidentialité complète est en cours de préparation.
```

Quando la politique de confidentialité (doc 02) sarà pubblicata, sostituire l'ultima frase con un link e passare a `v2`.

## 3. `marketing_email` — fr-CH v1

```
Avec votre accord, nous pouvons vous envoyer par e-mail des nouveautés sur VetApp et des conseils pour vos animaux. Vous pouvez retirer votre accord à tout moment dans les réglages ; cela n'a aucune incidence sur votre utilisation de l'application.
```

(LCD art. 3 al. 1 let. o: la pubblicità di massa via telecomunicazione richiede il **consenso preventivo**, l'indicazione del mittente e un modo semplice per rifiutare — conoscenza generale ❓ da `ch/04`, non riletta.)

## 4. `analytics` — fr-CH v1

```
Avec votre accord, nous recueillons des statistiques anonymes sur l'usage de l'application (par exemple, les écrans consultés et les fonctions utilisées) pour comprendre comment l'améliorer. Vous pouvez retirer votre accord à tout moment dans les réglages ; cela n'a aucune incidence sur votre utilisation de l'application.
```

Nota: oggi nessuno strumento di analisi è attivo; o si attiva, o si toglie la voce. Con uno strumento attivo: LTC art. 45c (`ch/01` §2): informare e dare diritto di rifiutare; linea più prudente (PFPDT, 🟡): consenso.

## 5. `contribution_rules` — fr-CH v1

```
Règles pour les signalements et les votes
1. Ne signalez que ce que vous avez vérifié vous-même ou que vous savez avec certitude.
2. Pour un établissement, indiquez uniquement son nom tel qu'il figure sur l'enseigne. N'indiquez ni numéros de téléphone, ni adresses privées, ni adresses e-mail, ni données d'autres personnes.
3. Les signalements restent « en cours de confirmation » tant que d'autres utilisateurs ne les ont pas confirmés. Ils ne sont pas une garantie : vérifiez toujours avant de vous déplacer.
4. Les votes sur les parcs à chiens sont des avis personnels : un vote par parc.
5. Ne signalez l'absence d'un parc à chiens que s'il est public et accessible à tous. Ne signalez pas de propriétés privées et n'incitez personne à entrer dans des espaces privés.
6. N'utilisez pas les signalements pour nuire à un établissement. Des signalements faux ou répétés peuvent entraîner la suspension de votre compte.
7. Les établissements peuvent demander la rectification ou le retrait d'une information : nous l'examinons et répondons dès que possible.
8. Vos signalements et vos votes sont publiés sans votre nom et sans vos données personnelles ; celles-ci sont traitées comme indiqué dans la politique de confidentialité.
```

(Termine «parc à chiens»; alternative romanda «place de jeux pour chiens», «espace canin»: scegliere uno nell'UI ❓.)

## 6. Consenso per animale: lettura della cartella clinica — fr-CH v1

Vive in `packages/core/domain/medical_record/consent_text.py`. Stesse regole di locale e versione; cifre (tre voci, due documenti, 1.200 / 3.500 caratteri) da vincolare con un test come per l'italiano.

```
Pour vous conseiller plus précisément, l'assistant peut lire le carnet de santé de votre animal. Lorsque vous posez une question, il peut lire les trois entrées les plus récentes, avec leur titre, leur date, leur description et le texte des documents joints, même si elles n'ont aucun lien avec votre question. Lorsque vous lui demandez d'expliquer un résultat d'examen, il peut lire les documents liés à cet examen, deux au maximum. D'un document très long, il ne lit que le début. Ce qu'il lit est envoyé au prestataire externe d'intelligence artificielle qui rédige la réponse. VetApp l'utilise uniquement pour vous répondre. Vous pouvez retirer votre accord à tout moment sur la page de votre animal ou dans les réglages ; cela vaut pour les demandes suivantes.
```

Question dans la discussion (à formater avec `pet_name`) :

```
Souhaitez-vous que je consulte le carnet de santé de {pet_name} pour vous conseiller plus précisément ? Je lis les trois entrées les plus récentes, y compris le texte des documents joints, et je les envoie au service d'IA qui rédige la réponse. Vous pouvez changer d'avis à tout moment sur la page de {pet_name}.
```

## Note per l'avvocato

1. Consensi facoltativi separati e mai condizione per usare l'app.
2. Il consenso `privacy_policy` è una presa visione; la giustificazione è il contratto.
3. I testi non dichiarano anonimizzazione né pagamenti attivi.
4. «Hors de Suisse» (non «hors de l'UE»): coerente con `ch/04`.
5. Termini nLPD: «données personnelles», «traiter» (non «bearbeiten/verarbeiten» tedeschi).
6. Come in `fr/04` nota 5: «conseiller plus précisément» vs «répondre plus précisément» (linea «informazioni generali»).

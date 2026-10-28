> **BOZZA — non è consulenza legale, da far rivedere a un legale locale**
> BORRADOR — no constituye asesoramiento jurídico; debe revisarlo un abogado o una abogada en España antes de su publicación.

# Testi dei consensi per il catalogo backend — es-ES (v1)

Data: 2026-10-14. Base: `packages/core/domain/consent/account_consent_text.py` (testi IT: ToS v1, Privacy v2, Marketing v1, Analytics v1, Contribution rules v2) e `packages/core/domain/medical_record/consent_text.py` (v2). I testi sotto sono **equivalenti nel contenuto** agli italiani e restano coerenti con ciò che l'app fa oggi. Stesso schema di `../de/04_*`. Testo spagnolo in «usted».

## Regole di registrazione (da implementare lato backend: non l'ho toccato)

Decisione dell'Orchestratore: **versione propria v1 per lingua/regione** e **lingua mostrata salvata** con il consenso (problema A6 in `docs/i18n/REVISIONE_MULTILANG.md`).

1. **Chiave di catalogo.** Oggi `CONSENT_TEXTS_BY_LANGUAGE` usa la lingua primaria (`es`) e `CURRENT_VERSIONS` è condiviso. Per la Spagna serve una chiave per **lingua + regione**: `CONSENT_TEXTS_BY_LOCALE["es-ES"]`, con `CURRENT_VERSIONS_BY_LOCALE` indipendente. Per altri paesi ispanofoni (Messico, Argentina…, doc 09) **non** esiste un testo: `es-MX`, `es-AR` ecc. non devono ricadere in silenzio su `es-ES`, perché autorità, diritti e consumatori sono diversi. Ripiego `es-XX → it`, mai `es-XX → es-ES` automatico.
2. **Versione.** Tutti i consensi `es-ES` partono da **`v1`**, sequenza indipendente da IT/DE/EN.
3. **Campo in `ConsentRecord`:** `locale` (es. `"es-ES"`, lingua+regione dei testi *mostrati*, non quella del dispositivo); meglio salvare anche un hash del testo.
4. **Cambio lingua o regione dopo il consenso.** Il consenso resta valido per il testo visto; non si riscrive. In Impostazioni: «Aceptado es-ES v1». Riconferma solo se cambia la sostanza (per i consensi obbligatori).
5. **Utente in Spagna con app in un'altra lingua.** Il testo legale segue la **regione** (`es-ES`) ed è mostrato in spagnolo (domanda 6 in doc 08).
6. **Registro vs. UI.** La UI spagnola dell'app (`app_es.arb` su MULTILANG, collaboratore) dà del **«tú»**; i testi legali qui danno del **«usted»** come da istruzioni. Esempio: `petsConsentFullText` nell'ARB è in «tú» ed è **diverso** dal testo del consenso per animale qui sotto. **Decisione dell'Orchestratore (2026-10-14):** l'app resta in «tú», i documenti legali in «usted». Il testo del consenso che compare *dentro* l'app (`petsConsentFullText`) segue l'app (tú) ma deve dire **esattamente le stesse cose** della versione legale qui sotto (3 voci recenti, 2 documenti, 1.200/3.500 caratteri, invio al fornitore IA esterno, revoca): nota per erykwest. In `ConsentRecord` va salvato il testo realmente mostrato.
7. **Revisione.** Sono bozze; `ConsentCatalogEntry` non ha un flag «bozza». Finché il legale non le approva, `es-ES` non va servita in produzione (o dietro flag).

Esempio di forma dati (illustrativo, non è codice del repo):

```python
CURRENT_VERSIONS_BY_LOCALE = {
    "es-ES": {
        "terms_of_service": "v1",
        "privacy_policy": "v1",
        "marketing_email": "v1",
        "analytics": "v1",
        "contribution_rules": "v1",
    }
}
```

## Tabella degli id

| Id catalogo | Tipo | Equivalente IT | Versione es-ES |
|---|---|---|---|
| `terms_of_service` | obbligatorio | `TERMS_OF_SERVICE` (IT v1) | v1 |
| `privacy_policy` | obbligatorio | `PRIVACY_POLICY` (IT v2) | v1 |
| `marketing_email` | facoltativo | `MARKETING_EMAIL` (IT v1) | v1 |
| `analytics` | facoltativo | `ANALYTICS` (IT v1) | v1 |
| `contribution_rules` | facoltativo | `CONTRIBUTION_RULES` (IT v2) | v1 |
| *(consenso per animale)* `medical_record_consent` | facoltativo, per pet | `MedicalRecordConsentRecord` (IT v2) | v1 (propria) |

---

## 1. `terms_of_service` — es-ES v1

```
Al usar Quokka, usted acepta las Condiciones de uso: las normas para usar la aplicación, sus obligaciones como usuario y los límites de nuestra responsabilidad, incluido el hecho de que las sugerencias del asistente no sustituyen el consejo de un veterinario. Sin esta aceptación no podemos crear su cuenta.
```

## 2. `privacy_policy` — es-ES v1

Sintesi, non la politica completa. Va tenuta vera rispetto all'app (come l'IT v2).

```
En resumen: para que pueda usar Quokka tratamos los datos de su cuenta (nombre y correo electrónico), las fichas de sus animales, los documentos y fotos que sube, sus conversaciones con el asistente y, si lo activa, su ubicación y los recorridos de sus paseos. Lo que envía al asistente (preguntas, archivos adjuntos, mensajes de voz) se envía a un proveedor externo de inteligencia artificial para que redacte las respuestas, en parte a países fuera de la UE; el historial clínico de su animal solo si usted lo autoriza. Sus datos se almacenan en servicios de alojamiento y base de datos de terceros. Puede solicitar el acceso, la rectificación o la supresión de sus datos escribiéndonos desde Ajustes → Contacto, y retirar en cualquier momento los consentimientos voluntarios en Ajustes. También puede presentar una reclamación ante la Agencia Española de Protección de Datos. La política de privacidad completa está en preparación.
```

Quando la politica (doc 02) sarà pubblicata, sostituire l'ultima frase con un link e passare a `v2`.

## 3. `marketing_email` — es-ES v1

```
Con su consentimiento, podemos enviarle por correo electrónico novedades sobre Quokka y consejos para sus animales. Puede retirar su consentimiento en cualquier momento en Ajustes o con el enlace de baja de cada correo; no afecta al uso de la aplicación.
```

(Art. 21 LSSI-CE ✅: vietate le comunicazioni commerciali per e-mail non richieste né autorizzate; ogni messaggio con modo semplice e gratuito di opporsi. Prassi consigliata: doppia conferma tramite e-mail, perché la prova spetta a chi invia — 🟡 conoscenza generale.)

## 4. `analytics` — es-ES v1

```
Con su consentimiento, recopilamos estadísticas anónimas sobre cómo se usa la aplicación (por ejemplo, qué pantallas se visitan y qué funciones se usan) para entender cómo mejorarla. Puede retirar su consentimiento en cualquier momento en Ajustes; no afecta al uso de la aplicación.
```

Nota: oggi non c'è alcuno strumento di analisi attivo. O si attiva uno strumento, o si toglie la voce. Con uno strumento che legge/scrive sul dispositivo vale l'art. 22.2 LSSI-CE: «Aceptar» e «Rechazar» con pari rilievo nel primo strato (guida AEPD, 11/07/2023).

## 5. `contribution_rules` — es-ES v1

```
Reglas para avisos y votos
1. Avise solo de lo que haya comprobado usted mismo o sepa con seguridad.
2. En los negocios, escriba solo el nombre tal como figura en el rótulo. No introduzca teléfonos, domicilios particulares, correos electrónicos ni datos de otras personas.
3. Los avisos permanecen «en confirmación» hasta que otros usuarios los confirmen. No son una garantía: compruebe siempre antes de desplazarse a un lugar.
4. Los votos sobre áreas para perros son opiniones personales: un voto por área.
5. Avise de un área para perros que falta solo si es pública y accesible para todos. No avise de terrenos privados ni invite a nadie a entrar en espacios privados.
6. No use los avisos para perjudicar a un negocio. Los avisos falsos o repetidos pueden provocar la suspensión de su cuenta.
7. Los negocios pueden solicitar la rectificación o supresión de un dato: lo revisaremos y responderemos lo antes posible.
8. Sus avisos y votos se publican sin su nombre y sin sus datos personales; estos se tratan como se describe en la Política de privacidad.
```

Adattamenti rispetto all'IT: «area cani» → «área para perros» (in Spagna anche «pipicán», «parque canino»; scegliere un termine nella UI ❓); «in attesa di conferma» → «en confirmación».

## 6. Consenso per animale: lettura della cartella clinica da parte della chat — es-ES v1

Non è un consenso di account: vive in `packages/core/domain/medical_record/consent_text.py`. Valgono le stesse regole di locale e versione. Il testo deve restare coerente con ciò che il codice legge (tre voci recenti, due documenti per «spiegami l'esame», 1.200 e 3.500 caratteri); il test `tests/unit/test_consent_texts_match_behaviour.py` ne vincola le cifre per l'italiano: va esteso alla versione spagnola.

```
Para orientarle con más precisión, el asistente puede leer el historial clínico de su animal. Cuando usted hace una pregunta, puede leer las tres entradas más recientes, con título, fecha, descripción y el texto de los documentos adjuntos, aunque no tengan relación con su pregunta. Si le pide que explique una prueba, puede leer los documentos relacionados con ella, como máximo dos. De un documento muy largo solo lee el principio. Lo que lee se envía al proveedor externo de inteligencia artificial que redacta la respuesta. Quokka lo usa únicamente para responderle. Puede retirar su consentimiento en cualquier momento desde la ficha de su animal o en Ajustes; se aplica a las solicitudes posteriores.
```

Pregunta en el chat (formatear con `pet_name`), equivalente de `INLINE_QUESTION_IT`:

```
¿Quiere que consulte el historial clínico de {pet_name} para orientarle con más precisión? Leeré las tres entradas más recientes, incluido el texto de los documentos adjuntos, y las enviaré al servicio de IA que redacta la respuesta. Puede cambiar de opinión en cualquier momento en la ficha de {pet_name}.
```

## Note per il legale

1. Coerenza con art. 7.4 RGPD (consenso libero: il consenso facoltativo non è condizione del servizio) e con l'art. 22.2 LSSI-CE.
2. Il consenso `privacy_policy` è una presa visione, non una base giuridica: la base è il contratto (doc 02 §3).
3. I testi non dichiarano anonimizzazione né pagamenti attivi.
4. «En parte a países fuera de la UE» è necessario perché il fornitore IA è negli USA.
5. Si tratta di **dati di salute dell'animale**, non della persona; ma documenti e note possono contenere dati personali dell'utente (doc 02 §2). Il consenso per animale è comunque scelta di prudenza e coerenza tra paesi.
6. Registro «usted» e forma neutra («usuarios», «veterinario») sono scelte di stile da confermare; l'ARB spagnolo usa «tú».

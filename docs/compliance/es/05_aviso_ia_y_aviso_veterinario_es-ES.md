> **BOZZA — non è consulenza legale, da far rivedere a un legale locale**
> BORRADOR — no constituye asesoramiento jurídico; debe revisarlo un abogado o una abogada en España antes de su publicación.

# Avviso IA e disclaimer veterinario — es-ES (v1 bozza)

Data: 2026-10-14. Base normativa: **AI Act art. 50 par. 1** (obbligo dal 02/08/2026; `../de/01 §6`), RD 666/2023 art. 32 (ricetta solo dopo esame clinico del veterinario prescrittore; vendita a distanza di farmaci Rx vietata), Ley 44/2003 art. 4 e 6.2.d, pratiche commerciali ingannevoli (TRLGDCU / Ley de Competencia Desleal, 🟡). Dettagli e incertezze in `01_ricerca_normativa.md` §5–§6.

**Linee guida di redazione (italiano)**

- Mai «diagnóstico», «diagnosticar», «recetar», «sustituye a su veterinario» riferiti a ciò che l'app *fa*. Sì a «información general», «le ayuda a prepararse», «consulte con su clínica veterinaria».
- L'assistente non indica posologie né suggerisce farmaci e **non cita nomi commerciali di medicinali soggetti a prescrizione**. La prescrizione richiede esame clinico (RD 666/2023 art. 32.2).
- Se ci sono segnali di emergenza il messaggio manda dal veterinario *subito*, con i riferimenti del doc 06.
- Chiavi consigliate per l'ARB: prefisso `legalAi…`, una per frase.
- Il titolo dell'etichetta riconosce la natura IA: la sola parola «Asistente» non basta (linee guida art. 50, fonte secondaria).
- Registro: «usted» (l'ARB della UI usa «tú»: decisione in doc 08).

---

## 1. Primo utilizzo (schermata una tantum)

**Title:** Sobre el asistente

```
El asistente de Quokka es una inteligencia artificial (IA). Sus respuestas las redacta un sistema de IA y siempre se identifican como «Generado por IA».

Ofrece información general para que pueda cuidar bien de su animal. No diagnostica, no receta ni trata, y no sustituye a un veterinario. Puede equivocarse.

Si su animal parece enfermo, tiene dolor o usted tiene dudas, consulte a su clínica veterinaria. En una urgencia, acuda de inmediato a un veterinario.
```

Buttons: **Entendido** · **Leer el aviso sobre la IA**

## 2. Etichetta sulle risposte generate da IA

```
Generado por IA
```

Tooltip / accessibility label:

```
Esta respuesta la ha redactado un sistema de IA. Puede contener errores.
```

(Risposte templated/rule-based, come il triage di sicurezza, non portano il badge. Vedi `docs/compliance/01_ai_disclosure.md`.)

## 3. Piè di pagina della chat (sotto il campo di scrittura)

```
Quokka ofrece información general, no asesoramiento veterinario. Ante cualquier duda sobre la salud de su animal, consulte siempre a su clínica veterinaria.
```

## 4. Banner di emergenza (mostrato quando il triage rileva segnali gravi)

```
Esto podría ser una urgencia.
Contacte ahora con un veterinario. Si no localiza a su clínica, busque un servicio de urgencias veterinarias o la clínica veterinaria abierta más cercana.
Si su animal puede haber ingerido algo tóxico, llame de inmediato a su clínica veterinaria o a un servicio de urgencias veterinarias. También puede llamar al Servicio de Información Toxicológica, 91 562 04 20 (24 horas): orienta, pero no sustituye al veterinario.
```

Nota: il SIT (91 562 04 20) è un servizio pubblico del Ministerio de Justicia che, secondo la sua memoria 2020, riceve consultazioni su **intossicazioni di animali** (2.089 nel 2020, il 58,5% da privati) ✅ (doc 06). Rispondono medici/forensi; per animali l'orientamento è informativo: la frase «Si su animal puede haber ingerido algo tóxico…» deve restare. **Non** mostrare il numero come «servicio veterinario de urgencias». Se l'utente è fuori dalla Spagna il banner mostra i riferimenti del *paese impostato nell'app*. SEVEMUR non è incluso finché non verificato (doc 06).

## 5. Avviso sui farmaci

```
Quokka no recomienda medicamentos ni dosis. No dé nunca a su animal medicamentos de uso humano ni medicamentos que no le hayan sido recetados, salvo que su veterinario se lo indique. Algunos son tóxicos para los animales.
```

## 6. Avviso sulla lettura di analisi e documenti («spiegami questo esame»)

```
Esta explicación es general y puede ser incompleta. Solo su veterinario, que conoce a su animal, puede decirle qué significa un resultado para él.
```

## 7. Avviso sull'analisi di foto o video

```
Una foto o un vídeo no lo muestra todo. El asistente puede describir lo que ve, pero no decir qué le ocurre a su animal. Si algo le preocupa, acuda a su clínica veterinaria.
```

## 8. Aviso sobre la IA (pagina completa, richiamata dalle Impostazioni)

**Aviso sobre la IA – cómo usa Quokka la inteligencia artificial**

```
Cómo funciona el asistente
Cuando usted hace una pregunta al asistente, enviamos su mensaje y todo lo que adjunta a un proveedor externo de IA que redacta la respuesta. Las respuestas se marcan como «Generado por IA». Antes de enviar el texto eliminamos automáticamente algunos datos personales, como correos electrónicos y teléfonos. Esto no lo captura todo; le rogamos que no escriba información que no deba compartirse.

El historial clínico de su animal
El asistente solo puede leer el historial clínico de su animal si usted lo autoriza para cada animal. Puede retirar la autorización en cualquier momento. Véase «Permisos y consentimientos» en Ajustes.

Lo que el asistente no hace
No diagnostica enfermedades ni lesiones, no receta medicamentos, no indica dosis y no sustituye a un examen veterinario. En España, las recetas veterinarias solo pueden expedirse tras un examen clínico por el veterinario prescriptor.

Errores
La IA puede equivocarse, estar desactualizada u omitir algo importante. Contraste lo que le diga con su clínica veterinaria, sobre todo si hay síntomas, alimentación, medicamentos o comportamientos que empeoran.

Urgencias
El asistente no es un servicio de urgencias. Si cree que su animal está en peligro, contacte de inmediato con un veterinario.

Decisiones sobre usted
No usamos el asistente para tomar decisiones que produzcan efectos jurídicos sobre usted o le afecten significativamente de modo similar.

Sus datos
La Política de privacidad explica cómo tratamos sus datos, incluido el proveedor de IA.

Preguntas o inquietudes
Escriba a [dirección de privacidad/soporte]. También puede presentar una reclamación ante la Agencia Española de Protección de Datos.
```

## 9. Scheda dello store e testi marketing (indicazioni)

- Sì: «Fichas, recordatorios y paseos de su animal en un solo lugar», «Asistente de IA con información general sobre el cuidado de animales», «Encuentre lugares amigables con los animales cerca de usted».
- No: «veterinario virtual», «diagnóstico para su mascota», «veterinario en el móvil», «veterinario IA», «sustituye a la visita al veterinario», «para urgencias», nomi commerciali di farmaci Rx.
- Motivo: pratiche commerciali ingannevoli, art. 50 AI Act, rischio di essere visti come offerta di telemedicina veterinaria (RD 666/2023 art. 32.2; Código Deontológico 🟡). ⚖️ da far confermare.

## 10. Punti per il legale

1. Confermare che il comportamento descritto (informazioni generali, nessuna diagnosi/prescrizione) resta fuori dalla riserva professionale (Ley 44/2003; art. 403 del Código Penal 🟡) e dalle norme deontologiche (Código Deontológico, artt. 36–38 non letti). In particolare: la chat può formulare *ipotesi*? Linea prudente di Quokka: no.
2. Verificare se il «triage di sicurezza» (domande chiuse → «acuda ya al veterinario») costituisce consulenza e come formularlo.
3. Confermare ruolo (fornitore) e testo definitivo dell'art. 50 AI Act, e se «Generado por IA» + schermata del primo uso bastano; seguire il Proyecto de Ley Orgánica de gobernanza de la IA (AESIA).
4. Verificare le schede store (pratiche ingannevoli, pubblicità sanitaria a livello di CCAA).
5. Verificare se un veterinario che *usa* Quokka o la raccomanda cambia il quadro (Colegio provincial, pubblicità).

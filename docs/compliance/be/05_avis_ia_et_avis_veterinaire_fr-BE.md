> **BOZZA — non è consulenza legale; da rivedere da un avvocato locale prima della pubblicazione**
> PROJET — ne constitue pas un conseil juridique ; à faire relire avant publication par un avocat en Belgique.

# Avviso IA e disclaimer veterinario — fr-BE (v1 bozza)

Data: 2026-10-14. Base normativa: **AI Act art. 50 par. 1** (in applicazione dal 02/08/2026; `../de/01` §6); esercizio della medicina veterinaria belga (loi du 28/08/1991 e art. 16 del Code de déontologie, quest'ultimo da fonte debole 🟡: nessuna diagnosi/prescrizione senza aver esaminato l'animale); **nessun quadro per la telemedicina veterinaria trovato** ❓. Dettagli e incertezze in `01_ricerca_normativa.md` §5. La linea di redazione è quella di `../fr/05_*` (applicata per prudenza: la distinzione «informazione generale vs consiglio personalizzato» è francese e non verificata per il Belgio).

**Linee guida di redazione (italiano)**

- Per prudenza si applica la linea francese (**più severa della Germania**): non basta evitare la parola «diagnostic». Il confine, secondo il CNOV francese (🟡), è tra **informazione generale** e **consiglio personalizzato fondato su un'anamnesi**; per il Belgio non l'ho verificato. I testi qui sotto parlano sempre di «informations générales» e rimandano al veterinario; **l'assistente non deve raccogliere un'anamnesi per arrivare a un consiglio o a un'ipotesi** (punto da decidere, doc 08 domanda 4).
- Mai «diagnostic», «ordonnance», «prescrire», «téléconsultation», «vétérinaire virtuel», «remplace le vétérinaire» riferiti a ciò che l'app *fa*. Sì a «informations générales», «vous aide à vous préparer», «parlez-en à votre vétérinaire».
- L'assistente non indica posologie né suggerisce medicinali e **non cita nomi commerciali di medicinali soggetti a prescrizione**.
- Con segnali di emergenza il messaggio indirizza al veterinario *subito*, con i riferimenti del doc 06.
- Il titolo dell'etichetta riconosce la natura dell'IA in modo chiaro («Généré par IA»); la sola parola «assistant» non basta (linee guida art. 50, fonte secondaria, `de/01` §6).
- Chiavi consigliate per l'ARB (prefisso `legalAi…`), una per frase.

---

## 1. Primo utilizzo (schermata una tantum)

**Title:** À propos de l'assistant

```
L'assistant de Quokka est une intelligence artificielle (IA). Ses réponses sont rédigées par un système d'IA et sont toujours signalées « Généré par IA ».

Il donne des informations générales pour vous aider à bien prendre soin de votre animal. Il ne pose pas de diagnostic, ne prescrit rien, ne soigne pas, et il ne remplace pas un vétérinaire. Il peut se tromper.

Si votre animal semble malade, souffre ou si vous avez un doute, contactez votre cabinet vétérinaire. En cas d'urgence, rendez-vous immédiatement chez un vétérinaire.
```

Buttons: **J'ai compris** · **Lire l'avis sur l'IA**

## 2. Etichetta sulle risposte generate da IA

```
Généré par IA
```

Tooltip / accessibility label:

```
Cette réponse a été rédigée par un système d'IA. Elle peut contenir des erreurs.
```

(Risposte templated/rule-based, come il triage di sicurezza, non portano il badge. Vedi `docs/compliance/01_ai_disclosure.md`. Il badge su ogni risposta + la schermata del primo uso soddisfano l'esempio «avviso all'inizio della sessione / indicatore permanente», 🟡 fonte secondaria.)

## 3. Piè di pagina della chat (sotto il campo di scrittura)

```
Quokka fournit des informations générales, pas un avis vétérinaire. Pour toute question sur la santé de votre animal, parlez-en toujours à votre vétérinaire.
```

## 4. Banner di emergenza (mostrato quando il triage rileva segnali gravi)

```
Cela pourrait être une urgence.
Contactez dès maintenant un vétérinaire. Si vous ne joignez pas votre cabinet, appelez le service de garde indiqué sur son répondeur ou rendez-vous dans la clinique vétérinaire d'urgence la plus proche.
Si votre animal a pu avaler une substance toxique, appelez sans attendre votre vétérinaire ou le Centre Antipoisons : [070 245 245].
```

Nota: il **Centre Antipoisons belga 070 245 245** è attivo 24 ore su 24, tutti i giorni, e la chiamata è gratuita (🟡 rapporti annuali del centro e stampa); i rapporti 2022–2025 indicano che le chiamate per intossicazioni di animali sono in aumento, quindi il servizio accoglie i casi di animali. La riga è tra parentesi quadre perché **non ho potuto leggere la pagina ufficiale sugli animali** (poisoncentre.be/fr → 404): telefonare una volta per conferma prima della pubblicazione. Il centro non cura: consiglia e rimanda al veterinario. Se l'animale collassa, la priorità resta il veterinario d'urgenza. Il banner mostra i riferimenti del *paese impostato nell'app*.

## 5. Avviso sui farmaci

```
Quokka ne recommande aucun médicament ni aucune posologie. Ne donnez jamais à votre animal un médicament destiné aux humains, ni un médicament qui ne lui a pas été prescrit, sauf avis de votre vétérinaire. Certains sont toxiques pour les animaux.
```

## 6. Avviso sulla lettura di analisi e documenti («spiegami questo esame»)

```
Cette explication est générale et peut être incomplète. Seul votre vétérinaire, qui connaît votre animal, peut dire ce que signifie un résultat pour lui.
```

## 7. Avviso sull'analisi di foto o video

```
Une photo ou une vidéo ne montre pas tout. L'assistant peut décrire ce qu'il voit, mais pas dire ce dont souffre votre animal. Si quelque chose vous inquiète, contactez votre vétérinaire.
```

## 8. Avis sur l'IA (pagina completa, richiamata dalle Impostazioni)

**Avis sur l'IA – comment Quokka utilise l'intelligence artificielle**

```
Comment fonctionne l'assistant
Lorsque vous posez une question à l'assistant, nous envoyons votre message et tout ce que vous joignez à un prestataire externe d'IA qui rédige la réponse. Les réponses sont signalées « Généré par IA ». Avant d'envoyer du texte, nous retirons automatiquement certaines informations personnelles, comme les adresses e-mail et les numéros de téléphone. Cela ne couvre pas tout ; merci de ne saisir aucune information que vous ne souhaitez pas partager.

Le carnet de santé de votre animal
L'assistant ne peut lire le carnet de santé de votre animal que si vous l'autorisez, animal par animal. Vous pouvez retirer cette autorisation à tout moment. Voir « Autorisations et consentements » dans les réglages.

Ce que l'assistant ne fait pas
Il ne pose pas de diagnostic de maladie ou de blessure, ne prescrit aucun médicament, n'indique aucune posologie et ne remplace pas l'examen d'un vétérinaire. Seul un vétérinaire, après avoir examiné votre animal, peut poser un diagnostic et prescrire. L'assistant fournit des informations générales ; il ne vous donne pas de conseil personnalisé de santé pour votre animal.

Erreurs
L'IA peut se tromper, être dépassée ou oublier quelque chose d'important. Vérifiez ce qu'elle vous dit auprès de votre vétérinaire, en particulier en cas de symptômes, d'alimentation, de médicaments ou de comportement qui s'aggrave.

Urgences
L'assistant n'est pas un service d'urgence. Si vous pensez que votre animal est en danger, contactez immédiatement un vétérinaire.

Décisions vous concernant
Nous n'utilisons pas l'assistant pour prendre des décisions qui produisent des effets juridiques à votre égard ou vous affectent de manière significative.

Vos données
La politique de confidentialité explique comment nous traitons vos données, y compris le prestataire d'IA.

Questions ou préoccupations
Écrivez à [adresse e-mail dédiée]. Vous pouvez aussi saisir l'Autorité de protection des données (www.autoriteprotectiondonnees.be).
```

## 9. Fiche du store et textes marketing (indicazioni)

- Sì: «Dossiers, rappels et promenades pour votre animal, au même endroit», «Assistant IA pour des informations générales sur les soins aux animaux», «Trouvez des lieux adaptés aux animaux près de chez vous».
- No: «vétérinaire virtuel», «diagnostic pour votre animal», «téléconsultation», «vétérinaire dans votre poche», «IA vétérinaire», «remplace la visite chez le vétérinaire», «pour les urgences», noms commerciaux de médicaments soumis à ordonnance.
- Motivo: pratiche commerciali ingannevoli (Livre VI CDE), esercizio abusivo della medicina veterinaria, art. 50 AI Act, rischio di essere assimilati a un'offerta di telemedicina senza quadro. ⚖️ da far confermare.

## 10. Punti per l'avvocato

1. Il comportamento descritto (informazioni generali, nessuna diagnosi/prescrizione, nessun consiglio personalizzato) è compatibile con la loi du 28/08/1991 e il Code de déontologie belgi? C'è un parere dell'Ordre des médecins vétérinaires sulla telemedicina? (`01` §5)
2. Verificare se la distinzione «informazione generale / consiglio personalizzato» vale anche in Belgio o se è solo francese.
3. Confermare ruolo (fornitore) e testo definitivo dell'art. 50 AI Act; autorità belga competente.
4. Verificare le schede dello store e le pratiche ingannevoli (Livre VI CDE).
5. Confermare il numero e le modalità del Centre Antipoisons per i proprietari di animali.

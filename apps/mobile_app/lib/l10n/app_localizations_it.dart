// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'VET APP';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonNext => 'Avanti';

  @override
  String get commonSkip => 'Salta';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get commonYes => 'Sì';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoading => 'Caricamento…';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonSearch => 'Cerca';

  @override
  String get commonShare => 'Condividi';

  @override
  String get languagePickerTitle => 'Scegli la tua lingua';

  @override
  String get languagePickerSubtitle =>
      'Potrai cambiarla in qualsiasi momento da Impostazioni.';

  @override
  String get languageSectionTitle => 'Lingua';

  @override
  String get languageSectionHint =>
      'Cambiando lingua cambiano anche le unità di misura predefinite, se non le hai già scelte tu.';

  @override
  String get authBannerCheckFieldsTitle => 'Controlla i campi';

  @override
  String get authLoginFieldsInvalidMessage =>
      'Servono una email valida e una password di almeno 6 caratteri.';

  @override
  String get authLoginLoadingTitle => 'Accesso in corso';

  @override
  String get authLoginLoadingMessage => 'Sto verificando le credenziali.';

  @override
  String get authLoginSuccessTitle => 'Accesso completato';

  @override
  String get authLoginSuccessMessage =>
      'La sessione e pronta. Ti porto nel flusso principale.';

  @override
  String get authLoginFailureTitle => 'Accesso non riuscito';

  @override
  String get authLoginTitle => 'Bentornato.';

  @override
  String get authLoginSubtitle =>
      'Accedi per ritrovare i tuoi animali, promemoria e documenti.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'nome@dominio.it';

  @override
  String get authEmailRequired => 'Inserisci la tua email.';

  @override
  String get authEmailInvalid => 'Email non valida.';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'Almeno 6 caratteri';

  @override
  String get authPasswordRequiredLogin => 'Inserisci la password.';

  @override
  String get authPasswordRequiredNew => 'Inserisci una password.';

  @override
  String get authPasswordMinLength => 'Minimo 6 caratteri.';

  @override
  String get authPasswordShow => 'Mostra password';

  @override
  String get authPasswordHide => 'Nascondi password';

  @override
  String get authRememberMe => 'Resta connesso';

  @override
  String get authForgotPasswordLink => 'Password dimenticata?';

  @override
  String get authLoginButton => 'Accedi';

  @override
  String get authNoAccountRegisterLink => 'Non hai un account? Registrati';

  @override
  String get authTermsOfServiceLabel => 'Termini di Servizio';

  @override
  String get authPrivacyPolicyLabel => 'Informativa Privacy';

  @override
  String authTermsAcceptance(String terms, String privacy) {
    return 'Accetto i $terms e l\'$privacy';
  }

  @override
  String get authRegisterCheckTitle => 'Serve un ultimo controllo';

  @override
  String get authRegisterTermsRequired =>
      'Devi accettare privacy e disclaimer per continuare.';

  @override
  String get authRegisterFieldsInvalid =>
      'Controlla i campi: nome, email e password devono essere validi.';

  @override
  String get authRegisterLoadingTitle => 'Creazione account';

  @override
  String get authRegisterLoadingMessage =>
      'Sto creando l account e preparando la sessione iniziale.';

  @override
  String get authRegisterSuccessTitle => 'Account pronto';

  @override
  String get authRegisterSuccessMessage =>
      'Registrazione completata. Ti porto nella home.';

  @override
  String get authRegisterFailureTitle => 'Account non creato';

  @override
  String get authRegisterTitle => 'Crea il tuo profilo.';

  @override
  String get authRegisterSubtitle =>
      'Pochi campi per iniziare a gestire salute e documenti dei tuoi animali.';

  @override
  String get authNameLabel => 'Nome';

  @override
  String get authNameHint => 'Il tuo nome';

  @override
  String get authNameRequired => 'Inserisci il tuo nome.';

  @override
  String get authConfirmPasswordLabel => 'Conferma password';

  @override
  String get authConfirmPasswordHint => 'Ripeti la password';

  @override
  String get authPasswordsMismatch => 'Le password non coincidono.';

  @override
  String get authRegisterButton => 'Crea account';

  @override
  String get authHaveAccountLoginLink => 'Hai già un account? Accedi';

  @override
  String get authResetInvalidTitle => 'Email non valida';

  @override
  String get authResetInvalidMessage =>
      'Inserisci un indirizzo email corretto per continuare.';

  @override
  String get authResetLoadingTitle => 'Invio in corso';

  @override
  String get authResetLoadingMessage =>
      'Sto preparando la richiesta di recupero password.';

  @override
  String get authResetSuccessTitle => 'Email inviata';

  @override
  String get authResetSuccessMessage =>
      'Se l account esiste, riceverai il link per il recupero accesso.';

  @override
  String get authResetFailureTitle => 'Invio non riuscito';

  @override
  String get authResetTitle => 'Recupera l accesso.';

  @override
  String get authResetSubtitle =>
      'Inserisci la tua email: ti mandiamo un link per reimpostare la password.';

  @override
  String get authResetSendButton => 'Invia link';

  @override
  String get authBackToLoginLink => 'Torna all accesso';

  @override
  String get authSetPasswordLoadingTitle => 'Aggiornamento in corso';

  @override
  String get authSetPasswordLoadingMessage => 'Sto salvando la nuova password.';

  @override
  String get authSetPasswordFailureTitle => 'Aggiornamento non riuscito';

  @override
  String get authSetPasswordTitle => 'Imposta una nuova password.';

  @override
  String get authSetPasswordSubtitle =>
      'Scegli una nuova password per il tuo account.';

  @override
  String get authNewPasswordLabel => 'Nuova password';

  @override
  String get authSetPasswordSaveButton => 'Salva nuova password';

  @override
  String get authLegalShareTooltip => 'Condividi o scarica';

  @override
  String get authLegalLoadError =>
      'Non riesco a caricare il testo adesso. Riprova tra poco.';

  @override
  String get authLegalPreparingNotice =>
      'Il testo completo dell\'informativa è in preparazione e sarà disponibile qui a breve, con la possibilità di scaricarlo.';

  @override
  String get authHubTitle => 'VetApp: i tuoi pet a portata di zampa';

  @override
  String get authHubSubtitle =>
      'Accedi al tuo account oppure creane uno nuovo in pochi secondi.';

  @override
  String get authHubCreateAccount => 'Crea un account';

  @override
  String get authHubPrivacyNote =>
      'I tuoi dati restano privati e li usiamo solo per gestire il profilo del tuo pet.';

  @override
  String get authErrorEmailExists =>
      'Esiste già un account con questa email. Prova ad accedere.';

  @override
  String get authErrorWeakPassword =>
      'La password è troppo debole: usa almeno 6 caratteri, meglio se con numeri o lettere maiuscole.';

  @override
  String get authErrorEmailInvalid => 'L\'indirizzo email non sembra valido.';

  @override
  String get authErrorNoConnection =>
      'Nessuna connessione. Controlla la rete e riprova.';

  @override
  String get authErrorLinkExpired =>
      'Il link non è più valido o è già stato usato. Richiedine uno nuovo dalla schermata di recupero.';

  @override
  String get authErrorRateLimit =>
      'Hai richiesto troppe email in poco tempo. Aspetta qualche minuto e riprova.';

  @override
  String get authErrorInvalidCredentials => 'Email o password non corrette.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Devi prima confermare la tua email: controlla la posta e apri il link che ti abbiamo mandato.';

  @override
  String get authErrorEmailNotFound =>
      'Non esiste un account con questa email.';

  @override
  String get authErrorGeneric =>
      'Qualcosa non è andato come previsto. Riprova tra poco.';

  @override
  String get authNetworkTimeout =>
      'La richiesta ha impiegato troppo tempo. Riprova.';

  @override
  String get authNetworkUnexpected => 'Qualcosa e\' andato storto. Riprova.';

  @override
  String get consentsErrorLoad =>
      'Non sono riuscito a leggere i tuoi consensi. Riprova.';

  @override
  String get consentsErrorSave =>
      'Non sono riuscito a salvare la tua scelta. Riprova.';

  @override
  String get billingErrorStatus =>
      'Non sono riuscito a verificare il tuo abbonamento. Riprova.';

  @override
  String get billingErrorSelectPlan =>
      'Non sono riuscito a salvare il piano scelto. Riprova.';

  @override
  String get billingIncludedPets => 'Profili dei tuoi animali';

  @override
  String get billingIncludedAssistant =>
      'Assistente per dubbi su salute, comportamento e routine';

  @override
  String get billingIncludedChatMedia =>
      'Foto, PDF e dettatura vocale nella chat';

  @override
  String get billingIncludedReminders => 'Promemoria';

  @override
  String get billingIncludedNearbyServices =>
      'Servizi per animali nei dintorni';

  @override
  String get billingFreePlaceholder => 'Limiti del piano Free: da definire';

  @override
  String get billingPlusPlaceholder =>
      'Funzioni extra del piano Plus: da definire';

  @override
  String get billingProPlaceholder =>
      'Funzioni extra del piano Pro: da definire';

  @override
  String get billingPlanBadgeRecommended => 'Consigliato';

  @override
  String get billingIncludedInAllPlans => 'Incluso in tutti i piani';

  @override
  String get billingPriceFree => 'Gratis';

  @override
  String billingPricePerMonth(String amount) {
    return '$amount/mese';
  }

  @override
  String billingPricePerMonthYearly(String amount) {
    return '$amount/mese, fatturato annualmente';
  }

  @override
  String get billingTitle => 'Abbonamento e pagamenti';

  @override
  String billingPlanSwitched(String plan) {
    return 'Ora sei sul piano $plan.';
  }

  @override
  String get billingPaymentHistory => 'Cronologia pagamenti';

  @override
  String get billingPaymentHistoryComingSoon =>
      'Le tue fatture e ricevute saranno consultabili qui.';

  @override
  String get billingComparePlans => 'Confronta i piani';

  @override
  String get billingPaymentMethodsSection => 'Metodi di pagamento';

  @override
  String get billingInvoicingSection => 'Fatturazione';

  @override
  String get billingTrialBannerTitle => 'Prova gratuita in corso';

  @override
  String billingTrialBannerDaysLeft(int days) {
    return 'Ti restano $days giorni gratis, nessuna carta richiesta. Scegli un piano quando vuoi, o alla scadenza.';
  }

  @override
  String get billingTrialBannerEnding =>
      'La prova gratuita sta per terminare: scegli un piano per continuare a usare VetApp.';

  @override
  String get billingDeveloperBanner =>
      'Account sviluppatore: accesso illimitato, nessun piano richiesto.';

  @override
  String get billingCurrentPlanLabel => 'Il tuo piano';

  @override
  String billingRenewalOn(String date) {
    return 'Rinnovo il $date';
  }

  @override
  String get billingCycleMonthly => 'Mensile';

  @override
  String get billingCycleYearly => 'Annuale';

  @override
  String get billingCurrentPlanButton => 'Piano attuale';

  @override
  String get billingBackToFree => 'Torna a Free';

  @override
  String billingSwitchToPlan(String plan) {
    return 'Passa a $plan';
  }

  @override
  String billingCardExpires(String expiry) {
    return 'Scade $expiry';
  }

  @override
  String billingCardExpiresDefault(String expiry) {
    return 'Scade $expiry · Predefinita';
  }

  @override
  String get billingSetDefault => 'Imposta come predefinita';

  @override
  String get billingRemove => 'Rimuovi';

  @override
  String get billingAddPaymentMethod => 'Aggiungi metodo di pagamento';

  @override
  String get billingCardBrandLabel => 'Circuito';

  @override
  String get billingCardLast4Label => 'Ultime 4 cifre';

  @override
  String get billingCardLast4Error => 'Inserisci 4 cifre';

  @override
  String get billingExpiryMonthLabel => 'Mese';

  @override
  String get billingExpiryYearLabel => 'Anno';

  @override
  String get billingPaywallTitle => 'La tua prova gratuita è terminata.';

  @override
  String get billingPaywallSubtitle =>
      'Scegli come continuare con VetApp. Puoi cambiare piano quando vuoi da Impostazioni.';

  @override
  String billingChoosePlan(String plan) {
    return 'Scegli $plan';
  }

  @override
  String billingTrialDialogTitle(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Ti restano $daysLeft giorni di prova',
      one: 'Ultimo giorno di prova',
    );
    return '$_temp0';
  }

  @override
  String get billingTrialDialogBody =>
      'Con il piano Free alcune funzioni sono limitate. Passa a Plus o Pro per avere tutto senza limiti quando la prova finisce.';

  @override
  String get billingTrialDialogLater => 'Più tardi';

  @override
  String get billingTrialDialogSeePlans => 'Vedi i piani';

  @override
  String get firstRunWelcomeTitle => 'Benvenuto in VetApp.';

  @override
  String get firstRunPlanIntroSubtitle =>
      'Scegli come iniziare: puoi provare tutto gratis per 10 giorni, senza carta, oppure scegliere subito un piano.';

  @override
  String get firstRunPlanOrChoose => 'OPPURE SCEGLI SUBITO UN PIANO';

  @override
  String get firstRunTrialCardTitle => 'Prova gratuita — 10 giorni';

  @override
  String get firstRunTrialCardBody =>
      'Nessuna carta richiesta. Alla scadenza dei 10 giorni ti chiederemo di scegliere un piano per continuare.';

  @override
  String get firstRunTrialStartButton => 'Inizia la prova gratuita';

  @override
  String get firstRunPlanSelectButton => 'Scegli';

  @override
  String get firstRunAddPetTitle => 'Aggiungi il tuo primo animale';

  @override
  String get firstRunAddPetBody =>
      'Bastano un paio di minuti: nome, specie e qualche dettaglio. Puoi farlo anche più tardi da Animali.';

  @override
  String get firstRunAddPetNow => 'Aggiungi ora';

  @override
  String get firstRunAddPetLater => 'Salta per ora';

  @override
  String get firstRunNotificationsTitle => 'Non perderti i promemoria';

  @override
  String get firstRunNotificationsBody =>
      'Attiva le notifiche per essere avvisato su vaccini, farmaci e visite in scadenza. Puoi cambiare idea in qualsiasi momento da Impostazioni.';

  @override
  String get firstRunNotificationsEnable => 'Attiva notifiche';

  @override
  String get firstRunNotificationsLater => 'Non ora';

  @override
  String get firstRunTutorialPetsTitle => 'Un profilo per ogni animale';

  @override
  String get firstRunTutorialPetsBody =>
      'Razza, peso, note mediche e documenti: tutto organizzato per ciascun pet, sempre a portata di mano.';

  @override
  String get firstRunTutorialAssistantTitle => 'Chiedi al tuo assistente';

  @override
  String get firstRunTutorialAssistantBody =>
      'Fai domande sulla salute dei tuoi animali e ricevi risposte pensate per la loro situazione specifica.';

  @override
  String get firstRunTutorialRemindersTitle =>
      'Niente più scadenze dimenticate';

  @override
  String get firstRunTutorialRemindersBody =>
      'Vaccini, farmaci e visite: imposta un promemoria e VetApp ti avvisa al momento giusto.';

  @override
  String get firstRunTutorialStart => 'Inizia';

  @override
  String get chatLoadingTitle => 'Apriamo la conversazione';

  @override
  String get chatLoadingSubtitle =>
      'Stiamo caricando il thread e l ultimo contesto disponibile.';

  @override
  String get chatEmptyTitle => 'La conversazione e vuota';

  @override
  String get chatEmptySubtitle =>
      'Scrivi il primo messaggio per iniziare il dialogo con l assistente.';

  @override
  String get chatEmptyAction => 'Scrivi ora';

  @override
  String chatEmptyGreeting(String pet) {
    return 'Ciao, ho una domanda per $pet.';
  }

  @override
  String get chatErrorTitle => 'Conversazione non disponibile';

  @override
  String get chatErrorSubtitle =>
      'Qualcosa e andato storto nel recupero del thread.';

  @override
  String get chatErrorAction => 'Torna alle chat';

  @override
  String get chatMessageEditAction => 'Modifica messaggio';

  @override
  String get chatMessageEditHint =>
      'La risposta e i messaggi successivi verranno sostituiti.';

  @override
  String chatComposerHint(String pet) {
    return 'Scrivi una domanda su $pet';
  }

  @override
  String chatNewConversationOnPet(String pet) {
    return 'Nuova conversazione su $pet';
  }

  @override
  String get chatNewConversationPrompt =>
      'Scrivi qui sotto cosa stai osservando: ti rispondo subito.';

  @override
  String get chatTypingText => 'Sta scrivendo una risposta...';

  @override
  String get chatTypingSlowText =>
      'Ci sto mettendo più del solito, la risposta arriva tra poco...';

  @override
  String chatDefaultTitle(String pet) {
    return 'Chat con $pet';
  }

  @override
  String get chatListeningText => 'Sto ascoltando… tocca per fermare';

  @override
  String get chatTranscribingText => 'Trascrivo…';

  @override
  String get chatEditingLabel => 'Modifica del messaggio';

  @override
  String get chatListeningHint => 'Sto ascoltando...';

  @override
  String get chatTranscribingHint => 'Trascrivo il messaggio...';

  @override
  String get chatAddPhotoTooltip => 'Aggiungi una foto';

  @override
  String get chatStopRecordingTooltip => 'Ferma e trascrivi';

  @override
  String get chatVoiceMessageTooltip => 'Messaggio vocale';

  @override
  String get chatMicPermissionNeeded =>
      'Serve il permesso per usare il microfono.';

  @override
  String get chatMicStartFailed =>
      'Non riesco ad avviare il microfono. Riprova.';

  @override
  String get chatRecordingFailed =>
      'La registrazione non è andata a buon fine. Riprova.';

  @override
  String get chatRecordingReadFailed =>
      'Non sono riuscito a leggere la registrazione. Riprova.';

  @override
  String get chatPhotoAnalyzing => 'Sto guardando la foto...';

  @override
  String get chatPhotoReady => 'Foto pronta da inviare';

  @override
  String get chatRemovePhotoTooltip => 'Rimuovi foto';

  @override
  String chatRecordingSemantics(String listening, int minutes, String seconds) {
    return '$listening, $minutes minuti e $seconds secondi';
  }

  @override
  String get chatCancelEditTooltip => 'Annulla modifica';

  @override
  String get chatMenuTooltip => 'Opzioni chat';

  @override
  String get chatMenuRename => 'Rinomina';

  @override
  String get chatMenuExport => 'Esporta chat';

  @override
  String get chatMenuSummary => 'Riassunto';

  @override
  String get chatExportOpenFirst => 'Apri la chat per esportarla.';

  @override
  String get chatSenderYou => 'Tu';

  @override
  String get chatSenderAssistant => 'Assistente';

  @override
  String get chatRenameTitle => 'Rinomina chat';

  @override
  String get chatRenameFieldLabel => 'Titolo';

  @override
  String get chatSummaryLoading => 'Preparo il riassunto…';

  @override
  String get chatSummaryTitle => 'Riassunto per il veterinario';

  @override
  String get chatSummaryDisclaimer =>
      'Questo riassunto è generato automaticamente e non è una diagnosi. Per decisioni cliniche consulta il veterinario.';

  @override
  String get chatSummaryEmpty => 'Nessun riassunto disponibile.';

  @override
  String get chatDeleteTitle => 'Eliminare questa chat?';

  @override
  String get chatDeleteBody =>
      'La conversazione e i suoi messaggi verranno eliminati.';

  @override
  String get chatFallbackPetName => 'il tuo pet';

  @override
  String get chatNewConversation => 'Nuova conversazione';

  @override
  String chatNewConversationTitle(String pet) {
    return '$pet - nuova conversazione';
  }

  @override
  String chatSavedConversationTitle(String pet) {
    return '$pet - conversazione';
  }

  @override
  String chatRetitled(String subject) {
    return 'Chat - $subject';
  }

  @override
  String get chatStatusSaved => 'Conversazione salvata';

  @override
  String get chatStatusSent => 'Messaggio inviato';

  @override
  String get chatStatusEdited => 'Messaggio modificato';

  @override
  String get chatStatusReplyReady => 'Risposta pronta';

  @override
  String get chatTimeYesterday => 'ieri';

  @override
  String get chatTimeNow => 'adesso';

  @override
  String get chatSummaryNotYet =>
      'Il riassunto sarà disponibile dopo il primo messaggio.';

  @override
  String get chatEditMessageMissing =>
      'Questo messaggio non è più nella conversazione.';

  @override
  String get chatEmptyThreadPreview => 'Nuovo thread pronto per essere usato.';

  @override
  String chatDemoReplyAppetite(String pet) {
    return 'Per $pet terrei sotto osservazione appetito, acqua e livello di energia per le prossime 24 ore. Se peggiora, meglio sentire il veterinario.';
  }

  @override
  String get chatDemoReplyVomiting =>
      'Se ci sono vomito o diarrea, conviene monitorare idratazione e contattare il veterinario se i sintomi si ripetono o diventano intensi.';

  @override
  String chatDemoReplyVaccine(String pet) {
    return 'Posso aiutarti a mettere il richiamo di $pet in agenda e aggiungere un reminder chiaro nella home.';
  }

  @override
  String chatDemoReplyWeight(String pet) {
    return 'Sul peso di $pet possiamo fissare un controllo periodico e confrontarlo con l ultima visita per capire se il trend cambia davvero.';
  }

  @override
  String chatDemoReplyDefault(String pet) {
    return 'Ho preso nota: per $pet ti preparo un riepilogo breve, cosi hai subito un piano pratico e leggibile.';
  }

  @override
  String get chatErrorContactAssistant =>
      'Non sono riuscito a contattare l\'assistente. Riprova.';

  @override
  String get chatErrorAssistantTimeout =>
      'L\'assistente non ha risposto in tempo. Tocca Riprova: se la risposta è già pronta, la recupero.';

  @override
  String get chatErrorGeneric => 'Qualcosa e\' andato storto. Riprova.';

  @override
  String get chatErrorRequestTimeout => 'Richiesta scaduta. Riprova.';

  @override
  String get chatErrorEditFailed =>
      'Non sono riuscito a modificare il messaggio. Riprova.';

  @override
  String get chatErrorEditNetwork =>
      'Non sono riuscito a modificare il messaggio. Controlla la connessione.';

  @override
  String chatErrorMessageTooLong(int max) {
    return 'Il messaggio è troppo lungo: puoi scrivere al massimo $max caratteri. Accorcialo e invialo di nuovo.';
  }

  @override
  String chatInputLimitReached(int max) {
    return 'Hai raggiunto il limite di $max caratteri.';
  }

  @override
  String get chatErrorPetBootstrap =>
      'Non sono riuscito a preparare il profilo del pet.';

  @override
  String get chatErrorTitleEmpty => 'Il titolo non può essere vuoto.';

  @override
  String get chatErrorRenameFailed =>
      'Non sono riuscito a rinominare la chat. Riprova.';

  @override
  String get chatErrorRenameNetwork =>
      'Non sono riuscito a rinominare la chat. Controlla la connessione.';

  @override
  String get chatErrorSummaryEmpty =>
      'Scrivi almeno un messaggio per avere un riassunto.';

  @override
  String get chatErrorSummaryModel =>
      'Il modello non ha risposto. Riprova tra poco.';

  @override
  String get chatErrorSummaryFailed =>
      'Non sono riuscito a preparare il riassunto. Riprova.';

  @override
  String get chatErrorSummaryNetwork =>
      'Non sono riuscito a preparare il riassunto. Controlla la connessione.';

  @override
  String get chatErrorDeleteFailed =>
      'Non sono riuscito a eliminare la chat sul server.';

  @override
  String get chatErrorListChats => 'Non sono riuscito a caricare le tue chat.';

  @override
  String get chatErrorListPets => 'Non sono riuscito a caricare i tuoi pet.';

  @override
  String chatErrorConversationLimit(String max) {
    return 'hai raggiunto il numero massimo di conversazioni ($max) per questo animale. Chiudine una per crearne una nuova.';
  }

  @override
  String get chatErrorConversationNotFound =>
      'Questa conversazione non esiste più.';

  @override
  String get chatErrorAttachmentOffline =>
      'Sei offline o la connessione non è stabile. Riprova quando torni online.';

  @override
  String get chatErrorAttachmentDownload =>
      'Non sono riuscito a scaricare il file.';

  @override
  String get chatErrorAttachmentTooLarge =>
      'Il file è troppo grande (max 4 MB).';

  @override
  String get chatErrorAttachmentUnsupported =>
      'Questo tipo di file non è supportato. Puoi caricare foto (JPG, PNG, WEBP) o PDF.';

  @override
  String get chatErrorPdfTooManyPages =>
      'Il PDF supera le 30 pagine consentite.';

  @override
  String get chatErrorPdfUnreadable =>
      'Non riesco a leggere questo PDF: potrebbe essere danneggiato o protetto da password.';

  @override
  String get chatErrorAttachmentUpload =>
      'Non sono riuscito a caricare il file. Riprova.';

  @override
  String get chatErrorTranscribe =>
      'Non sono riuscito a trascrivere il messaggio vocale.';

  @override
  String get chatSeedConv1Title => 'Moka - appetito e controllo';

  @override
  String get chatSeedConv1Subtitle =>
      'Piccolo calo dell appetito, monitoraggio e piano d azione.';

  @override
  String get chatSeedConv1Preview =>
      'Se resta vivace possiamo osservare fino a domani, ma tieni nota di appetito e acqua.';

  @override
  String get chatSeedConv1Status => 'Contesto attivo del pet';

  @override
  String get chatSeedConv1Msg1 =>
      'Raccontami pure cosa stai osservando: appetito, energia, acqua e feci ci aiutano a capire subito se serve una visita o basta monitorare.';

  @override
  String get chatSeedConv1Msg2 =>
      'Da ieri mangia meno del solito ma resta vivace. Devo preoccuparmi subito?';

  @override
  String get chatSeedConv1Msg3 =>
      'Se non ci sono vomito, abbattimento o dolore evidente, in genere conviene monitorare 24 ore e tenere nota di appetito, acqua e feci. Se qualcosa peggiora, contatta il veterinario.';

  @override
  String get chatSeedConv1Msg4 =>
      'Per sicurezza ti lascio anche un mini piano: pasti piccoli, acqua sempre disponibile e controllo della temperatura se ti sembra piu fiacco del solito.';

  @override
  String get chatSeedConv2Title => 'Moka - promemoria vaccino';

  @override
  String get chatSeedConv2Subtitle =>
      'Richiamo annuale con nota sul richiamo antiparassitario.';

  @override
  String get chatSeedConv2Preview =>
      'Ho già messo il richiamo e il promemoria di follow-up per la prossima settimana.';

  @override
  String get chatSeedConv2Status => 'Promemoria attivo';

  @override
  String get chatSeedConv2Msg1 =>
      'Ho impostato il richiamo e aggiunto una nota sull antiparassitario. Se vuoi, possiamo allineare anche la prossima visita di controllo.';

  @override
  String get chatSeedConv2Msg2 =>
      'Perfetto, mi avvisi anche quando manca una settimana?';

  @override
  String get chatSeedConv2Msg3 =>
      'Certo. Ti preparo anche una nota visiva con la scadenza piu vicina, cosi la trovi subito nella home.';

  @override
  String get chatSeedConv3Title => 'Moka - referto visita';

  @override
  String get chatSeedConv3Subtitle =>
      'Sintesi del controllo, terapia leggera e prossima azione.';

  @override
  String get chatSeedConv3Preview =>
      'Posso riassumere il referto in tre punti: quadro, terapia e prossimo controllo.';

  @override
  String get chatSeedConv3Status => 'Referto caricato';

  @override
  String get chatSeedConv3Msg1 =>
      'Posso sintetizzare il referto in tre punti: quadro clinico, terapia e prossimi controlli. Se vuoi, preparo anche una versione breve da condividere.';

  @override
  String get chatSeedConv3Msg2 => 'Sì, dammi la versione breve.';

  @override
  String get chatSeedConv3Msg3 =>
      'In breve: quadro stabile, terapia leggera per pochi giorni e controllo di follow-up gia programmato.';

  @override
  String get chatSeedAgo2Min => '2 min fa';

  @override
  String get chatSeedAgo3Days => '3 gg fa';

  @override
  String get marketplacePermissionDenied =>
      'Solo chi ha pubblicato l\'annuncio può modificarlo o eliminarlo.';

  @override
  String get marketplaceCategoryKennelsCarriers =>
      'Cucce, lettini e trasportini';

  @override
  String get marketplaceCategoryLeashesCollars =>
      'Guinzagli, collari e pettorine';

  @override
  String get marketplaceCategoryToys => 'Giochi';

  @override
  String get marketplaceCategoryClothing => 'Abbigliamento';

  @override
  String get marketplaceCategoryFeeding => 'Ciotole e alimentazione';

  @override
  String get marketplaceCategoryHygieneGrooming => 'Igiene e toelettatura';

  @override
  String get marketplaceCategoryAquariumsTerrariums => 'Acquari e terrari';

  @override
  String get marketplaceCategoryCagesAviaries => 'Gabbie e voliere';

  @override
  String get marketplaceOther => 'Altro';

  @override
  String get marketplaceConditionNew => 'Nuovo';

  @override
  String get marketplaceConditionLikeNew => 'Come nuovo';

  @override
  String get marketplaceConditionGood => 'Buono';

  @override
  String get marketplaceConditionWorn => 'Usato';

  @override
  String get marketplaceSpeciesAll => 'Tutte le specie';

  @override
  String get marketplaceSpeciesDog => 'Cane';

  @override
  String get marketplaceSpeciesCat => 'Gatto';

  @override
  String get marketplaceSpeciesSmallMammal => 'Piccoli mammiferi';

  @override
  String get marketplaceSpeciesBird => 'Uccello';

  @override
  String get marketplaceSpeciesReptileAmphibian => 'Rettili e anfibi';

  @override
  String get marketplaceSpeciesFish => 'Pesce';

  @override
  String get marketplacePriceGift => 'In regalo';

  @override
  String get marketplaceDistanceAnywhere => 'Ovunque';

  @override
  String get marketplaceDemoBedTitle => 'Cuccia imbottita (demo)';

  @override
  String get marketplaceDemoBedDescription => 'Poco usata, taglia media.';

  @override
  String get marketplaceDemoBedArea => 'Centro, Milano';

  @override
  String get marketplaceDemoScratcherTitle => 'Tiragraffi a due piani (demo)';

  @override
  String get marketplaceDemoScratcherArea => 'Città Studi, Milano';

  @override
  String get marketplacePageTitle => 'Mercatino dell\'usato';

  @override
  String get marketplaceMapAction => 'Mappa';

  @override
  String get marketplaceNewListing => 'Nuovo annuncio';

  @override
  String get marketplaceIntro =>
      'Compra, vendi e regala articoli per animali con altri proprietari.';

  @override
  String get marketplaceDistanceNeedsLocation =>
      'Per filtrare per distanza imposta la tua posizione in Impostazioni → Località.';

  @override
  String get marketplaceEmptyFiltered =>
      'Nessun annuncio con questi filtri per ora.';

  @override
  String get marketplaceLoadError =>
      'Non riesco a caricare gli annunci. Controlla la connessione.';

  @override
  String get marketplaceFilterAllCategories => 'Tutte';

  @override
  String get marketplaceFilterAllSpecies => 'Tutti gli animali';

  @override
  String get marketplaceReportListing => 'Segnala annuncio';

  @override
  String get marketplaceReasonSpam => 'Spam';

  @override
  String get marketplaceReasonScam => 'Truffa';

  @override
  String get marketplaceReasonProhibitedItem => 'Articolo non consentito';

  @override
  String get marketplaceReasonInappropriate => 'Contenuto inappropriato';

  @override
  String get marketplaceReportRemoved =>
      'Grazie, l\'annuncio è stato rimosso dopo le segnalazioni ricevute.';

  @override
  String get marketplaceReportSent => 'Segnalazione inviata, grazie.';

  @override
  String get marketplaceDeleteConfirmTitle => 'Eliminare l\'annuncio?';

  @override
  String marketplaceDeleteConfirmBody(String title) {
    return '\"$title\" e le sue foto verranno cancellati. Non si può annullare.';
  }

  @override
  String get marketplaceDeleteFailed =>
      'Non sono riuscito a eliminare l\'annuncio. Riprova.';

  @override
  String get marketplaceDeleted => 'Annuncio eliminato.';

  @override
  String marketplaceDetailApproxZone(String city) {
    return '$city · zona approssimata';
  }

  @override
  String marketplaceDetailForSpecies(String species) {
    return 'Per: $species';
  }

  @override
  String get marketplaceEditListing => 'Modifica annuncio';

  @override
  String get marketplaceDeleting => 'Eliminazione...';

  @override
  String get marketplaceDeleteListing => 'Elimina annuncio';

  @override
  String get marketplaceReporting => 'Invio segnalazione...';

  @override
  String get marketplaceMapTitle => 'Mappa del mercatino';

  @override
  String marketplaceListingsCount(int count) {
    return '$count annunci';
  }

  @override
  String marketplaceMapClusterTitle(int count) {
    return '$count annunci in questa zona';
  }

  @override
  String get marketplaceMapEmpty => 'Nessun annuncio con questi filtri.';

  @override
  String marketplaceMapSummary(int count) {
    return '$count annunci · posizioni approssimate (circa 1 km)';
  }

  @override
  String get marketplaceLocationErrorWithHome =>
      'Non riesco a rilevare la tua posizione. Controlla i permessi di localizzazione oppure usa la residenza.';

  @override
  String get marketplaceLocationErrorNoHome =>
      'Non riesco a rilevare la tua posizione: serve per mostrare l\'annuncio nella zona giusta (in forma approssimata). Controlla i permessi di localizzazione e riprova.';

  @override
  String get marketplaceCameraOpenError =>
      'Non riesco ad aprire la fotocamera.';

  @override
  String get marketplaceGalleryOpenError => 'Non riesco ad aprire la galleria.';

  @override
  String marketplacePhotosSkipped(int count) {
    return '$count foto non leggibili sono state saltate.';
  }

  @override
  String marketplacePhotosMaxReached(int max) {
    return 'Puoi aggiungere al massimo $max foto.';
  }

  @override
  String get marketplaceZoneWait =>
      'Aspetta che la zona sia stata trovata, poi riprova.';

  @override
  String get marketplaceSaveFailed =>
      'Non sono riuscito a salvare l\'annuncio. Controlla la connessione e riprova.';

  @override
  String get marketplacePriceRequired =>
      'Inserisci un prezzo, oppure scegli \"In regalo\"';

  @override
  String get marketplacePriceInvalid => 'Inserisci un prezzo valido';

  @override
  String get marketplacePriceNegative => 'Il prezzo non può essere negativo';

  @override
  String get marketplacePriceZero => 'Per regalarlo scegli \"In regalo\"';

  @override
  String get marketplacePriceTooHigh => 'Prezzo troppo alto';

  @override
  String get marketplaceFieldTitle => 'Titolo';

  @override
  String get marketplaceTitleRequired => 'Inserisci un titolo';

  @override
  String get marketplaceFieldDescription => 'Descrizione (facoltativa)';

  @override
  String get marketplaceFieldCategory => 'Categoria';

  @override
  String get marketplaceCategoryRequired => 'Scegli una categoria';

  @override
  String get marketplaceConditionLabel => 'Condizione';

  @override
  String get marketplaceSpeciesLabel => 'Per quali animali';

  @override
  String get marketplaceSpeciesRequired =>
      'Indica per quali animali è, oppure \"Tutte le specie\"';

  @override
  String get marketplaceGiftSubtitle => 'Lo regali a chi ne ha bisogno';

  @override
  String get marketplaceFieldPrice => 'Prezzo in €';

  @override
  String get marketplaceSaving => 'Salvataggio...';

  @override
  String get marketplaceSaveChanges => 'Salva modifiche';

  @override
  String get marketplacePublish => 'Pubblica annuncio';

  @override
  String marketplacePhotosTitle(int count, int max) {
    return 'Foto ($count/$max)';
  }

  @override
  String get marketplaceTakePhoto => 'Scatta foto';

  @override
  String get marketplaceFromGallery => 'Dalla galleria';

  @override
  String get marketplacePhotosPrivacy =>
      'Prima dell\'invio togliamo dalle foto i dati nascosti (posizione, dispositivo, data).';

  @override
  String get marketplaceLocationTitle => 'Dove si trova';

  @override
  String get marketplaceLocationKeep => 'Zona attuale dell\'annuncio';

  @override
  String get marketplaceLocationNow => 'Dove sono ora';

  @override
  String get marketplaceLocationHome => 'Residenza';

  @override
  String get marketplaceLocationHomeHint =>
      'Per usare la residenza impostala in Impostazioni → Località.';

  @override
  String get marketplaceLocationSearching => 'Cerco la tua zona...';

  @override
  String get marketplaceZoneLabel => 'Zona mostrata (quartiere o comune)';

  @override
  String get marketplaceZoneHelper => 'Niente via o numero civico';

  @override
  String get marketplacePrivacyApproxOnMap =>
      'Sulla mappa l\'annuncio appare in un punto approssimato (circa 1 km), mai al tuo indirizzo.';

  @override
  String get marketplacePrivacyApproxAlways =>
      'Per la tua privacy, la posizione dell\'annuncio è sempre approssimata (circa 1 km), mai il tuo indirizzo esatto.';

  @override
  String get medicalActionOpen => 'Apri';

  @override
  String get medicalActionSend => 'Invia';

  @override
  String get medicalActionRename => 'Rinomina';

  @override
  String get medicalFileUnavailable =>
      'Il file non è disponibile ora. Controlla la connessione e riprova.';

  @override
  String get medicalPdfOpenFailed =>
      'Non sono riuscito ad aprire il PDF. Riprova oppure usa Invia.';

  @override
  String get medicalNoPdfAppTitle => 'Nessuna app per aprire il PDF';

  @override
  String get medicalNoPdfAppBody =>
      'Su questo dispositivo non c\'è un\'app che apre i PDF. Puoi inviare il file a un\'app che lo apre.';

  @override
  String get medicalPreparingFiles => 'Preparo i file da inviare…';

  @override
  String get medicalNoFilesToSend =>
      'Nessun file disponibile da inviare. Controlla la connessione e riprova.';

  @override
  String medicalFilesMissing(int count) {
    return '$count file non disponibili non sono stati inclusi.';
  }

  @override
  String get medicalDeleteConfirmTitle => 'Eliminare questo documento?';

  @override
  String medicalDeleteConfirmBody(String title) {
    return '\"$title\" verrà eliminato definitivamente.';
  }

  @override
  String get medicalDeleting => 'Elimino il referto…';

  @override
  String get medicalRenameTitle => 'Rinomina referto';

  @override
  String get medicalRenameFieldLabel => 'Nome del file';

  @override
  String get medicalDefaultRecordTitle => 'Referto clinico';

  @override
  String get medicalSaveNoSession =>
      'Accesso non disponibile: riprova dopo aver effettuato di nuovo il login.';

  @override
  String medicalSavePetNotSynced(String petName) {
    return 'Il profilo di $petName non è sincronizzato sul server: sistemalo prima di caricare referti.';
  }

  @override
  String get medicalSaveFailed =>
      'Non sono riuscito a salvare il referto sul server. Controlla la connessione e riprova.';

  @override
  String get medicalRenameFailed =>
      'Non sono riuscito a rinominare il referto. Riprova.';

  @override
  String get medicalDeleteFailed =>
      'Non sono riuscito a eliminare il referto. Riprova.';

  @override
  String get medicalRecordMetaNotUploaded => 'File non caricato sul server';

  @override
  String get medicalRecordMetaAnalysisFailed =>
      'File salvato, lettura automatica non riuscita';

  @override
  String get medicalRecordMetaUploadedNow => 'Caricato adesso da te';

  @override
  String get medicalRecordBadgeNotUploaded => 'Non caricato';

  @override
  String get medicalRecordBadgeNew => 'Nuovo';

  @override
  String get medicalRecordSourceLocalOnly => 'Solo su questo telefono';

  @override
  String get medicalRecordSourceUploadedByYou => 'Caricato da te';

  @override
  String get medicalTimelineImported => 'Importato';

  @override
  String get medicalTimelineUpload => 'Caricamento';

  @override
  String get medicalTimelineFailed => 'Non riuscito';

  @override
  String get medicalTimelineCompleted => 'Completato';

  @override
  String get medicalTimelineReadyToSend => 'Pronto per l\'invio';

  @override
  String get medicalTimelineAvailable => 'Disponibile';

  @override
  String get medicalUploadTitle => 'Carica documento';

  @override
  String medicalUploadForPet(String petName) {
    return 'Per $petName · PDF, JPG o PNG';
  }

  @override
  String get medicalUploadAction => 'Carica';

  @override
  String get medicalUploadPickPrompt => 'Tocca per scegliere un file';

  @override
  String get medicalUploadPickHint => 'PDF, JPG o PNG dal tuo dispositivo';

  @override
  String get medicalUploadChange => 'Cambia';

  @override
  String get medicalUploadFailedTitle => 'Il file non è stato caricato';

  @override
  String medicalUploadFailedBody(String reason) {
    return '$reason In alternativa puoi salvare il referto solo su questo telefono: sarà marcato come «Non caricato» e non sarà disponibile sugli altri dispositivi.';
  }

  @override
  String get medicalUploadFailedDefaultReason =>
      'Controlla la connessione e riprova.';

  @override
  String get medicalUploadSaveLocalOnly => 'Salva solo sul telefono';

  @override
  String get medicalUploadDemoSubtitle =>
      'Carica PDF, JPG o PNG e completa i metadati.';

  @override
  String get medicalUploadDemoAction => 'Dettaglio';

  @override
  String get medicalUploadDemoCardBody =>
      'Caricato con successo e pronto per la revisione dei metadati.';

  @override
  String get medicalListTitle => 'Referti';

  @override
  String get medicalListSubtitle =>
      'Referti, note e allegati di Moka in un archivio chiaro.';

  @override
  String get medicalListSyncTitle => 'Sincronizzazione referti';

  @override
  String get medicalListSyncBody =>
      'Sto recuperando documenti e metadati da Supabase o dalla sorgente demo.';

  @override
  String get medicalListLoadErrorTitle => 'Impossibile caricare l archivio';

  @override
  String get medicalListLoadErrorBody =>
      'Riprova dopo aver controllato la connessione o continua con il fallback demo.';

  @override
  String get medicalListEmptyTitle => 'Nessun documento ancora';

  @override
  String get medicalListEmptyBody =>
      'Carica il primo referto per costruire l archivio documenti.';

  @override
  String get medicalListUploadFirst => 'Carica il primo file';

  @override
  String medicalListSummaryAllTitle(int count) {
    return '$count documenti attivi';
  }

  @override
  String medicalListSummaryPetTitle(int count, String petName) {
    return '$count documenti di $petName';
  }

  @override
  String get medicalListSummaryAllBody =>
      '1 referto pronto da condividere, 1 esame da rivedere e 1 nota archiviata.';

  @override
  String medicalListSummaryPetBody(String petName) {
    return 'Filtri attivi sul profilo di $petName. Apri i documenti piu utili senza rumore.';
  }

  @override
  String get medicalListNextActionTitle => 'Prossima azione';

  @override
  String get medicalListNextActionAllBody =>
      'Apri il referto vaccinale di Moka e condividilo con Francesco.';

  @override
  String medicalListNextActionPetBody(String petName) {
    return 'Condividi il documento piu recente di $petName e conserva la nota nel profilo.';
  }

  @override
  String medicalListEmptyPetTitle(String petName) {
    return 'Nessun documento per $petName';
  }

  @override
  String get medicalListEmptyPetBody =>
      'Cambia filtro oppure carica un nuovo documento per questo pet.';

  @override
  String get medicalListRemoveFilter => 'Rimuovi filtro';

  @override
  String medicalFilterAll(int count) {
    return 'Tutti ($count)';
  }

  @override
  String get medicalMetaType => 'Tipo';

  @override
  String get medicalMetaDate => 'Data';

  @override
  String get medicalMetaSource => 'Fonte';

  @override
  String get medicalMetaFormat => 'Formato';

  @override
  String get medicalStatePreviewPill => 'Stato anteprima';

  @override
  String get medicalStateLoadingPill => 'Caricamento';

  @override
  String get medicalChecklistFormat => 'Formato file supportato';

  @override
  String get medicalChecklistMetadata => 'Metadati estratti';

  @override
  String get medicalChecklistLinkedPet => 'Collegato al pet attivo';

  @override
  String get homeGreeting => 'Buongiorno';

  @override
  String get homeAgendaTitle => 'Prossime attività';

  @override
  String get homeAgendaLoadingSubtitle =>
      'Spot e cicli, per tutti gli animali.';

  @override
  String homeAgendaSummary(int count) {
    return '$count attività nei prossimi 10 giorni';
  }

  @override
  String get homeNewsTitle => 'Curiosità per i tuoi animali';

  @override
  String get homeNewsSubtitle =>
      'Notizie dal mondo dei pet selezionate per te.';

  @override
  String get homeNewsUnavailable =>
      'Curiosità non disponibili al momento. Riprova più tardi.';

  @override
  String get homeNewsMore => 'Scopri altre notizie';

  @override
  String get homeNearbyTitle => 'Vicino a me';

  @override
  String get homeSponsorBanner => 'Spazio riservato ai nostri partner.';

  @override
  String get homeSectionLoading => 'Caricamento...';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabPets => 'Animali';

  @override
  String get shellTabActivities => 'Attività';

  @override
  String get shellTabSettings => 'Impostazioni';

  @override
  String get shellRailFooter => 'Spazio clinico caldo';

  @override
  String get shellInterruptedWalkTitle => 'Passeggiata interrotta';

  @override
  String shellInterruptedWalkBody(String distance) {
    return 'È rimasta una passeggiata in corso ($distance finora). Vuoi riprenderla?';
  }

  @override
  String get shellInterruptedWalkDiscard => 'Scarta';

  @override
  String get shellInterruptedWalkResume => 'Riprendi';

  @override
  String shellWalkPausedBanner(String distance) {
    return 'Passeggiata in pausa · $distance';
  }

  @override
  String shellWalkActiveBanner(String elapsed, String distance) {
    return 'Passeggiata in corso · $elapsed · $distance';
  }

  @override
  String get splashMessageWalks => 'Registra le passeggiate con il tuo cane!';

  @override
  String get splashMessageVet => 'Chiedi al veterinario virtuale, 24 ore su 24';

  @override
  String get splashMessageReminders =>
      'Non dimenticare più una scadenza: promemoria e calendario';

  @override
  String get splashMessageRecords => 'Tieni i referti sempre a portata di mano';

  @override
  String get splashMessageNearby =>
      'Scopri le attività pet-friendly vicino a te';

  @override
  String get splashMessageNews => 'Segui le novità sul mondo degli animali';

  @override
  String get splashMessageProfiles =>
      'Un profilo per ogni amico a quattro zampe (o con le pinne!)';

  @override
  String get splashMessageHealthBook =>
      'Il libretto sanitario nel taschino, senza più carte sparse';

  @override
  String get splashMessageVaccines =>
      'Vaccini, vermifughi, visite: ci pensiamo noi a ricordarteli';

  @override
  String get splashMessageSpecies =>
      'Cane, gatto, coniglio, pappagallo o pesciolino: qui c\'è posto per tutti';

  @override
  String get sharedGuestName => 'Ospite';

  @override
  String get sharedComingSoon => 'In arrivo';

  @override
  String get sharedLoadingLabel => 'Caricamento';

  @override
  String get sharedAttachmentTooLarge => 'Il file è troppo grande (max 4 MB).';

  @override
  String get sharedAttachmentInvalidPdf =>
      'Questo file non sembra un PDF valido.';

  @override
  String get sharedAiGenerated => 'Generato da IA';

  @override
  String get sharedAiNotReviewed => 'Risposta automatica, non revisionata';

  @override
  String get petsAgeLessThanMonth => 'Meno di un mese';

  @override
  String petsAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesi',
      one: '1 mese',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anni',
      one: '1 anno',
    );
    return '$_temp0';
  }

  @override
  String petsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profili',
      one: '1 profilo',
    );
    return '$_temp0';
  }

  @override
  String petsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count specie',
      one: '1 specie',
    );
    return '$_temp0';
  }

  @override
  String petsFishCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pesci',
      one: '1 pesce',
    );
    return '$_temp0';
  }

  @override
  String petsAquariumSummary(String species, String fish) {
    return '$species · $fish';
  }

  @override
  String get petsBreedUnspecified => 'Razza non specificata';

  @override
  String petsBreedOtherWithSize(String size) {
    return 'Altro · Taglia $size';
  }

  @override
  String get petsHabitatAquarium => 'Acquario';

  @override
  String get petsHabitatTerrarium => 'Terrario';

  @override
  String get petsHabitatAviary => 'Voliera';

  @override
  String get petsHabitatGeneric => 'Habitat';

  @override
  String get petsCreateTitle => 'Crea un profilo pet';

  @override
  String get petsCreateLoading => 'Preparo il form di creazione...';

  @override
  String get petsCreateErrorTitle => 'Form di creazione non disponibile';

  @override
  String get petsCreateErrorDefault =>
      'Al momento non riesco a creare un nuovo profilo pet.';

  @override
  String get petsCreateFormTitle => 'Nuovo profilo';

  @override
  String get petsCreateSubmit => 'Salva profilo pet';

  @override
  String get petsCreateUnsyncedSnack =>
      'Profilo salvato sul telefono ma non sul server. Aprilo dalla lista e tocca Riprova.';

  @override
  String petsEditTitle(String name) {
    return 'Modifica $name';
  }

  @override
  String get petsEditLoading => 'Carico il form di modifica...';

  @override
  String get petsEditErrorTitle => 'Modifica non disponibile';

  @override
  String get petsEditErrorDefault =>
      'Non riesco ad aprire questo profilo pet per la modifica.';

  @override
  String get petsEditFormTitle => 'Bozza profilo';

  @override
  String get petsEditSubmit => 'Salva modifiche';

  @override
  String get petsEditUnsyncedSnack =>
      'Modifiche salvate sul telefono ma non sul server. Apri il profilo e tocca Riprova.';

  @override
  String get petsEditDeleteTitle => 'Rimuovere questo profilo?';

  @override
  String petsEditDeleteMessage(String name) {
    return 'Il profilo di \"$name\" verrà eliminato definitivamente, insieme ai suoi dati.';
  }

  @override
  String get petsEditDeleteConfirm => 'Rimuovi';

  @override
  String get petsEditDeleteAction => 'Rimuovi profilo';

  @override
  String get petsEditMemorialTitle => 'Spostare nei ricordi?';

  @override
  String petsEditMemorialMessage(String name) {
    return '\"$name\" uscirà dalla lista Animali e sarà conservato nella sezione Ricordi, con il suo profilo e le sue foto.';
  }

  @override
  String get petsEditMemorialConfirm => 'Sposta';

  @override
  String get petsEditMemorialAction => 'Sposta nei ricordi';

  @override
  String get petsFormAllSpeciesAdded =>
      'Hai già aggiunto tutte le specie disponibili.';

  @override
  String get petsFormAddSpecies => 'Aggiungi specie';

  @override
  String get petsFormIdentityColor => 'Colore identificativo';

  @override
  String get petsFormNameLabel => 'Nome';

  @override
  String get petsFormNameHint => 'Moka';

  @override
  String get petsFormNameError => 'Inserisci il nome del pet.';

  @override
  String get petsFormSpeciesLabel => 'Specie';

  @override
  String get petsFormSpeciesHint => 'Seleziona una specie';

  @override
  String get petsFormSpeciesError => 'Seleziona una specie.';

  @override
  String get petsFormProfileType => 'Tipo di profilo';

  @override
  String get petsFormSingleFish => 'Un pesce';

  @override
  String get petsFormAquariumPopulation => 'Popolazione dell\'acquario';

  @override
  String get petsFormNoSpeciesYet => 'Nessuna specie aggiunta ancora.';

  @override
  String get petsFormAquariumNeedsSpecies =>
      'Aggiungi almeno una specie all\'acquario.';

  @override
  String get petsFormBreedLabel => 'Razza';

  @override
  String get petsFormBreedSelectSpeciesFirst => 'Seleziona prima la specie';

  @override
  String get petsFormBreedOptional => 'Facoltativa';

  @override
  String get petsFormBreedPlaceholder => 'Seleziona una razza';

  @override
  String get petsFormBreedSearchHint => 'Cerca una razza';

  @override
  String get petsFormBreedSearchHintScientific =>
      'Cerca (anche per nome scientifico)';

  @override
  String get petsFormOtherBreedLabel => 'Quale razza? (facoltativo)';

  @override
  String get petsFormOtherBreedHint => 'Es. incrocio di barboncino';

  @override
  String get petsFormOtherSpeciesLabel => 'Quale specie o razza? (facoltativo)';

  @override
  String get petsFormOtherSpeciesHint => 'Es. nome comune o varietà';

  @override
  String get petsFormDogSizeLabel => 'Taglia (facoltativa)';

  @override
  String get petsFormDogSizeHint => 'Seleziona una taglia';

  @override
  String get petsFormBirthDateLabel => 'Data di nascita';

  @override
  String get petsFormBirthDateHint => 'gg/mm/aaaa';

  @override
  String get petsFormBirthDateRequired => 'Seleziona la data di nascita.';

  @override
  String get petsFormBirthDateInvalid => 'Data non valida (gg/mm/aaaa).';

  @override
  String get petsFormBirthDateFuture =>
      'La data di nascita non può essere nel futuro.';

  @override
  String get petsFormSexLabel => 'Sesso';

  @override
  String get petsFormSexHint => 'Seleziona';

  @override
  String get petsFormSexError => 'Seleziona il sesso.';

  @override
  String get petsFormSexUnknown => 'Sconosciuto';

  @override
  String get petsFormWeightLabelKg => 'Peso (facoltativo, kg)';

  @override
  String get petsFormWeightLabelLb => 'Peso (facoltativo, lb)';

  @override
  String get petsFormWeightHintKg => 'Es. 18,4';

  @override
  String get petsFormWeightHintLb => 'Es. 40,5';

  @override
  String get petsFormWeightInvalid => 'Inserisci un peso valido.';

  @override
  String get petsFormWeightPositive => 'Il peso deve essere maggiore di zero.';

  @override
  String get petsFormNotesLabel => 'Note';

  @override
  String get petsFormNotesHint =>
      'Aggiungi note brevi su dieta, farmaci o comportamento.';

  @override
  String get petsFormSaving => 'Salvataggio in corso…';

  @override
  String get petsFormPhotoAdd => 'Aggiungi foto';

  @override
  String get petsFormPhotoChange => 'Cambia foto';

  @override
  String get petsFormPhotoRemove => 'Rimuovi';

  @override
  String get petsFormHabitatLength => 'Lunghezza';

  @override
  String get petsFormHabitatWidth => 'Larghezza';

  @override
  String get petsFormHabitatHeight => 'Altezza';

  @override
  String get petsFormHabitatUsGallons => 'Galloni USA';

  @override
  String get petsFormHabitatLiters => 'Litri';

  @override
  String get petsFormHabitatVolumeHint =>
      'Calcolati dalle dimensioni, modificabili';

  @override
  String get petsFormHabitatTemperature => 'Temperatura';

  @override
  String get petsFormHabitatTemperatureHintF => 'Es. 75-79°F';

  @override
  String get petsFormHabitatTemperatureHintC => 'Es. 24-26°C';

  @override
  String get petsFormHabitatSubstrate => 'Substrato';

  @override
  String get petsFormHabitatSubstrateHint => 'Es. ghiaia fine, fibra di cocco';

  @override
  String get petsFormHabitatEquipment => 'Attrezzatura';

  @override
  String get petsFormHabitatEquipmentHint =>
      'Filtro, illuminazione, riscaldatore, piante, lampada UVB, posatoi...';

  @override
  String get petsDetailTitleFallback => 'Dettaglio pet';

  @override
  String get petsDetailGalleryTooltip => 'Galleria foto';

  @override
  String get petsDetailLoading => 'Carico il dettaglio pet...';

  @override
  String get petsDetailErrorTitle => 'Dettaglio pet non disponibile';

  @override
  String get petsDetailErrorDefault =>
      'Questo profilo pet non e disponibile al momento.';

  @override
  String get petsDetailBackToList => 'Torna alla lista';

  @override
  String get petsDetailEmptyTitle => 'Nessun pet selezionato';

  @override
  String get petsDetailEmptySubtitle =>
      'Scegli un profilo dalla lista per vedere dettagli, chat e referti.';

  @override
  String get petsDetailTabReminders => 'Promemoria';

  @override
  String get petsDetailTabChat => 'Chat';

  @override
  String get petsDetailTabRecords => 'Referti';

  @override
  String get petsDetailTabWalks => 'Passeggiate';

  @override
  String get petsDetailHabitatTapForDetails => 'Tocca per i dettagli';

  @override
  String get petsDetailHabitatDimensions => 'Dimensioni';

  @override
  String get petsDetailHabitatVolume => 'Volume';

  @override
  String get petsDetailPopulation => 'Popolazione';

  @override
  String get petsDetailRemindersNew => 'Nuovo promemoria';

  @override
  String petsDetailRemindersEmpty(String petName) {
    return 'Nessun promemoria ancora per $petName.';
  }

  @override
  String get petsDetailChatNew => 'Nuova chat';

  @override
  String petsDetailChatEmpty(String petName) {
    return 'Nessuna conversazione ancora per $petName.';
  }

  @override
  String petsDetailChatDeleteFailed(String error) {
    return 'Chat rimossa qui, ma non sul server: $error';
  }

  @override
  String get petsDetailChatDeleteTitle => 'Eliminare questa chat?';

  @override
  String petsDetailChatDeleteMessage(String title) {
    return '\"$title\" verrà eliminata definitivamente.';
  }

  @override
  String get petsDetailChatLimitTitle => 'Limite chat raggiunto';

  @override
  String petsDetailChatLimitMessage(int max, String petName) {
    return 'Puoi avere al massimo $max conversazioni attive per $petName. Elimina una chat esistente per aprirne una nuova.';
  }

  @override
  String get petsDetailChatLimitOk => 'Ho capito';

  @override
  String get petsDetailRecordsSendTitle => 'Invia file';

  @override
  String get petsDetailRecordsSendSubtitle =>
      'Scegli un documento da inviare via email, WhatsApp e altro.';

  @override
  String petsDetailRecordShareText(String title, String source, String date) {
    return '📄 $title\n$source · $date\n\nCondiviso da VetApp';
  }

  @override
  String get petsDetailShareUnavailable =>
      'Condivisione non disponibile su questo dispositivo.';

  @override
  String get petsDetailRecordsUpload => 'Carica file';

  @override
  String get petsDetailRecordsSend => 'Invia';

  @override
  String petsDetailRecordsEmpty(String petName) {
    return 'Nessun documento ancora per $petName.';
  }

  @override
  String get petsDetailRecordsLoadError =>
      'Non riesco a leggere i referti. Controlla la connessione e riprova.';

  @override
  String petsDetailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionati',
      one: '1 selezionato',
    );
    return '$_temp0';
  }

  @override
  String get petsDetailWalksStart => 'Avvia passeggiata';

  @override
  String get petsDetailWalksBadges => 'Badge';

  @override
  String petsDetailWalksEmpty(String petName) {
    return 'Nessuna passeggiata ancora per $petName.';
  }

  @override
  String get petsDetailWalksRecords => 'Record 🏆';

  @override
  String get petsDetailWalksFavorites => 'Preferite ⭐';

  @override
  String get petsDetailWalksRecent => 'Recenti';

  @override
  String get petsDetailWalkLongest => 'Più lunga';

  @override
  String get petsDetailWalkLongestDuration => 'Più duratura';

  @override
  String get petsDetailWalkLongestAndDuration => 'Più lunga · Più duratura';

  @override
  String petsDetailWalkStatusActive(String distance, String elapsed) {
    return 'Passeggiata in corso · $distance · $elapsed';
  }

  @override
  String petsDetailWalkStatusPaused(String distance, String elapsed) {
    return 'In pausa · $distance · $elapsed';
  }

  @override
  String get petsDetailWalkUnfavoriteTitle => 'Togliere dai preferiti?';

  @override
  String get petsDetailWalkUnfavoriteMessage =>
      'Se non è anche il record o tra le ultime 3 passeggiate, potrà perdere la mappa alla prossima pulizia automatica.';

  @override
  String get petsDetailWalkUnfavoriteConfirm => 'Togli dai preferiti';

  @override
  String get petsDetailWalkDeleteTitle => 'Eliminare questa passeggiata?';

  @override
  String petsDetailWalkDeleteMessage(String date, String distance) {
    return 'La passeggiata del $date ($distance) verrà eliminata definitivamente.';
  }

  @override
  String petsDetailWalkSteps(int count) {
    return '~$count passi';
  }

  @override
  String get petsDetailUnsyncedBanner =>
      'Non sincronizzato: le modifiche sono solo su questo telefono.';

  @override
  String get petsDetailUnsyncedRetryFailed =>
      'Ancora nessun collegamento al server. Riprova più tardi.';

  @override
  String get petsScaffoldBadge => 'Pet';

  @override
  String get petsLoadingDefaultLabel => 'Caricamento pet...';

  @override
  String get petsLoadingSubtitle =>
      'Attendi un istante mentre prepariamo la schermata.';

  @override
  String get petsDemoDeleteFailed =>
      'Non sono riuscito a eliminare il profilo. Riprova.';

  @override
  String get petsDemoNewProfileNote =>
      'Profilo creato da poco, pronto per la prossima visita.';

  @override
  String get petsDemoNextVisitToPlan => 'Da pianificare';

  @override
  String get petsValueSpeciesDog => 'Cane';

  @override
  String get petsValueSpeciesCat => 'Gatto';

  @override
  String get petsValueSpeciesSmallMammals => 'Piccoli mammiferi';

  @override
  String get petsValueSpeciesBird => 'Uccello';

  @override
  String get petsValueSpeciesReptiles => 'Rettili e anfibi';

  @override
  String get petsValueSpeciesFish => 'Pesce';

  @override
  String get petsValueSpeciesOther => 'Altro';

  @override
  String get petsValueSpeciesAll => 'Tutti';

  @override
  String get petsValueSexMale => 'Maschio';

  @override
  String get petsValueSexFemale => 'Femmina';

  @override
  String get petsValueSexMaleIntact => 'Maschio intero';

  @override
  String get petsValueSexMaleNeutered => 'Maschio castrato';

  @override
  String get petsValueSexFemaleIntact => 'Femmina intera';

  @override
  String get petsValueSexFemaleSpayed => 'Femmina sterilizzata';

  @override
  String get petsValueDogSizeToy => 'Toy';

  @override
  String get petsValueDogSizeSmall => 'Piccola';

  @override
  String get petsValueDogSizeMedium => 'Media';

  @override
  String get petsValueDogSizeLarge => 'Grande';

  @override
  String get petsValueDogSizeGiant => 'Gigante';

  @override
  String get petsListTitle => 'Animali';

  @override
  String get petsListMemoriesTooltip => 'Ricordi';

  @override
  String get petsListLoading => 'Carico la lista pet...';

  @override
  String get petsListErrorTitle => 'Pet non disponibili';

  @override
  String get petsListErrorDefault =>
      'Al momento non riesco a caricare i profili pet.';

  @override
  String get petsListEmptyTitle => 'Nessun pet ancora';

  @override
  String get petsListEmptySubtitle =>
      'Crea il primo profilo per tenere sotto controllo salute, note e scadenze.';

  @override
  String get petsListEmptyAction => 'Crea pet';

  @override
  String get petsListFilterEmpty => 'Nessun pet per questo filtro.';

  @override
  String get petsMemoriesRemoveTitle => 'Rimuovere definitivamente?';

  @override
  String petsMemoriesRemoveBody(String name) {
    return 'Il ricordo di \"$name\" verrà eliminato, senza possibilità di recupero.';
  }

  @override
  String get petsMemoriesRemoveConfirm => 'Rimuovi';

  @override
  String get petsMemoriesTitle => 'Ricordi';

  @override
  String get petsMemoriesSubtitle =>
      'I profili dei pet che hanno condiviso la vostra strada.';

  @override
  String get petsMemoriesEmpty => 'Nessun ricordo conservato ancora.';

  @override
  String petsMemoriesWithUsUntil(String date) {
    return 'Con noi fino al $date';
  }

  @override
  String petsMemoriesWithUsRange(String from, String to) {
    return 'Con noi dal $from al $to';
  }

  @override
  String get petsMemoriesComingSoon =>
      'Presto: i vostri momenti più belli insieme, come le passeggiate più lunghe o i traguardi raggiunti, raccolti qui.';

  @override
  String get petsMediaGalleryTitle => 'Galleria';

  @override
  String get petsMediaFoldersLoading => 'Carico le cartelle…';

  @override
  String get petsMediaFoldersEmpty =>
      'Aggiungi un animale per creare la sua cartella di foto.';

  @override
  String get petsMediaFolderCounting => 'Conto le foto…';

  @override
  String petsMediaCountPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountPhotosAndVideos(String photos, String videos) {
    return '$photos · $videos';
  }

  @override
  String get petsMediaVideoSemantics => 'Video';

  @override
  String get petsMediaDeleteVideoTitle => 'Eliminare questo video?';

  @override
  String get petsMediaDeletePhotoTitle => 'Eliminare questa foto?';

  @override
  String get petsMediaDeleteVideoBody =>
      'Il video verrà rimosso definitivamente dalla galleria.';

  @override
  String get petsMediaDeletePhotoBody =>
      'La foto verrà rimossa definitivamente dalla galleria.';

  @override
  String get petsMediaOperationFailed =>
      'Non sono riuscito a completare l\'operazione. Riprova.';

  @override
  String get petsMediaSetAsProfile => 'Imposta come foto profilo';

  @override
  String get petsMediaDeleteVideoAction => 'Elimina video';

  @override
  String get petsMediaDeletePhotoAction => 'Elimina foto';

  @override
  String get petsMediaImportFromGallery => 'Importa dalla galleria';

  @override
  String get petsMediaImportFromGalleryHint => 'Foto e video, anche più di uno';

  @override
  String get petsMediaTakePhoto => 'Scatta foto';

  @override
  String get petsMediaRecordVideo => 'Registra video';

  @override
  String petsMediaRecordVideoLimit(int seconds) {
    return 'Fino a $seconds secondi';
  }

  @override
  String petsMediaGalleryOf(String name) {
    return 'Galleria di $name';
  }

  @override
  String get petsMediaGalleryEmpty =>
      'Nessuna foto o video ancora. Usa il pulsante \"Aggiungi\" qui sotto.';

  @override
  String get petsMediaVideoPlaybackFailed =>
      'Non riesco a riprodurre questo video.';

  @override
  String get petsMediaVideoLoading => 'Carico il video...';

  @override
  String get petsMediaCancelling => 'Annullo...';

  @override
  String get petsMediaPreparingFile => 'Preparo il file...';

  @override
  String petsMediaPreparingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preparo $count file...',
      one: 'Preparo il file...',
    );
    return '$_temp0';
  }

  @override
  String get petsMediaUploadingFile => 'Carico il file...';

  @override
  String petsMediaUploadingProgress(int current, int total) {
    return 'Carico $current di $total...';
  }

  @override
  String get petsMediaUploadingVideo => 'Carico il video...';

  @override
  String petsMediaUploadingVideoOf(int current, int total) {
    return 'Carico il video $current di $total...';
  }

  @override
  String petsMediaReducingVideo(int percent) {
    return 'Riduco il video... $percent%';
  }

  @override
  String petsMediaReducingVideoOf(int current, int total, int percent) {
    return 'Riduco il video $current di $total... $percent%';
  }

  @override
  String petsMediaImportJoin(String first, String second) {
    return '$first e $second';
  }

  @override
  String petsMediaImportDone(String list) {
    return 'Caricati: $list';
  }

  @override
  String get petsMediaImportCancelled => 'Caricamento annullato.';

  @override
  String petsMediaImportCancelledWith(String done) {
    return 'Caricamento annullato. $done.';
  }

  @override
  String get petsMediaImportNothingToAdd => 'Niente da aggiungere.';

  @override
  String petsMediaImportProblemMore(String problem, int count) {
    return '$problem (altri $count non aggiunti)';
  }

  @override
  String petsMediaImportDoneWithProblem(String done, String problem) {
    return '$done. $problem';
  }

  @override
  String petsMediaPhotoAddedTo(String name) {
    return 'Foto aggiunta alla galleria di $name';
  }

  @override
  String petsMediaVideoAddedTo(String name) {
    return 'Video aggiunto alla galleria di $name';
  }

  @override
  String petsMediaImportFileFailed(String file) {
    return 'Non sono riuscito a caricare $file.';
  }

  @override
  String get petsMediaImportUnnamedFile => 'un file';

  @override
  String get petsMediaPhotoSaveOffline =>
      'Il salvataggio delle foto non è disponibile senza connessione.';

  @override
  String get petsMediaVideoSaveOffline =>
      'Il salvataggio dei video non è disponibile senza connessione.';

  @override
  String petsMediaImportRefused(String file, String message) {
    return '$file: $message';
  }

  @override
  String get petsMediaVideoUnsupportedFormat =>
      'Formato video non supportato: usa un file MP4 o MOV.';

  @override
  String petsMediaVideoTooBigSource(int size, int max) {
    return 'Video troppo pesante ($size MB): il massimo è $max MB.';
  }

  @override
  String petsMediaVideoTooBigBrowser(int size, int max) {
    return 'Video troppo pesante ($size MB): dal browser il massimo è $max MB. Dall\'app sul telefono i video vengono ridotti in automatico.';
  }

  @override
  String get petsMediaVideoUnreadable => 'Non riesco a leggere questo video.';

  @override
  String petsMediaVideoTooLong(int seconds) {
    return 'Video troppo lungo: il massimo è $seconds secondi.';
  }

  @override
  String petsMediaVideoTooBigReduced(int size, int max) {
    return 'Anche ridotto il video pesa $size MB (massimo $max MB): prova con un clip più breve.';
  }

  @override
  String petsMediaVideoTooBigNotReduced(int size, int max) {
    return 'Non sono riuscito a ridurre il video e pesa $size MB (massimo $max MB): prova con un clip più breve.';
  }

  @override
  String petsConsentSemanticsExpanded(String name) {
    return 'Consenso alla lettura della cartella clinica di $name. Tocca per chiudere il testo completo';
  }

  @override
  String petsConsentSemanticsCollapsed(String name) {
    return 'Consenso alla lettura della cartella clinica di $name. Tocca per leggere il testo completo';
  }

  @override
  String petsConsentCardTitle(String name) {
    return 'Cartella clinica di $name';
  }

  @override
  String get petsConsentReadHow => 'Leggi come viene usata';

  @override
  String petsConsentSwitchSemantics(String name) {
    return 'Consenti all\'assistente di leggere la cartella clinica di $name';
  }

  @override
  String get petsConsentWithoutConsent =>
      'Senza consenso l\'assistente non vede né i titoli né il contenuto dei referti.';

  @override
  String get petsConsentSaveFailed =>
      'Non sono riuscito a salvare il consenso. Riprova.';

  @override
  String get petsConsentStatusUnavailable =>
      'Stato del consenso non disponibile: controlla la connessione.';

  @override
  String get petsConsentSlowConnection =>
      'Connessione lenta. Il consenso non è stato salvato, riprova.';

  @override
  String get petsConsentOffline =>
      'Sei offline: il consenso non è stato salvato. Riprova con la connessione.';

  @override
  String get placesDetailBarrierFence => 'Recintata';

  @override
  String get placesDetailBarrierWall => 'Recintata da un muro';

  @override
  String get placesDetailBarrierHedge => 'Delimitata da una siepe';

  @override
  String get placesDetailSurfaceGrass => 'Fondo in erba';

  @override
  String get placesDetailSurfaceGround => 'Fondo in terra';

  @override
  String get placesDetailSurfaceSand => 'Fondo in sabbia';

  @override
  String get placesDetailSurfaceGravel => 'Fondo in ghiaia';

  @override
  String get placesDetailSurfaceAsphalt => 'Fondo asfaltato';

  @override
  String get placesDetailSurfacePaved => 'Fondo pavimentato';

  @override
  String get placesDetailAccessFree => 'Accesso libero';

  @override
  String get placesDetailAccessPermissive => 'Accesso consentito';

  @override
  String get placesDetailAccessCustomers => 'Solo per i clienti';

  @override
  String get placesDetailAccessPrivate => 'Area privata';

  @override
  String get placesDetailWheelchairYes => 'Accessibile in sedia a rotelle';

  @override
  String get placesDetailWheelchairLimited =>
      'Accessibilità parziale in sedia a rotelle';

  @override
  String get placesDetailWheelchairNo => 'Non accessibile in sedia a rotelle';

  @override
  String get placesDetailDrinkingWaterYes => 'Acqua potabile';

  @override
  String get placesDetailDrinkingWaterNo => 'Senza acqua potabile';

  @override
  String get placesDetailLitYes => 'Illuminata';

  @override
  String get placesDetailLitNo => 'Non illuminata';

  @override
  String get placesDetailDogUnleashed => 'Cani liberi senza guinzaglio';

  @override
  String get placesDetailAdoptionYes => 'Adozioni possibili';

  @override
  String get placesDetailAdoptionNo => 'Non dà in adozione';

  @override
  String placesPendingDogPark(String progress) {
    return 'Segnalata dagli utenti, verifica che sia un’area pubblica ($progress)';
  }

  @override
  String placesPendingPlace(String progress) {
    return 'Segnalato dagli utenti · in attesa di conferma ($progress)';
  }

  @override
  String placesMailRemoveSubject(String id) {
    return 'Area cani da rimuovere dal radar ($id)';
  }

  @override
  String placesMailRemoveBody(String name, String position, String id) {
    return 'Questa area segnalata dagli utenti non è un’area cani pubblica.\n\nNome: $name\nPosizione: $position\nIdentificativo: $id\n\nMotivo: ';
  }

  @override
  String get placesWithdrawTitle => 'Ritirare la segnalazione?';

  @override
  String get placesWithdrawBody =>
      'La segnalazione viene cancellata e non sarà più visibile a nessuno.';

  @override
  String get placesWithdrawConfirm => 'Ritira';

  @override
  String get placesWithdrawnSnack => 'Segnalazione ritirata.';

  @override
  String get placesVoteConfirmedSnack => 'Grazie, conferma registrata.';

  @override
  String get placesVoteDeniedSnack => 'Grazie, registrato.';

  @override
  String placesRatedSnack(int stars) {
    return 'Voto registrato: $stars su 5.';
  }

  @override
  String get placesReportsInactiveSnack =>
      'Le segnalazioni non sono attive in questo momento.';

  @override
  String get placesReportProblemTitle => 'Cosa non va in questo luogo?';

  @override
  String get placesReportAlreadyKnown =>
      'Era già stato segnalato: la tua segnalazione vale come conferma.';

  @override
  String get placesReportSent =>
      'Segnalazione inviata. Sarà applicata quando altri utenti la confermano.';

  @override
  String get placesSheetPendingQuestion => 'Questo luogo esiste davvero qui?';

  @override
  String get placesSheetNotPublicWrite => 'Non è un’area pubblica? Scrivici';

  @override
  String placesSheetClosedReported(String progress) {
    return 'Segnalato come chiuso ($progress)';
  }

  @override
  String get placesSheetClosedQuestion => 'Ha chiuso davvero?';

  @override
  String placesSheetOpeningHours(String hours) {
    return 'Orari indicati: $hours';
  }

  @override
  String get placesActionCall => 'Chiama';

  @override
  String get placesActionDirections => 'Indicazioni';

  @override
  String get placesActionWebsite => 'Sito web';

  @override
  String get placesDisclaimerCommunity =>
      'Luogo segnalato dagli utenti: non è una garanzia, verifica prima di andarci.';

  @override
  String get placesDisclaimerClinic =>
      'In caso di urgenza telefona prima di partire: orari e recapiti arrivano da archivi aperti e non sono verificati da VetApp.';

  @override
  String get placesDisclaimerGeneric =>
      'Orari e recapiti arrivano da archivi aperti e non sono verificati da VetApp.';

  @override
  String placesSourceLine(String source) {
    return 'Fonte: $source';
  }

  @override
  String placesAlsoIn(String sources) {
    return 'Presente anche in: $sources';
  }

  @override
  String get placesReportProblemAction => 'Segnala un problema';

  @override
  String get placesBannerWithdrawing => 'Ritiro la segnalazione…';

  @override
  String get placesBannerYouReported =>
      'L’hai segnalato tu: servono le conferme di altri utenti.';

  @override
  String get placesBannerConfirmedSaving => 'Hai confermato. Salvataggio…';

  @override
  String get placesBannerConfirmedChange =>
      'Hai confermato. Puoi cambiare idea.';

  @override
  String get placesBannerDeniedSaving =>
      'Hai indicato che non è così. Salvataggio…';

  @override
  String get placesBannerDeniedChange =>
      'Hai indicato che non è così. Puoi cambiare idea.';

  @override
  String get placesBannerWithdrawButton => 'Ritira la mia segnalazione';

  @override
  String get placesBannerConfirm => 'Confermo';

  @override
  String get placesBannerDeny => 'Non è così';

  @override
  String placesVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voti',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String placesRatingAverage(String average, String votes) {
    return 'Voto della community: $average su 5 · $votes';
  }

  @override
  String get placesRatingNone => 'Voto della community: nessun voto ancora';

  @override
  String placesRatingBelowThreshold(String votes) {
    return 'Voto della community: $votes · la media compare da 3 voti';
  }

  @override
  String placesRateStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dai $count stelle',
      one: 'Dai 1 stella',
    );
    return '$_temp0';
  }

  @override
  String placesRatingSaving(int stars) {
    return 'Il tuo voto: $stars su 5. Salvataggio…';
  }

  @override
  String placesRatingYours(int stars) {
    return 'Il tuo voto: $stars su 5. Tocca una stella per cambiarlo.';
  }

  @override
  String get placesRatingPrompt =>
      'Com’è quest’area cani? Tocca una stella per dare il tuo voto.';

  @override
  String get placesExpiryToday => 'Scade oggi se nessuno conferma.';

  @override
  String placesExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Scade tra $days giorni se nessuno conferma.',
      one: 'Scade tra 1 giorno se nessuno conferma.',
    );
    return '$_temp0';
  }

  @override
  String get placesProblemClosed => 'Ha chiuso o non esiste più';

  @override
  String get placesProblemDuplicate => 'È un doppione di un altro luogo';

  @override
  String get placesProblemWrongPosition => 'La posizione è sbagliata';

  @override
  String get placesCategoryVeterinary => 'Veterinari';

  @override
  String get placesCategoryShop => 'Negozi';

  @override
  String get placesCategoryDogPark => 'Aree cani';

  @override
  String get placesCategoryShelter => 'Rifugi e adozioni';

  @override
  String get placesCategoryGrooming => 'Toelettature';

  @override
  String get placesCategoryHotel => 'Pensioni';

  @override
  String get placesCategorySchool => 'Addestramento';

  @override
  String get placesCategoryPetSitting => 'Pet sitter';

  @override
  String get placesCategoryBreeder => 'Allevamenti';

  @override
  String get placesCategoryOther => 'Altri servizi';

  @override
  String get placesTypeVeterinary => 'Veterinario';

  @override
  String get placesTypeGrooming => 'Toelettatura';

  @override
  String get placesTypeShop => 'Negozio per animali';

  @override
  String get placesTypeSchool => 'Addestramento';

  @override
  String get placesTypePetSitting => 'Pet sitter';

  @override
  String get placesTypeBreeder => 'Allevamento';

  @override
  String get placesTypeHotel => 'Pensione per animali';

  @override
  String get placesTypeDogPark => 'Area cani';

  @override
  String get placesTypeShelter => 'Rifugio per animali';

  @override
  String get placesTypeOther => 'Servizio per animali';

  @override
  String get placesHours247 => 'Indicato come aperto 24 ore su 24';

  @override
  String get placesHoursHolidays => 'Festivi';

  @override
  String get placesHoursClosed => 'chiuso';

  @override
  String get placesSourcesTitle => 'Fonti dati';

  @override
  String get placesSourcesIntro =>
      'I luoghi del radar arrivano da archivi aperti, non da VetApp. Ogni scheda indica la sua fonte. Orari e recapiti possono non essere aggiornati.';

  @override
  String get placesSourcesNoContact =>
      'Hai trovato un dato sbagliato? Usa \"Segnala un problema\" nella scheda del luogo.';

  @override
  String placesSourcesContact(String email) {
    return 'Hai trovato un dato sbagliato, o sei il titolare e vuoi che una scheda venga corretta o rimossa? Scrivi a $email.';
  }

  @override
  String placesSourceLicense(String license) {
    return 'Licenza: $license';
  }

  @override
  String placesSourceVersion(String release, String date) {
    return 'Versione $release, importata il $date';
  }

  @override
  String get placesSourceLicenseLink => 'Licenza e condizioni';

  @override
  String get placesSourceOsmDescription =>
      'Mappa libera curata da volontari. Fonte delle aree cani e di parte di veterinari, negozi e altri servizi, con i dettagli che i volontari hanno indicato.';

  @override
  String get placesSourceOvertureDescription =>
      'Archivio aperto di attività commerciali. Fonte di veterinari, toelettature, negozi, pensioni e addestratori che OpenStreetMap non conosce.';

  @override
  String get placesSourceBolognaDescription =>
      'Elenco ufficiale delle aree di sgambatura per cani del Comune di Bologna.';

  @override
  String get placesSourceTorinoDescription =>
      'Elenco ufficiale delle aree cani della Città di Torino.';

  @override
  String get placesSourceMilanoDescription =>
      'Elenco ufficiale delle aree cani del Comune di Milano.';

  @override
  String get placesSourceBolognaAttribution =>
      'Comune di Bologna, Aree sgambatura cani (opendata.comune.bologna.it), licenza CC BY 4.0';

  @override
  String get placesSourceTorinoAttribution =>
      'Comune di Torino, Aree Cani (aperto.comune.torino.it), licenza CC BY 4.0, dati del 2019';

  @override
  String get placesSourceMilanoAttribution =>
      'Comune di Milano, Territorio: localizzazione delle aree cani (dati.comune.milano.it), licenza CC BY 4.0. Contiene elaborazioni di dati CC BY 3.0 da dati.gov.it';

  @override
  String get placesSourceLicenseCcBy =>
      'Creative Commons Attribuzione 4.0 (CC BY 4.0)';

  @override
  String get placesSourceUsersName => 'Utenti VetApp';

  @override
  String get placesSourceUsersDescription =>
      'Luoghi segnalati dagli utenti e confermati da altri utenti.';

  @override
  String get placesSourceUsersAttribution => 'Segnalato dagli utenti VetApp';

  @override
  String placesMapTitle(String radius) {
    return 'Mappa · $radius';
  }

  @override
  String placesMapClusterSemantics(int count) {
    return '$count luoghi vicini tra loro';
  }

  @override
  String placesMapMarkerPending(String category, String label) {
    return '$category, in attesa di conferma: $label';
  }

  @override
  String placesMapMarker(String category, String label) {
    return '$category: $label';
  }

  @override
  String get placesReportTitle => 'Segnala un luogo mancante';

  @override
  String get placesReportUnavailable =>
      'Le segnalazioni non sono disponibili in questo momento. Riprova più tardi.';

  @override
  String get placesReportWhatIs => 'Che cos’è?';

  @override
  String get placesReportNameOptional => 'Nome (facoltativo)';

  @override
  String get placesReportNameLabel => 'Nome sull’insegna';

  @override
  String get placesReportNameHelper =>
      'Solo il nome: niente telefoni, indirizzi o nomi di persone.';

  @override
  String get placesReportWhere => 'Dove si trova?';

  @override
  String get placesReportMapHint =>
      'Sposta la mappa finché il segnaposto è sul luogo. L’indirizzo viene ricavato dalla posizione.';

  @override
  String get placesReportSubmit => 'Invia segnalazione';

  @override
  String placesReportFootnote(int days) {
    return 'La segnalazione sarà visibile a tutti come \"in attesa di conferma\" e diventerà definitiva quando altri utenti la confermano. Se entro $days giorni nessuno la conferma, viene cancellata in automatico. Puoi ritirarla in ogni momento dalla sua scheda. Il tuo nome non compare.';
  }

  @override
  String placesReportSentExpiry(int days) {
    return 'Segnalazione inviata. Se entro $days giorni nessuno la conferma, viene cancellata.';
  }

  @override
  String get placesRulesTitle => 'Prima di segnalare o votare';

  @override
  String get placesRulesCheckbox =>
      'Ho letto le regole e segnalo o voto in buona fede.';

  @override
  String get placesRulesAccept => 'Accetto';

  @override
  String get placesRulesFallback =>
      'Segnala solo ciò che hai verificato di persona. Per le attività scrivi solo il nome dell’insegna, senza telefoni, indirizzi privati o dati di altre persone. Le segnalazioni restano in attesa finché altri utenti non le confermano. Segnalazioni false o ripetute possono portare alla sospensione dell’account. Segnalazioni e voti sono pubblicati senza il tuo nome.';

  @override
  String get placesErrSignedOutContribute => 'Accedi per segnalare o votare.';

  @override
  String get placesErrOperationFailed =>
      'Non sono riuscito a completare l’operazione. Riprova.';

  @override
  String get placesErrTimeout =>
      'La richiesta ha impiegato troppo tempo. Riprova.';

  @override
  String get placesErrNotConfigured =>
      'Anteprima senza backend: i luoghi mostrati sono dati di esempio.';

  @override
  String get placesErrSignedOut =>
      'Accedi per vedere i servizi per animali vicino a te.';

  @override
  String get placesErrPreparing =>
      'Sto ancora preparando i servizi di questa zona. Riprova tra poco.';

  @override
  String get placesErrSessionExpired =>
      'La sessione non è più valida: esci e accedi di nuovo per vedere i servizi vicini.';

  @override
  String get placesErrLoadFailed =>
      'Non sono riuscito a caricare i servizi vicini. Riprova.';

  @override
  String get placesBackendRulesRequired =>
      'Per segnalare o votare accetta prima le regole per segnalazioni e voti.';

  @override
  String get placesBackendReportClosed =>
      'Questa segnalazione è già stata chiusa.';

  @override
  String get placesBackendReportExpired =>
      'Questa segnalazione è scaduta: nessuno l\'ha confermata.';

  @override
  String get placesBackendOwnReportVote =>
      'Non puoi confermare una tua segnalazione.';

  @override
  String get placesBackendKindNotActive =>
      'Questo tipo di segnalazione non è attivo.';

  @override
  String get placesBackendCategoryNotReportable =>
      'Questa categoria non può essere segnalata.';

  @override
  String get placesBackendTargetRequired =>
      'Indica il luogo a cui si riferisce la segnalazione.';

  @override
  String get placesBackendPendingUseDeny =>
      'Per un luogo in attesa di conferma usa \"Non è così\" sulla sua scheda.';

  @override
  String get placesBackendAlreadyReported =>
      'Hai già fatto questa segnalazione.';

  @override
  String placesBackendDailyLimit(int count) {
    return 'Puoi fare al massimo $count segnalazioni al giorno.';
  }

  @override
  String get placesBackendReportNotFound => 'Segnalazione non trovata.';

  @override
  String get placesBackendWithdrawOwnOnly =>
      'Puoi ritirare solo una tua segnalazione.';

  @override
  String get placesBackendWithdrawClosed =>
      'Questa segnalazione è già chiusa: non si può più ritirare.';

  @override
  String get placesBackendRatingsOff => 'Le valutazioni non sono attive.';

  @override
  String get placesBackendRatePublicOnly =>
      'Si possono valutare solo le aree cani pubbliche.';

  @override
  String get placesBackendDogParkNotFound => 'Area cani non trovata.';

  @override
  String get placesBackendContributionsOff =>
      'Segnalazioni e voti non sono ancora attivi.';

  @override
  String get placesBackendNameRequired =>
      'Scrivi il nome dell\'attività, come appare sull\'insegna.';

  @override
  String placesBackendNameTooLong(int count) {
    return 'Il nome può avere al massimo $count caratteri.';
  }

  @override
  String get placesBackendNameNoContacts =>
      'Nel nome non inserire telefoni, email o siti web.';

  @override
  String get placesBackendNameBlockedWords =>
      'Il nome contiene parole non ammesse.';

  @override
  String get eventsTitle => 'Eventi';

  @override
  String get eventsSearching => 'Cerco gli eventi...';

  @override
  String get eventsAllRegions => 'Tutte le regioni';

  @override
  String get eventsAllTypes => 'Tutti i tipi';

  @override
  String get eventsReset => 'Reimposta';

  @override
  String get eventsDisclaimer =>
      'Date e luoghi possono cambiare: verifica sempre sul sito dell\'organizzatore.';

  @override
  String get eventsPickRegionTitle => 'Regione';

  @override
  String get eventsPickTypeTitle => 'Tipo di evento';

  @override
  String get eventsPickDatesHelp => 'Scegli il periodo';

  @override
  String get eventsPickDatesSave => 'Applica';

  @override
  String get eventsStatusCancelled => 'Annullato';

  @override
  String get eventsStatusPostponed => 'Rinviato';

  @override
  String eventsOrganizedBy(String name) {
    return 'Organizzato da $name';
  }

  @override
  String get eventsLoadError =>
      'Non riesco a caricare gli eventi. Controlla la connessione e riprova.';

  @override
  String eventsWindowDefault(int days) {
    return 'Prossimi $days giorni';
  }

  @override
  String get eventsEmptyFiltered =>
      'Nessun evento con questi filtri nel periodo scelto';

  @override
  String eventsEmptyDefault(int days) {
    return 'Nessun evento nei prossimi $days giorni';
  }

  @override
  String get eventsEmptyPeriod => 'Nessun evento nel periodo scelto';

  @override
  String get eventsLevelLocal => 'Locale';

  @override
  String get eventsLevelProvincial => 'Provinciale';

  @override
  String get eventsLevelRegional => 'Regionale';

  @override
  String get eventsLevelNational => 'Nazionale';

  @override
  String get eventsLevelInternational => 'Internazionale';

  @override
  String get eventsTypePetFair => 'Fiera per animali';

  @override
  String get eventsTypeDogShow => 'Esposizione canina';

  @override
  String get eventsTypeBreedGathering => 'Raduno di razza';

  @override
  String get eventsTypeCatShow => 'Esposizione felina';

  @override
  String get eventsTypeWorkTrial => 'Prova di lavoro';

  @override
  String get eventsTypeDogSport => 'Sport cinofili';

  @override
  String get eventsTypeAdoptionDay => 'Giornata di adozione';

  @override
  String get eventsTypeShelterOpenDay => 'Open day rifugio';

  @override
  String get eventsTypeMicrochipDay => 'Microchip day';

  @override
  String get eventsTypeVaccinationCampaign => 'Campagna vaccinale';

  @override
  String get eventsTypeGroupWalk => 'Passeggiata di gruppo';

  @override
  String get eventsTypeCourseSeminar => 'Corso o seminario';

  @override
  String get eventsTypeMarket => 'Mercatino';

  @override
  String get eventsTypeCharityEvent => 'Evento benefico';

  @override
  String get eventsTypeAquariumExpo => 'Acquariofilia';

  @override
  String get eventsTypeReptileExpo => 'Terraristica';

  @override
  String get eventsTypeBirdShow => 'Ornitologia';

  @override
  String get eventsTypeEquestrian => 'Equestre';

  @override
  String get eventsTypeOther => 'Altro';

  @override
  String get localActivitiesKindEvent => 'Evento';

  @override
  String get localActivitiesKindService => 'Servizio';

  @override
  String get localEventsTitle => 'Vicino a me';

  @override
  String get localEventsLocating => 'Cerco la tua posizione…';

  @override
  String get localEventsSearchingAround =>
      'Cerco cosa c’è attorno a te. La prima volta in una zona può richiedere fino a un minuto.';

  @override
  String get localEventsConsentTitle => 'Usare la tua posizione?';

  @override
  String get localEventsConsentBody =>
      'Per mostrarti cosa c’è vicino a te VetApp usa la posizione del telefono solo mentre usi l’app. In alternativa puoi indicare un indirizzo.';

  @override
  String get localEventsConsentChooseAddress => 'Scegli un indirizzo';

  @override
  String get localEventsConsentAllow => 'Consenti';

  @override
  String get localEventsReportMissing => 'Segnala! Manca un luogo';

  @override
  String get localEventsServicesHeader => 'Servizi nella zona';

  @override
  String get localEventsClinicsHeader => 'Cliniche e ambulatori';

  @override
  String get localEventsNoClinics =>
      'Nessuna clinica trovata con questi filtri.';

  @override
  String get localEventsNoServices =>
      'Nessun servizio trovato con questi filtri.';

  @override
  String get localEventsAll => 'Tutti';

  @override
  String get localEventsMapFullscreen => 'Apri la mappa a tutto schermo';

  @override
  String get localEventsNoLocationTitle => 'Imposta una località';

  @override
  String get localEventsNoLocationBody =>
      'Per mostrarti cosa c’è attorno a te serve la tua posizione. Consenti l’accesso alla posizione oppure indica la tua residenza in Impostazioni → Località.';

  @override
  String get localEventsOpenSettings => 'Apri Impostazioni';

  @override
  String localEventsSearchingRadius(String radius) {
    return 'Cerco i servizi entro $radius. La prima volta in una zona può richiedere fino a un minuto.';
  }

  @override
  String get localEventsSearchingNearby =>
      'Cerco i servizi nella tua zona. La prima volta può richiedere qualche secondo.';

  @override
  String get localEventsStale =>
      'Non sono riuscito ad aggiornare i servizi di questa zona: vedi gli ultimi dati disponibili, che potrebbero non essere recenti.';

  @override
  String localEventsPartialRadius(String radius) {
    return 'Per ora i servizi sono disponibili entro $radius: riprova tra poco per il raggio completo.';
  }

  @override
  String get localEventsShowLess => 'Mostra meno';

  @override
  String localEventsShowAllCount(int count) {
    return 'Mostra tutti ($count)';
  }

  @override
  String localEventsShowAllCategory(String category, int count) {
    return 'Mostra tutti: $category ($count)';
  }

  @override
  String localEventsCategoryNone(String category, String radius) {
    return '$category: nessuno entro $radius';
  }

  @override
  String localEventsCategoryCount(String category, int count) {
    return '$category ($count)';
  }

  @override
  String localEventsCallTooltip(String name) {
    return 'Chiama $name';
  }

  @override
  String localEventsDirectionsTooltip(String name) {
    return 'Indicazioni per $name';
  }

  @override
  String get remindersRelativeToday => 'oggi';

  @override
  String get remindersRelativeTomorrow => 'domani';

  @override
  String get remindersRelativeYesterday => 'ieri';

  @override
  String remindersRelativeInDays(int days) {
    return 'tra $days giorni';
  }

  @override
  String remindersRelativeDaysAgo(int days) {
    return '$days giorni fa';
  }

  @override
  String get remindersKindEvent => 'Evento';

  @override
  String remindersKindRecurring(String interval, String end) {
    return 'Ricorrente · $interval$end';
  }

  @override
  String remindersCourseStarts(String day) {
    return 'Inizia $day';
  }

  @override
  String get remindersCourseCompleted => 'Completato';

  @override
  String remindersCourseDayOf(int day, int total) {
    return 'Giorno $day di $total';
  }

  @override
  String remindersKindCourse(int days) {
    return 'Ciclo · $days giorni';
  }

  @override
  String remindersKindCourseWithTimes(int days, String times) {
    return 'Ciclo · $days giorni · $times';
  }

  @override
  String remindersIntervalEveryDays(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: '$value giorni',
      one: '1 giorno',
    );
    return 'ogni $_temp0';
  }

  @override
  String remindersIntervalEveryMonths(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: '$value mesi',
      one: '1 mese',
    );
    return 'ogni $_temp0';
  }

  @override
  String remindersEndAfterTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count volte',
      one: '1 volta',
    );
    return ' · per $_temp0';
  }

  @override
  String remindersEndUntilDate(String date) {
    return ' · fino al $date';
  }

  @override
  String get remindersMenuTooltip => 'Opzioni promemoria';

  @override
  String get remindersMenuMarkDone => 'Segna come fatto';

  @override
  String get remindersDeleteConfirmTitle => 'Eliminare questo promemoria?';

  @override
  String remindersDeleteConfirmBody(String title) {
    return '\"$title\" verrà eliminato definitivamente.';
  }

  @override
  String get remindersErrorPetNotSynced =>
      'Il profilo dell\'animale non è sincronizzato sul server: sistemalo prima di creare promemoria.';

  @override
  String get remindersErrorSaveFailed =>
      'Non sono riuscito a salvare il promemoria. Riprova.';

  @override
  String get remindersErrorDeleteFailed =>
      'Non sono riuscito a eliminare il promemoria. Riprova.';

  @override
  String get petNewsTitle => 'Notizie';

  @override
  String get petNewsLoading => 'Carico le News...';

  @override
  String get petNewsEmpty =>
      'Nessuna notizia disponibile per questa categoria al momento.';

  @override
  String get petNewsCategoryAll => 'Tutti';

  @override
  String get petNewsCategoryDog => 'Cane';

  @override
  String get petNewsCategoryCat => 'Gatto';

  @override
  String get petNewsCategorySmallMammals => 'Piccoli mammiferi';

  @override
  String get petNewsCategoryBird => 'Uccello';

  @override
  String get petNewsCategoryReptiles => 'Rettili e anfibi';

  @override
  String get petNewsCategoryFish => 'Pesce';

  @override
  String get petNewsCategoryOther => 'Altro';

  @override
  String get petNewsCategoryGeneral => 'Generale';

  @override
  String get profileLogoutDialogTitle => 'Esci';

  @override
  String get profileLogoutDialogBody =>
      'Vuoi disconnetterti da questo account?';

  @override
  String get profileGuestName => 'Ospite';

  @override
  String get profileNoActiveSession => 'Nessuna sessione attiva';

  @override
  String profileSummaryBody(String pets) {
    return 'Profilo owner collegato a $pets e pronto per la web app responsive.';
  }

  @override
  String profilePetCount(int count) {
    return '$count pet';
  }

  @override
  String get profileContactsTitle => 'Contatti';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePhoneLabel => 'Telefono';

  @override
  String get profilePhoneNotSet => 'Non specificato';

  @override
  String get profileCityLabel => 'Città';

  @override
  String get profileCityNotSet => 'Non specificata';

  @override
  String get profileEveningThemeTitle => 'Tema serale';

  @override
  String get profileEveningThemeBody =>
      'Anteprima di una palette piu soft per l uso serale.';

  @override
  String get profileAccountStatusTitle => 'Stato account';

  @override
  String get profileSessionLabel => 'Sessione';

  @override
  String get profileSessionActive => 'Attiva';

  @override
  String get profilePrivacyLabel => 'Privacy';

  @override
  String get profilePrivacyUpdated => 'Aggiornata';

  @override
  String get profileSupportLabel => 'Supporto';

  @override
  String get profileSupportAvailable => 'Disponibile';

  @override
  String get profileSettingsButton => 'Impostazioni';

  @override
  String get profileLogoutButton => 'Logout';

  @override
  String get profileTitle => 'Profilo';

  @override
  String get profileIntro =>
      'Dati owner, preferenze e dettagli account in un unico posto per la web app responsive.';

  @override
  String get profileRoadmapTitle => 'Prossimi step';

  @override
  String get profileRoadmapBody =>
      'Qui possiamo far evolvere consensi, preferenze e collegamento account senza cambiare il flusso web.';

  @override
  String get activitiesTitle => 'Attività';

  @override
  String get activitiesSubtitle =>
      'Tutto quello che ruota attorno alla vita con i tuoi animali.';

  @override
  String get activitiesNewsSubtitle =>
      'Curiosità e attualità sugli animali domestici.';

  @override
  String get activitiesNearbyTitle => 'Vicino a me';

  @override
  String get activitiesNearbySubtitle =>
      'Veterinari, negozi e aree cani vicino a te.';

  @override
  String get activitiesEventsTitle => 'Eventi';

  @override
  String get activitiesEventsSubtitle =>
      'Fiere, esposizioni e iniziative per animali in tutta Italia.';

  @override
  String get activitiesGalleryTitle => 'Galleria';

  @override
  String get activitiesGallerySubtitle =>
      'Raccogli foto e ricordi dei tuoi animali.';

  @override
  String get activitiesMarketplaceTitle => 'Mercatino dell\'usato';

  @override
  String get activitiesMarketplaceSubtitle =>
      'Compra, vendi e scambia articoli per animali.';

  @override
  String get activitiesPetFriendTitle => 'Pet friend';

  @override
  String get activitiesPetFriendSubtitle =>
      'Incontri e compagnia tra animali e proprietari.';

  @override
  String get activitiesComingSoonBadge => 'In arrivo';

  @override
  String get activitiesPetFriendDescription =>
      'Incontra altri proprietari e organizza uscite tra animali con affinità simili.';

  @override
  String get remindersTitle => 'Promemoria';

  @override
  String get remindersSubtitle =>
      'Vaccini, trattamenti e visite da tenere sotto controllo.';

  @override
  String get remindersCreateButton => 'Crea';

  @override
  String get remindersLoadingTitle => 'Caricamento promemoria';

  @override
  String get remindersLoadingBody =>
      'Sto leggendo date, ricorrenze e note del proprietario.';

  @override
  String get remindersSyncErrorLabel => 'Errore sync';

  @override
  String get remindersSyncErrorTitle => 'Sincronizzazione promemoria fallita.';

  @override
  String get remindersSyncErrorBody =>
      'La sorgente demo e ancora disponibile. Riprova quando la rete torna su.';

  @override
  String get remindersEmptyLabel => 'Nessun promemoria';

  @override
  String get remindersEmptyTitle => 'La lista dei promemoria e vuota.';

  @override
  String get remindersEmptyBody =>
      'Crea il primo promemoria per vaccino o trattamento e resta in carreggiata.';

  @override
  String get remindersNoMatchForFilters =>
      'Nessun promemoria per questi filtri.';

  @override
  String get remindersFilterAll => 'Tutti';

  @override
  String get remindersFilterEvents => 'Eventi';

  @override
  String get remindersFilterCourses => 'Cicli';

  @override
  String get remindersViewList => 'Lista';

  @override
  String get remindersViewCalendar => 'Calendario';

  @override
  String get remindersNothingThisDay => 'Nessuna attività in questo giorno.';

  @override
  String get remindersTodayCapitalized => 'Oggi';

  @override
  String get remindersEditTitle => 'Modifica promemoria';

  @override
  String get remindersEditSubtitle => 'Aggiorna tipo, data e note.';

  @override
  String get remindersDosePickerHelp => 'Orario della dose';

  @override
  String get remindersDateRequired => 'Inserisci una data.';

  @override
  String get remindersDateInvalid => 'Data non valida (gg/mm/aaaa).';

  @override
  String get remindersFormKind => 'Tipo';

  @override
  String get remindersFormTitleLabel => 'Titolo';

  @override
  String get remindersFormTitleHint => 'Es. Richiamo vaccinale';

  @override
  String remindersFormTitleHintWithPet(String petName) {
    return 'Es. Richiamo vaccinale di $petName';
  }

  @override
  String get remindersTitleRequired => 'Inserisci un titolo.';

  @override
  String get remindersFieldDate => 'Data';

  @override
  String get remindersFieldNextDue => 'Prossima scadenza';

  @override
  String get remindersFieldStartDate => 'Data di inizio';

  @override
  String get remindersFieldTime => 'Ora';

  @override
  String get remindersRepeats => 'Si ripete';

  @override
  String get remindersCustomNumberHint => 'Numero';

  @override
  String get remindersRecurrenceEndLabel => 'Fine ricorrenza';

  @override
  String get remindersOccurrenceCountHint => 'Numero di volte';

  @override
  String get remindersLastDate => 'Ultima data';

  @override
  String get remindersCourseDuration => 'Durata del ciclo';

  @override
  String get remindersDoseTimes => 'Orari delle dosi';

  @override
  String get remindersAddDoseTime => 'Aggiungi orario';

  @override
  String get remindersNoDoseTimesNote =>
      'Senza orari ricevi un avviso al giorno, alle 9:00.';

  @override
  String get remindersFormNote => 'Nota';

  @override
  String get remindersFormNoteHint => 'Es. Porta il libretto sanitario';

  @override
  String get remindersKindOptionRecurring => 'Ricorrente';

  @override
  String get remindersKindOptionCourse => 'Ciclo';

  @override
  String get remindersDatePlaceholder => 'gg/mm/aaaa';

  @override
  String get remindersPreset7Days => '7 gg';

  @override
  String get remindersPreset30Days => '30 gg';

  @override
  String get remindersPreset6Months => '6 mesi';

  @override
  String get remindersPreset12Months => '12 mesi';

  @override
  String get remindersPresetCustom => 'Personalizzato';

  @override
  String get remindersEndAlways => 'Sempre';

  @override
  String get remindersEndAfterN => 'Per N volte';

  @override
  String get remindersEndUntil => 'Fino a una data';

  @override
  String get remindersUnitDays => 'Giorni';

  @override
  String get remindersUnitMonths => 'Mesi';

  @override
  String get remindersOneDayLess => 'Un giorno in meno';

  @override
  String remindersDurationRange(int min, int max) {
    return 'Da $min a $max giorni.';
  }

  @override
  String remindersDurationUnit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'giorni',
      one: 'giorno',
    );
    return '$_temp0';
  }

  @override
  String get remindersOneDayMore => 'Un giorno in più';

  @override
  String get remindersNotFoundTitle => 'Promemoria non trovato';

  @override
  String get remindersNotFoundSubtitle =>
      'Questo promemoria non è più disponibile.';

  @override
  String get remindersNotFoundLabel => 'Non trovato';

  @override
  String get remindersNotFoundPanelTitle => 'Nessun promemoria da mostrare.';

  @override
  String get remindersNotFoundBody =>
      'Potrebbe essere stato eliminato o non essere ancora sincronizzato.';

  @override
  String get remindersBackToList => 'Torna alla lista';

  @override
  String get remindersDetailTitle => 'Dettaglio promemoria';

  @override
  String get remindersDetailSubtitle => 'Tipo, data e nota del promemoria.';

  @override
  String get remindersNoNote => 'Nessuna nota aggiunta.';

  @override
  String get remindersSummaryTitle => 'Riepilogo promemoria';

  @override
  String get remindersSummaryPet => 'Animale';

  @override
  String get remindersSummaryStatus => 'Stato';

  @override
  String get remindersDeleteButton => 'Elimina promemoria';

  @override
  String get remindersLoadingLabel => 'Caricamento';

  @override
  String get remindersWait => 'Attendi';

  @override
  String get remindersCreateTitle => 'Crea promemoria';

  @override
  String remindersCreateTitleForPet(String petName) {
    return 'Nuovo promemoria per $petName';
  }

  @override
  String get remindersCreateSubtitle => 'Scegli il tipo, la data e i dettagli.';

  @override
  String get settingsUnitSystemMetricLabel => 'Metrico';

  @override
  String get settingsUnitSystemUkLabel => 'Regno Unito';

  @override
  String get settingsUnitSystemUsLabel => 'USA';

  @override
  String get settingsUnitSystemMetricDescription => 'km, kg, °C, litri';

  @override
  String get settingsUnitSystemUkDescription => 'miglia, libbre, °C, litri';

  @override
  String get settingsUnitSystemUsDescription =>
      'miglia, libbre, °F, galloni USA';

  @override
  String settingsVolumeLiters(int liters) {
    return '$liters litri';
  }

  @override
  String get settingsUnitLitersName => 'litri';

  @override
  String get settingsTextSizeSmall => 'Piccolo';

  @override
  String get settingsTextSizeNormal => 'Normale';

  @override
  String get settingsTextSizeLarge => 'Grande';

  @override
  String get settingsTextSizeExtraLarge => 'Molto grande';

  @override
  String get settingsLocationPickerTitle => 'Scegli sulla mappa';

  @override
  String get settingsLocationPickerHint =>
      'Sposta la mappa finché il segnaposto è sul punto giusto, poi conferma.';

  @override
  String get settingsLocationPickerConfirm => 'Conferma questo punto';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsNumericDatePattern => 'dd/MM/yyyy';

  @override
  String get settingsGuestInitial => 'O';

  @override
  String get settingsGuestName => 'Ospite';

  @override
  String get settingsNoActiveSession => 'Nessuna sessione attiva';

  @override
  String get settingsSectionSubscription => 'Abbonamento';

  @override
  String get settingsSubscriptionAndPayments => 'Abbonamento e pagamenti';

  @override
  String settingsTrialExpiresOn(String date) {
    return 'Prova · scade il $date';
  }

  @override
  String get settingsSectionPushNotifications => 'Notifiche push';

  @override
  String get settingsNotificationsToggle => 'Notifiche';

  @override
  String get settingsSectionLayout => 'Layout';

  @override
  String get settingsLayoutWeeksTitle => 'Settimane visualizzate in Home';

  @override
  String get settingsLayoutWeeksSubtitle =>
      'Quante settimane mostrare nel calendario della Home.';

  @override
  String get settingsLayoutWeekStartTitle => 'Inizio settimana';

  @override
  String get settingsLayoutChatTextSizeTitle => 'Dimensione del testo in chat';

  @override
  String get settingsLayoutChatTextSizePreview =>
      'Così vedrai i messaggi della chat.';

  @override
  String get settingsLayoutUnitsTitle => 'Unità di misura';

  @override
  String get settingsSectionPhotosVideos => 'Foto e video';

  @override
  String get settingsGallerySaveTitle => 'Salva le foto nella galleria';

  @override
  String get settingsGallerySaveSubtitle =>
      'Le foto e i video scattati con la fotocamera dell\'app vengono copiati nell\'album \"VetApp\" del telefono.';

  @override
  String get settingsSectionLocation => 'Località';

  @override
  String get settingsLocationIntro =>
      'Usata per personalizzare eventi e news in base alla zona.';

  @override
  String get settingsLocationReferenceTitle => 'Posizione di riferimento';

  @override
  String get settingsLocationModeCurrent => 'Attuale';

  @override
  String get settingsLocationModeHome => 'Residenza';

  @override
  String get settingsLocationCurrentTitle => 'Posizione attuale';

  @override
  String get settingsLocationDetecting => 'Rilevamento in corso…';

  @override
  String get settingsLocationCurrentNotSet => 'Non ancora impostata';

  @override
  String get settingsLocationRefresh => 'Aggiorna';

  @override
  String get settingsLocationHomeTitle => 'Residenza abituale';

  @override
  String get settingsLocationHomeNotSet => 'Non impostata';

  @override
  String get settingsLocationSet => 'Imposta';

  @override
  String get settingsLocationErrorPermissionDenied =>
      'Permesso di localizzazione negato: abilitalo dalle impostazioni del dispositivo per usare la posizione attuale.';

  @override
  String get settingsLocationErrorServiceDisabled =>
      'La localizzazione è disattivata sul dispositivo.';

  @override
  String get settingsLocationErrorTimeout =>
      'Non sono riuscito a rilevare la posizione in tempo, riprova.';

  @override
  String get settingsLocationErrorUnsupported =>
      'Localizzazione non disponibile su questo dispositivo/browser.';

  @override
  String get settingsSectionPermissions => 'Permessi e consensi';

  @override
  String get settingsConsentsUnavailable => 'Non disponibili al momento';

  @override
  String get settingsConsentsTapToRetry => 'Tocca per riprovare';

  @override
  String get settingsConsentTerms => 'Termini di servizio';

  @override
  String get settingsConsentPrivacy => 'Informativa privacy';

  @override
  String get settingsConsentMarketingEmail => 'Email di marketing';

  @override
  String get settingsConsentAnalytics => 'Analisi d\'uso';

  @override
  String settingsConsentAccepted(String version, String date) {
    return 'Accettati v$version il $date';
  }

  @override
  String get settingsConsentToConfirm => 'Da confermare';

  @override
  String get settingsClinicalConsentSection => 'Cartella clinica e assistente';

  @override
  String get settingsPrivacyPolicyFullTitle => 'Informativa privacy completa';

  @override
  String get settingsPrivacyPolicyFullSubtitle =>
      'Leggi, scarica o condividi il testo';

  @override
  String get settingsSectionSupport => 'Assistenza';

  @override
  String get settingsHelpCenterTitle => 'Centro assistenza';

  @override
  String get settingsHelpCenterComingSoon =>
      'Domande frequenti e guide rapide, presto disponibili direttamente qui.';

  @override
  String get settingsContactUs => 'Contattaci';

  @override
  String get settingsContactUnavailable =>
      'Il contatto dell’assistenza non è disponibile in questo momento. Riprova più tardi.';

  @override
  String settingsContactWriteTo(String email) {
    return 'Scrivi a $email per qualsiasi domanda.';
  }

  @override
  String get settingsRateApp => 'Valuta l\'app';

  @override
  String get settingsRateAppThanks => 'Grazie per il supporto! ⭐';

  @override
  String get settingsSectionInfo => 'Info';

  @override
  String get settingsDataSourcesTitle => 'Fonti dati';

  @override
  String get settingsDataSourcesSubtitle =>
      'Da dove arrivano i luoghi del radar';

  @override
  String get settingsAppVersion => 'Versione app';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsLogout => 'Esci';

  @override
  String get settingsLogoutConfirmBody =>
      'Vuoi disconnetterti da questo account?';

  @override
  String get settingsHomeCountryDefault => 'Italia';

  @override
  String get settingsHomeAddressNotFound =>
      'Non trovo questo indirizzo. Controlla i dati e riprova.';

  @override
  String get settingsHomeAddressOrType => 'Oppure scrivi l\'indirizzo:';

  @override
  String get settingsHomeAddressStreet => 'Indirizzo';

  @override
  String get settingsHomeAddressStreetRequired => 'Inserisci l\'indirizzo';

  @override
  String get settingsHomeAddressPostalCode => 'CAP';

  @override
  String get settingsHomeAddressPostalCodeRequired => 'Inserisci il CAP';

  @override
  String get settingsHomeAddressCity => 'Città';

  @override
  String get settingsHomeAddressCityRequired => 'Inserisci la città';

  @override
  String get settingsHomeAddressCountry => 'Nazione';

  @override
  String get settingsHomeAddressCountryRequired => 'Inserisci la nazione';

  @override
  String get settingsHomeAddressSearching => 'Ricerca…';

  @override
  String get notificationsCategoryReminders => 'Visite e vaccini';

  @override
  String get notificationsCategoryMedicines => 'Orari dei farmaci';

  @override
  String get notificationsCategoryBirthdays => 'Compleanni';

  @override
  String get notificationsChannelRemindersName => 'Promemoria';

  @override
  String get notificationsChannelRemindersDescription =>
      'Visite, vaccini e altri promemoria';

  @override
  String get notificationsChannelMedicinesName => 'Farmaci';

  @override
  String get notificationsChannelBirthdaysDescription =>
      'Compleanni degli animali';

  @override
  String notificationsReminderTodayBody(String petName, String time) {
    return '$petName · oggi alle $time';
  }

  @override
  String notificationsReminderTomorrowTitle(String title) {
    return 'Domani: $title';
  }

  @override
  String notificationsReminderTomorrowBody(String petName, String time) {
    return '$petName · alle $time';
  }

  @override
  String notificationsMedicineTitle(String petName) {
    return 'Farmaco per $petName';
  }

  @override
  String notificationsMedicineDayBody(String title, int day, int total) {
    return '$title · giorno $day di $total';
  }

  @override
  String notificationsMedicineDoseBody(String title, String time) {
    return '$title · dose delle $time';
  }

  @override
  String notificationsBirthdayTitle(String petName) {
    return 'Buon compleanno, $petName!';
  }

  @override
  String notificationsBirthdayBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Oggi compie $count anni.',
      one: 'Oggi compie 1 anno.',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBirthdayUpcomingTitle => 'Compleanno in arrivo';

  @override
  String notificationsBirthdayUpcomingBody(String petName) {
    return 'Tra una settimana è il compleanno di $petName: pensa a un regalo.';
  }

  @override
  String walksPageTitle(String petName) {
    return 'Passeggiata di $petName';
  }

  @override
  String get walksStatusInProgress => 'Passeggiata in corso';

  @override
  String get walksStatusPaused => 'Passeggiata in pausa';

  @override
  String get walksStatDistance => 'Distanza';

  @override
  String get walksStatDuration => 'Durata';

  @override
  String get walksStatPhotos => 'Foto';

  @override
  String walksStatPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pause',
      one: 'Pausa',
    );
    return '$_temp0';
  }

  @override
  String get walksActionPause => 'Pausa';

  @override
  String get walksActionResume => 'Riavvia';

  @override
  String get walksActionFinish => 'Termina';

  @override
  String get walksActionSaving => 'Salvataggio...';

  @override
  String get walksActionStarting => 'Avvio...';

  @override
  String get walksActionStart => 'Avvia passeggiata';

  @override
  String get walksWaitingForGps => 'In attesa di un segnale GPS preciso…';

  @override
  String get walksCameraTooltip => 'Foto o video';

  @override
  String get walksCaptureTakePhoto => 'Scatta foto';

  @override
  String get walksCaptureRecordVideo => 'Registra video';

  @override
  String walksCaptureVideoLimit(int seconds) {
    return 'Fino a $seconds secondi';
  }

  @override
  String get walksErrorOtherPetActive =>
      'C\'è già una passeggiata in corso con un altro pet: terminala prima di iniziarne una nuova.';

  @override
  String get walksErrorLocationUnavailable =>
      'Non riesco a rilevare la tua posizione: serve per tracciare il percorso. Controlla i permessi di localizzazione e riprova.';

  @override
  String get walksPhotoPinSemantics => 'Foto scattata durante la passeggiata';

  @override
  String walksPhotoCaption(String date) {
    return 'Passeggiata del $date';
  }

  @override
  String get walksMapUnavailable => 'Percorso non disponibile';

  @override
  String get walksNoMoveTitle => 'Passeggiata senza spostamento';

  @override
  String get walksNoMoveBody =>
      'Non è stato registrato alcuno spostamento: la passeggiata non è stata salvata.';

  @override
  String get walksNoMoveAck => 'Ho capito';

  @override
  String get walksFavoritePromptTitle => 'Salva tra le preferite?';

  @override
  String walksFavoritePromptBody(String distance) {
    return 'Vuoi aggiungere questa passeggiata ($distance) alle tue preferite ⭐?';
  }

  @override
  String get walksFavoriteNoThanks => 'No, grazie';

  @override
  String get walksFavoriteSave => 'Salva ⭐';

  @override
  String get walksFavoriteEvictTitle => 'Hai già 5 preferite';

  @override
  String get walksFavoriteEvictBody =>
      'Scegli quale togliere dalle preferite per fare posto a quella appena conclusa.';

  @override
  String get walksSheetOpen => 'Apri passeggiata';

  @override
  String get walksSheetFinish => 'Fine passeggiata';

  @override
  String walksConfirmFinishTitle(String petName) {
    return 'Terminare la passeggiata con $petName?';
  }

  @override
  String get walksConfirmFinishBody =>
      'Il percorso registrato finora verrà salvato.';

  @override
  String get walksSavingSnackbar => 'Salvo la passeggiata...';

  @override
  String get walksNotifPermTitle => 'Vedi la passeggiata nelle notifiche';

  @override
  String get walksNotifPermBody =>
      'Durante la passeggiata VetApp mostra una notifica fissa con tempo e distanza: da lì puoi metterla in pausa o terminarla anche con il telefono in tasca. Per vederla serve il permesso per le notifiche.\n\nLa passeggiata viene registrata comunque, anche se scegli \"Non ora\".';

  @override
  String get walksNotifPermNotNow => 'Non ora';

  @override
  String get walksNotifPermAllow => 'Consenti';

  @override
  String walksNotifTitleWithPet(String petName) {
    return 'Passeggiata con $petName';
  }

  @override
  String walksNotifTitleWithPetPaused(String petName) {
    return 'Passeggiata con $petName · in pausa';
  }

  @override
  String get walksNotifTitleNoPetPaused => 'Passeggiata in corso · in pausa';

  @override
  String walksNotifRunningText(String distance) {
    return '$distance percorsi';
  }

  @override
  String get walksNotifFallbackPausedText =>
      'Il tracciamento è in pausa. Riprendi dall\'app quando vuoi.';

  @override
  String get walksNotifFallbackRunningText =>
      'VetApp sta tracciando il percorso della passeggiata.';

  @override
  String get walksNotifChannelName => 'Tracciamento passeggiata';

  @override
  String get walksSyncFailed =>
      'Sincronizzazione non riuscita: modifica salvata solo sul telefono';

  @override
  String get walksFavoriteSaveFailed =>
      'Non sono riuscito a salvare la preferita: riprova.';

  @override
  String get walksFavoriteRemoveFailed =>
      'Non sono riuscito a togliere la preferita: riprova.';

  @override
  String get walksDeleteFailed =>
      'Non sono riuscito a eliminare la passeggiata: riprova.';

  @override
  String get walksHighlightLongest => 'Più lunga';

  @override
  String get walksHighlightMostDurable => 'Più duratura';

  @override
  String get walksHighlightFavorite => 'Preferita';

  @override
  String walksDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String walksDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get walksBadgeLabelFirstWalk => 'Prima passeggiata 🐾';

  @override
  String walksBadgeLabelDistance(String km) {
    return '$km km percorsi 🏃';
  }

  @override
  String walksBadgeLabelWalkCount(String count) {
    return '$count uscite 🎖️';
  }

  @override
  String get walksBadgeLabel30Min => '30 minuti in una passeggiata ⏱️';

  @override
  String get walksBadgeLabel1Hour => '1 ora in una passeggiata ⏱️';

  @override
  String get walksBadgeLabelStreak => '7 giorni di fila 🔥';

  @override
  String get walksBadgeLabelDawn => 'Passeggiata all\'alba 🌅';

  @override
  String get walksBadgeLabelNight => 'Passeggiata notturna 🌙';

  @override
  String get walksBadgeEarnedBarrier => 'Badge sbloccato';

  @override
  String walksBadgeEarnedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nuovi badge sbloccati!',
      one: 'Nuovo badge sbloccato!',
    );
    return '$_temp0';
  }

  @override
  String get walksBadgeEarnedAction => 'Evviva!';

  @override
  String get walksBadgeGalleryTitle => 'Badge';

  @override
  String get walksBadgeNameFirstWalk => 'Prima passeggiata';

  @override
  String get walksBadgeDescFirstWalk =>
      'Completa la tua prima passeggiata con questo pet.';

  @override
  String walksBadgeNameKm(String km) {
    return '$km km';
  }

  @override
  String walksBadgeDescKm(String km) {
    return 'Percorri $km km in totale.';
  }

  @override
  String get walksBadgeName30Min => '30 minuti';

  @override
  String get walksBadgeDesc30Min => 'Fai una passeggiata di almeno 30 minuti.';

  @override
  String get walksBadgeName1Hour => '1 ora';

  @override
  String get walksBadgeDesc1Hour => 'Fai una passeggiata di almeno un\'ora.';

  @override
  String get walksBadgeNameStreak => '7 giorni di fila';

  @override
  String get walksBadgeDescStreak =>
      'Esci a passeggio per 7 giorni consecutivi.';

  @override
  String get walksBadgeNameDawn => 'Passeggiata all\'alba';

  @override
  String get walksBadgeDescDawn =>
      'Fai una passeggiata tra le 5 e le 7 del mattino.';

  @override
  String get walksBadgeNameNight => 'Passeggiata notturna';

  @override
  String get walksBadgeDescNight =>
      'Fai una passeggiata dopo le 21 o prima delle 5.';

  @override
  String walksBadgeNameWalkCount(String count) {
    return '$count uscite';
  }

  @override
  String walksBadgeDescWalkCount(String count) {
    return 'Completa $count passeggiate in totale.';
  }

  @override
  String get settingsAccountProfile => 'Il tuo profilo';

  @override
  String get settingsAccountChangeEmail => 'Cambia email';

  @override
  String get settingsAccountChangePassword => 'Cambia password';

  @override
  String get settingsAccountSupport => 'Assistenza';

  @override
  String get settingsAccountSupportSubtitle => 'Scrivici una email';

  @override
  String get settingsAccountDelete => 'Elimina account';

  @override
  String get settingsAccountDeleteSubtitle =>
      'Cancella il tuo account e tutti i tuoi dati';

  @override
  String accountSupportSubject(String version) {
    return 'Assistenza VetApp (versione $version)';
  }

  @override
  String accountSupportBody(String version) {
    return 'Scrivi qui il tuo messaggio:\n\n\n\n—\nVersione app: $version';
  }

  @override
  String get accountProfileTitle => 'Il tuo profilo';

  @override
  String get accountProfileFirstName => 'Nome';

  @override
  String get accountProfileLastName => 'Cognome';

  @override
  String get accountProfilePhone => 'Telefono (facoltativo)';

  @override
  String get accountProfilePhoneHint => '+39 333 1234567';

  @override
  String get accountProfileFirstNameRequired => 'Inserisci il tuo nome.';

  @override
  String get accountProfileLastNameRequired => 'Inserisci il tuo cognome.';

  @override
  String get accountProfilePhoneInvalid => 'Numero di telefono non valido.';

  @override
  String get accountProfilePhotoAdd => 'Aggiungi foto';

  @override
  String get accountProfilePhotoChange => 'Cambia foto';

  @override
  String get accountProfilePhotoRemove => 'Rimuovi foto';

  @override
  String get accountProfilePhotoFailed =>
      'Non sono riuscito a caricare la foto. Riprova.';

  @override
  String get accountProfileSaved => 'Profilo salvato.';

  @override
  String get accountProfileEmailLabel => 'Email';

  @override
  String get accountProfileEmailChange => 'Cambia';

  @override
  String get accountEmailTitle => 'Cambia email';

  @override
  String get accountEmailCurrent => 'Email attuale';

  @override
  String get accountEmailNew => 'Nuova email';

  @override
  String get accountEmailSame => 'È la tua email attuale.';

  @override
  String get accountEmailSubmit => 'Cambia email';

  @override
  String accountEmailApplied(String email) {
    return 'Email aggiornata: da ora accedi con $email.';
  }

  @override
  String accountEmailConfirmationSent(String email) {
    return 'Ti abbiamo mandato un link di conferma al nuovo indirizzo ($email). Aprilo per completare il cambio: fino ad allora continui ad accedere con l\'email attuale.';
  }

  @override
  String get accountPasswordTitle => 'Cambia password';

  @override
  String get accountPasswordCurrent => 'Password attuale';

  @override
  String get accountPasswordCurrentRequired => 'Inserisci la password attuale.';

  @override
  String get accountPasswordCurrentWrong =>
      'La password attuale non è corretta.';

  @override
  String get accountPasswordNew => 'Nuova password';

  @override
  String get accountPasswordRepeat => 'Ripeti la nuova password';

  @override
  String get accountPasswordSameAsOld =>
      'La nuova password deve essere diversa da quella attuale.';

  @override
  String get accountPasswordSubmit => 'Cambia password';

  @override
  String get accountPasswordChanged => 'Password cambiata.';

  @override
  String get accountDeleteTitle => 'Elimina account';

  @override
  String get accountDeleteWarningTitle => 'Questa azione è definitiva';

  @override
  String get accountDeleteWarningBody =>
      'Verranno cancellati per sempre: i profili dei tuoi animali, le chat con l\'assistente, i promemoria, le passeggiate, le foto e i video, i referti e i documenti caricati, le misurazioni, i consensi, la posizione salvata e gli annunci che hai pubblicato nel mercatino. Non potremo recuperarli.';

  @override
  String get accountDeletePasswordLabel =>
      'Scrivi la tua password per confermare';

  @override
  String get accountDeletePasswordRequired => 'Inserisci la tua password.';

  @override
  String get accountDeleteUnderstood =>
      'Ho capito: il mio account e tutti i miei dati verranno cancellati per sempre.';

  @override
  String get accountDeleteSubmit => 'Elimina definitivamente il mio account';

  @override
  String get accountDeleteFailed =>
      'Non sono riuscito a eliminare l\'account. Riprova tra poco; se il problema continua, scrivi all\'assistenza.';

  @override
  String get accountDeleteDone => 'Il tuo account è stato eliminato.';
}

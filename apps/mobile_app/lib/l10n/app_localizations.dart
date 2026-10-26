import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it')
  ];

  /// No description provided for @petsConsentFullText.
  ///
  /// In it, this message translates to:
  /// **'Per darti un consiglio più preciso, l\'assistente può leggere la cartella clinica del tuo animale. Quando fai una domanda può leggere le tre voci più recenti, con titolo, categoria (visita, esame, vaccino, terapia o documento), data dell\'evento, descrizione e testo dei documenti allegati, anche se non c\'entrano con la domanda. Può leggere anche le malattie pregresse ancora in corso, con il nome e la data di inizio, al massimo cinque. Se chiedi di spiegare un esame, può leggere i documenti che lo riguardano, al massimo due. Di un documento molto lungo legge solo l\'inizio. Ciò che legge viene inviato al fornitore esterno di intelligenza artificiale che scrive la risposta. VetApp lo usa solo per risponderti. Puoi revocare il consenso in qualsiasi momento dalla scheda dell\'animale o dalle Impostazioni: vale per le richieste successive.'**
  String get petsConsentFullText;

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'VET APP'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get commonConfirm;

  /// No description provided for @commonOk.
  ///
  /// In it, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get commonRetry;

  /// No description provided for @commonBack.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In it, this message translates to:
  /// **'Avanti'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In it, this message translates to:
  /// **'Salta'**
  String get commonSkip;

  /// No description provided for @commonEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get commonAdd;

  /// No description provided for @commonYes.
  ///
  /// In it, this message translates to:
  /// **'Sì'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In it, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonLoading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento…'**
  String get commonLoading;

  /// No description provided for @commonDone.
  ///
  /// In it, this message translates to:
  /// **'Fatto'**
  String get commonDone;

  /// No description provided for @commonContinue.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get commonContinue;

  /// No description provided for @commonSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get commonSearch;

  /// No description provided for @commonShare.
  ///
  /// In it, this message translates to:
  /// **'Condividi'**
  String get commonShare;

  /// No description provided for @languagePickerTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli la tua lingua'**
  String get languagePickerTitle;

  /// No description provided for @languagePickerSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Potrai cambiarla in qualsiasi momento da Impostazioni.'**
  String get languagePickerSubtitle;

  /// No description provided for @languageSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get languageSectionTitle;

  /// No description provided for @languageSectionHint.
  ///
  /// In it, this message translates to:
  /// **'Cambiando lingua cambiano anche le unità di misura predefinite, se non le hai già scelte tu.'**
  String get languageSectionHint;

  /// No description provided for @authBannerCheckFieldsTitle.
  ///
  /// In it, this message translates to:
  /// **'Controlla i campi'**
  String get authBannerCheckFieldsTitle;

  /// No description provided for @authLoginFieldsInvalidMessage.
  ///
  /// In it, this message translates to:
  /// **'Servono una email valida e una password di almeno 6 caratteri.'**
  String get authLoginFieldsInvalidMessage;

  /// No description provided for @authLoginLoadingTitle.
  ///
  /// In it, this message translates to:
  /// **'Accesso in corso'**
  String get authLoginLoadingTitle;

  /// No description provided for @authLoginLoadingMessage.
  ///
  /// In it, this message translates to:
  /// **'Sto verificando le credenziali.'**
  String get authLoginLoadingMessage;

  /// No description provided for @authLoginSuccessTitle.
  ///
  /// In it, this message translates to:
  /// **'Accesso completato'**
  String get authLoginSuccessTitle;

  /// No description provided for @authLoginSuccessMessage.
  ///
  /// In it, this message translates to:
  /// **'La sessione e pronta. Ti porto nel flusso principale.'**
  String get authLoginSuccessMessage;

  /// No description provided for @authLoginFailureTitle.
  ///
  /// In it, this message translates to:
  /// **'Accesso non riuscito'**
  String get authLoginFailureTitle;

  /// No description provided for @authLoginTitle.
  ///
  /// In it, this message translates to:
  /// **'Bentornato.'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi per ritrovare i tuoi animali, promemoria e documenti.'**
  String get authLoginSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authEmailHint.
  ///
  /// In it, this message translates to:
  /// **'nome@dominio.it'**
  String get authEmailHint;

  /// No description provided for @authEmailRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua email.'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In it, this message translates to:
  /// **'Email non valida.'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordHint.
  ///
  /// In it, this message translates to:
  /// **'Almeno 6 caratteri'**
  String get authPasswordHint;

  /// No description provided for @authPasswordRequiredLogin.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password.'**
  String get authPasswordRequiredLogin;

  /// No description provided for @authPasswordRequiredNew.
  ///
  /// In it, this message translates to:
  /// **'Inserisci una password.'**
  String get authPasswordRequiredNew;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In it, this message translates to:
  /// **'Minimo 6 caratteri.'**
  String get authPasswordMinLength;

  /// No description provided for @authPasswordShow.
  ///
  /// In it, this message translates to:
  /// **'Mostra password'**
  String get authPasswordShow;

  /// No description provided for @authPasswordHide.
  ///
  /// In it, this message translates to:
  /// **'Nascondi password'**
  String get authPasswordHide;

  /// No description provided for @authRememberMe.
  ///
  /// In it, this message translates to:
  /// **'Resta connesso'**
  String get authRememberMe;

  /// No description provided for @authForgotPasswordLink.
  ///
  /// In it, this message translates to:
  /// **'Password dimenticata?'**
  String get authForgotPasswordLink;

  /// No description provided for @authLoginButton.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get authLoginButton;

  /// No description provided for @authNoAccountRegisterLink.
  ///
  /// In it, this message translates to:
  /// **'Non hai un account? Registrati'**
  String get authNoAccountRegisterLink;

  /// No description provided for @authTermsOfServiceLabel.
  ///
  /// In it, this message translates to:
  /// **'Termini di Servizio'**
  String get authTermsOfServiceLabel;

  /// No description provided for @authPrivacyPolicyLabel.
  ///
  /// In it, this message translates to:
  /// **'Informativa Privacy'**
  String get authPrivacyPolicyLabel;

  /// No description provided for @authTermsAcceptance.
  ///
  /// In it, this message translates to:
  /// **'Accetto i {terms} e l\'{privacy}'**
  String authTermsAcceptance(String terms, String privacy);

  /// No description provided for @authRegisterCheckTitle.
  ///
  /// In it, this message translates to:
  /// **'Serve un ultimo controllo'**
  String get authRegisterCheckTitle;

  /// No description provided for @authRegisterTermsRequired.
  ///
  /// In it, this message translates to:
  /// **'Devi accettare privacy e disclaimer per continuare.'**
  String get authRegisterTermsRequired;

  /// No description provided for @authRegisterFieldsInvalid.
  ///
  /// In it, this message translates to:
  /// **'Controlla i campi: nome, email e password devono essere validi.'**
  String get authRegisterFieldsInvalid;

  /// No description provided for @authRegisterLoadingTitle.
  ///
  /// In it, this message translates to:
  /// **'Creazione account'**
  String get authRegisterLoadingTitle;

  /// No description provided for @authRegisterLoadingMessage.
  ///
  /// In it, this message translates to:
  /// **'Sto creando l account e preparando la sessione iniziale.'**
  String get authRegisterLoadingMessage;

  /// No description provided for @authRegisterSuccessTitle.
  ///
  /// In it, this message translates to:
  /// **'Account pronto'**
  String get authRegisterSuccessTitle;

  /// No description provided for @authRegisterSuccessMessage.
  ///
  /// In it, this message translates to:
  /// **'Registrazione completata. Ti porto nella home.'**
  String get authRegisterSuccessMessage;

  /// No description provided for @authRegisterFailureTitle.
  ///
  /// In it, this message translates to:
  /// **'Account non creato'**
  String get authRegisterFailureTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In it, this message translates to:
  /// **'Crea il tuo profilo.'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Pochi campi per iniziare a gestire salute e documenti dei tuoi animali.'**
  String get authRegisterSubtitle;

  /// No description provided for @authNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get authNameLabel;

  /// No description provided for @authNameHint.
  ///
  /// In it, this message translates to:
  /// **'Il tuo nome'**
  String get authNameHint;

  /// No description provided for @authNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il tuo nome.'**
  String get authNameRequired;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Conferma password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConfirmPasswordHint.
  ///
  /// In it, this message translates to:
  /// **'Ripeti la password'**
  String get authConfirmPasswordHint;

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non coincidono.'**
  String get authPasswordsMismatch;

  /// No description provided for @authRegisterButton.
  ///
  /// In it, this message translates to:
  /// **'Crea account'**
  String get authRegisterButton;

  /// No description provided for @authHaveAccountLoginLink.
  ///
  /// In it, this message translates to:
  /// **'Hai già un account? Accedi'**
  String get authHaveAccountLoginLink;

  /// No description provided for @authResetInvalidTitle.
  ///
  /// In it, this message translates to:
  /// **'Email non valida'**
  String get authResetInvalidTitle;

  /// No description provided for @authResetInvalidMessage.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un indirizzo email corretto per continuare.'**
  String get authResetInvalidMessage;

  /// No description provided for @authResetLoadingTitle.
  ///
  /// In it, this message translates to:
  /// **'Invio in corso'**
  String get authResetLoadingTitle;

  /// No description provided for @authResetLoadingMessage.
  ///
  /// In it, this message translates to:
  /// **'Sto preparando la richiesta di recupero password.'**
  String get authResetLoadingMessage;

  /// No description provided for @authResetSuccessTitle.
  ///
  /// In it, this message translates to:
  /// **'Email inviata'**
  String get authResetSuccessTitle;

  /// No description provided for @authResetSuccessMessage.
  ///
  /// In it, this message translates to:
  /// **'Se l account esiste, riceverai il link per il recupero accesso.'**
  String get authResetSuccessMessage;

  /// No description provided for @authResetFailureTitle.
  ///
  /// In it, this message translates to:
  /// **'Invio non riuscito'**
  String get authResetFailureTitle;

  /// No description provided for @authResetTitle.
  ///
  /// In it, this message translates to:
  /// **'Recupera l accesso.'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua email: ti mandiamo un link per reimpostare la password.'**
  String get authResetSubtitle;

  /// No description provided for @authResetSendButton.
  ///
  /// In it, this message translates to:
  /// **'Invia link'**
  String get authResetSendButton;

  /// No description provided for @authBackToLoginLink.
  ///
  /// In it, this message translates to:
  /// **'Torna all accesso'**
  String get authBackToLoginLink;

  /// No description provided for @authSetPasswordLoadingTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento in corso'**
  String get authSetPasswordLoadingTitle;

  /// No description provided for @authSetPasswordLoadingMessage.
  ///
  /// In it, this message translates to:
  /// **'Sto salvando la nuova password.'**
  String get authSetPasswordLoadingMessage;

  /// No description provided for @authSetPasswordFailureTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento non riuscito'**
  String get authSetPasswordFailureTitle;

  /// No description provided for @authSetPasswordTitle.
  ///
  /// In it, this message translates to:
  /// **'Imposta una nuova password.'**
  String get authSetPasswordTitle;

  /// No description provided for @authSetPasswordSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli una nuova password per il tuo account.'**
  String get authSetPasswordSubtitle;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Nuova password'**
  String get authNewPasswordLabel;

  /// No description provided for @authSetPasswordSaveButton.
  ///
  /// In it, this message translates to:
  /// **'Salva nuova password'**
  String get authSetPasswordSaveButton;

  /// No description provided for @authLegalShareTooltip.
  ///
  /// In it, this message translates to:
  /// **'Condividi o scarica'**
  String get authLegalShareTooltip;

  /// No description provided for @authLegalLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a caricare il testo adesso. Riprova tra poco.'**
  String get authLegalLoadError;

  /// No description provided for @authLegalPreparingNotice.
  ///
  /// In it, this message translates to:
  /// **'Il testo completo dell\'informativa è in preparazione e sarà disponibile qui a breve, con la possibilità di scaricarlo.'**
  String get authLegalPreparingNotice;

  /// No description provided for @authHubTitle.
  ///
  /// In it, this message translates to:
  /// **'VetApp: i tuoi pet a portata di zampa'**
  String get authHubTitle;

  /// No description provided for @authHubSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi al tuo account oppure creane uno nuovo in pochi secondi.'**
  String get authHubSubtitle;

  /// No description provided for @authHubCreateAccount.
  ///
  /// In it, this message translates to:
  /// **'Crea un account'**
  String get authHubCreateAccount;

  /// No description provided for @authHubPrivacyNote.
  ///
  /// In it, this message translates to:
  /// **'I tuoi dati restano privati e li usiamo solo per gestire il profilo del tuo pet.'**
  String get authHubPrivacyNote;

  /// No description provided for @authErrorEmailExists.
  ///
  /// In it, this message translates to:
  /// **'Esiste già un account con questa email. Prova ad accedere.'**
  String get authErrorEmailExists;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In it, this message translates to:
  /// **'La password è troppo debole: usa almeno 6 caratteri, meglio se con numeri o lettere maiuscole.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorEmailInvalid.
  ///
  /// In it, this message translates to:
  /// **'L\'indirizzo email non sembra valido.'**
  String get authErrorEmailInvalid;

  /// No description provided for @authErrorNoConnection.
  ///
  /// In it, this message translates to:
  /// **'Nessuna connessione. Controlla la rete e riprova.'**
  String get authErrorNoConnection;

  /// No description provided for @authErrorLinkExpired.
  ///
  /// In it, this message translates to:
  /// **'Il link non è più valido o è già stato usato. Richiedine uno nuovo dalla schermata di recupero.'**
  String get authErrorLinkExpired;

  /// No description provided for @authErrorRateLimit.
  ///
  /// In it, this message translates to:
  /// **'Hai richiesto troppe email in poco tempo. Aspetta qualche minuto e riprova.'**
  String get authErrorRateLimit;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In it, this message translates to:
  /// **'Email o password non corrette.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Devi prima confermare la tua email: controlla la posta e apri il link che ti abbiamo mandato.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorEmailNotFound.
  ///
  /// In it, this message translates to:
  /// **'Non esiste un account con questa email.'**
  String get authErrorEmailNotFound;

  /// No description provided for @authErrorGeneric.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa non è andato come previsto. Riprova tra poco.'**
  String get authErrorGeneric;

  /// No description provided for @authNetworkTimeout.
  ///
  /// In it, this message translates to:
  /// **'La richiesta ha impiegato troppo tempo. Riprova.'**
  String get authNetworkTimeout;

  /// No description provided for @authNetworkUnexpected.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa e\' andato storto. Riprova.'**
  String get authNetworkUnexpected;

  /// No description provided for @consentsErrorLoad.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a leggere i tuoi consensi. Riprova.'**
  String get consentsErrorLoad;

  /// No description provided for @consentsErrorSave.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare la tua scelta. Riprova.'**
  String get consentsErrorSave;

  /// No description provided for @billingErrorStatus.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a verificare il tuo abbonamento. Riprova.'**
  String get billingErrorStatus;

  /// No description provided for @billingErrorSelectPlan.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare il piano scelto. Riprova.'**
  String get billingErrorSelectPlan;

  /// No description provided for @billingIncludedPets.
  ///
  /// In it, this message translates to:
  /// **'Profili dei tuoi animali'**
  String get billingIncludedPets;

  /// No description provided for @billingIncludedAssistant.
  ///
  /// In it, this message translates to:
  /// **'Assistente per dubbi su salute, comportamento e routine'**
  String get billingIncludedAssistant;

  /// No description provided for @billingIncludedChatMedia.
  ///
  /// In it, this message translates to:
  /// **'Foto, PDF e dettatura vocale nella chat'**
  String get billingIncludedChatMedia;

  /// No description provided for @billingIncludedReminders.
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get billingIncludedReminders;

  /// No description provided for @billingIncludedNearbyServices.
  ///
  /// In it, this message translates to:
  /// **'Servizi per animali nei dintorni'**
  String get billingIncludedNearbyServices;

  /// No description provided for @billingFreePlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Limiti del piano Free: da definire'**
  String get billingFreePlaceholder;

  /// No description provided for @billingPlusPlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Funzioni extra del piano Plus: da definire'**
  String get billingPlusPlaceholder;

  /// No description provided for @billingProPlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Funzioni extra del piano Pro: da definire'**
  String get billingProPlaceholder;

  /// No description provided for @billingPlanBadgeRecommended.
  ///
  /// In it, this message translates to:
  /// **'Consigliato'**
  String get billingPlanBadgeRecommended;

  /// No description provided for @billingIncludedInAllPlans.
  ///
  /// In it, this message translates to:
  /// **'Incluso in tutti i piani'**
  String get billingIncludedInAllPlans;

  /// No description provided for @billingPriceFree.
  ///
  /// In it, this message translates to:
  /// **'Gratis'**
  String get billingPriceFree;

  /// No description provided for @billingPricePerMonth.
  ///
  /// In it, this message translates to:
  /// **'{amount}/mese'**
  String billingPricePerMonth(String amount);

  /// No description provided for @billingPricePerMonthYearly.
  ///
  /// In it, this message translates to:
  /// **'{amount}/mese, fatturato annualmente'**
  String billingPricePerMonthYearly(String amount);

  /// No description provided for @billingTitle.
  ///
  /// In it, this message translates to:
  /// **'Abbonamento e pagamenti'**
  String get billingTitle;

  /// No description provided for @billingPlanSwitched.
  ///
  /// In it, this message translates to:
  /// **'Ora sei sul piano {plan}.'**
  String billingPlanSwitched(String plan);

  /// No description provided for @billingPaymentHistory.
  ///
  /// In it, this message translates to:
  /// **'Cronologia pagamenti'**
  String get billingPaymentHistory;

  /// No description provided for @billingPaymentHistoryComingSoon.
  ///
  /// In it, this message translates to:
  /// **'Le tue fatture e ricevute saranno consultabili qui.'**
  String get billingPaymentHistoryComingSoon;

  /// No description provided for @billingComparePlans.
  ///
  /// In it, this message translates to:
  /// **'Confronta i piani'**
  String get billingComparePlans;

  /// No description provided for @billingPaymentMethodsSection.
  ///
  /// In it, this message translates to:
  /// **'Metodi di pagamento'**
  String get billingPaymentMethodsSection;

  /// No description provided for @billingInvoicingSection.
  ///
  /// In it, this message translates to:
  /// **'Fatturazione'**
  String get billingInvoicingSection;

  /// No description provided for @billingTrialBannerTitle.
  ///
  /// In it, this message translates to:
  /// **'Prova gratuita in corso'**
  String get billingTrialBannerTitle;

  /// No description provided for @billingTrialBannerDaysLeft.
  ///
  /// In it, this message translates to:
  /// **'Ti restano {days} giorni gratis, nessuna carta richiesta. Scegli un piano quando vuoi, o alla scadenza.'**
  String billingTrialBannerDaysLeft(int days);

  /// No description provided for @billingTrialBannerEnding.
  ///
  /// In it, this message translates to:
  /// **'La prova gratuita sta per terminare: scegli un piano per continuare a usare VetApp.'**
  String get billingTrialBannerEnding;

  /// No description provided for @billingDeveloperBanner.
  ///
  /// In it, this message translates to:
  /// **'Account sviluppatore: accesso illimitato, nessun piano richiesto.'**
  String get billingDeveloperBanner;

  /// No description provided for @billingCurrentPlanLabel.
  ///
  /// In it, this message translates to:
  /// **'Il tuo piano'**
  String get billingCurrentPlanLabel;

  /// No description provided for @billingRenewalOn.
  ///
  /// In it, this message translates to:
  /// **'Rinnovo il {date}'**
  String billingRenewalOn(String date);

  /// No description provided for @billingCycleMonthly.
  ///
  /// In it, this message translates to:
  /// **'Mensile'**
  String get billingCycleMonthly;

  /// No description provided for @billingCycleYearly.
  ///
  /// In it, this message translates to:
  /// **'Annuale'**
  String get billingCycleYearly;

  /// No description provided for @billingCurrentPlanButton.
  ///
  /// In it, this message translates to:
  /// **'Piano attuale'**
  String get billingCurrentPlanButton;

  /// No description provided for @billingBackToFree.
  ///
  /// In it, this message translates to:
  /// **'Torna a Free'**
  String get billingBackToFree;

  /// No description provided for @billingSwitchToPlan.
  ///
  /// In it, this message translates to:
  /// **'Passa a {plan}'**
  String billingSwitchToPlan(String plan);

  /// No description provided for @billingCardExpires.
  ///
  /// In it, this message translates to:
  /// **'Scade {expiry}'**
  String billingCardExpires(String expiry);

  /// No description provided for @billingCardExpiresDefault.
  ///
  /// In it, this message translates to:
  /// **'Scade {expiry} · Predefinita'**
  String billingCardExpiresDefault(String expiry);

  /// No description provided for @billingSetDefault.
  ///
  /// In it, this message translates to:
  /// **'Imposta come predefinita'**
  String get billingSetDefault;

  /// No description provided for @billingRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get billingRemove;

  /// No description provided for @billingAddPaymentMethod.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi metodo di pagamento'**
  String get billingAddPaymentMethod;

  /// No description provided for @billingCardBrandLabel.
  ///
  /// In it, this message translates to:
  /// **'Circuito'**
  String get billingCardBrandLabel;

  /// No description provided for @billingCardLast4Label.
  ///
  /// In it, this message translates to:
  /// **'Ultime 4 cifre'**
  String get billingCardLast4Label;

  /// No description provided for @billingCardLast4Error.
  ///
  /// In it, this message translates to:
  /// **'Inserisci 4 cifre'**
  String get billingCardLast4Error;

  /// No description provided for @billingExpiryMonthLabel.
  ///
  /// In it, this message translates to:
  /// **'Mese'**
  String get billingExpiryMonthLabel;

  /// No description provided for @billingExpiryYearLabel.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get billingExpiryYearLabel;

  /// No description provided for @billingPaywallTitle.
  ///
  /// In it, this message translates to:
  /// **'La tua prova gratuita è terminata.'**
  String get billingPaywallTitle;

  /// No description provided for @billingPaywallSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli come continuare con VetApp. Puoi cambiare piano quando vuoi da Impostazioni.'**
  String get billingPaywallSubtitle;

  /// No description provided for @billingChoosePlan.
  ///
  /// In it, this message translates to:
  /// **'Scegli {plan}'**
  String billingChoosePlan(String plan);

  /// No description provided for @billingTrialDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'{daysLeft, plural, =1{Ultimo giorno di prova} other{Ti restano {daysLeft} giorni di prova}}'**
  String billingTrialDialogTitle(int daysLeft);

  /// No description provided for @billingTrialDialogBody.
  ///
  /// In it, this message translates to:
  /// **'Con il piano Free alcune funzioni sono limitate. Passa a Plus o Pro per avere tutto senza limiti quando la prova finisce.'**
  String get billingTrialDialogBody;

  /// No description provided for @billingTrialDialogLater.
  ///
  /// In it, this message translates to:
  /// **'Più tardi'**
  String get billingTrialDialogLater;

  /// No description provided for @billingTrialDialogSeePlans.
  ///
  /// In it, this message translates to:
  /// **'Vedi i piani'**
  String get billingTrialDialogSeePlans;

  /// No description provided for @firstRunWelcomeTitle.
  ///
  /// In it, this message translates to:
  /// **'Benvenuto in VetApp.'**
  String get firstRunWelcomeTitle;

  /// No description provided for @firstRunPlanIntroSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli come iniziare: puoi provare tutto gratis per 10 giorni, senza carta, oppure scegliere subito un piano.'**
  String get firstRunPlanIntroSubtitle;

  /// No description provided for @firstRunPlanOrChoose.
  ///
  /// In it, this message translates to:
  /// **'OPPURE SCEGLI SUBITO UN PIANO'**
  String get firstRunPlanOrChoose;

  /// No description provided for @firstRunTrialCardTitle.
  ///
  /// In it, this message translates to:
  /// **'Prova gratuita — 10 giorni'**
  String get firstRunTrialCardTitle;

  /// No description provided for @firstRunTrialCardBody.
  ///
  /// In it, this message translates to:
  /// **'Nessuna carta richiesta. Alla scadenza dei 10 giorni ti chiederemo di scegliere un piano per continuare.'**
  String get firstRunTrialCardBody;

  /// No description provided for @firstRunTrialStartButton.
  ///
  /// In it, this message translates to:
  /// **'Inizia la prova gratuita'**
  String get firstRunTrialStartButton;

  /// No description provided for @firstRunPlanSelectButton.
  ///
  /// In it, this message translates to:
  /// **'Scegli'**
  String get firstRunPlanSelectButton;

  /// No description provided for @firstRunAddPetTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi il tuo primo animale'**
  String get firstRunAddPetTitle;

  /// No description provided for @firstRunAddPetBody.
  ///
  /// In it, this message translates to:
  /// **'Bastano un paio di minuti: nome, specie e qualche dettaglio. Puoi farlo anche più tardi da Animali.'**
  String get firstRunAddPetBody;

  /// No description provided for @firstRunAddPetNow.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi ora'**
  String get firstRunAddPetNow;

  /// No description provided for @firstRunAddPetLater.
  ///
  /// In it, this message translates to:
  /// **'Salta per ora'**
  String get firstRunAddPetLater;

  /// No description provided for @firstRunNotificationsTitle.
  ///
  /// In it, this message translates to:
  /// **'Non perderti i promemoria'**
  String get firstRunNotificationsTitle;

  /// No description provided for @firstRunNotificationsBody.
  ///
  /// In it, this message translates to:
  /// **'Attiva le notifiche per essere avvisato su vaccini, farmaci e visite in scadenza. Puoi cambiare idea in qualsiasi momento da Impostazioni.'**
  String get firstRunNotificationsBody;

  /// No description provided for @firstRunNotificationsEnable.
  ///
  /// In it, this message translates to:
  /// **'Attiva notifiche'**
  String get firstRunNotificationsEnable;

  /// No description provided for @firstRunNotificationsLater.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get firstRunNotificationsLater;

  /// No description provided for @firstRunTutorialPetsTitle.
  ///
  /// In it, this message translates to:
  /// **'Un profilo per ogni animale'**
  String get firstRunTutorialPetsTitle;

  /// No description provided for @firstRunTutorialPetsBody.
  ///
  /// In it, this message translates to:
  /// **'Specie e razza, peso, note mediche e documenti: tutto organizzato per ciascun pet, sempre a portata di mano.'**
  String get firstRunTutorialPetsBody;

  /// No description provided for @firstRunTutorialAssistantTitle.
  ///
  /// In it, this message translates to:
  /// **'Chiedi al tuo assistente'**
  String get firstRunTutorialAssistantTitle;

  /// No description provided for @firstRunTutorialAssistantBody.
  ///
  /// In it, this message translates to:
  /// **'Fai domande sulla salute dei tuoi animali e ricevi risposte pensate per la loro situazione specifica.'**
  String get firstRunTutorialAssistantBody;

  /// No description provided for @firstRunTutorialRemindersTitle.
  ///
  /// In it, this message translates to:
  /// **'Niente più scadenze dimenticate'**
  String get firstRunTutorialRemindersTitle;

  /// No description provided for @firstRunTutorialRemindersBody.
  ///
  /// In it, this message translates to:
  /// **'Vaccini, farmaci e visite: imposta un promemoria e VetApp ti avvisa al momento giusto.'**
  String get firstRunTutorialRemindersBody;

  /// No description provided for @firstRunTutorialStart.
  ///
  /// In it, this message translates to:
  /// **'Inizia'**
  String get firstRunTutorialStart;

  /// No description provided for @chatLoadingTitle.
  ///
  /// In it, this message translates to:
  /// **'Apriamo la conversazione'**
  String get chatLoadingTitle;

  /// No description provided for @chatLoadingSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Stiamo caricando il thread e l ultimo contesto disponibile.'**
  String get chatLoadingSubtitle;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'La conversazione e vuota'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scrivi il primo messaggio per iniziare il dialogo con l assistente.'**
  String get chatEmptySubtitle;

  /// No description provided for @chatEmptyAction.
  ///
  /// In it, this message translates to:
  /// **'Scrivi ora'**
  String get chatEmptyAction;

  /// No description provided for @chatEmptyGreeting.
  ///
  /// In it, this message translates to:
  /// **'Ciao, ho una domanda per {pet}.'**
  String chatEmptyGreeting(String pet);

  /// No description provided for @chatErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Conversazione non disponibile'**
  String get chatErrorTitle;

  /// No description provided for @chatErrorSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa e andato storto nel recupero del thread.'**
  String get chatErrorSubtitle;

  /// No description provided for @chatErrorAction.
  ///
  /// In it, this message translates to:
  /// **'Torna alle chat'**
  String get chatErrorAction;

  /// No description provided for @chatMessageEditAction.
  ///
  /// In it, this message translates to:
  /// **'Modifica messaggio'**
  String get chatMessageEditAction;

  /// No description provided for @chatMessageEditHint.
  ///
  /// In it, this message translates to:
  /// **'La risposta e i messaggi successivi verranno sostituiti.'**
  String get chatMessageEditHint;

  /// No description provided for @chatComposerHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi una domanda su {pet}'**
  String chatComposerHint(String pet);

  /// No description provided for @chatNewConversationOnPet.
  ///
  /// In it, this message translates to:
  /// **'Nuova conversazione su {pet}'**
  String chatNewConversationOnPet(String pet);

  /// No description provided for @chatNewConversationPrompt.
  ///
  /// In it, this message translates to:
  /// **'Scrivi qui sotto cosa stai osservando: ti rispondo subito.'**
  String get chatNewConversationPrompt;

  /// No description provided for @chatTypingText.
  ///
  /// In it, this message translates to:
  /// **'Sta scrivendo una risposta...'**
  String get chatTypingText;

  /// No description provided for @chatTypingSlowText.
  ///
  /// In it, this message translates to:
  /// **'Ci sto mettendo più del solito, la risposta arriva tra poco...'**
  String get chatTypingSlowText;

  /// No description provided for @chatDefaultTitle.
  ///
  /// In it, this message translates to:
  /// **'Chat con {pet}'**
  String chatDefaultTitle(String pet);

  /// No description provided for @chatListeningText.
  ///
  /// In it, this message translates to:
  /// **'Sto ascoltando… tocca per fermare'**
  String get chatListeningText;

  /// No description provided for @chatTranscribingText.
  ///
  /// In it, this message translates to:
  /// **'Trascrivo…'**
  String get chatTranscribingText;

  /// No description provided for @chatEditingLabel.
  ///
  /// In it, this message translates to:
  /// **'Modifica del messaggio'**
  String get chatEditingLabel;

  /// No description provided for @chatListeningHint.
  ///
  /// In it, this message translates to:
  /// **'Sto ascoltando...'**
  String get chatListeningHint;

  /// No description provided for @chatTranscribingHint.
  ///
  /// In it, this message translates to:
  /// **'Trascrivo il messaggio...'**
  String get chatTranscribingHint;

  /// No description provided for @chatAddPhotoTooltip.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi una foto'**
  String get chatAddPhotoTooltip;

  /// No description provided for @chatStopRecordingTooltip.
  ///
  /// In it, this message translates to:
  /// **'Ferma e trascrivi'**
  String get chatStopRecordingTooltip;

  /// No description provided for @chatVoiceMessageTooltip.
  ///
  /// In it, this message translates to:
  /// **'Messaggio vocale'**
  String get chatVoiceMessageTooltip;

  /// No description provided for @chatMicPermissionNeeded.
  ///
  /// In it, this message translates to:
  /// **'Serve il permesso per usare il microfono.'**
  String get chatMicPermissionNeeded;

  /// No description provided for @chatMicStartFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad avviare il microfono. Riprova.'**
  String get chatMicStartFailed;

  /// No description provided for @chatRecordingFailed.
  ///
  /// In it, this message translates to:
  /// **'La registrazione non è andata a buon fine. Riprova.'**
  String get chatRecordingFailed;

  /// No description provided for @chatRecordingReadFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a leggere la registrazione. Riprova.'**
  String get chatRecordingReadFailed;

  /// No description provided for @chatPhotoAnalyzing.
  ///
  /// In it, this message translates to:
  /// **'Sto guardando la foto...'**
  String get chatPhotoAnalyzing;

  /// No description provided for @chatPhotoReady.
  ///
  /// In it, this message translates to:
  /// **'Foto pronta da inviare'**
  String get chatPhotoReady;

  /// No description provided for @chatRemovePhotoTooltip.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi foto'**
  String get chatRemovePhotoTooltip;

  /// No description provided for @chatRecordingSemantics.
  ///
  /// In it, this message translates to:
  /// **'{listening}, {minutes} minuti e {seconds} secondi'**
  String chatRecordingSemantics(String listening, int minutes, String seconds);

  /// No description provided for @chatCancelEditTooltip.
  ///
  /// In it, this message translates to:
  /// **'Annulla modifica'**
  String get chatCancelEditTooltip;

  /// No description provided for @chatMenuTooltip.
  ///
  /// In it, this message translates to:
  /// **'Opzioni chat'**
  String get chatMenuTooltip;

  /// No description provided for @chatMenuRename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get chatMenuRename;

  /// No description provided for @chatMenuExport.
  ///
  /// In it, this message translates to:
  /// **'Esporta chat'**
  String get chatMenuExport;

  /// No description provided for @chatMenuSummary.
  ///
  /// In it, this message translates to:
  /// **'Riassunto'**
  String get chatMenuSummary;

  /// No description provided for @chatExportOpenFirst.
  ///
  /// In it, this message translates to:
  /// **'Apri la chat per esportarla.'**
  String get chatExportOpenFirst;

  /// No description provided for @chatSenderYou.
  ///
  /// In it, this message translates to:
  /// **'Tu'**
  String get chatSenderYou;

  /// No description provided for @chatSenderAssistant.
  ///
  /// In it, this message translates to:
  /// **'Assistente'**
  String get chatSenderAssistant;

  /// No description provided for @chatRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina chat'**
  String get chatRenameTitle;

  /// No description provided for @chatRenameFieldLabel.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get chatRenameFieldLabel;

  /// No description provided for @chatSummaryLoading.
  ///
  /// In it, this message translates to:
  /// **'Preparo il riassunto…'**
  String get chatSummaryLoading;

  /// No description provided for @chatSummaryTitle.
  ///
  /// In it, this message translates to:
  /// **'Riassunto per il veterinario'**
  String get chatSummaryTitle;

  /// No description provided for @chatSummaryDisclaimer.
  ///
  /// In it, this message translates to:
  /// **'Questo riassunto è generato automaticamente e non è una diagnosi. Per decisioni cliniche consulta il veterinario.'**
  String get chatSummaryDisclaimer;

  /// No description provided for @chatSummaryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun riassunto disponibile.'**
  String get chatSummaryEmpty;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa chat?'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'La conversazione e i suoi messaggi verranno eliminati.'**
  String get chatDeleteBody;

  /// No description provided for @chatFallbackPetName.
  ///
  /// In it, this message translates to:
  /// **'il tuo pet'**
  String get chatFallbackPetName;

  /// No description provided for @chatNewConversation.
  ///
  /// In it, this message translates to:
  /// **'Nuova conversazione'**
  String get chatNewConversation;

  /// No description provided for @chatNewConversationTitle.
  ///
  /// In it, this message translates to:
  /// **'{pet} - nuova conversazione'**
  String chatNewConversationTitle(String pet);

  /// No description provided for @chatSavedConversationTitle.
  ///
  /// In it, this message translates to:
  /// **'{pet} - conversazione'**
  String chatSavedConversationTitle(String pet);

  /// No description provided for @chatRetitled.
  ///
  /// In it, this message translates to:
  /// **'Chat - {subject}'**
  String chatRetitled(String subject);

  /// No description provided for @chatStatusSaved.
  ///
  /// In it, this message translates to:
  /// **'Conversazione salvata'**
  String get chatStatusSaved;

  /// No description provided for @chatStatusSent.
  ///
  /// In it, this message translates to:
  /// **'Messaggio inviato'**
  String get chatStatusSent;

  /// No description provided for @chatStatusEdited.
  ///
  /// In it, this message translates to:
  /// **'Messaggio modificato'**
  String get chatStatusEdited;

  /// No description provided for @chatStatusReplyReady.
  ///
  /// In it, this message translates to:
  /// **'Risposta pronta'**
  String get chatStatusReplyReady;

  /// No description provided for @chatTimeYesterday.
  ///
  /// In it, this message translates to:
  /// **'ieri'**
  String get chatTimeYesterday;

  /// No description provided for @chatTimeNow.
  ///
  /// In it, this message translates to:
  /// **'adesso'**
  String get chatTimeNow;

  /// No description provided for @chatSummaryNotYet.
  ///
  /// In it, this message translates to:
  /// **'Il riassunto sarà disponibile dopo il primo messaggio.'**
  String get chatSummaryNotYet;

  /// No description provided for @chatEditMessageMissing.
  ///
  /// In it, this message translates to:
  /// **'Questo messaggio non è più nella conversazione.'**
  String get chatEditMessageMissing;

  /// No description provided for @chatEmptyThreadPreview.
  ///
  /// In it, this message translates to:
  /// **'Nuovo thread pronto per essere usato.'**
  String get chatEmptyThreadPreview;

  /// No description provided for @chatDemoReplyAppetite.
  ///
  /// In it, this message translates to:
  /// **'Per {pet} terrei sotto osservazione appetito, acqua e livello di energia per le prossime 24 ore. Se peggiora, meglio sentire il veterinario.'**
  String chatDemoReplyAppetite(String pet);

  /// No description provided for @chatDemoReplyVomiting.
  ///
  /// In it, this message translates to:
  /// **'Se ci sono vomito o diarrea, conviene monitorare idratazione e contattare il veterinario se i sintomi si ripetono o diventano intensi.'**
  String get chatDemoReplyVomiting;

  /// No description provided for @chatDemoReplyVaccine.
  ///
  /// In it, this message translates to:
  /// **'Posso aiutarti a mettere il richiamo di {pet} in agenda e aggiungere un reminder chiaro nella home.'**
  String chatDemoReplyVaccine(String pet);

  /// No description provided for @chatDemoReplyWeight.
  ///
  /// In it, this message translates to:
  /// **'Sul peso di {pet} possiamo fissare un controllo periodico e confrontarlo con l ultima visita per capire se il trend cambia davvero.'**
  String chatDemoReplyWeight(String pet);

  /// No description provided for @chatDemoReplyDefault.
  ///
  /// In it, this message translates to:
  /// **'Ho preso nota: per {pet} ti preparo un riepilogo breve, cosi hai subito un piano pratico e leggibile.'**
  String chatDemoReplyDefault(String pet);

  /// No description provided for @chatErrorContactAssistant.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a contattare l\'assistente. Riprova.'**
  String get chatErrorContactAssistant;

  /// No description provided for @chatErrorAssistantTimeout.
  ///
  /// In it, this message translates to:
  /// **'L\'assistente non ha risposto in tempo. Tocca Riprova: se la risposta è già pronta, la recupero.'**
  String get chatErrorAssistantTimeout;

  /// No description provided for @chatErrorGeneric.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa e\' andato storto. Riprova.'**
  String get chatErrorGeneric;

  /// No description provided for @chatErrorRequestTimeout.
  ///
  /// In it, this message translates to:
  /// **'Richiesta scaduta. Riprova.'**
  String get chatErrorRequestTimeout;

  /// No description provided for @chatErrorEditFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a modificare il messaggio. Riprova.'**
  String get chatErrorEditFailed;

  /// No description provided for @chatErrorEditNetwork.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a modificare il messaggio. Controlla la connessione.'**
  String get chatErrorEditNetwork;

  /// No description provided for @chatErrorMessageTooLong.
  ///
  /// In it, this message translates to:
  /// **'Il messaggio è troppo lungo: puoi scrivere al massimo {max} caratteri. Accorcialo e invialo di nuovo.'**
  String chatErrorMessageTooLong(int max);

  /// No description provided for @chatInputLimitReached.
  ///
  /// In it, this message translates to:
  /// **'Hai raggiunto il limite di {max} caratteri.'**
  String chatInputLimitReached(int max);

  /// No description provided for @chatErrorPetBootstrap.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a preparare il profilo del pet.'**
  String get chatErrorPetBootstrap;

  /// No description provided for @chatErrorTitleEmpty.
  ///
  /// In it, this message translates to:
  /// **'Il titolo non può essere vuoto.'**
  String get chatErrorTitleEmpty;

  /// No description provided for @chatErrorRenameFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a rinominare la chat. Riprova.'**
  String get chatErrorRenameFailed;

  /// No description provided for @chatErrorRenameNetwork.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a rinominare la chat. Controlla la connessione.'**
  String get chatErrorRenameNetwork;

  /// No description provided for @chatErrorSummaryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Scrivi almeno un messaggio per avere un riassunto.'**
  String get chatErrorSummaryEmpty;

  /// No description provided for @chatErrorSummaryModel.
  ///
  /// In it, this message translates to:
  /// **'Il modello non ha risposto. Riprova tra poco.'**
  String get chatErrorSummaryModel;

  /// No description provided for @chatErrorSummaryFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a preparare il riassunto. Riprova.'**
  String get chatErrorSummaryFailed;

  /// No description provided for @chatErrorSummaryNetwork.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a preparare il riassunto. Controlla la connessione.'**
  String get chatErrorSummaryNetwork;

  /// No description provided for @chatErrorDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare la chat sul server.'**
  String get chatErrorDeleteFailed;

  /// No description provided for @chatErrorListChats.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare le tue chat.'**
  String get chatErrorListChats;

  /// No description provided for @chatErrorListPets.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare i tuoi pet.'**
  String get chatErrorListPets;

  /// No description provided for @chatErrorConversationLimit.
  ///
  /// In it, this message translates to:
  /// **'hai raggiunto il numero massimo di conversazioni ({max}) per questo animale. Chiudine una per crearne una nuova.'**
  String chatErrorConversationLimit(String max);

  /// No description provided for @chatErrorConversationNotFound.
  ///
  /// In it, this message translates to:
  /// **'Questa conversazione non esiste più.'**
  String get chatErrorConversationNotFound;

  /// No description provided for @chatErrorAttachmentOffline.
  ///
  /// In it, this message translates to:
  /// **'Sei offline o la connessione non è stabile. Riprova quando torni online.'**
  String get chatErrorAttachmentOffline;

  /// No description provided for @chatErrorAttachmentDownload.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a scaricare il file.'**
  String get chatErrorAttachmentDownload;

  /// No description provided for @chatErrorAttachmentTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Il file è troppo grande (max 4 MB).'**
  String get chatErrorAttachmentTooLarge;

  /// No description provided for @chatErrorAttachmentUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Questo tipo di file non è supportato. Puoi caricare foto (JPG, PNG, WEBP) o PDF.'**
  String get chatErrorAttachmentUnsupported;

  /// No description provided for @chatErrorPdfTooManyPages.
  ///
  /// In it, this message translates to:
  /// **'Il PDF supera le 30 pagine consentite.'**
  String get chatErrorPdfTooManyPages;

  /// No description provided for @chatErrorPdfUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere questo PDF: potrebbe essere danneggiato o protetto da password.'**
  String get chatErrorPdfUnreadable;

  /// No description provided for @chatErrorAttachmentUpload.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare il file. Riprova.'**
  String get chatErrorAttachmentUpload;

  /// No description provided for @chatErrorTranscribe.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a trascrivere il messaggio vocale.'**
  String get chatErrorTranscribe;

  /// No description provided for @chatSeedConv1Title.
  ///
  /// In it, this message translates to:
  /// **'Moka - appetito e controllo'**
  String get chatSeedConv1Title;

  /// No description provided for @chatSeedConv1Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Piccolo calo dell appetito, monitoraggio e piano d azione.'**
  String get chatSeedConv1Subtitle;

  /// No description provided for @chatSeedConv1Preview.
  ///
  /// In it, this message translates to:
  /// **'Se resta vivace possiamo osservare fino a domani, ma tieni nota di appetito e acqua.'**
  String get chatSeedConv1Preview;

  /// No description provided for @chatSeedConv1Status.
  ///
  /// In it, this message translates to:
  /// **'Contesto attivo del pet'**
  String get chatSeedConv1Status;

  /// No description provided for @chatSeedConv1Msg1.
  ///
  /// In it, this message translates to:
  /// **'Raccontami pure cosa stai osservando: appetito, energia, acqua e feci ci aiutano a capire subito se serve una visita o basta monitorare.'**
  String get chatSeedConv1Msg1;

  /// No description provided for @chatSeedConv1Msg2.
  ///
  /// In it, this message translates to:
  /// **'Da ieri mangia meno del solito ma resta vivace. Devo preoccuparmi subito?'**
  String get chatSeedConv1Msg2;

  /// No description provided for @chatSeedConv1Msg3.
  ///
  /// In it, this message translates to:
  /// **'Se non ci sono vomito, abbattimento o dolore evidente, in genere conviene monitorare 24 ore e tenere nota di appetito, acqua e feci. Se qualcosa peggiora, contatta il veterinario.'**
  String get chatSeedConv1Msg3;

  /// No description provided for @chatSeedConv1Msg4.
  ///
  /// In it, this message translates to:
  /// **'Per sicurezza ti lascio anche un mini piano: pasti piccoli, acqua sempre disponibile e controllo della temperatura se ti sembra piu fiacco del solito.'**
  String get chatSeedConv1Msg4;

  /// No description provided for @chatSeedConv2Title.
  ///
  /// In it, this message translates to:
  /// **'Moka - promemoria vaccino'**
  String get chatSeedConv2Title;

  /// No description provided for @chatSeedConv2Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Richiamo annuale con nota sul richiamo antiparassitario.'**
  String get chatSeedConv2Subtitle;

  /// No description provided for @chatSeedConv2Preview.
  ///
  /// In it, this message translates to:
  /// **'Ho già messo il richiamo e il promemoria di follow-up per la prossima settimana.'**
  String get chatSeedConv2Preview;

  /// No description provided for @chatSeedConv2Status.
  ///
  /// In it, this message translates to:
  /// **'Promemoria attivo'**
  String get chatSeedConv2Status;

  /// No description provided for @chatSeedConv2Msg1.
  ///
  /// In it, this message translates to:
  /// **'Ho impostato il richiamo e aggiunto una nota sull antiparassitario. Se vuoi, possiamo allineare anche la prossima visita di controllo.'**
  String get chatSeedConv2Msg1;

  /// No description provided for @chatSeedConv2Msg2.
  ///
  /// In it, this message translates to:
  /// **'Perfetto, mi avvisi anche quando manca una settimana?'**
  String get chatSeedConv2Msg2;

  /// No description provided for @chatSeedConv2Msg3.
  ///
  /// In it, this message translates to:
  /// **'Certo. Ti preparo anche una nota visiva con la scadenza piu vicina, cosi la trovi subito nella home.'**
  String get chatSeedConv2Msg3;

  /// No description provided for @chatSeedConv3Title.
  ///
  /// In it, this message translates to:
  /// **'Moka - referto visita'**
  String get chatSeedConv3Title;

  /// No description provided for @chatSeedConv3Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Sintesi del controllo, terapia leggera e prossima azione.'**
  String get chatSeedConv3Subtitle;

  /// No description provided for @chatSeedConv3Preview.
  ///
  /// In it, this message translates to:
  /// **'Posso riassumere il referto in tre punti: quadro, terapia e prossimo controllo.'**
  String get chatSeedConv3Preview;

  /// No description provided for @chatSeedConv3Status.
  ///
  /// In it, this message translates to:
  /// **'Referto caricato'**
  String get chatSeedConv3Status;

  /// No description provided for @chatSeedConv3Msg1.
  ///
  /// In it, this message translates to:
  /// **'Posso sintetizzare il referto in tre punti: quadro clinico, terapia e prossimi controlli. Se vuoi, preparo anche una versione breve da condividere.'**
  String get chatSeedConv3Msg1;

  /// No description provided for @chatSeedConv3Msg2.
  ///
  /// In it, this message translates to:
  /// **'Sì, dammi la versione breve.'**
  String get chatSeedConv3Msg2;

  /// No description provided for @chatSeedConv3Msg3.
  ///
  /// In it, this message translates to:
  /// **'In breve: quadro stabile, terapia leggera per pochi giorni e controllo di follow-up gia programmato.'**
  String get chatSeedConv3Msg3;

  /// No description provided for @chatSeedAgo2Min.
  ///
  /// In it, this message translates to:
  /// **'2 min fa'**
  String get chatSeedAgo2Min;

  /// No description provided for @chatSeedAgo3Days.
  ///
  /// In it, this message translates to:
  /// **'3 gg fa'**
  String get chatSeedAgo3Days;

  /// No description provided for @marketplacePermissionDenied.
  ///
  /// In it, this message translates to:
  /// **'Solo chi ha pubblicato l\'annuncio può modificarlo o eliminarlo.'**
  String get marketplacePermissionDenied;

  /// No description provided for @marketplaceCategoryKennelsCarriers.
  ///
  /// In it, this message translates to:
  /// **'Cucce, lettini e trasportini'**
  String get marketplaceCategoryKennelsCarriers;

  /// No description provided for @marketplaceCategoryLeashesCollars.
  ///
  /// In it, this message translates to:
  /// **'Guinzagli, collari e pettorine'**
  String get marketplaceCategoryLeashesCollars;

  /// No description provided for @marketplaceCategoryToys.
  ///
  /// In it, this message translates to:
  /// **'Giochi'**
  String get marketplaceCategoryToys;

  /// No description provided for @marketplaceCategoryClothing.
  ///
  /// In it, this message translates to:
  /// **'Abbigliamento'**
  String get marketplaceCategoryClothing;

  /// No description provided for @marketplaceCategoryFeeding.
  ///
  /// In it, this message translates to:
  /// **'Ciotole e alimentazione'**
  String get marketplaceCategoryFeeding;

  /// No description provided for @marketplaceCategoryHygieneGrooming.
  ///
  /// In it, this message translates to:
  /// **'Igiene e toelettatura'**
  String get marketplaceCategoryHygieneGrooming;

  /// No description provided for @marketplaceCategoryAquariumsTerrariums.
  ///
  /// In it, this message translates to:
  /// **'Acquari e terrari'**
  String get marketplaceCategoryAquariumsTerrariums;

  /// No description provided for @marketplaceCategoryCagesAviaries.
  ///
  /// In it, this message translates to:
  /// **'Gabbie e voliere'**
  String get marketplaceCategoryCagesAviaries;

  /// No description provided for @marketplaceOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get marketplaceOther;

  /// No description provided for @marketplaceConditionNew.
  ///
  /// In it, this message translates to:
  /// **'Nuovo'**
  String get marketplaceConditionNew;

  /// No description provided for @marketplaceConditionLikeNew.
  ///
  /// In it, this message translates to:
  /// **'Come nuovo'**
  String get marketplaceConditionLikeNew;

  /// No description provided for @marketplaceConditionGood.
  ///
  /// In it, this message translates to:
  /// **'Buono'**
  String get marketplaceConditionGood;

  /// No description provided for @marketplaceConditionWorn.
  ///
  /// In it, this message translates to:
  /// **'Usato'**
  String get marketplaceConditionWorn;

  /// No description provided for @marketplaceSpeciesAll.
  ///
  /// In it, this message translates to:
  /// **'Tutte le specie'**
  String get marketplaceSpeciesAll;

  /// No description provided for @marketplaceSpeciesDog.
  ///
  /// In it, this message translates to:
  /// **'Cane'**
  String get marketplaceSpeciesDog;

  /// No description provided for @marketplaceSpeciesCat.
  ///
  /// In it, this message translates to:
  /// **'Gatto'**
  String get marketplaceSpeciesCat;

  /// No description provided for @marketplaceSpeciesSmallMammal.
  ///
  /// In it, this message translates to:
  /// **'Piccoli mammiferi'**
  String get marketplaceSpeciesSmallMammal;

  /// No description provided for @marketplaceSpeciesBird.
  ///
  /// In it, this message translates to:
  /// **'Uccello'**
  String get marketplaceSpeciesBird;

  /// No description provided for @marketplaceSpeciesReptileAmphibian.
  ///
  /// In it, this message translates to:
  /// **'Rettili e anfibi'**
  String get marketplaceSpeciesReptileAmphibian;

  /// No description provided for @marketplaceSpeciesFish.
  ///
  /// In it, this message translates to:
  /// **'Pesce'**
  String get marketplaceSpeciesFish;

  /// No description provided for @marketplacePriceGift.
  ///
  /// In it, this message translates to:
  /// **'In regalo'**
  String get marketplacePriceGift;

  /// No description provided for @marketplaceDemoBedTitle.
  ///
  /// In it, this message translates to:
  /// **'Cuccia imbottita (demo)'**
  String get marketplaceDemoBedTitle;

  /// No description provided for @marketplaceDemoBedDescription.
  ///
  /// In it, this message translates to:
  /// **'Poco usata, taglia media.'**
  String get marketplaceDemoBedDescription;

  /// No description provided for @marketplaceDemoBedArea.
  ///
  /// In it, this message translates to:
  /// **'Centro, Milano'**
  String get marketplaceDemoBedArea;

  /// No description provided for @marketplaceDemoScratcherTitle.
  ///
  /// In it, this message translates to:
  /// **'Tiragraffi a due piani (demo)'**
  String get marketplaceDemoScratcherTitle;

  /// No description provided for @marketplaceDemoScratcherArea.
  ///
  /// In it, this message translates to:
  /// **'Città Studi, Milano'**
  String get marketplaceDemoScratcherArea;

  /// No description provided for @marketplacePageTitle.
  ///
  /// In it, this message translates to:
  /// **'Mercatino dell\'usato'**
  String get marketplacePageTitle;

  /// No description provided for @marketplaceMapAction.
  ///
  /// In it, this message translates to:
  /// **'Mappa'**
  String get marketplaceMapAction;

  /// No description provided for @marketplaceNewListing.
  ///
  /// In it, this message translates to:
  /// **'Nuovo annuncio'**
  String get marketplaceNewListing;

  /// No description provided for @marketplaceIntro.
  ///
  /// In it, this message translates to:
  /// **'Compra, vendi e regala articoli per animali con altri proprietari.'**
  String get marketplaceIntro;

  /// No description provided for @marketplaceEmptyFiltered.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio con questi filtri per ora.'**
  String get marketplaceEmptyFiltered;

  /// No description provided for @marketplaceNeedsLocation.
  ///
  /// In it, this message translates to:
  /// **'Il Mercatino mostra solo gli annunci vicino a te. Imposta la tua posizione in Impostazioni → Località per vederli.'**
  String get marketplaceNeedsLocation;

  /// No description provided for @marketplaceNoLiveAnimalsNote.
  ///
  /// In it, this message translates to:
  /// **'Nel tuo paese il Mercatino non ammette annunci di animali vivi: solo prodotti e servizi per animali.'**
  String get marketplaceNoLiveAnimalsNote;

  /// No description provided for @marketplaceNoLiveAnimalsConfirm.
  ///
  /// In it, this message translates to:
  /// **'Confermo che questo annuncio non offre un animale vivo (vendita, regalo o cessione)'**
  String get marketplaceNoLiveAnimalsConfirm;

  /// No description provided for @marketplaceNoLiveAnimalsRequired.
  ///
  /// In it, this message translates to:
  /// **'Conferma che l\'annuncio non offre un animale vivo'**
  String get marketplaceNoLiveAnimalsRequired;

  /// No description provided for @marketplaceLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a caricare gli annunci. Controlla la connessione.'**
  String get marketplaceLoadError;

  /// No description provided for @marketplaceFilterAllCategories.
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get marketplaceFilterAllCategories;

  /// No description provided for @marketplaceFilterAllSpecies.
  ///
  /// In it, this message translates to:
  /// **'Tutti gli animali'**
  String get marketplaceFilterAllSpecies;

  /// No description provided for @marketplaceReportListing.
  ///
  /// In it, this message translates to:
  /// **'Segnala annuncio'**
  String get marketplaceReportListing;

  /// No description provided for @marketplaceReasonSpam.
  ///
  /// In it, this message translates to:
  /// **'Spam'**
  String get marketplaceReasonSpam;

  /// No description provided for @marketplaceReasonScam.
  ///
  /// In it, this message translates to:
  /// **'Truffa'**
  String get marketplaceReasonScam;

  /// No description provided for @marketplaceReasonProhibitedItem.
  ///
  /// In it, this message translates to:
  /// **'Articolo non consentito'**
  String get marketplaceReasonProhibitedItem;

  /// No description provided for @marketplaceReasonInappropriate.
  ///
  /// In it, this message translates to:
  /// **'Contenuto inappropriato'**
  String get marketplaceReasonInappropriate;

  /// No description provided for @marketplaceReportRemoved.
  ///
  /// In it, this message translates to:
  /// **'Grazie, l\'annuncio è stato rimosso dopo le segnalazioni ricevute.'**
  String get marketplaceReportRemoved;

  /// No description provided for @marketplaceReportSent.
  ///
  /// In it, this message translates to:
  /// **'Segnalazione inviata, grazie.'**
  String get marketplaceReportSent;

  /// No description provided for @marketplaceDeleteConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'annuncio?'**
  String get marketplaceDeleteConfirmTitle;

  /// No description provided for @marketplaceDeleteConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'\"{title}\" e le sue foto verranno cancellati. Non si può annullare.'**
  String marketplaceDeleteConfirmBody(String title);

  /// No description provided for @marketplaceDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare l\'annuncio. Riprova.'**
  String get marketplaceDeleteFailed;

  /// No description provided for @marketplaceDeleted.
  ///
  /// In it, this message translates to:
  /// **'Annuncio eliminato.'**
  String get marketplaceDeleted;

  /// No description provided for @marketplaceDetailApproxZone.
  ///
  /// In it, this message translates to:
  /// **'{city} · zona approssimata'**
  String marketplaceDetailApproxZone(String city);

  /// No description provided for @marketplaceDetailForSpecies.
  ///
  /// In it, this message translates to:
  /// **'Per: {species}'**
  String marketplaceDetailForSpecies(String species);

  /// No description provided for @marketplaceEditListing.
  ///
  /// In it, this message translates to:
  /// **'Modifica annuncio'**
  String get marketplaceEditListing;

  /// No description provided for @marketplaceDeleting.
  ///
  /// In it, this message translates to:
  /// **'Eliminazione...'**
  String get marketplaceDeleting;

  /// No description provided for @marketplaceDeleteListing.
  ///
  /// In it, this message translates to:
  /// **'Elimina annuncio'**
  String get marketplaceDeleteListing;

  /// No description provided for @marketplaceReporting.
  ///
  /// In it, this message translates to:
  /// **'Invio segnalazione...'**
  String get marketplaceReporting;

  /// No description provided for @marketplaceMapTitle.
  ///
  /// In it, this message translates to:
  /// **'Mappa del mercatino'**
  String get marketplaceMapTitle;

  /// No description provided for @marketplaceListingsCount.
  ///
  /// In it, this message translates to:
  /// **'{count} annunci'**
  String marketplaceListingsCount(int count);

  /// No description provided for @marketplaceMapClusterTitle.
  ///
  /// In it, this message translates to:
  /// **'{count} annunci in questa zona'**
  String marketplaceMapClusterTitle(int count);

  /// No description provided for @marketplaceMapEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun annuncio con questi filtri.'**
  String get marketplaceMapEmpty;

  /// No description provided for @marketplaceMapSummary.
  ///
  /// In it, this message translates to:
  /// **'{count} annunci · posizioni approssimate (circa 1 km)'**
  String marketplaceMapSummary(int count);

  /// No description provided for @marketplaceLocationErrorWithHome.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a rilevare la tua posizione. Controlla i permessi di localizzazione oppure usa la residenza.'**
  String get marketplaceLocationErrorWithHome;

  /// No description provided for @marketplaceLocationErrorNoHome.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a rilevare la tua posizione: serve per mostrare l\'annuncio nella zona giusta (in forma approssimata). Controlla i permessi di localizzazione e riprova.'**
  String get marketplaceLocationErrorNoHome;

  /// No description provided for @marketplaceCameraOpenError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad aprire la fotocamera.'**
  String get marketplaceCameraOpenError;

  /// No description provided for @marketplaceGalleryOpenError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad aprire la galleria.'**
  String get marketplaceGalleryOpenError;

  /// No description provided for @marketplacePhotosSkipped.
  ///
  /// In it, this message translates to:
  /// **'{count} foto non leggibili sono state saltate.'**
  String marketplacePhotosSkipped(int count);

  /// No description provided for @marketplacePhotosMaxReached.
  ///
  /// In it, this message translates to:
  /// **'Puoi aggiungere al massimo {max} foto.'**
  String marketplacePhotosMaxReached(int max);

  /// No description provided for @marketplaceZoneWait.
  ///
  /// In it, this message translates to:
  /// **'Aspetta che la zona sia stata trovata, poi riprova.'**
  String get marketplaceZoneWait;

  /// No description provided for @marketplaceSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare l\'annuncio. Controlla la connessione e riprova.'**
  String get marketplaceSaveFailed;

  /// No description provided for @marketplacePriceRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un prezzo, oppure scegli \"In regalo\"'**
  String get marketplacePriceRequired;

  /// No description provided for @marketplacePriceInvalid.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un prezzo valido'**
  String get marketplacePriceInvalid;

  /// No description provided for @marketplacePriceNegative.
  ///
  /// In it, this message translates to:
  /// **'Il prezzo non può essere negativo'**
  String get marketplacePriceNegative;

  /// No description provided for @marketplacePriceZero.
  ///
  /// In it, this message translates to:
  /// **'Per regalarlo scegli \"In regalo\"'**
  String get marketplacePriceZero;

  /// No description provided for @marketplacePriceTooHigh.
  ///
  /// In it, this message translates to:
  /// **'Prezzo troppo alto'**
  String get marketplacePriceTooHigh;

  /// No description provided for @marketplaceFieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get marketplaceFieldTitle;

  /// No description provided for @marketplaceTitleRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un titolo'**
  String get marketplaceTitleRequired;

  /// No description provided for @marketplaceFieldDescription.
  ///
  /// In it, this message translates to:
  /// **'Descrizione (facoltativa)'**
  String get marketplaceFieldDescription;

  /// No description provided for @marketplaceFieldCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get marketplaceFieldCategory;

  /// No description provided for @marketplaceCategoryRequired.
  ///
  /// In it, this message translates to:
  /// **'Scegli una categoria'**
  String get marketplaceCategoryRequired;

  /// No description provided for @marketplaceConditionLabel.
  ///
  /// In it, this message translates to:
  /// **'Condizione'**
  String get marketplaceConditionLabel;

  /// No description provided for @marketplaceSpeciesLabel.
  ///
  /// In it, this message translates to:
  /// **'Per quali animali'**
  String get marketplaceSpeciesLabel;

  /// No description provided for @marketplaceSpeciesRequired.
  ///
  /// In it, this message translates to:
  /// **'Indica per quali animali è, oppure \"Tutte le specie\"'**
  String get marketplaceSpeciesRequired;

  /// No description provided for @marketplaceGiftSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Lo regali a chi ne ha bisogno'**
  String get marketplaceGiftSubtitle;

  /// No description provided for @marketplaceFieldPrice.
  ///
  /// In it, this message translates to:
  /// **'Prezzo in {currency}'**
  String marketplaceFieldPrice(String currency);

  /// No description provided for @marketplaceSaving.
  ///
  /// In it, this message translates to:
  /// **'Salvataggio...'**
  String get marketplaceSaving;

  /// No description provided for @marketplaceSaveChanges.
  ///
  /// In it, this message translates to:
  /// **'Salva modifiche'**
  String get marketplaceSaveChanges;

  /// No description provided for @marketplacePublish.
  ///
  /// In it, this message translates to:
  /// **'Pubblica annuncio'**
  String get marketplacePublish;

  /// No description provided for @marketplacePhotosTitle.
  ///
  /// In it, this message translates to:
  /// **'Foto ({count}/{max})'**
  String marketplacePhotosTitle(int count, int max);

  /// No description provided for @marketplaceTakePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta foto'**
  String get marketplaceTakePhoto;

  /// No description provided for @marketplaceFromGallery.
  ///
  /// In it, this message translates to:
  /// **'Dalla galleria'**
  String get marketplaceFromGallery;

  /// No description provided for @marketplacePhotosPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Prima dell\'invio togliamo dalle foto i dati nascosti (posizione, dispositivo, data).'**
  String get marketplacePhotosPrivacy;

  /// No description provided for @marketplaceLocationTitle.
  ///
  /// In it, this message translates to:
  /// **'Dove si trova'**
  String get marketplaceLocationTitle;

  /// No description provided for @marketplaceLocationKeep.
  ///
  /// In it, this message translates to:
  /// **'Zona attuale dell\'annuncio'**
  String get marketplaceLocationKeep;

  /// No description provided for @marketplaceLocationNow.
  ///
  /// In it, this message translates to:
  /// **'Dove sono ora'**
  String get marketplaceLocationNow;

  /// No description provided for @marketplaceLocationHome.
  ///
  /// In it, this message translates to:
  /// **'Residenza'**
  String get marketplaceLocationHome;

  /// No description provided for @marketplaceLocationHomeHint.
  ///
  /// In it, this message translates to:
  /// **'Per usare la residenza impostala in Impostazioni → Località.'**
  String get marketplaceLocationHomeHint;

  /// No description provided for @marketplaceLocationSearching.
  ///
  /// In it, this message translates to:
  /// **'Cerco la tua zona...'**
  String get marketplaceLocationSearching;

  /// No description provided for @marketplaceZoneLabel.
  ///
  /// In it, this message translates to:
  /// **'Zona mostrata (quartiere o comune)'**
  String get marketplaceZoneLabel;

  /// No description provided for @marketplaceZoneHelper.
  ///
  /// In it, this message translates to:
  /// **'Niente via o numero civico'**
  String get marketplaceZoneHelper;

  /// No description provided for @marketplacePrivacyApproxOnMap.
  ///
  /// In it, this message translates to:
  /// **'Sulla mappa l\'annuncio appare in un punto approssimato (circa 1 km), mai al tuo indirizzo.'**
  String get marketplacePrivacyApproxOnMap;

  /// No description provided for @marketplacePrivacyApproxAlways.
  ///
  /// In it, this message translates to:
  /// **'Per la tua privacy, la posizione dell\'annuncio è sempre approssimata (circa 1 km), mai il tuo indirizzo esatto.'**
  String get marketplacePrivacyApproxAlways;

  /// No description provided for @medicalActionOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri'**
  String get medicalActionOpen;

  /// No description provided for @medicalActionSend.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get medicalActionSend;

  /// No description provided for @medicalActionRename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get medicalActionRename;

  /// No description provided for @medicalFileUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Il file non è disponibile ora. Controlla la connessione e riprova.'**
  String get medicalFileUnavailable;

  /// No description provided for @medicalPdfOpenFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito ad aprire il PDF. Riprova oppure usa Invia.'**
  String get medicalPdfOpenFailed;

  /// No description provided for @medicalNoPdfAppTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna app per aprire il PDF'**
  String get medicalNoPdfAppTitle;

  /// No description provided for @medicalNoPdfAppBody.
  ///
  /// In it, this message translates to:
  /// **'Su questo dispositivo non c\'è un\'app che apre i PDF. Puoi inviare il file a un\'app che lo apre.'**
  String get medicalNoPdfAppBody;

  /// No description provided for @medicalPreparingFiles.
  ///
  /// In it, this message translates to:
  /// **'Preparo i file da inviare…'**
  String get medicalPreparingFiles;

  /// No description provided for @medicalNoFilesToSend.
  ///
  /// In it, this message translates to:
  /// **'Nessun file disponibile da inviare. Controlla la connessione e riprova.'**
  String get medicalNoFilesToSend;

  /// No description provided for @medicalFilesMissing.
  ///
  /// In it, this message translates to:
  /// **'{count} file non disponibili non sono stati inclusi.'**
  String medicalFilesMissing(int count);

  /// No description provided for @medicalDeleteConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questo documento?'**
  String get medicalDeleteConfirmTitle;

  /// No description provided for @medicalDeleteConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'\"{title}\" verrà eliminato definitivamente.'**
  String medicalDeleteConfirmBody(String title);

  /// No description provided for @medicalDeleting.
  ///
  /// In it, this message translates to:
  /// **'Elimino il referto…'**
  String get medicalDeleting;

  /// No description provided for @medicalRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina referto'**
  String get medicalRenameTitle;

  /// No description provided for @medicalRenameFieldLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome del file'**
  String get medicalRenameFieldLabel;

  /// No description provided for @medicalDefaultRecordTitle.
  ///
  /// In it, this message translates to:
  /// **'Referto clinico'**
  String get medicalDefaultRecordTitle;

  /// No description provided for @medicalSaveNoSession.
  ///
  /// In it, this message translates to:
  /// **'Accesso non disponibile: riprova dopo aver effettuato di nuovo il login.'**
  String get medicalSaveNoSession;

  /// No description provided for @medicalSavePetNotSynced.
  ///
  /// In it, this message translates to:
  /// **'Il profilo di {petName} non è sincronizzato sul server: sistemalo prima di caricare referti.'**
  String medicalSavePetNotSynced(String petName);

  /// No description provided for @medicalSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare il referto sul server. Controlla la connessione e riprova.'**
  String get medicalSaveFailed;

  /// No description provided for @medicalRenameFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a rinominare il referto. Riprova.'**
  String get medicalRenameFailed;

  /// No description provided for @medicalDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare il referto. Riprova.'**
  String get medicalDeleteFailed;

  /// No description provided for @medicalRecordMetaNotUploaded.
  ///
  /// In it, this message translates to:
  /// **'File non caricato sul server'**
  String get medicalRecordMetaNotUploaded;

  /// No description provided for @medicalRecordMetaAnalysisFailed.
  ///
  /// In it, this message translates to:
  /// **'File salvato, lettura automatica non riuscita'**
  String get medicalRecordMetaAnalysisFailed;

  /// No description provided for @medicalRecordMetaUploadedNow.
  ///
  /// In it, this message translates to:
  /// **'Caricato adesso da te'**
  String get medicalRecordMetaUploadedNow;

  /// No description provided for @medicalRecordBadgeNotUploaded.
  ///
  /// In it, this message translates to:
  /// **'Non caricato'**
  String get medicalRecordBadgeNotUploaded;

  /// No description provided for @medicalRecordBadgeNew.
  ///
  /// In it, this message translates to:
  /// **'Nuovo'**
  String get medicalRecordBadgeNew;

  /// No description provided for @medicalRecordSourceLocalOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo su questo telefono'**
  String get medicalRecordSourceLocalOnly;

  /// No description provided for @medicalRecordSourceUploadedByYou.
  ///
  /// In it, this message translates to:
  /// **'Caricato da te'**
  String get medicalRecordSourceUploadedByYou;

  /// No description provided for @medicalTimelineImported.
  ///
  /// In it, this message translates to:
  /// **'Importato'**
  String get medicalTimelineImported;

  /// No description provided for @medicalTimelineUpload.
  ///
  /// In it, this message translates to:
  /// **'Caricamento'**
  String get medicalTimelineUpload;

  /// No description provided for @medicalTimelineFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riuscito'**
  String get medicalTimelineFailed;

  /// No description provided for @medicalTimelineCompleted.
  ///
  /// In it, this message translates to:
  /// **'Completato'**
  String get medicalTimelineCompleted;

  /// No description provided for @medicalTimelineReadyToSend.
  ///
  /// In it, this message translates to:
  /// **'Pronto per l\'invio'**
  String get medicalTimelineReadyToSend;

  /// No description provided for @medicalTimelineAvailable.
  ///
  /// In it, this message translates to:
  /// **'Disponibile'**
  String get medicalTimelineAvailable;

  /// No description provided for @medicalUploadTitle.
  ///
  /// In it, this message translates to:
  /// **'Carica documento'**
  String get medicalUploadTitle;

  /// No description provided for @medicalUploadForPet.
  ///
  /// In it, this message translates to:
  /// **'Per {petName} · PDF, JPG o PNG'**
  String medicalUploadForPet(String petName);

  /// No description provided for @medicalUploadAction.
  ///
  /// In it, this message translates to:
  /// **'Carica'**
  String get medicalUploadAction;

  /// No description provided for @medicalUploadPickPrompt.
  ///
  /// In it, this message translates to:
  /// **'Tocca per scegliere un file'**
  String get medicalUploadPickPrompt;

  /// No description provided for @medicalUploadPickHint.
  ///
  /// In it, this message translates to:
  /// **'PDF, JPG o PNG dal tuo dispositivo'**
  String get medicalUploadPickHint;

  /// No description provided for @medicalUploadChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia'**
  String get medicalUploadChange;

  /// No description provided for @medicalUploadFailedTitle.
  ///
  /// In it, this message translates to:
  /// **'Il file non è stato caricato'**
  String get medicalUploadFailedTitle;

  /// No description provided for @medicalUploadFailedBody.
  ///
  /// In it, this message translates to:
  /// **'{reason} In alternativa puoi salvare il referto solo su questo telefono: sarà marcato come «Non caricato» e non sarà disponibile sugli altri dispositivi.'**
  String medicalUploadFailedBody(String reason);

  /// No description provided for @medicalUploadFailedDefaultReason.
  ///
  /// In it, this message translates to:
  /// **'Controlla la connessione e riprova.'**
  String get medicalUploadFailedDefaultReason;

  /// No description provided for @medicalUploadSaveLocalOnly.
  ///
  /// In it, this message translates to:
  /// **'Salva solo sul telefono'**
  String get medicalUploadSaveLocalOnly;

  /// No description provided for @medicalUploadDemoSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Carica PDF, JPG o PNG e completa i metadati.'**
  String get medicalUploadDemoSubtitle;

  /// No description provided for @medicalUploadDemoAction.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio'**
  String get medicalUploadDemoAction;

  /// No description provided for @medicalUploadDemoCardBody.
  ///
  /// In it, this message translates to:
  /// **'Caricato con successo e pronto per la revisione dei metadati.'**
  String get medicalUploadDemoCardBody;

  /// No description provided for @medicalListTitle.
  ///
  /// In it, this message translates to:
  /// **'Referti'**
  String get medicalListTitle;

  /// No description provided for @medicalListSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Referti, note e allegati di Moka in un archivio chiaro.'**
  String get medicalListSubtitle;

  /// No description provided for @medicalListSyncTitle.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione referti'**
  String get medicalListSyncTitle;

  /// No description provided for @medicalListSyncBody.
  ///
  /// In it, this message translates to:
  /// **'Sto recuperando documenti e metadati da Supabase o dalla sorgente demo.'**
  String get medicalListSyncBody;

  /// No description provided for @medicalListLoadErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare l archivio'**
  String get medicalListLoadErrorTitle;

  /// No description provided for @medicalListLoadErrorBody.
  ///
  /// In it, this message translates to:
  /// **'Riprova dopo aver controllato la connessione o continua con il fallback demo.'**
  String get medicalListLoadErrorBody;

  /// No description provided for @medicalListEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento ancora'**
  String get medicalListEmptyTitle;

  /// No description provided for @medicalListEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Carica il primo referto per costruire l archivio documenti.'**
  String get medicalListEmptyBody;

  /// No description provided for @medicalListUploadFirst.
  ///
  /// In it, this message translates to:
  /// **'Carica il primo file'**
  String get medicalListUploadFirst;

  /// No description provided for @medicalListSummaryAllTitle.
  ///
  /// In it, this message translates to:
  /// **'{count} documenti attivi'**
  String medicalListSummaryAllTitle(int count);

  /// No description provided for @medicalListSummaryPetTitle.
  ///
  /// In it, this message translates to:
  /// **'{count} documenti di {petName}'**
  String medicalListSummaryPetTitle(int count, String petName);

  /// No description provided for @medicalListSummaryAllBody.
  ///
  /// In it, this message translates to:
  /// **'1 referto pronto da condividere, 1 esame da rivedere e 1 nota archiviata.'**
  String get medicalListSummaryAllBody;

  /// No description provided for @medicalListSummaryPetBody.
  ///
  /// In it, this message translates to:
  /// **'Filtri attivi sul profilo di {petName}. Apri i documenti piu utili senza rumore.'**
  String medicalListSummaryPetBody(String petName);

  /// No description provided for @medicalListNextActionTitle.
  ///
  /// In it, this message translates to:
  /// **'Prossima azione'**
  String get medicalListNextActionTitle;

  /// No description provided for @medicalListNextActionAllBody.
  ///
  /// In it, this message translates to:
  /// **'Apri il referto vaccinale di Moka e condividilo con Francesco.'**
  String get medicalListNextActionAllBody;

  /// No description provided for @medicalListNextActionPetBody.
  ///
  /// In it, this message translates to:
  /// **'Condividi il documento piu recente di {petName} e conserva la nota nel profilo.'**
  String medicalListNextActionPetBody(String petName);

  /// No description provided for @medicalListEmptyPetTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento per {petName}'**
  String medicalListEmptyPetTitle(String petName);

  /// No description provided for @medicalListEmptyPetBody.
  ///
  /// In it, this message translates to:
  /// **'Cambia filtro oppure carica un nuovo documento per questo pet.'**
  String get medicalListEmptyPetBody;

  /// No description provided for @medicalListRemoveFilter.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi filtro'**
  String get medicalListRemoveFilter;

  /// No description provided for @medicalFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti ({count})'**
  String medicalFilterAll(int count);

  /// No description provided for @medicalMetaType.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get medicalMetaType;

  /// No description provided for @medicalMetaDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get medicalMetaDate;

  /// No description provided for @medicalMetaSource.
  ///
  /// In it, this message translates to:
  /// **'Fonte'**
  String get medicalMetaSource;

  /// No description provided for @medicalMetaFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get medicalMetaFormat;

  /// No description provided for @medicalStatePreviewPill.
  ///
  /// In it, this message translates to:
  /// **'Stato anteprima'**
  String get medicalStatePreviewPill;

  /// No description provided for @medicalStateLoadingPill.
  ///
  /// In it, this message translates to:
  /// **'Caricamento'**
  String get medicalStateLoadingPill;

  /// No description provided for @medicalChecklistFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato file supportato'**
  String get medicalChecklistFormat;

  /// No description provided for @medicalChecklistMetadata.
  ///
  /// In it, this message translates to:
  /// **'Metadati estratti'**
  String get medicalChecklistMetadata;

  /// No description provided for @medicalChecklistLinkedPet.
  ///
  /// In it, this message translates to:
  /// **'Collegato al pet attivo'**
  String get medicalChecklistLinkedPet;

  /// No description provided for @homeGreeting.
  ///
  /// In it, this message translates to:
  /// **'Buongiorno'**
  String get homeGreeting;

  /// No description provided for @homeAgendaTitle.
  ///
  /// In it, this message translates to:
  /// **'Prossime attività'**
  String get homeAgendaTitle;

  /// No description provided for @homeAgendaLoadingSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Spot e cicli, per tutti gli animali.'**
  String get homeAgendaLoadingSubtitle;

  /// No description provided for @homeAgendaSummary.
  ///
  /// In it, this message translates to:
  /// **'{count} attività nei prossimi 10 giorni'**
  String homeAgendaSummary(int count);

  /// No description provided for @homeNewsTitle.
  ///
  /// In it, this message translates to:
  /// **'Curiosità per i tuoi animali'**
  String get homeNewsTitle;

  /// No description provided for @homeNewsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Notizie dal mondo dei pet selezionate per te.'**
  String get homeNewsSubtitle;

  /// No description provided for @homeNewsUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Curiosità non disponibili al momento. Riprova più tardi.'**
  String get homeNewsUnavailable;

  /// No description provided for @homeNewsMore.
  ///
  /// In it, this message translates to:
  /// **'Scopri altre notizie'**
  String get homeNewsMore;

  /// No description provided for @homeNearbyTitle.
  ///
  /// In it, this message translates to:
  /// **'Vicino a me'**
  String get homeNearbyTitle;

  /// No description provided for @homeSponsorBanner.
  ///
  /// In it, this message translates to:
  /// **'Spazio riservato ai nostri partner.'**
  String get homeSponsorBanner;

  /// No description provided for @homeSectionLoading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento...'**
  String get homeSectionLoading;

  /// No description provided for @shellTabHome.
  ///
  /// In it, this message translates to:
  /// **'Home'**
  String get shellTabHome;

  /// No description provided for @shellTabPets.
  ///
  /// In it, this message translates to:
  /// **'Animali'**
  String get shellTabPets;

  /// No description provided for @shellTabActivities.
  ///
  /// In it, this message translates to:
  /// **'Attività'**
  String get shellTabActivities;

  /// No description provided for @shellTabSettings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get shellTabSettings;

  /// No description provided for @shellRailFooter.
  ///
  /// In it, this message translates to:
  /// **'Spazio clinico caldo'**
  String get shellRailFooter;

  /// No description provided for @shellInterruptedWalkTitle.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata interrotta'**
  String get shellInterruptedWalkTitle;

  /// No description provided for @shellInterruptedWalkBody.
  ///
  /// In it, this message translates to:
  /// **'È rimasta una passeggiata in corso ({distance} finora). Vuoi riprenderla?'**
  String shellInterruptedWalkBody(String distance);

  /// No description provided for @shellInterruptedWalkDiscard.
  ///
  /// In it, this message translates to:
  /// **'Scarta'**
  String get shellInterruptedWalkDiscard;

  /// No description provided for @shellInterruptedWalkResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get shellInterruptedWalkResume;

  /// No description provided for @shellWalkPausedBanner.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata in pausa · {distance}'**
  String shellWalkPausedBanner(String distance);

  /// No description provided for @shellWalkActiveBanner.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata in corso · {elapsed} · {distance}'**
  String shellWalkActiveBanner(String elapsed, String distance);

  /// No description provided for @splashMessageWalks.
  ///
  /// In it, this message translates to:
  /// **'Registra le passeggiate con il tuo cane!'**
  String get splashMessageWalks;

  /// No description provided for @splashMessageVet.
  ///
  /// In it, this message translates to:
  /// **'Chiedi al veterinario virtuale, 24 ore su 24'**
  String get splashMessageVet;

  /// No description provided for @splashMessageReminders.
  ///
  /// In it, this message translates to:
  /// **'Non dimenticare più una scadenza: promemoria e calendario'**
  String get splashMessageReminders;

  /// No description provided for @splashMessageRecords.
  ///
  /// In it, this message translates to:
  /// **'Tieni i referti sempre a portata di mano'**
  String get splashMessageRecords;

  /// No description provided for @splashMessageNearby.
  ///
  /// In it, this message translates to:
  /// **'Scopri le attività pet-friendly vicino a te'**
  String get splashMessageNearby;

  /// No description provided for @splashMessageNews.
  ///
  /// In it, this message translates to:
  /// **'Segui le novità sul mondo degli animali'**
  String get splashMessageNews;

  /// No description provided for @splashMessageProfiles.
  ///
  /// In it, this message translates to:
  /// **'Un profilo per ogni amico a quattro zampe (o con le pinne!)'**
  String get splashMessageProfiles;

  /// No description provided for @splashMessageHealthBook.
  ///
  /// In it, this message translates to:
  /// **'Il libretto sanitario nel taschino, senza più carte sparse'**
  String get splashMessageHealthBook;

  /// No description provided for @splashMessageVaccines.
  ///
  /// In it, this message translates to:
  /// **'Vaccini, vermifughi, visite: ci pensiamo noi a ricordarteli'**
  String get splashMessageVaccines;

  /// No description provided for @splashMessageSpecies.
  ///
  /// In it, this message translates to:
  /// **'Cane, gatto, coniglio, pappagallo o pesciolino: qui c\'è posto per tutti'**
  String get splashMessageSpecies;

  /// No description provided for @sharedGuestName.
  ///
  /// In it, this message translates to:
  /// **'Ospite'**
  String get sharedGuestName;

  /// No description provided for @sharedComingSoon.
  ///
  /// In it, this message translates to:
  /// **'In arrivo'**
  String get sharedComingSoon;

  /// No description provided for @sharedLoadingLabel.
  ///
  /// In it, this message translates to:
  /// **'Caricamento'**
  String get sharedLoadingLabel;

  /// No description provided for @sharedAttachmentTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Il file è troppo grande (max 4 MB).'**
  String get sharedAttachmentTooLarge;

  /// No description provided for @sharedAttachmentInvalidPdf.
  ///
  /// In it, this message translates to:
  /// **'Questo file non sembra un PDF valido.'**
  String get sharedAttachmentInvalidPdf;

  /// No description provided for @sharedAiGenerated.
  ///
  /// In it, this message translates to:
  /// **'Generato da IA'**
  String get sharedAiGenerated;

  /// No description provided for @sharedAiNotReviewed.
  ///
  /// In it, this message translates to:
  /// **'Risposta automatica, non revisionata'**
  String get sharedAiNotReviewed;

  /// No description provided for @petsAgeLessThanMonth.
  ///
  /// In it, this message translates to:
  /// **'Meno di un mese'**
  String get petsAgeLessThanMonth;

  /// No description provided for @petsAgeMonths.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 mese} other{{count} mesi}}'**
  String petsAgeMonths(int count);

  /// No description provided for @petsAgeYears.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 anno} other{{count} anni}}'**
  String petsAgeYears(int count);

  /// No description provided for @petsProfilesCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 profilo} other{{count} profili}}'**
  String petsProfilesCount(int count);

  /// No description provided for @petsSpeciesCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 specie} other{{count} specie}}'**
  String petsSpeciesCount(int count);

  /// No description provided for @petsFishCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 pesce} other{{count} pesci}}'**
  String petsFishCount(int count);

  /// No description provided for @petsAquariumSummary.
  ///
  /// In it, this message translates to:
  /// **'{species} · {fish}'**
  String petsAquariumSummary(String species, String fish);

  /// No description provided for @petsBreedUnspecified.
  ///
  /// In it, this message translates to:
  /// **'Razza non specificata'**
  String get petsBreedUnspecified;

  /// No description provided for @petsSpeciesUnspecified.
  ///
  /// In it, this message translates to:
  /// **'Specie non specificata'**
  String get petsSpeciesUnspecified;

  /// No description provided for @petsBreedOtherWithSize.
  ///
  /// In it, this message translates to:
  /// **'Altro · Taglia {size}'**
  String petsBreedOtherWithSize(String size);

  /// No description provided for @petsHabitatAquarium.
  ///
  /// In it, this message translates to:
  /// **'Acquario'**
  String get petsHabitatAquarium;

  /// No description provided for @petsHabitatTerrarium.
  ///
  /// In it, this message translates to:
  /// **'Terrario'**
  String get petsHabitatTerrarium;

  /// No description provided for @petsHabitatAviary.
  ///
  /// In it, this message translates to:
  /// **'Voliera'**
  String get petsHabitatAviary;

  /// No description provided for @petsHabitatGeneric.
  ///
  /// In it, this message translates to:
  /// **'Habitat'**
  String get petsHabitatGeneric;

  /// No description provided for @petsCreateTitle.
  ///
  /// In it, this message translates to:
  /// **'Crea un profilo pet'**
  String get petsCreateTitle;

  /// No description provided for @petsCreateLoading.
  ///
  /// In it, this message translates to:
  /// **'Preparo il form di creazione...'**
  String get petsCreateLoading;

  /// No description provided for @petsCreateErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Form di creazione non disponibile'**
  String get petsCreateErrorTitle;

  /// No description provided for @petsCreateErrorDefault.
  ///
  /// In it, this message translates to:
  /// **'Al momento non riesco a creare un nuovo profilo pet.'**
  String get petsCreateErrorDefault;

  /// No description provided for @petsCreateFormTitle.
  ///
  /// In it, this message translates to:
  /// **'Nuovo profilo'**
  String get petsCreateFormTitle;

  /// No description provided for @petsCreateSubmit.
  ///
  /// In it, this message translates to:
  /// **'Salva profilo pet'**
  String get petsCreateSubmit;

  /// No description provided for @petsCreateUnsyncedSnack.
  ///
  /// In it, this message translates to:
  /// **'Profilo salvato sul telefono ma non sul server. Aprilo dalla lista e tocca Riprova.'**
  String get petsCreateUnsyncedSnack;

  /// No description provided for @petsEditTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica {name}'**
  String petsEditTitle(String name);

  /// No description provided for @petsEditLoading.
  ///
  /// In it, this message translates to:
  /// **'Carico il form di modifica...'**
  String get petsEditLoading;

  /// No description provided for @petsEditErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica non disponibile'**
  String get petsEditErrorTitle;

  /// No description provided for @petsEditErrorDefault.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad aprire questo profilo pet per la modifica.'**
  String get petsEditErrorDefault;

  /// No description provided for @petsEditFormTitle.
  ///
  /// In it, this message translates to:
  /// **'Bozza profilo'**
  String get petsEditFormTitle;

  /// No description provided for @petsEditSubmit.
  ///
  /// In it, this message translates to:
  /// **'Salva modifiche'**
  String get petsEditSubmit;

  /// No description provided for @petsEditUnsyncedSnack.
  ///
  /// In it, this message translates to:
  /// **'Modifiche salvate sul telefono ma non sul server. Apri il profilo e tocca Riprova.'**
  String get petsEditUnsyncedSnack;

  /// No description provided for @petsEditDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere questo profilo?'**
  String get petsEditDeleteTitle;

  /// No description provided for @petsEditDeleteMessage.
  ///
  /// In it, this message translates to:
  /// **'Il profilo di \"{name}\" verrà eliminato definitivamente, insieme ai suoi dati.'**
  String petsEditDeleteMessage(String name);

  /// No description provided for @petsEditDeleteConfirm.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get petsEditDeleteConfirm;

  /// No description provided for @petsEditDeleteAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi profilo'**
  String get petsEditDeleteAction;

  /// No description provided for @petsEditMemorialTitle.
  ///
  /// In it, this message translates to:
  /// **'Spostare nei ricordi?'**
  String get petsEditMemorialTitle;

  /// No description provided for @petsEditMemorialMessage.
  ///
  /// In it, this message translates to:
  /// **'\"{name}\" uscirà dalla lista Animali e sarà conservato nella sezione Ricordi, con il suo profilo e le sue foto.'**
  String petsEditMemorialMessage(String name);

  /// No description provided for @petsEditMemorialConfirm.
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get petsEditMemorialConfirm;

  /// No description provided for @petsEditMemorialAction.
  ///
  /// In it, this message translates to:
  /// **'Sposta nei ricordi'**
  String get petsEditMemorialAction;

  /// No description provided for @petsFormAddSpecies.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi specie'**
  String get petsFormAddSpecies;

  /// No description provided for @petsFormIdentityColor.
  ///
  /// In it, this message translates to:
  /// **'Colore identificativo'**
  String get petsFormIdentityColor;

  /// No description provided for @petsFormNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get petsFormNameLabel;

  /// No description provided for @petsFormNameHint.
  ///
  /// In it, this message translates to:
  /// **'Moka'**
  String get petsFormNameHint;

  /// No description provided for @petsFormNameError.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il nome del pet.'**
  String get petsFormNameError;

  /// No description provided for @petsFormSpeciesLabel.
  ///
  /// In it, this message translates to:
  /// **'Tipo di animale'**
  String get petsFormSpeciesLabel;

  /// No description provided for @petsFormSpeciesHint.
  ///
  /// In it, this message translates to:
  /// **'Seleziona il tipo di animale'**
  String get petsFormSpeciesHint;

  /// No description provided for @petsFormSpeciesError.
  ///
  /// In it, this message translates to:
  /// **'Seleziona il tipo di animale.'**
  String get petsFormSpeciesError;

  /// No description provided for @petsFormProfileType.
  ///
  /// In it, this message translates to:
  /// **'Cosa vuoi registrare?'**
  String get petsFormProfileType;

  /// No description provided for @petsFormFishSingleTitle.
  ///
  /// In it, this message translates to:
  /// **'Pesce'**
  String get petsFormFishSingleTitle;

  /// No description provided for @petsFormFishSingleBody.
  ///
  /// In it, this message translates to:
  /// **'Un solo pesce, scelto per specie (es. Betta, pesce rosso)'**
  String get petsFormFishSingleBody;

  /// No description provided for @petsFormFishAquariumBody.
  ///
  /// In it, this message translates to:
  /// **'Una vasca con più specie e più esemplari, maschi e femmine'**
  String get petsFormFishAquariumBody;

  /// No description provided for @petsFormAquariumPopulation.
  ///
  /// In it, this message translates to:
  /// **'Popolazione dell\'acquario'**
  String get petsFormAquariumPopulation;

  /// No description provided for @petsFormNoSpeciesYet.
  ///
  /// In it, this message translates to:
  /// **'Nessuna specie aggiunta ancora.'**
  String get petsFormNoSpeciesYet;

  /// No description provided for @petsFormAquariumNeedsSpecies.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi almeno una specie all\'acquario.'**
  String get petsFormAquariumNeedsSpecies;

  /// No description provided for @petsFormBreedLabel.
  ///
  /// In it, this message translates to:
  /// **'Razza'**
  String get petsFormBreedLabel;

  /// No description provided for @petsFormBreedSelectSpeciesFirst.
  ///
  /// In it, this message translates to:
  /// **'Seleziona prima il tipo di animale'**
  String get petsFormBreedSelectSpeciesFirst;

  /// No description provided for @petsFormBreedSpeciesLabel.
  ///
  /// In it, this message translates to:
  /// **'Specie'**
  String get petsFormBreedSpeciesLabel;

  /// No description provided for @petsFormBreedRequired.
  ///
  /// In it, this message translates to:
  /// **'Scegli la razza.'**
  String get petsFormBreedRequired;

  /// No description provided for @petsFormBreedSpeciesRequired.
  ///
  /// In it, this message translates to:
  /// **'Scegli la specie.'**
  String get petsFormBreedSpeciesRequired;

  /// No description provided for @petsFormBreedTextRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi la razza.'**
  String get petsFormBreedTextRequired;

  /// No description provided for @petsFormBreedSpeciesTextRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi la specie.'**
  String get petsFormBreedSpeciesTextRequired;

  /// No description provided for @petsFormBreedSpeciesPlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Seleziona una specie'**
  String get petsFormBreedSpeciesPlaceholder;

  /// No description provided for @petsFormOtherSpeciesDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'Quale specie?'**
  String get petsFormOtherSpeciesDialogTitle;

  /// No description provided for @petsFormBreedPlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Seleziona una razza'**
  String get petsFormBreedPlaceholder;

  /// No description provided for @petsFormBreedSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca una razza'**
  String get petsFormBreedSearchHint;

  /// No description provided for @petsFormBreedSearchHintScientific.
  ///
  /// In it, this message translates to:
  /// **'Cerca (anche per nome scientifico)'**
  String get petsFormBreedSearchHintScientific;

  /// No description provided for @petsFormOtherBreedLabel.
  ///
  /// In it, this message translates to:
  /// **'Quale razza?'**
  String get petsFormOtherBreedLabel;

  /// No description provided for @petsFormOtherBreedHint.
  ///
  /// In it, this message translates to:
  /// **'Es. incrocio di barboncino'**
  String get petsFormOtherBreedHint;

  /// No description provided for @petsFormOtherSpeciesLabel.
  ///
  /// In it, this message translates to:
  /// **'Quale specie?'**
  String get petsFormOtherSpeciesLabel;

  /// No description provided for @petsFormOtherSpeciesHint.
  ///
  /// In it, this message translates to:
  /// **'Es. nome comune o scientifico'**
  String get petsFormOtherSpeciesHint;

  /// No description provided for @petsFormDogSizeLabel.
  ///
  /// In it, this message translates to:
  /// **'Taglia (facoltativa)'**
  String get petsFormDogSizeLabel;

  /// No description provided for @petsFormDogSizeHint.
  ///
  /// In it, this message translates to:
  /// **'Seleziona una taglia'**
  String get petsFormDogSizeHint;

  /// No description provided for @petsFormBirthDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Data di nascita'**
  String get petsFormBirthDateLabel;

  /// No description provided for @petsFormBirthDateHint.
  ///
  /// In it, this message translates to:
  /// **'gg/mm/aaaa'**
  String get petsFormBirthDateHint;

  /// No description provided for @petsFormBirthDateRequired.
  ///
  /// In it, this message translates to:
  /// **'Seleziona la data di nascita.'**
  String get petsFormBirthDateRequired;

  /// No description provided for @petsFormBirthDateInvalid.
  ///
  /// In it, this message translates to:
  /// **'Data non valida (gg/mm/aaaa).'**
  String get petsFormBirthDateInvalid;

  /// No description provided for @petsFormBirthDateFuture.
  ///
  /// In it, this message translates to:
  /// **'La data di nascita non può essere nel futuro.'**
  String get petsFormBirthDateFuture;

  /// No description provided for @petsFormSexLabel.
  ///
  /// In it, this message translates to:
  /// **'Sesso'**
  String get petsFormSexLabel;

  /// No description provided for @petsFormSexHint.
  ///
  /// In it, this message translates to:
  /// **'Seleziona'**
  String get petsFormSexHint;

  /// No description provided for @petsFormSexUnknown.
  ///
  /// In it, this message translates to:
  /// **'Sconosciuto'**
  String get petsFormSexUnknown;

  /// No description provided for @petsFormWeightLabelKg.
  ///
  /// In it, this message translates to:
  /// **'Peso (facoltativo, kg)'**
  String get petsFormWeightLabelKg;

  /// No description provided for @petsFormWeightLabelLb.
  ///
  /// In it, this message translates to:
  /// **'Peso (facoltativo, lb)'**
  String get petsFormWeightLabelLb;

  /// No description provided for @petsFormWeightHintKg.
  ///
  /// In it, this message translates to:
  /// **'Es. 18,4'**
  String get petsFormWeightHintKg;

  /// No description provided for @petsFormWeightLabelG.
  ///
  /// In it, this message translates to:
  /// **'Peso (facoltativo, g)'**
  String get petsFormWeightLabelG;

  /// No description provided for @petsFormWeightHintG.
  ///
  /// In it, this message translates to:
  /// **'Es. 35'**
  String get petsFormWeightHintG;

  /// No description provided for @petsFormWeightHintLb.
  ///
  /// In it, this message translates to:
  /// **'Es. 40,5'**
  String get petsFormWeightHintLb;

  /// No description provided for @petsFormWeightInvalid.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un peso valido.'**
  String get petsFormWeightInvalid;

  /// No description provided for @petsFormWeightPositive.
  ///
  /// In it, this message translates to:
  /// **'Il peso deve essere maggiore di zero.'**
  String get petsFormWeightPositive;

  /// No description provided for @petsFormNotesLabel.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get petsFormNotesLabel;

  /// No description provided for @petsFormNotesHint.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi note brevi su dieta, farmaci o comportamento.'**
  String get petsFormNotesHint;

  /// No description provided for @petsFormSaving.
  ///
  /// In it, this message translates to:
  /// **'Salvataggio in corso…'**
  String get petsFormSaving;

  /// No description provided for @petsFormPhotoAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi foto'**
  String get petsFormPhotoAdd;

  /// No description provided for @petsFormPhotoChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia foto'**
  String get petsFormPhotoChange;

  /// No description provided for @petsFormPhotoRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get petsFormPhotoRemove;

  /// No description provided for @petsFormHabitatLength.
  ///
  /// In it, this message translates to:
  /// **'Lunghezza'**
  String get petsFormHabitatLength;

  /// No description provided for @petsFormHabitatWidth.
  ///
  /// In it, this message translates to:
  /// **'Larghezza'**
  String get petsFormHabitatWidth;

  /// No description provided for @petsFormHabitatHeight.
  ///
  /// In it, this message translates to:
  /// **'Altezza'**
  String get petsFormHabitatHeight;

  /// No description provided for @petsFormHabitatUsGallons.
  ///
  /// In it, this message translates to:
  /// **'Galloni USA'**
  String get petsFormHabitatUsGallons;

  /// No description provided for @petsFormHabitatLiters.
  ///
  /// In it, this message translates to:
  /// **'Litri'**
  String get petsFormHabitatLiters;

  /// No description provided for @petsFormHabitatVolumeHint.
  ///
  /// In it, this message translates to:
  /// **'Calcolati dalle dimensioni, modificabili'**
  String get petsFormHabitatVolumeHint;

  /// No description provided for @petsFormHabitatTemperature.
  ///
  /// In it, this message translates to:
  /// **'Temperatura'**
  String get petsFormHabitatTemperature;

  /// No description provided for @petsFormHabitatTemperatureHintF.
  ///
  /// In it, this message translates to:
  /// **'Es. 75-79°F'**
  String get petsFormHabitatTemperatureHintF;

  /// No description provided for @petsFormHabitatTemperatureHintC.
  ///
  /// In it, this message translates to:
  /// **'Es. 24-26°C'**
  String get petsFormHabitatTemperatureHintC;

  /// No description provided for @petsFormHabitatSubstrate.
  ///
  /// In it, this message translates to:
  /// **'Substrato'**
  String get petsFormHabitatSubstrate;

  /// No description provided for @petsFormHabitatSubstrateHint.
  ///
  /// In it, this message translates to:
  /// **'Es. ghiaia fine, fibra di cocco'**
  String get petsFormHabitatSubstrateHint;

  /// No description provided for @petsFormHabitatEquipment.
  ///
  /// In it, this message translates to:
  /// **'Attrezzatura'**
  String get petsFormHabitatEquipment;

  /// No description provided for @petsFormHabitatEquipmentHint.
  ///
  /// In it, this message translates to:
  /// **'Filtro, illuminazione, riscaldatore, piante, lampada UVB, posatoi...'**
  String get petsFormHabitatEquipmentHint;

  /// No description provided for @petsDetailTitleFallback.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio pet'**
  String get petsDetailTitleFallback;

  /// No description provided for @petsDetailGalleryTooltip.
  ///
  /// In it, this message translates to:
  /// **'Galleria foto'**
  String get petsDetailGalleryTooltip;

  /// No description provided for @petsDetailLoading.
  ///
  /// In it, this message translates to:
  /// **'Carico il dettaglio pet...'**
  String get petsDetailLoading;

  /// No description provided for @petsDetailErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio pet non disponibile'**
  String get petsDetailErrorTitle;

  /// No description provided for @petsDetailErrorDefault.
  ///
  /// In it, this message translates to:
  /// **'Questo profilo pet non e disponibile al momento.'**
  String get petsDetailErrorDefault;

  /// No description provided for @petsDetailBackToList.
  ///
  /// In it, this message translates to:
  /// **'Torna alla lista'**
  String get petsDetailBackToList;

  /// No description provided for @petsDetailEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun pet selezionato'**
  String get petsDetailEmptyTitle;

  /// No description provided for @petsDetailEmptySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli un profilo dalla lista per vedere dettagli, chat e referti.'**
  String get petsDetailEmptySubtitle;

  /// No description provided for @petsDetailTabReminders.
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get petsDetailTabReminders;

  /// No description provided for @petsDetailTabChat.
  ///
  /// In it, this message translates to:
  /// **'Chat'**
  String get petsDetailTabChat;

  /// No description provided for @petsDetailTabRecords.
  ///
  /// In it, this message translates to:
  /// **'Referti'**
  String get petsDetailTabRecords;

  /// No description provided for @petsDetailTabWalks.
  ///
  /// In it, this message translates to:
  /// **'Passeggiate'**
  String get petsDetailTabWalks;

  /// No description provided for @petsDetailHabitatTapForDetails.
  ///
  /// In it, this message translates to:
  /// **'Tocca per i dettagli'**
  String get petsDetailHabitatTapForDetails;

  /// No description provided for @petsDetailHabitatDimensions.
  ///
  /// In it, this message translates to:
  /// **'Dimensioni'**
  String get petsDetailHabitatDimensions;

  /// No description provided for @petsDetailHabitatVolume.
  ///
  /// In it, this message translates to:
  /// **'Volume'**
  String get petsDetailHabitatVolume;

  /// No description provided for @petsDetailPopulation.
  ///
  /// In it, this message translates to:
  /// **'Popolazione'**
  String get petsDetailPopulation;

  /// No description provided for @petsDetailRemindersNew.
  ///
  /// In it, this message translates to:
  /// **'Nuovo promemoria'**
  String get petsDetailRemindersNew;

  /// No description provided for @petsDetailRemindersEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun promemoria ancora per {petName}.'**
  String petsDetailRemindersEmpty(String petName);

  /// No description provided for @petsDetailChatNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova chat'**
  String get petsDetailChatNew;

  /// No description provided for @petsDetailChatEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna conversazione ancora per {petName}.'**
  String petsDetailChatEmpty(String petName);

  /// No description provided for @petsDetailChatDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Chat rimossa qui, ma non sul server: {error}'**
  String petsDetailChatDeleteFailed(String error);

  /// No description provided for @petsDetailChatDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa chat?'**
  String get petsDetailChatDeleteTitle;

  /// No description provided for @petsDetailChatDeleteMessage.
  ///
  /// In it, this message translates to:
  /// **'\"{title}\" verrà eliminata definitivamente.'**
  String petsDetailChatDeleteMessage(String title);

  /// No description provided for @petsDetailChatLimitTitle.
  ///
  /// In it, this message translates to:
  /// **'Limite chat raggiunto'**
  String get petsDetailChatLimitTitle;

  /// No description provided for @petsDetailChatLimitMessage.
  ///
  /// In it, this message translates to:
  /// **'Puoi avere al massimo {max} conversazioni attive per {petName}. Elimina una chat esistente per aprirne una nuova.'**
  String petsDetailChatLimitMessage(int max, String petName);

  /// No description provided for @petsDetailChatLimitOk.
  ///
  /// In it, this message translates to:
  /// **'Ho capito'**
  String get petsDetailChatLimitOk;

  /// No description provided for @petsDetailRecordsSendTitle.
  ///
  /// In it, this message translates to:
  /// **'Invia file'**
  String get petsDetailRecordsSendTitle;

  /// No description provided for @petsDetailRecordsSendSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli un documento da inviare via email, WhatsApp e altro.'**
  String get petsDetailRecordsSendSubtitle;

  /// No description provided for @petsDetailRecordShareText.
  ///
  /// In it, this message translates to:
  /// **'📄 {title}\n{source} · {date}\n\nCondiviso da VetApp'**
  String petsDetailRecordShareText(String title, String source, String date);

  /// No description provided for @petsDetailShareUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Condivisione non disponibile su questo dispositivo.'**
  String get petsDetailShareUnavailable;

  /// No description provided for @petsDetailRecordsUpload.
  ///
  /// In it, this message translates to:
  /// **'Carica file'**
  String get petsDetailRecordsUpload;

  /// No description provided for @petsDetailRecordsSend.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get petsDetailRecordsSend;

  /// No description provided for @petsDetailRecordsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento ancora per {petName}.'**
  String petsDetailRecordsEmpty(String petName);

  /// No description provided for @petsDetailRecordsLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere i referti. Controlla la connessione e riprova.'**
  String get petsDetailRecordsLoadError;

  /// No description provided for @petsDetailSelectedCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 selezionato} other{{count} selezionati}}'**
  String petsDetailSelectedCount(int count);

  /// No description provided for @petsDetailWalksStart.
  ///
  /// In it, this message translates to:
  /// **'Avvia passeggiata'**
  String get petsDetailWalksStart;

  /// No description provided for @petsDetailWalksBadges.
  ///
  /// In it, this message translates to:
  /// **'Badge'**
  String get petsDetailWalksBadges;

  /// No description provided for @petsDetailWalksEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna passeggiata ancora per {petName}.'**
  String petsDetailWalksEmpty(String petName);

  /// No description provided for @petsDetailWalksRecords.
  ///
  /// In it, this message translates to:
  /// **'Record 🏆'**
  String get petsDetailWalksRecords;

  /// No description provided for @petsDetailWalksFavorites.
  ///
  /// In it, this message translates to:
  /// **'Preferite ⭐'**
  String get petsDetailWalksFavorites;

  /// No description provided for @petsDetailWalksRecent.
  ///
  /// In it, this message translates to:
  /// **'Recenti'**
  String get petsDetailWalksRecent;

  /// No description provided for @petsDetailWalkLongest.
  ///
  /// In it, this message translates to:
  /// **'Più lunga'**
  String get petsDetailWalkLongest;

  /// No description provided for @petsDetailWalkLongestDuration.
  ///
  /// In it, this message translates to:
  /// **'Più duratura'**
  String get petsDetailWalkLongestDuration;

  /// No description provided for @petsDetailWalkLongestAndDuration.
  ///
  /// In it, this message translates to:
  /// **'Più lunga · Più duratura'**
  String get petsDetailWalkLongestAndDuration;

  /// No description provided for @petsDetailWalkStatusActive.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata in corso · {distance} · {elapsed}'**
  String petsDetailWalkStatusActive(String distance, String elapsed);

  /// No description provided for @petsDetailWalkStatusPaused.
  ///
  /// In it, this message translates to:
  /// **'In pausa · {distance} · {elapsed}'**
  String petsDetailWalkStatusPaused(String distance, String elapsed);

  /// No description provided for @petsDetailWalkUnfavoriteTitle.
  ///
  /// In it, this message translates to:
  /// **'Togliere dai preferiti?'**
  String get petsDetailWalkUnfavoriteTitle;

  /// No description provided for @petsDetailWalkUnfavoriteMessage.
  ///
  /// In it, this message translates to:
  /// **'Se non è anche il record o tra le ultime 3 passeggiate, potrà perdere la mappa alla prossima pulizia automatica.'**
  String get petsDetailWalkUnfavoriteMessage;

  /// No description provided for @petsDetailWalkUnfavoriteConfirm.
  ///
  /// In it, this message translates to:
  /// **'Togli dai preferiti'**
  String get petsDetailWalkUnfavoriteConfirm;

  /// No description provided for @petsDetailWalkDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa passeggiata?'**
  String get petsDetailWalkDeleteTitle;

  /// No description provided for @petsDetailWalkDeleteMessage.
  ///
  /// In it, this message translates to:
  /// **'La passeggiata del {date} ({distance}) verrà eliminata definitivamente.'**
  String petsDetailWalkDeleteMessage(String date, String distance);

  /// No description provided for @petsDetailWalkSteps.
  ///
  /// In it, this message translates to:
  /// **'~{count} passi'**
  String petsDetailWalkSteps(int count);

  /// No description provided for @petsDetailUnsyncedBanner.
  ///
  /// In it, this message translates to:
  /// **'Non sincronizzato: le modifiche sono solo su questo telefono.'**
  String get petsDetailUnsyncedBanner;

  /// No description provided for @petsDetailUnsyncedRetryFailed.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessun collegamento al server. Riprova più tardi.'**
  String get petsDetailUnsyncedRetryFailed;

  /// No description provided for @petsScaffoldBadge.
  ///
  /// In it, this message translates to:
  /// **'Pet'**
  String get petsScaffoldBadge;

  /// No description provided for @petsLoadingDefaultLabel.
  ///
  /// In it, this message translates to:
  /// **'Caricamento pet...'**
  String get petsLoadingDefaultLabel;

  /// No description provided for @petsLoadingSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Attendi un istante mentre prepariamo la schermata.'**
  String get petsLoadingSubtitle;

  /// No description provided for @petsDemoDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare il profilo. Riprova.'**
  String get petsDemoDeleteFailed;

  /// No description provided for @petsDemoNewProfileNote.
  ///
  /// In it, this message translates to:
  /// **'Profilo creato da poco, pronto per la prossima visita.'**
  String get petsDemoNewProfileNote;

  /// No description provided for @petsDemoNextVisitToPlan.
  ///
  /// In it, this message translates to:
  /// **'Da pianificare'**
  String get petsDemoNextVisitToPlan;

  /// No description provided for @petsValueSpeciesDog.
  ///
  /// In it, this message translates to:
  /// **'Cane'**
  String get petsValueSpeciesDog;

  /// No description provided for @petsValueSpeciesCat.
  ///
  /// In it, this message translates to:
  /// **'Gatto'**
  String get petsValueSpeciesCat;

  /// No description provided for @petsValueSpeciesSmallMammals.
  ///
  /// In it, this message translates to:
  /// **'Piccoli mammiferi'**
  String get petsValueSpeciesSmallMammals;

  /// No description provided for @petsValueSpeciesBird.
  ///
  /// In it, this message translates to:
  /// **'Uccello'**
  String get petsValueSpeciesBird;

  /// No description provided for @petsValueSpeciesReptiles.
  ///
  /// In it, this message translates to:
  /// **'Rettili e anfibi'**
  String get petsValueSpeciesReptiles;

  /// No description provided for @petsValueSpeciesFish.
  ///
  /// In it, this message translates to:
  /// **'Pesce'**
  String get petsValueSpeciesFish;

  /// No description provided for @petsValueSpeciesOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get petsValueSpeciesOther;

  /// No description provided for @petsValueSpeciesAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get petsValueSpeciesAll;

  /// No description provided for @petsValueSexMale.
  ///
  /// In it, this message translates to:
  /// **'Maschio'**
  String get petsValueSexMale;

  /// No description provided for @petsValueSexFemale.
  ///
  /// In it, this message translates to:
  /// **'Femmina'**
  String get petsValueSexFemale;

  /// No description provided for @petsValueSexMaleIntact.
  ///
  /// In it, this message translates to:
  /// **'Maschio intero'**
  String get petsValueSexMaleIntact;

  /// No description provided for @petsValueSexMaleNeutered.
  ///
  /// In it, this message translates to:
  /// **'Maschio castrato'**
  String get petsValueSexMaleNeutered;

  /// No description provided for @petsValueSexFemaleIntact.
  ///
  /// In it, this message translates to:
  /// **'Femmina intera'**
  String get petsValueSexFemaleIntact;

  /// No description provided for @petsValueSexFemaleSpayed.
  ///
  /// In it, this message translates to:
  /// **'Femmina sterilizzata'**
  String get petsValueSexFemaleSpayed;

  /// No description provided for @petsValueDogSizeToy.
  ///
  /// In it, this message translates to:
  /// **'Toy'**
  String get petsValueDogSizeToy;

  /// No description provided for @petsValueDogSizeSmall.
  ///
  /// In it, this message translates to:
  /// **'Piccola'**
  String get petsValueDogSizeSmall;

  /// No description provided for @petsValueDogSizeMedium.
  ///
  /// In it, this message translates to:
  /// **'Media'**
  String get petsValueDogSizeMedium;

  /// No description provided for @petsValueDogSizeLarge.
  ///
  /// In it, this message translates to:
  /// **'Grande'**
  String get petsValueDogSizeLarge;

  /// No description provided for @petsValueDogSizeGiant.
  ///
  /// In it, this message translates to:
  /// **'Gigante'**
  String get petsValueDogSizeGiant;

  /// No description provided for @petsListTitle.
  ///
  /// In it, this message translates to:
  /// **'Animali'**
  String get petsListTitle;

  /// No description provided for @petsListMemoriesTooltip.
  ///
  /// In it, this message translates to:
  /// **'Ricordi'**
  String get petsListMemoriesTooltip;

  /// No description provided for @petsListLoading.
  ///
  /// In it, this message translates to:
  /// **'Carico la lista pet...'**
  String get petsListLoading;

  /// No description provided for @petsListErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Pet non disponibili'**
  String get petsListErrorTitle;

  /// No description provided for @petsListErrorDefault.
  ///
  /// In it, this message translates to:
  /// **'Al momento non riesco a caricare i profili pet.'**
  String get petsListErrorDefault;

  /// No description provided for @petsListEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun pet ancora'**
  String get petsListEmptyTitle;

  /// No description provided for @petsListEmptySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Crea il primo profilo per tenere sotto controllo salute, note e scadenze.'**
  String get petsListEmptySubtitle;

  /// No description provided for @petsListEmptyAction.
  ///
  /// In it, this message translates to:
  /// **'Crea pet'**
  String get petsListEmptyAction;

  /// No description provided for @petsListFilterEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun pet per questo filtro.'**
  String get petsListFilterEmpty;

  /// No description provided for @petsMemoriesRemoveTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere definitivamente?'**
  String get petsMemoriesRemoveTitle;

  /// No description provided for @petsMemoriesRemoveBody.
  ///
  /// In it, this message translates to:
  /// **'Il ricordo di \"{name}\" verrà eliminato, senza possibilità di recupero.'**
  String petsMemoriesRemoveBody(String name);

  /// No description provided for @petsMemoriesRemoveConfirm.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get petsMemoriesRemoveConfirm;

  /// No description provided for @petsMemoriesTitle.
  ///
  /// In it, this message translates to:
  /// **'Ricordi'**
  String get petsMemoriesTitle;

  /// No description provided for @petsMemoriesSubtitle.
  ///
  /// In it, this message translates to:
  /// **'I profili dei pet che hanno condiviso la vostra strada.'**
  String get petsMemoriesSubtitle;

  /// No description provided for @petsMemoriesEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun ricordo conservato ancora.'**
  String get petsMemoriesEmpty;

  /// No description provided for @petsMemoriesWithUsUntil.
  ///
  /// In it, this message translates to:
  /// **'Con noi fino al {date}'**
  String petsMemoriesWithUsUntil(String date);

  /// No description provided for @petsMemoriesWithUsRange.
  ///
  /// In it, this message translates to:
  /// **'Con noi dal {from} al {to}'**
  String petsMemoriesWithUsRange(String from, String to);

  /// No description provided for @petsMemoriesComingSoon.
  ///
  /// In it, this message translates to:
  /// **'Presto: i vostri momenti più belli insieme, come le passeggiate più lunghe o i traguardi raggiunti, raccolti qui.'**
  String get petsMemoriesComingSoon;

  /// No description provided for @petsMediaGalleryTitle.
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get petsMediaGalleryTitle;

  /// No description provided for @petsMediaFoldersLoading.
  ///
  /// In it, this message translates to:
  /// **'Carico le cartelle…'**
  String get petsMediaFoldersLoading;

  /// No description provided for @petsMediaFoldersEmpty.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un animale per creare la sua cartella di foto.'**
  String get petsMediaFoldersEmpty;

  /// No description provided for @petsMediaFolderCounting.
  ///
  /// In it, this message translates to:
  /// **'Conto le foto…'**
  String get petsMediaFolderCounting;

  /// No description provided for @petsMediaCountPhotos.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, other{{count} foto}}'**
  String petsMediaCountPhotos(int count);

  /// No description provided for @petsMediaCountVideos.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, other{{count} video}}'**
  String petsMediaCountVideos(int count);

  /// No description provided for @petsMediaCountPhotosAndVideos.
  ///
  /// In it, this message translates to:
  /// **'{photos} · {videos}'**
  String petsMediaCountPhotosAndVideos(String photos, String videos);

  /// No description provided for @petsMediaVideoSemantics.
  ///
  /// In it, this message translates to:
  /// **'Video'**
  String get petsMediaVideoSemantics;

  /// No description provided for @petsMediaDeleteVideoTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questo video?'**
  String get petsMediaDeleteVideoTitle;

  /// No description provided for @petsMediaDeletePhotoTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa foto?'**
  String get petsMediaDeletePhotoTitle;

  /// No description provided for @petsMediaDeleteVideoBody.
  ///
  /// In it, this message translates to:
  /// **'Il video verrà rimosso definitivamente dalla galleria.'**
  String get petsMediaDeleteVideoBody;

  /// No description provided for @petsMediaDeletePhotoBody.
  ///
  /// In it, this message translates to:
  /// **'La foto verrà rimossa definitivamente dalla galleria.'**
  String get petsMediaDeletePhotoBody;

  /// No description provided for @petsMediaOperationFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a completare l\'operazione. Riprova.'**
  String get petsMediaOperationFailed;

  /// No description provided for @petsMediaSetAsProfile.
  ///
  /// In it, this message translates to:
  /// **'Imposta come foto profilo'**
  String get petsMediaSetAsProfile;

  /// No description provided for @petsMediaDeleteVideoAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina video'**
  String get petsMediaDeleteVideoAction;

  /// No description provided for @petsMediaDeletePhotoAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina foto'**
  String get petsMediaDeletePhotoAction;

  /// No description provided for @petsMediaImportFromGallery.
  ///
  /// In it, this message translates to:
  /// **'Importa dalla galleria'**
  String get petsMediaImportFromGallery;

  /// No description provided for @petsMediaImportFromGalleryHint.
  ///
  /// In it, this message translates to:
  /// **'Foto e video, anche più di uno'**
  String get petsMediaImportFromGalleryHint;

  /// No description provided for @petsMediaTakePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta foto'**
  String get petsMediaTakePhoto;

  /// No description provided for @petsMediaRecordVideo.
  ///
  /// In it, this message translates to:
  /// **'Registra video'**
  String get petsMediaRecordVideo;

  /// No description provided for @petsMediaRecordVideoLimit.
  ///
  /// In it, this message translates to:
  /// **'Fino a {seconds} secondi'**
  String petsMediaRecordVideoLimit(int seconds);

  /// No description provided for @petsMediaGalleryOf.
  ///
  /// In it, this message translates to:
  /// **'Galleria di {name}'**
  String petsMediaGalleryOf(String name);

  /// No description provided for @petsMediaGalleryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna foto o video ancora. Usa il pulsante \"Aggiungi\" qui sotto.'**
  String get petsMediaGalleryEmpty;

  /// No description provided for @petsMediaVideoPlaybackFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a riprodurre questo video.'**
  String get petsMediaVideoPlaybackFailed;

  /// No description provided for @petsMediaVideoLoading.
  ///
  /// In it, this message translates to:
  /// **'Carico il video...'**
  String get petsMediaVideoLoading;

  /// No description provided for @petsMediaCancelling.
  ///
  /// In it, this message translates to:
  /// **'Annullo...'**
  String get petsMediaCancelling;

  /// No description provided for @petsMediaPreparingFile.
  ///
  /// In it, this message translates to:
  /// **'Preparo il file...'**
  String get petsMediaPreparingFile;

  /// No description provided for @petsMediaPreparingFiles.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Preparo il file...} other{Preparo {count} file...}}'**
  String petsMediaPreparingFiles(int count);

  /// No description provided for @petsMediaUploadingFile.
  ///
  /// In it, this message translates to:
  /// **'Carico il file...'**
  String get petsMediaUploadingFile;

  /// No description provided for @petsMediaUploadingProgress.
  ///
  /// In it, this message translates to:
  /// **'Carico {current} di {total}...'**
  String petsMediaUploadingProgress(int current, int total);

  /// No description provided for @petsMediaUploadingVideo.
  ///
  /// In it, this message translates to:
  /// **'Carico il video...'**
  String get petsMediaUploadingVideo;

  /// No description provided for @petsMediaUploadingVideoOf.
  ///
  /// In it, this message translates to:
  /// **'Carico il video {current} di {total}...'**
  String petsMediaUploadingVideoOf(int current, int total);

  /// No description provided for @petsMediaReducingVideo.
  ///
  /// In it, this message translates to:
  /// **'Riduco il video... {percent}%'**
  String petsMediaReducingVideo(int percent);

  /// No description provided for @petsMediaReducingVideoOf.
  ///
  /// In it, this message translates to:
  /// **'Riduco il video {current} di {total}... {percent}%'**
  String petsMediaReducingVideoOf(int current, int total, int percent);

  /// No description provided for @petsMediaImportJoin.
  ///
  /// In it, this message translates to:
  /// **'{first} e {second}'**
  String petsMediaImportJoin(String first, String second);

  /// No description provided for @petsMediaImportDone.
  ///
  /// In it, this message translates to:
  /// **'Caricati: {list}'**
  String petsMediaImportDone(String list);

  /// No description provided for @petsMediaImportCancelled.
  ///
  /// In it, this message translates to:
  /// **'Caricamento annullato.'**
  String get petsMediaImportCancelled;

  /// No description provided for @petsMediaImportCancelledWith.
  ///
  /// In it, this message translates to:
  /// **'Caricamento annullato. {done}.'**
  String petsMediaImportCancelledWith(String done);

  /// No description provided for @petsMediaImportNothingToAdd.
  ///
  /// In it, this message translates to:
  /// **'Niente da aggiungere.'**
  String get petsMediaImportNothingToAdd;

  /// No description provided for @petsMediaImportProblemMore.
  ///
  /// In it, this message translates to:
  /// **'{problem} (altri {count} non aggiunti)'**
  String petsMediaImportProblemMore(String problem, int count);

  /// No description provided for @petsMediaImportDoneWithProblem.
  ///
  /// In it, this message translates to:
  /// **'{done}. {problem}'**
  String petsMediaImportDoneWithProblem(String done, String problem);

  /// No description provided for @petsMediaPhotoAddedTo.
  ///
  /// In it, this message translates to:
  /// **'Foto aggiunta alla galleria di {name}'**
  String petsMediaPhotoAddedTo(String name);

  /// No description provided for @petsMediaVideoAddedTo.
  ///
  /// In it, this message translates to:
  /// **'Video aggiunto alla galleria di {name}'**
  String petsMediaVideoAddedTo(String name);

  /// No description provided for @petsMediaImportFileFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare {file}.'**
  String petsMediaImportFileFailed(String file);

  /// No description provided for @petsMediaImportUnnamedFile.
  ///
  /// In it, this message translates to:
  /// **'un file'**
  String get petsMediaImportUnnamedFile;

  /// No description provided for @petsMediaPhotoSaveOffline.
  ///
  /// In it, this message translates to:
  /// **'Il salvataggio delle foto non è disponibile senza connessione.'**
  String get petsMediaPhotoSaveOffline;

  /// No description provided for @petsMediaVideoSaveOffline.
  ///
  /// In it, this message translates to:
  /// **'Il salvataggio dei video non è disponibile senza connessione.'**
  String get petsMediaVideoSaveOffline;

  /// No description provided for @petsMediaImportRefused.
  ///
  /// In it, this message translates to:
  /// **'{file}: {message}'**
  String petsMediaImportRefused(String file, String message);

  /// No description provided for @petsMediaVideoUnsupportedFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato video non supportato: usa un file MP4 o MOV.'**
  String get petsMediaVideoUnsupportedFormat;

  /// No description provided for @petsMediaVideoTooBigSource.
  ///
  /// In it, this message translates to:
  /// **'Video troppo pesante ({size} MB): il massimo è {max} MB.'**
  String petsMediaVideoTooBigSource(int size, int max);

  /// No description provided for @petsMediaVideoTooBigBrowser.
  ///
  /// In it, this message translates to:
  /// **'Video troppo pesante ({size} MB): dal browser il massimo è {max} MB. Dall\'app sul telefono i video vengono ridotti in automatico.'**
  String petsMediaVideoTooBigBrowser(int size, int max);

  /// No description provided for @petsMediaVideoUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere questo video.'**
  String get petsMediaVideoUnreadable;

  /// No description provided for @petsMediaVideoTooLong.
  ///
  /// In it, this message translates to:
  /// **'Video troppo lungo: il massimo è {seconds} secondi.'**
  String petsMediaVideoTooLong(int seconds);

  /// No description provided for @petsMediaVideoTooBigReduced.
  ///
  /// In it, this message translates to:
  /// **'Anche ridotto il video pesa {size} MB (massimo {max} MB): prova con un clip più breve.'**
  String petsMediaVideoTooBigReduced(int size, int max);

  /// No description provided for @petsMediaVideoTooBigNotReduced.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a ridurre il video e pesa {size} MB (massimo {max} MB): prova con un clip più breve.'**
  String petsMediaVideoTooBigNotReduced(int size, int max);

  /// No description provided for @petsConsentSemanticsExpanded.
  ///
  /// In it, this message translates to:
  /// **'Consenso alla lettura della cartella clinica di {name}. Tocca per chiudere il testo completo'**
  String petsConsentSemanticsExpanded(String name);

  /// No description provided for @petsConsentSemanticsCollapsed.
  ///
  /// In it, this message translates to:
  /// **'Consenso alla lettura della cartella clinica di {name}. Tocca per leggere il testo completo'**
  String petsConsentSemanticsCollapsed(String name);

  /// No description provided for @petsConsentCardTitle.
  ///
  /// In it, this message translates to:
  /// **'Cartella clinica di {name}'**
  String petsConsentCardTitle(String name);

  /// No description provided for @petsConsentReadHow.
  ///
  /// In it, this message translates to:
  /// **'Leggi come viene usata'**
  String get petsConsentReadHow;

  /// No description provided for @petsConsentSwitchSemantics.
  ///
  /// In it, this message translates to:
  /// **'Consenti all\'assistente di leggere la cartella clinica di {name}'**
  String petsConsentSwitchSemantics(String name);

  /// No description provided for @petsConsentWithoutConsent.
  ///
  /// In it, this message translates to:
  /// **'Senza consenso l\'assistente non vede né i titoli né il contenuto dei referti.'**
  String get petsConsentWithoutConsent;

  /// No description provided for @petsConsentSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare il consenso. Riprova.'**
  String get petsConsentSaveFailed;

  /// No description provided for @petsConsentStatusUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Stato del consenso non disponibile: controlla la connessione.'**
  String get petsConsentStatusUnavailable;

  /// No description provided for @petsConsentSlowConnection.
  ///
  /// In it, this message translates to:
  /// **'Connessione lenta. Il consenso non è stato salvato, riprova.'**
  String get petsConsentSlowConnection;

  /// No description provided for @petsConsentOffline.
  ///
  /// In it, this message translates to:
  /// **'Sei offline: il consenso non è stato salvato. Riprova con la connessione.'**
  String get petsConsentOffline;

  /// No description provided for @placesDetailBarrierFence.
  ///
  /// In it, this message translates to:
  /// **'Recintata'**
  String get placesDetailBarrierFence;

  /// No description provided for @placesDetailBarrierWall.
  ///
  /// In it, this message translates to:
  /// **'Recintata da un muro'**
  String get placesDetailBarrierWall;

  /// No description provided for @placesDetailBarrierHedge.
  ///
  /// In it, this message translates to:
  /// **'Delimitata da una siepe'**
  String get placesDetailBarrierHedge;

  /// No description provided for @placesDetailSurfaceGrass.
  ///
  /// In it, this message translates to:
  /// **'Fondo in erba'**
  String get placesDetailSurfaceGrass;

  /// No description provided for @placesDetailSurfaceGround.
  ///
  /// In it, this message translates to:
  /// **'Fondo in terra'**
  String get placesDetailSurfaceGround;

  /// No description provided for @placesDetailSurfaceSand.
  ///
  /// In it, this message translates to:
  /// **'Fondo in sabbia'**
  String get placesDetailSurfaceSand;

  /// No description provided for @placesDetailSurfaceGravel.
  ///
  /// In it, this message translates to:
  /// **'Fondo in ghiaia'**
  String get placesDetailSurfaceGravel;

  /// No description provided for @placesDetailSurfaceAsphalt.
  ///
  /// In it, this message translates to:
  /// **'Fondo asfaltato'**
  String get placesDetailSurfaceAsphalt;

  /// No description provided for @placesDetailSurfacePaved.
  ///
  /// In it, this message translates to:
  /// **'Fondo pavimentato'**
  String get placesDetailSurfacePaved;

  /// No description provided for @placesDetailAccessFree.
  ///
  /// In it, this message translates to:
  /// **'Accesso libero'**
  String get placesDetailAccessFree;

  /// No description provided for @placesDetailAccessPermissive.
  ///
  /// In it, this message translates to:
  /// **'Accesso consentito'**
  String get placesDetailAccessPermissive;

  /// No description provided for @placesDetailAccessCustomers.
  ///
  /// In it, this message translates to:
  /// **'Solo per i clienti'**
  String get placesDetailAccessCustomers;

  /// No description provided for @placesDetailAccessPrivate.
  ///
  /// In it, this message translates to:
  /// **'Area privata'**
  String get placesDetailAccessPrivate;

  /// No description provided for @placesDetailWheelchairYes.
  ///
  /// In it, this message translates to:
  /// **'Accessibile in sedia a rotelle'**
  String get placesDetailWheelchairYes;

  /// No description provided for @placesDetailWheelchairLimited.
  ///
  /// In it, this message translates to:
  /// **'Accessibilità parziale in sedia a rotelle'**
  String get placesDetailWheelchairLimited;

  /// No description provided for @placesDetailWheelchairNo.
  ///
  /// In it, this message translates to:
  /// **'Non accessibile in sedia a rotelle'**
  String get placesDetailWheelchairNo;

  /// No description provided for @placesDetailDrinkingWaterYes.
  ///
  /// In it, this message translates to:
  /// **'Acqua potabile'**
  String get placesDetailDrinkingWaterYes;

  /// No description provided for @placesDetailDrinkingWaterNo.
  ///
  /// In it, this message translates to:
  /// **'Senza acqua potabile'**
  String get placesDetailDrinkingWaterNo;

  /// No description provided for @placesDetailLitYes.
  ///
  /// In it, this message translates to:
  /// **'Illuminata'**
  String get placesDetailLitYes;

  /// No description provided for @placesDetailLitNo.
  ///
  /// In it, this message translates to:
  /// **'Non illuminata'**
  String get placesDetailLitNo;

  /// No description provided for @placesDetailDogUnleashed.
  ///
  /// In it, this message translates to:
  /// **'Cani liberi senza guinzaglio'**
  String get placesDetailDogUnleashed;

  /// No description provided for @placesDetailAdoptionYes.
  ///
  /// In it, this message translates to:
  /// **'Adozioni possibili'**
  String get placesDetailAdoptionYes;

  /// No description provided for @placesDetailAdoptionNo.
  ///
  /// In it, this message translates to:
  /// **'Non dà in adozione'**
  String get placesDetailAdoptionNo;

  /// No description provided for @placesPendingDogPark.
  ///
  /// In it, this message translates to:
  /// **'Segnalata dagli utenti, verifica che sia un’area pubblica ({progress})'**
  String placesPendingDogPark(String progress);

  /// No description provided for @placesPendingPlace.
  ///
  /// In it, this message translates to:
  /// **'Segnalato dagli utenti · in attesa di conferma ({progress})'**
  String placesPendingPlace(String progress);

  /// No description provided for @placesMailRemoveSubject.
  ///
  /// In it, this message translates to:
  /// **'Area cani da rimuovere dal radar ({id})'**
  String placesMailRemoveSubject(String id);

  /// No description provided for @placesMailRemoveBody.
  ///
  /// In it, this message translates to:
  /// **'Questa area segnalata dagli utenti non è un’area cani pubblica.\n\nNome: {name}\nPosizione: {position}\nIdentificativo: {id}\n\nMotivo: '**
  String placesMailRemoveBody(String name, String position, String id);

  /// No description provided for @placesWithdrawTitle.
  ///
  /// In it, this message translates to:
  /// **'Ritirare la segnalazione?'**
  String get placesWithdrawTitle;

  /// No description provided for @placesWithdrawBody.
  ///
  /// In it, this message translates to:
  /// **'La segnalazione viene cancellata e non sarà più visibile a nessuno.'**
  String get placesWithdrawBody;

  /// No description provided for @placesWithdrawConfirm.
  ///
  /// In it, this message translates to:
  /// **'Ritira'**
  String get placesWithdrawConfirm;

  /// No description provided for @placesWithdrawnSnack.
  ///
  /// In it, this message translates to:
  /// **'Segnalazione ritirata.'**
  String get placesWithdrawnSnack;

  /// No description provided for @placesVoteConfirmedSnack.
  ///
  /// In it, this message translates to:
  /// **'Grazie, conferma registrata.'**
  String get placesVoteConfirmedSnack;

  /// No description provided for @placesVoteDeniedSnack.
  ///
  /// In it, this message translates to:
  /// **'Grazie, registrato.'**
  String get placesVoteDeniedSnack;

  /// No description provided for @placesRatedSnack.
  ///
  /// In it, this message translates to:
  /// **'Voto registrato: {stars} su 5.'**
  String placesRatedSnack(int stars);

  /// No description provided for @placesReportsInactiveSnack.
  ///
  /// In it, this message translates to:
  /// **'Le segnalazioni non sono attive in questo momento.'**
  String get placesReportsInactiveSnack;

  /// No description provided for @placesReportProblemTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa non va in questo luogo?'**
  String get placesReportProblemTitle;

  /// No description provided for @placesReportAlreadyKnown.
  ///
  /// In it, this message translates to:
  /// **'Era già stato segnalato: la tua segnalazione vale come conferma.'**
  String get placesReportAlreadyKnown;

  /// No description provided for @placesReportSent.
  ///
  /// In it, this message translates to:
  /// **'Segnalazione inviata. Sarà applicata quando altri utenti la confermano.'**
  String get placesReportSent;

  /// No description provided for @placesSheetPendingQuestion.
  ///
  /// In it, this message translates to:
  /// **'Questo luogo esiste davvero qui?'**
  String get placesSheetPendingQuestion;

  /// No description provided for @placesSheetNotPublicWrite.
  ///
  /// In it, this message translates to:
  /// **'Non è un’area pubblica? Scrivici'**
  String get placesSheetNotPublicWrite;

  /// No description provided for @placesSheetClosedReported.
  ///
  /// In it, this message translates to:
  /// **'Segnalato come chiuso ({progress})'**
  String placesSheetClosedReported(String progress);

  /// No description provided for @placesSheetClosedQuestion.
  ///
  /// In it, this message translates to:
  /// **'Ha chiuso davvero?'**
  String get placesSheetClosedQuestion;

  /// No description provided for @placesSheetOpeningHours.
  ///
  /// In it, this message translates to:
  /// **'Orari indicati: {hours}'**
  String placesSheetOpeningHours(String hours);

  /// No description provided for @placesActionCall.
  ///
  /// In it, this message translates to:
  /// **'Chiama'**
  String get placesActionCall;

  /// No description provided for @placesActionDirections.
  ///
  /// In it, this message translates to:
  /// **'Indicazioni'**
  String get placesActionDirections;

  /// No description provided for @placesActionWebsite.
  ///
  /// In it, this message translates to:
  /// **'Sito web'**
  String get placesActionWebsite;

  /// No description provided for @placesDisclaimerCommunity.
  ///
  /// In it, this message translates to:
  /// **'Luogo segnalato dagli utenti: non è una garanzia, verifica prima di andarci.'**
  String get placesDisclaimerCommunity;

  /// No description provided for @placesDisclaimerClinic.
  ///
  /// In it, this message translates to:
  /// **'In caso di urgenza telefona prima di partire: orari e recapiti arrivano da archivi aperti e non sono verificati da VetApp.'**
  String get placesDisclaimerClinic;

  /// No description provided for @placesDisclaimerGeneric.
  ///
  /// In it, this message translates to:
  /// **'Orari e recapiti arrivano da archivi aperti e non sono verificati da VetApp.'**
  String get placesDisclaimerGeneric;

  /// No description provided for @placesSourceLine.
  ///
  /// In it, this message translates to:
  /// **'Fonte: {source}'**
  String placesSourceLine(String source);

  /// No description provided for @placesAlsoIn.
  ///
  /// In it, this message translates to:
  /// **'Presente anche in: {sources}'**
  String placesAlsoIn(String sources);

  /// No description provided for @placesReportProblemAction.
  ///
  /// In it, this message translates to:
  /// **'Segnala un problema'**
  String get placesReportProblemAction;

  /// No description provided for @placesBannerWithdrawing.
  ///
  /// In it, this message translates to:
  /// **'Ritiro la segnalazione…'**
  String get placesBannerWithdrawing;

  /// No description provided for @placesBannerYouReported.
  ///
  /// In it, this message translates to:
  /// **'L’hai segnalato tu: servono le conferme di altri utenti.'**
  String get placesBannerYouReported;

  /// No description provided for @placesBannerConfirmedSaving.
  ///
  /// In it, this message translates to:
  /// **'Hai confermato. Salvataggio…'**
  String get placesBannerConfirmedSaving;

  /// No description provided for @placesBannerConfirmedChange.
  ///
  /// In it, this message translates to:
  /// **'Hai confermato. Puoi cambiare idea.'**
  String get placesBannerConfirmedChange;

  /// No description provided for @placesBannerDeniedSaving.
  ///
  /// In it, this message translates to:
  /// **'Hai indicato che non è così. Salvataggio…'**
  String get placesBannerDeniedSaving;

  /// No description provided for @placesBannerDeniedChange.
  ///
  /// In it, this message translates to:
  /// **'Hai indicato che non è così. Puoi cambiare idea.'**
  String get placesBannerDeniedChange;

  /// No description provided for @placesBannerWithdrawButton.
  ///
  /// In it, this message translates to:
  /// **'Ritira la mia segnalazione'**
  String get placesBannerWithdrawButton;

  /// No description provided for @placesBannerConfirm.
  ///
  /// In it, this message translates to:
  /// **'Confermo'**
  String get placesBannerConfirm;

  /// No description provided for @placesBannerDeny.
  ///
  /// In it, this message translates to:
  /// **'Non è così'**
  String get placesBannerDeny;

  /// No description provided for @placesVotesCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 voto} other{{count} voti}}'**
  String placesVotesCount(int count);

  /// No description provided for @placesRatingAverage.
  ///
  /// In it, this message translates to:
  /// **'Voto della community: {average} su 5 · {votes}'**
  String placesRatingAverage(String average, String votes);

  /// No description provided for @placesRatingNone.
  ///
  /// In it, this message translates to:
  /// **'Voto della community: nessun voto ancora'**
  String get placesRatingNone;

  /// No description provided for @placesRatingBelowThreshold.
  ///
  /// In it, this message translates to:
  /// **'Voto della community: {votes} · la media compare da 3 voti'**
  String placesRatingBelowThreshold(String votes);

  /// No description provided for @placesRateStarTooltip.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Dai 1 stella} other{Dai {count} stelle}}'**
  String placesRateStarTooltip(int count);

  /// No description provided for @placesRatingSaving.
  ///
  /// In it, this message translates to:
  /// **'Il tuo voto: {stars} su 5. Salvataggio…'**
  String placesRatingSaving(int stars);

  /// No description provided for @placesRatingYours.
  ///
  /// In it, this message translates to:
  /// **'Il tuo voto: {stars} su 5. Tocca una stella per cambiarlo.'**
  String placesRatingYours(int stars);

  /// No description provided for @placesRatingPrompt.
  ///
  /// In it, this message translates to:
  /// **'Com’è quest’area cani? Tocca una stella per dare il tuo voto.'**
  String get placesRatingPrompt;

  /// No description provided for @placesExpiryToday.
  ///
  /// In it, this message translates to:
  /// **'Scade oggi se nessuno conferma.'**
  String get placesExpiryToday;

  /// No description provided for @placesExpiryDays.
  ///
  /// In it, this message translates to:
  /// **'{days, plural, =1{Scade tra 1 giorno se nessuno conferma.} other{Scade tra {days} giorni se nessuno conferma.}}'**
  String placesExpiryDays(int days);

  /// No description provided for @placesProblemClosed.
  ///
  /// In it, this message translates to:
  /// **'Ha chiuso o non esiste più'**
  String get placesProblemClosed;

  /// No description provided for @placesProblemDuplicate.
  ///
  /// In it, this message translates to:
  /// **'È un doppione di un altro luogo'**
  String get placesProblemDuplicate;

  /// No description provided for @placesProblemWrongPosition.
  ///
  /// In it, this message translates to:
  /// **'La posizione è sbagliata'**
  String get placesProblemWrongPosition;

  /// No description provided for @placesCategoryVeterinary.
  ///
  /// In it, this message translates to:
  /// **'Veterinari'**
  String get placesCategoryVeterinary;

  /// No description provided for @placesCategoryShop.
  ///
  /// In it, this message translates to:
  /// **'Negozi'**
  String get placesCategoryShop;

  /// No description provided for @placesCategoryDogPark.
  ///
  /// In it, this message translates to:
  /// **'Aree cani'**
  String get placesCategoryDogPark;

  /// No description provided for @placesCategoryShelter.
  ///
  /// In it, this message translates to:
  /// **'Rifugi e adozioni'**
  String get placesCategoryShelter;

  /// No description provided for @placesCategoryAssociation.
  ///
  /// In it, this message translates to:
  /// **'Associazioni'**
  String get placesCategoryAssociation;

  /// No description provided for @placesCategoryGrooming.
  ///
  /// In it, this message translates to:
  /// **'Toelettature'**
  String get placesCategoryGrooming;

  /// No description provided for @placesCategoryHotel.
  ///
  /// In it, this message translates to:
  /// **'Pensioni'**
  String get placesCategoryHotel;

  /// No description provided for @placesCategorySchool.
  ///
  /// In it, this message translates to:
  /// **'Addestramento'**
  String get placesCategorySchool;

  /// No description provided for @placesCategoryPetSitting.
  ///
  /// In it, this message translates to:
  /// **'Pet sitter'**
  String get placesCategoryPetSitting;

  /// No description provided for @placesCategoryBreeder.
  ///
  /// In it, this message translates to:
  /// **'Allevamenti'**
  String get placesCategoryBreeder;

  /// No description provided for @placesCategoryOther.
  ///
  /// In it, this message translates to:
  /// **'Altri servizi'**
  String get placesCategoryOther;

  /// No description provided for @placesTypeVeterinary.
  ///
  /// In it, this message translates to:
  /// **'Veterinario'**
  String get placesTypeVeterinary;

  /// No description provided for @placesTypeGrooming.
  ///
  /// In it, this message translates to:
  /// **'Toelettatura'**
  String get placesTypeGrooming;

  /// No description provided for @placesTypeShop.
  ///
  /// In it, this message translates to:
  /// **'Negozio per animali'**
  String get placesTypeShop;

  /// No description provided for @placesTypeSchool.
  ///
  /// In it, this message translates to:
  /// **'Addestramento'**
  String get placesTypeSchool;

  /// No description provided for @placesTypePetSitting.
  ///
  /// In it, this message translates to:
  /// **'Pet sitter'**
  String get placesTypePetSitting;

  /// No description provided for @placesTypeBreeder.
  ///
  /// In it, this message translates to:
  /// **'Allevamento'**
  String get placesTypeBreeder;

  /// No description provided for @placesTypeHotel.
  ///
  /// In it, this message translates to:
  /// **'Pensione per animali'**
  String get placesTypeHotel;

  /// No description provided for @placesTypeDogPark.
  ///
  /// In it, this message translates to:
  /// **'Area cani'**
  String get placesTypeDogPark;

  /// No description provided for @placesTypeShelter.
  ///
  /// In it, this message translates to:
  /// **'Rifugio per animali'**
  String get placesTypeShelter;

  /// No description provided for @placesTypeAssociation.
  ///
  /// In it, this message translates to:
  /// **'Associazione per animali'**
  String get placesTypeAssociation;

  /// No description provided for @placesTypeOther.
  ///
  /// In it, this message translates to:
  /// **'Servizio per animali'**
  String get placesTypeOther;

  /// No description provided for @placesHours247.
  ///
  /// In it, this message translates to:
  /// **'Indicato come aperto 24 ore su 24'**
  String get placesHours247;

  /// No description provided for @placesHoursHolidays.
  ///
  /// In it, this message translates to:
  /// **'Festivi'**
  String get placesHoursHolidays;

  /// No description provided for @placesHoursClosed.
  ///
  /// In it, this message translates to:
  /// **'chiuso'**
  String get placesHoursClosed;

  /// No description provided for @placesSourcesTitle.
  ///
  /// In it, this message translates to:
  /// **'Fonti dati'**
  String get placesSourcesTitle;

  /// No description provided for @placesSourcesIntro.
  ///
  /// In it, this message translates to:
  /// **'I luoghi del radar arrivano da archivi aperti, non da VetApp. Ogni scheda indica la sua fonte. Orari e recapiti possono non essere aggiornati.'**
  String get placesSourcesIntro;

  /// No description provided for @placesSourcesNoContact.
  ///
  /// In it, this message translates to:
  /// **'Hai trovato un dato sbagliato? Usa \"Segnala un problema\" nella scheda del luogo.'**
  String get placesSourcesNoContact;

  /// No description provided for @placesSourcesContact.
  ///
  /// In it, this message translates to:
  /// **'Hai trovato un dato sbagliato, o sei il titolare e vuoi che una scheda venga corretta o rimossa? Scrivi a {email}.'**
  String placesSourcesContact(String email);

  /// No description provided for @placesSourceLicense.
  ///
  /// In it, this message translates to:
  /// **'Licenza: {license}'**
  String placesSourceLicense(String license);

  /// No description provided for @placesSourceVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione {release}, importata il {date}'**
  String placesSourceVersion(String release, String date);

  /// No description provided for @placesSourceLicenseLink.
  ///
  /// In it, this message translates to:
  /// **'Licenza e condizioni'**
  String get placesSourceLicenseLink;

  /// No description provided for @placesSourceOsmDescription.
  ///
  /// In it, this message translates to:
  /// **'Mappa libera curata da volontari. Fonte delle aree cani e di parte di veterinari, negozi e altri servizi, con i dettagli che i volontari hanno indicato.'**
  String get placesSourceOsmDescription;

  /// No description provided for @placesSourceOvertureDescription.
  ///
  /// In it, this message translates to:
  /// **'Archivio aperto di attività commerciali. Fonte di veterinari, toelettature, negozi, pensioni e addestratori che OpenStreetMap non conosce.'**
  String get placesSourceOvertureDescription;

  /// No description provided for @placesSourceBolognaDescription.
  ///
  /// In it, this message translates to:
  /// **'Elenco ufficiale delle aree di sgambatura per cani del Comune di Bologna.'**
  String get placesSourceBolognaDescription;

  /// No description provided for @placesSourceTorinoDescription.
  ///
  /// In it, this message translates to:
  /// **'Elenco ufficiale delle aree cani della Città di Torino.'**
  String get placesSourceTorinoDescription;

  /// No description provided for @placesSourceMilanoDescription.
  ///
  /// In it, this message translates to:
  /// **'Elenco ufficiale delle aree cani del Comune di Milano.'**
  String get placesSourceMilanoDescription;

  /// No description provided for @placesSourceBolognaAttribution.
  ///
  /// In it, this message translates to:
  /// **'Comune di Bologna, Aree sgambatura cani (opendata.comune.bologna.it), licenza CC BY 4.0'**
  String get placesSourceBolognaAttribution;

  /// No description provided for @placesSourceTorinoAttribution.
  ///
  /// In it, this message translates to:
  /// **'Comune di Torino, Aree Cani (aperto.comune.torino.it), licenza CC BY 4.0, dati del 2019'**
  String get placesSourceTorinoAttribution;

  /// No description provided for @placesSourceMilanoAttribution.
  ///
  /// In it, this message translates to:
  /// **'Comune di Milano, Territorio: localizzazione delle aree cani (dati.comune.milano.it), licenza CC BY 4.0. Contiene elaborazioni di dati CC BY 3.0 da dati.gov.it'**
  String get placesSourceMilanoAttribution;

  /// No description provided for @placesSourceLicenseCcBy.
  ///
  /// In it, this message translates to:
  /// **'Creative Commons Attribuzione 4.0 (CC BY 4.0)'**
  String get placesSourceLicenseCcBy;

  /// No description provided for @placesSourceUsersName.
  ///
  /// In it, this message translates to:
  /// **'Utenti VetApp'**
  String get placesSourceUsersName;

  /// No description provided for @placesSourceUsersDescription.
  ///
  /// In it, this message translates to:
  /// **'Luoghi segnalati dagli utenti e confermati da altri utenti.'**
  String get placesSourceUsersDescription;

  /// No description provided for @placesSourceUsersAttribution.
  ///
  /// In it, this message translates to:
  /// **'Segnalato dagli utenti VetApp'**
  String get placesSourceUsersAttribution;

  /// No description provided for @placesMapTitle.
  ///
  /// In it, this message translates to:
  /// **'Mappa · {radius}'**
  String placesMapTitle(String radius);

  /// No description provided for @placesMapClusterSemantics.
  ///
  /// In it, this message translates to:
  /// **'{count} luoghi vicini tra loro'**
  String placesMapClusterSemantics(int count);

  /// No description provided for @placesMapMarkerPending.
  ///
  /// In it, this message translates to:
  /// **'{category}, in attesa di conferma: {label}'**
  String placesMapMarkerPending(String category, String label);

  /// No description provided for @placesMapMarker.
  ///
  /// In it, this message translates to:
  /// **'{category}: {label}'**
  String placesMapMarker(String category, String label);

  /// No description provided for @placesReportTitle.
  ///
  /// In it, this message translates to:
  /// **'Segnala un luogo mancante'**
  String get placesReportTitle;

  /// No description provided for @placesReportUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Le segnalazioni non sono disponibili in questo momento. Riprova più tardi.'**
  String get placesReportUnavailable;

  /// No description provided for @placesReportWhatIs.
  ///
  /// In it, this message translates to:
  /// **'Che cos’è?'**
  String get placesReportWhatIs;

  /// No description provided for @placesReportNameOptional.
  ///
  /// In it, this message translates to:
  /// **'Nome (facoltativo)'**
  String get placesReportNameOptional;

  /// No description provided for @placesReportNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome sull’insegna'**
  String get placesReportNameLabel;

  /// No description provided for @placesReportNameHelper.
  ///
  /// In it, this message translates to:
  /// **'Solo il nome: niente telefoni, indirizzi o nomi di persone.'**
  String get placesReportNameHelper;

  /// No description provided for @placesReportWhere.
  ///
  /// In it, this message translates to:
  /// **'Dove si trova?'**
  String get placesReportWhere;

  /// No description provided for @placesReportMapHint.
  ///
  /// In it, this message translates to:
  /// **'Sposta la mappa finché il segnaposto è sul luogo. L’indirizzo viene ricavato dalla posizione.'**
  String get placesReportMapHint;

  /// No description provided for @placesReportSubmit.
  ///
  /// In it, this message translates to:
  /// **'Invia segnalazione'**
  String get placesReportSubmit;

  /// No description provided for @placesReportFootnote.
  ///
  /// In it, this message translates to:
  /// **'La segnalazione sarà visibile a tutti come \"in attesa di conferma\" e diventerà definitiva quando altri utenti la confermano. Se entro {days} giorni nessuno la conferma, viene cancellata in automatico. Puoi ritirarla in ogni momento dalla sua scheda. Il tuo nome non compare.'**
  String placesReportFootnote(int days);

  /// No description provided for @placesReportSentExpiry.
  ///
  /// In it, this message translates to:
  /// **'Segnalazione inviata. Se entro {days} giorni nessuno la conferma, viene cancellata.'**
  String placesReportSentExpiry(int days);

  /// No description provided for @placesRulesTitle.
  ///
  /// In it, this message translates to:
  /// **'Prima di segnalare o votare'**
  String get placesRulesTitle;

  /// No description provided for @placesRulesCheckbox.
  ///
  /// In it, this message translates to:
  /// **'Ho letto le regole e segnalo o voto in buona fede.'**
  String get placesRulesCheckbox;

  /// No description provided for @placesRulesAccept.
  ///
  /// In it, this message translates to:
  /// **'Accetto'**
  String get placesRulesAccept;

  /// No description provided for @placesRulesFallback.
  ///
  /// In it, this message translates to:
  /// **'Segnala solo ciò che hai verificato di persona. Per le attività scrivi solo il nome dell’insegna, senza telefoni, indirizzi privati o dati di altre persone. Le segnalazioni restano in attesa finché altri utenti non le confermano. Segnalazioni false o ripetute possono portare alla sospensione dell’account. Segnalazioni e voti sono pubblicati senza il tuo nome.'**
  String get placesRulesFallback;

  /// No description provided for @placesErrSignedOutContribute.
  ///
  /// In it, this message translates to:
  /// **'Accedi per segnalare o votare.'**
  String get placesErrSignedOutContribute;

  /// No description provided for @placesErrOperationFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a completare l’operazione. Riprova.'**
  String get placesErrOperationFailed;

  /// No description provided for @placesErrTimeout.
  ///
  /// In it, this message translates to:
  /// **'La richiesta ha impiegato troppo tempo. Riprova.'**
  String get placesErrTimeout;

  /// No description provided for @placesErrNotConfigured.
  ///
  /// In it, this message translates to:
  /// **'Anteprima senza backend: i luoghi mostrati sono dati di esempio.'**
  String get placesErrNotConfigured;

  /// No description provided for @placesErrSignedOut.
  ///
  /// In it, this message translates to:
  /// **'Accedi per vedere i servizi per animali vicino a te.'**
  String get placesErrSignedOut;

  /// No description provided for @placesErrPreparing.
  ///
  /// In it, this message translates to:
  /// **'Sto ancora preparando i servizi di questa zona. Riprova tra poco.'**
  String get placesErrPreparing;

  /// No description provided for @placesErrSessionExpired.
  ///
  /// In it, this message translates to:
  /// **'La sessione non è più valida: esci e accedi di nuovo per vedere i servizi vicini.'**
  String get placesErrSessionExpired;

  /// No description provided for @placesErrLoadFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare i servizi vicini. Riprova.'**
  String get placesErrLoadFailed;

  /// No description provided for @placesBackendRulesRequired.
  ///
  /// In it, this message translates to:
  /// **'Per segnalare o votare accetta prima le regole per segnalazioni e voti.'**
  String get placesBackendRulesRequired;

  /// No description provided for @placesBackendReportClosed.
  ///
  /// In it, this message translates to:
  /// **'Questa segnalazione è già stata chiusa.'**
  String get placesBackendReportClosed;

  /// No description provided for @placesBackendReportExpired.
  ///
  /// In it, this message translates to:
  /// **'Questa segnalazione è scaduta: nessuno l\'ha confermata.'**
  String get placesBackendReportExpired;

  /// No description provided for @placesBackendOwnReportVote.
  ///
  /// In it, this message translates to:
  /// **'Non puoi confermare una tua segnalazione.'**
  String get placesBackendOwnReportVote;

  /// No description provided for @placesBackendKindNotActive.
  ///
  /// In it, this message translates to:
  /// **'Questo tipo di segnalazione non è attivo.'**
  String get placesBackendKindNotActive;

  /// No description provided for @placesBackendCategoryNotReportable.
  ///
  /// In it, this message translates to:
  /// **'Questa categoria non può essere segnalata.'**
  String get placesBackendCategoryNotReportable;

  /// No description provided for @placesBackendTargetRequired.
  ///
  /// In it, this message translates to:
  /// **'Indica il luogo a cui si riferisce la segnalazione.'**
  String get placesBackendTargetRequired;

  /// No description provided for @placesBackendPendingUseDeny.
  ///
  /// In it, this message translates to:
  /// **'Per un luogo in attesa di conferma usa \"Non è così\" sulla sua scheda.'**
  String get placesBackendPendingUseDeny;

  /// No description provided for @placesBackendAlreadyReported.
  ///
  /// In it, this message translates to:
  /// **'Hai già fatto questa segnalazione.'**
  String get placesBackendAlreadyReported;

  /// No description provided for @placesBackendDailyLimit.
  ///
  /// In it, this message translates to:
  /// **'Puoi fare al massimo {count} segnalazioni al giorno.'**
  String placesBackendDailyLimit(int count);

  /// No description provided for @placesBackendReportNotFound.
  ///
  /// In it, this message translates to:
  /// **'Segnalazione non trovata.'**
  String get placesBackendReportNotFound;

  /// No description provided for @placesBackendWithdrawOwnOnly.
  ///
  /// In it, this message translates to:
  /// **'Puoi ritirare solo una tua segnalazione.'**
  String get placesBackendWithdrawOwnOnly;

  /// No description provided for @placesBackendWithdrawClosed.
  ///
  /// In it, this message translates to:
  /// **'Questa segnalazione è già chiusa: non si può più ritirare.'**
  String get placesBackendWithdrawClosed;

  /// No description provided for @placesBackendRatingsOff.
  ///
  /// In it, this message translates to:
  /// **'Le valutazioni non sono attive.'**
  String get placesBackendRatingsOff;

  /// No description provided for @placesBackendRatePublicOnly.
  ///
  /// In it, this message translates to:
  /// **'Si possono valutare solo le aree cani pubbliche.'**
  String get placesBackendRatePublicOnly;

  /// No description provided for @placesBackendDogParkNotFound.
  ///
  /// In it, this message translates to:
  /// **'Area cani non trovata.'**
  String get placesBackendDogParkNotFound;

  /// No description provided for @placesBackendContributionsOff.
  ///
  /// In it, this message translates to:
  /// **'Segnalazioni e voti non sono ancora attivi.'**
  String get placesBackendContributionsOff;

  /// No description provided for @placesBackendNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi il nome dell\'attività, come appare sull\'insegna.'**
  String get placesBackendNameRequired;

  /// No description provided for @placesBackendNameTooLong.
  ///
  /// In it, this message translates to:
  /// **'Il nome può avere al massimo {count} caratteri.'**
  String placesBackendNameTooLong(int count);

  /// No description provided for @placesBackendNameNoContacts.
  ///
  /// In it, this message translates to:
  /// **'Nel nome non inserire telefoni, email o siti web.'**
  String get placesBackendNameNoContacts;

  /// No description provided for @placesBackendNameBlockedWords.
  ///
  /// In it, this message translates to:
  /// **'Il nome contiene parole non ammesse.'**
  String get placesBackendNameBlockedWords;

  /// No description provided for @eventsTitle.
  ///
  /// In it, this message translates to:
  /// **'Eventi'**
  String get eventsTitle;

  /// No description provided for @eventsSearching.
  ///
  /// In it, this message translates to:
  /// **'Cerco gli eventi...'**
  String get eventsSearching;

  /// No description provided for @eventsAllRegions.
  ///
  /// In it, this message translates to:
  /// **'Tutte le regioni'**
  String get eventsAllRegions;

  /// No description provided for @eventsAllTypes.
  ///
  /// In it, this message translates to:
  /// **'Tutti i tipi'**
  String get eventsAllTypes;

  /// No description provided for @eventsReset.
  ///
  /// In it, this message translates to:
  /// **'Reimposta'**
  String get eventsReset;

  /// No description provided for @eventsDisclaimer.
  ///
  /// In it, this message translates to:
  /// **'Date e luoghi possono cambiare: verifica sempre sul sito dell\'organizzatore.'**
  String get eventsDisclaimer;

  /// No description provided for @eventsPickRegionTitle.
  ///
  /// In it, this message translates to:
  /// **'Regione'**
  String get eventsPickRegionTitle;

  /// No description provided for @eventsPickTypeTitle.
  ///
  /// In it, this message translates to:
  /// **'Tipo di evento'**
  String get eventsPickTypeTitle;

  /// No description provided for @eventsPickDatesHelp.
  ///
  /// In it, this message translates to:
  /// **'Scegli il periodo'**
  String get eventsPickDatesHelp;

  /// No description provided for @eventsPickDatesSave.
  ///
  /// In it, this message translates to:
  /// **'Applica'**
  String get eventsPickDatesSave;

  /// No description provided for @eventsStatusCancelled.
  ///
  /// In it, this message translates to:
  /// **'Annullato'**
  String get eventsStatusCancelled;

  /// No description provided for @eventsStatusPostponed.
  ///
  /// In it, this message translates to:
  /// **'Rinviato'**
  String get eventsStatusPostponed;

  /// No description provided for @eventsOrganizedBy.
  ///
  /// In it, this message translates to:
  /// **'Organizzato da {name}'**
  String eventsOrganizedBy(String name);

  /// No description provided for @eventsSuggestAction.
  ///
  /// In it, this message translates to:
  /// **'Segnala un evento'**
  String get eventsSuggestAction;

  /// No description provided for @eventsSuggestTitle.
  ///
  /// In it, this message translates to:
  /// **'Segnala un evento'**
  String get eventsSuggestTitle;

  /// No description provided for @eventsSuggestIntro.
  ///
  /// In it, this message translates to:
  /// **'Conosci una fiera o un evento per animali che non trovi qui? Compila i dati: lo controlliamo sul sito dell\'organizzatore prima di pubblicarlo.'**
  String get eventsSuggestIntro;

  /// No description provided for @eventsSuggestPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Scrivi solo informazioni sull\'evento: niente nomi di persone, email o telefoni.'**
  String get eventsSuggestPrivacy;

  /// No description provided for @eventsSuggestFieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Nome dell\'evento'**
  String get eventsSuggestFieldTitle;

  /// No description provided for @eventsSuggestFieldType.
  ///
  /// In it, this message translates to:
  /// **'Tipo di evento'**
  String get eventsSuggestFieldType;

  /// No description provided for @eventsSuggestFieldDates.
  ///
  /// In it, this message translates to:
  /// **'Date'**
  String get eventsSuggestFieldDates;

  /// No description provided for @eventsSuggestPickDates.
  ///
  /// In it, this message translates to:
  /// **'Scegli le date'**
  String get eventsSuggestPickDates;

  /// No description provided for @eventsSuggestFieldCity.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get eventsSuggestFieldCity;

  /// No description provided for @eventsSuggestFieldProvince.
  ///
  /// In it, this message translates to:
  /// **'Provincia (sigla, es. MO)'**
  String get eventsSuggestFieldProvince;

  /// No description provided for @eventsSuggestFieldVenue.
  ///
  /// In it, this message translates to:
  /// **'Luogo, ad esempio la fiera (facoltativo)'**
  String get eventsSuggestFieldVenue;

  /// No description provided for @eventsSuggestFieldLink.
  ///
  /// In it, this message translates to:
  /// **'Link alla pagina dell\'evento'**
  String get eventsSuggestFieldLink;

  /// No description provided for @eventsSuggestRequired.
  ///
  /// In it, this message translates to:
  /// **'Campo obbligatorio'**
  String get eventsSuggestRequired;

  /// No description provided for @eventsSuggestInvalidLink.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un indirizzo che inizi con http:// o https://'**
  String get eventsSuggestInvalidLink;

  /// No description provided for @eventsSuggestInvalidProvince.
  ///
  /// In it, this message translates to:
  /// **'Usa la sigla di due lettere'**
  String get eventsSuggestInvalidProvince;

  /// No description provided for @eventsSuggestSend.
  ///
  /// In it, this message translates to:
  /// **'Invia segnalazione'**
  String get eventsSuggestSend;

  /// No description provided for @eventsSuggestThanks.
  ///
  /// In it, this message translates to:
  /// **'Grazie! Controlleremo l\'evento prima di pubblicarlo.'**
  String get eventsSuggestThanks;

  /// No description provided for @eventsSuggestNeedLogin.
  ///
  /// In it, this message translates to:
  /// **'Accedi per segnalare un evento.'**
  String get eventsSuggestNeedLogin;

  /// No description provided for @eventsSuggestLimit.
  ///
  /// In it, this message translates to:
  /// **'Hai già inviato le segnalazioni di oggi: riprova domani.'**
  String get eventsSuggestLimit;

  /// No description provided for @eventsSuggestError.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a inviare la segnalazione. Riprova più tardi.'**
  String get eventsSuggestError;

  /// No description provided for @eventsLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a caricare gli eventi. Controlla la connessione e riprova.'**
  String get eventsLoadError;

  /// No description provided for @eventsWindowDefault.
  ///
  /// In it, this message translates to:
  /// **'Prossimi {days} giorni'**
  String eventsWindowDefault(int days);

  /// No description provided for @eventsEmptyFiltered.
  ///
  /// In it, this message translates to:
  /// **'Nessun evento con questi filtri nel periodo scelto'**
  String get eventsEmptyFiltered;

  /// No description provided for @eventsEmptyDefault.
  ///
  /// In it, this message translates to:
  /// **'Nessun evento nei prossimi {days} giorni'**
  String eventsEmptyDefault(int days);

  /// No description provided for @eventsEmptyPeriod.
  ///
  /// In it, this message translates to:
  /// **'Nessun evento nel periodo scelto'**
  String get eventsEmptyPeriod;

  /// No description provided for @eventsCountryOnlyNote.
  ///
  /// In it, this message translates to:
  /// **'Mostriamo solo gli eventi del tuo paese, quello della lingua scelta nell\'app.'**
  String get eventsCountryOnlyNote;

  /// No description provided for @eventsLevelLocal.
  ///
  /// In it, this message translates to:
  /// **'Locale'**
  String get eventsLevelLocal;

  /// No description provided for @eventsLevelProvincial.
  ///
  /// In it, this message translates to:
  /// **'Provinciale'**
  String get eventsLevelProvincial;

  /// No description provided for @eventsLevelRegional.
  ///
  /// In it, this message translates to:
  /// **'Regionale'**
  String get eventsLevelRegional;

  /// No description provided for @eventsLevelNational.
  ///
  /// In it, this message translates to:
  /// **'Nazionale'**
  String get eventsLevelNational;

  /// No description provided for @eventsLevelInternational.
  ///
  /// In it, this message translates to:
  /// **'Internazionale'**
  String get eventsLevelInternational;

  /// No description provided for @eventsTypePetFair.
  ///
  /// In it, this message translates to:
  /// **'Fiera per animali'**
  String get eventsTypePetFair;

  /// No description provided for @eventsTypeDogShow.
  ///
  /// In it, this message translates to:
  /// **'Esposizione canina'**
  String get eventsTypeDogShow;

  /// No description provided for @eventsTypeBreedGathering.
  ///
  /// In it, this message translates to:
  /// **'Raduno di razza'**
  String get eventsTypeBreedGathering;

  /// No description provided for @eventsTypeCatShow.
  ///
  /// In it, this message translates to:
  /// **'Esposizione felina'**
  String get eventsTypeCatShow;

  /// No description provided for @eventsTypeWorkTrial.
  ///
  /// In it, this message translates to:
  /// **'Prova di lavoro'**
  String get eventsTypeWorkTrial;

  /// No description provided for @eventsTypeDogSport.
  ///
  /// In it, this message translates to:
  /// **'Sport cinofili'**
  String get eventsTypeDogSport;

  /// No description provided for @eventsTypeAdoptionDay.
  ///
  /// In it, this message translates to:
  /// **'Giornata di adozione'**
  String get eventsTypeAdoptionDay;

  /// No description provided for @eventsTypeShelterOpenDay.
  ///
  /// In it, this message translates to:
  /// **'Open day rifugio'**
  String get eventsTypeShelterOpenDay;

  /// No description provided for @eventsTypeMicrochipDay.
  ///
  /// In it, this message translates to:
  /// **'Microchip day'**
  String get eventsTypeMicrochipDay;

  /// No description provided for @eventsTypeVaccinationCampaign.
  ///
  /// In it, this message translates to:
  /// **'Campagna vaccinale'**
  String get eventsTypeVaccinationCampaign;

  /// No description provided for @eventsTypeGroupWalk.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata di gruppo'**
  String get eventsTypeGroupWalk;

  /// No description provided for @eventsTypeCourseSeminar.
  ///
  /// In it, this message translates to:
  /// **'Corso o seminario'**
  String get eventsTypeCourseSeminar;

  /// No description provided for @eventsTypeMarket.
  ///
  /// In it, this message translates to:
  /// **'Mercatino'**
  String get eventsTypeMarket;

  /// No description provided for @eventsTypeCharityEvent.
  ///
  /// In it, this message translates to:
  /// **'Evento benefico'**
  String get eventsTypeCharityEvent;

  /// No description provided for @eventsTypeAquariumExpo.
  ///
  /// In it, this message translates to:
  /// **'Acquariofilia'**
  String get eventsTypeAquariumExpo;

  /// No description provided for @eventsTypeReptileExpo.
  ///
  /// In it, this message translates to:
  /// **'Terraristica'**
  String get eventsTypeReptileExpo;

  /// No description provided for @eventsTypeBirdShow.
  ///
  /// In it, this message translates to:
  /// **'Ornitologia'**
  String get eventsTypeBirdShow;

  /// No description provided for @eventsTypeEquestrian.
  ///
  /// In it, this message translates to:
  /// **'Equestre'**
  String get eventsTypeEquestrian;

  /// No description provided for @eventsTypeOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get eventsTypeOther;

  /// No description provided for @localActivitiesKindEvent.
  ///
  /// In it, this message translates to:
  /// **'Evento'**
  String get localActivitiesKindEvent;

  /// No description provided for @localActivitiesKindService.
  ///
  /// In it, this message translates to:
  /// **'Servizio'**
  String get localActivitiesKindService;

  /// No description provided for @localEventsTitle.
  ///
  /// In it, this message translates to:
  /// **'Vicino a me'**
  String get localEventsTitle;

  /// No description provided for @localEventsLocating.
  ///
  /// In it, this message translates to:
  /// **'Cerco la tua posizione…'**
  String get localEventsLocating;

  /// No description provided for @localEventsSearchingAround.
  ///
  /// In it, this message translates to:
  /// **'Cerco cosa c’è attorno a te. La prima volta in una zona può richiedere fino a un minuto.'**
  String get localEventsSearchingAround;

  /// No description provided for @localEventsConsentTitle.
  ///
  /// In it, this message translates to:
  /// **'Usare la tua posizione?'**
  String get localEventsConsentTitle;

  /// No description provided for @localEventsConsentBody.
  ///
  /// In it, this message translates to:
  /// **'Per mostrarti cosa c’è vicino a te VetApp usa la posizione del telefono solo mentre usi l’app. In alternativa puoi indicare un indirizzo.'**
  String get localEventsConsentBody;

  /// No description provided for @localEventsConsentChooseAddress.
  ///
  /// In it, this message translates to:
  /// **'Scegli un indirizzo'**
  String get localEventsConsentChooseAddress;

  /// No description provided for @localEventsConsentAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get localEventsConsentAllow;

  /// No description provided for @localEventsReportMissing.
  ///
  /// In it, this message translates to:
  /// **'Segnala! Manca un luogo'**
  String get localEventsReportMissing;

  /// No description provided for @localEventsServicesHeader.
  ///
  /// In it, this message translates to:
  /// **'Servizi nella zona'**
  String get localEventsServicesHeader;

  /// No description provided for @localEventsClinicsHeader.
  ///
  /// In it, this message translates to:
  /// **'Cliniche e ambulatori'**
  String get localEventsClinicsHeader;

  /// No description provided for @localEventsNoClinics.
  ///
  /// In it, this message translates to:
  /// **'Nessuna clinica trovata con questi filtri.'**
  String get localEventsNoClinics;

  /// No description provided for @localEventsNoServices.
  ///
  /// In it, this message translates to:
  /// **'Nessun servizio trovato con questi filtri.'**
  String get localEventsNoServices;

  /// No description provided for @localEventsAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get localEventsAll;

  /// No description provided for @localEventsMapFullscreen.
  ///
  /// In it, this message translates to:
  /// **'Apri la mappa a tutto schermo'**
  String get localEventsMapFullscreen;

  /// No description provided for @localEventsNoLocationTitle.
  ///
  /// In it, this message translates to:
  /// **'Imposta una località'**
  String get localEventsNoLocationTitle;

  /// No description provided for @localEventsNoLocationBody.
  ///
  /// In it, this message translates to:
  /// **'Per mostrarti cosa c’è attorno a te serve la tua posizione. Consenti l’accesso alla posizione oppure indica la tua residenza in Impostazioni → Località.'**
  String get localEventsNoLocationBody;

  /// No description provided for @localEventsOpenSettings.
  ///
  /// In it, this message translates to:
  /// **'Apri Impostazioni'**
  String get localEventsOpenSettings;

  /// No description provided for @localEventsSearchingRadius.
  ///
  /// In it, this message translates to:
  /// **'Cerco i servizi entro {radius}. La prima volta in una zona può richiedere fino a un minuto.'**
  String localEventsSearchingRadius(String radius);

  /// No description provided for @localEventsSearchingNearby.
  ///
  /// In it, this message translates to:
  /// **'Cerco i servizi nella tua zona. La prima volta può richiedere qualche secondo.'**
  String get localEventsSearchingNearby;

  /// No description provided for @localEventsCoverageLimited.
  ///
  /// In it, this message translates to:
  /// **'I dati dei servizi per questa zona sono ancora in preparazione: potresti vedere pochi luoghi o aspettare di più.'**
  String get localEventsCoverageLimited;

  /// No description provided for @localEventsCoverageUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Il radar non copre ancora questo paese: vedi solo ciò che OpenStreetMap conosce, senza altri controlli.'**
  String get localEventsCoverageUnsupported;

  /// No description provided for @localEventsStale.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito ad aggiornare i servizi di questa zona: vedi gli ultimi dati disponibili, che potrebbero non essere recenti.'**
  String get localEventsStale;

  /// No description provided for @localEventsPartialRadius.
  ///
  /// In it, this message translates to:
  /// **'Per ora i servizi sono disponibili entro {radius}: riprova tra poco per il raggio completo.'**
  String localEventsPartialRadius(String radius);

  /// No description provided for @localEventsShowLess.
  ///
  /// In it, this message translates to:
  /// **'Mostra meno'**
  String get localEventsShowLess;

  /// No description provided for @localEventsShowAllCount.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutti ({count})'**
  String localEventsShowAllCount(int count);

  /// No description provided for @localEventsShowAllCategory.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutti: {category} ({count})'**
  String localEventsShowAllCategory(String category, int count);

  /// No description provided for @localEventsCategoryNone.
  ///
  /// In it, this message translates to:
  /// **'{category}: nessuno entro {radius}'**
  String localEventsCategoryNone(String category, String radius);

  /// No description provided for @localEventsCategoryCount.
  ///
  /// In it, this message translates to:
  /// **'{category} ({count})'**
  String localEventsCategoryCount(String category, int count);

  /// No description provided for @localEventsSectionExpand.
  ///
  /// In it, this message translates to:
  /// **'Apri {section}'**
  String localEventsSectionExpand(String section);

  /// No description provided for @localEventsSectionCollapse.
  ///
  /// In it, this message translates to:
  /// **'Chiudi {section}'**
  String localEventsSectionCollapse(String section);

  /// No description provided for @localEventsCallTooltip.
  ///
  /// In it, this message translates to:
  /// **'Chiama {name}'**
  String localEventsCallTooltip(String name);

  /// No description provided for @localEventsDirectionsTooltip.
  ///
  /// In it, this message translates to:
  /// **'Indicazioni per {name}'**
  String localEventsDirectionsTooltip(String name);

  /// No description provided for @remindersRelativeToday.
  ///
  /// In it, this message translates to:
  /// **'oggi'**
  String get remindersRelativeToday;

  /// No description provided for @remindersRelativeTomorrow.
  ///
  /// In it, this message translates to:
  /// **'domani'**
  String get remindersRelativeTomorrow;

  /// No description provided for @remindersRelativeYesterday.
  ///
  /// In it, this message translates to:
  /// **'ieri'**
  String get remindersRelativeYesterday;

  /// No description provided for @remindersRelativeInDays.
  ///
  /// In it, this message translates to:
  /// **'tra {days} giorni'**
  String remindersRelativeInDays(int days);

  /// No description provided for @remindersRelativeDaysAgo.
  ///
  /// In it, this message translates to:
  /// **'{days} giorni fa'**
  String remindersRelativeDaysAgo(int days);

  /// No description provided for @remindersKindEvent.
  ///
  /// In it, this message translates to:
  /// **'Evento'**
  String get remindersKindEvent;

  /// No description provided for @remindersKindRecurring.
  ///
  /// In it, this message translates to:
  /// **'Ricorrente · {interval}{end}'**
  String remindersKindRecurring(String interval, String end);

  /// No description provided for @remindersCourseStarts.
  ///
  /// In it, this message translates to:
  /// **'Inizia {day}'**
  String remindersCourseStarts(String day);

  /// No description provided for @remindersCourseCompleted.
  ///
  /// In it, this message translates to:
  /// **'Completato'**
  String get remindersCourseCompleted;

  /// No description provided for @remindersCourseDayOf.
  ///
  /// In it, this message translates to:
  /// **'Giorno {day} di {total}'**
  String remindersCourseDayOf(int day, int total);

  /// No description provided for @remindersKindCourse.
  ///
  /// In it, this message translates to:
  /// **'Ciclo · {days} giorni'**
  String remindersKindCourse(int days);

  /// No description provided for @remindersKindCourseWithTimes.
  ///
  /// In it, this message translates to:
  /// **'Ciclo · {days} giorni · {times}'**
  String remindersKindCourseWithTimes(int days, String times);

  /// No description provided for @remindersIntervalEveryDays.
  ///
  /// In it, this message translates to:
  /// **'ogni {value, plural, =1{1 giorno} other{{value} giorni}}'**
  String remindersIntervalEveryDays(int value);

  /// No description provided for @remindersIntervalEveryMonths.
  ///
  /// In it, this message translates to:
  /// **'ogni {value, plural, =1{1 mese} other{{value} mesi}}'**
  String remindersIntervalEveryMonths(int value);

  /// No description provided for @remindersEndAfterTimes.
  ///
  /// In it, this message translates to:
  /// **' · per {count, plural, =1{1 volta} other{{count} volte}}'**
  String remindersEndAfterTimes(int count);

  /// No description provided for @remindersEndUntilDate.
  ///
  /// In it, this message translates to:
  /// **' · fino al {date}'**
  String remindersEndUntilDate(String date);

  /// No description provided for @remindersMenuTooltip.
  ///
  /// In it, this message translates to:
  /// **'Opzioni promemoria'**
  String get remindersMenuTooltip;

  /// No description provided for @remindersMenuMarkDone.
  ///
  /// In it, this message translates to:
  /// **'Segna come fatto'**
  String get remindersMenuMarkDone;

  /// No description provided for @remindersDeleteConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questo promemoria?'**
  String get remindersDeleteConfirmTitle;

  /// No description provided for @remindersDeleteConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'\"{title}\" verrà eliminato definitivamente.'**
  String remindersDeleteConfirmBody(String title);

  /// No description provided for @remindersErrorPetNotSynced.
  ///
  /// In it, this message translates to:
  /// **'Il profilo dell\'animale non è sincronizzato sul server: sistemalo prima di creare promemoria.'**
  String get remindersErrorPetNotSynced;

  /// No description provided for @remindersErrorSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare il promemoria. Riprova.'**
  String get remindersErrorSaveFailed;

  /// No description provided for @remindersErrorDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare il promemoria. Riprova.'**
  String get remindersErrorDeleteFailed;

  /// No description provided for @petNewsTitle.
  ///
  /// In it, this message translates to:
  /// **'Notizie'**
  String get petNewsTitle;

  /// No description provided for @petNewsLoading.
  ///
  /// In it, this message translates to:
  /// **'Carico le News...'**
  String get petNewsLoading;

  /// No description provided for @petNewsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna notizia disponibile per questa categoria al momento.'**
  String get petNewsEmpty;

  /// No description provided for @petNewsEmptyLocal.
  ///
  /// In it, this message translates to:
  /// **'Per ora non ci sono notizie nella tua lingua e per il tuo paese. Non mostriamo notizie di altri paesi.'**
  String get petNewsEmptyLocal;

  /// No description provided for @petNewsCategoryAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get petNewsCategoryAll;

  /// No description provided for @petNewsCategoryDog.
  ///
  /// In it, this message translates to:
  /// **'Cane'**
  String get petNewsCategoryDog;

  /// No description provided for @petNewsCategoryCat.
  ///
  /// In it, this message translates to:
  /// **'Gatto'**
  String get petNewsCategoryCat;

  /// No description provided for @petNewsCategorySmallMammals.
  ///
  /// In it, this message translates to:
  /// **'Piccoli mammiferi'**
  String get petNewsCategorySmallMammals;

  /// No description provided for @petNewsCategoryBird.
  ///
  /// In it, this message translates to:
  /// **'Uccello'**
  String get petNewsCategoryBird;

  /// No description provided for @petNewsCategoryReptiles.
  ///
  /// In it, this message translates to:
  /// **'Rettili e anfibi'**
  String get petNewsCategoryReptiles;

  /// No description provided for @petNewsCategoryFish.
  ///
  /// In it, this message translates to:
  /// **'Pesce'**
  String get petNewsCategoryFish;

  /// No description provided for @petNewsCategoryOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get petNewsCategoryOther;

  /// No description provided for @petNewsCategoryGeneral.
  ///
  /// In it, this message translates to:
  /// **'Generale'**
  String get petNewsCategoryGeneral;

  /// No description provided for @profileLogoutDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get profileLogoutDialogTitle;

  /// No description provided for @profileLogoutDialogBody.
  ///
  /// In it, this message translates to:
  /// **'Vuoi disconnetterti da questo account?'**
  String get profileLogoutDialogBody;

  /// No description provided for @profileGuestName.
  ///
  /// In it, this message translates to:
  /// **'Ospite'**
  String get profileGuestName;

  /// No description provided for @profileNoActiveSession.
  ///
  /// In it, this message translates to:
  /// **'Nessuna sessione attiva'**
  String get profileNoActiveSession;

  /// No description provided for @profileSummaryBody.
  ///
  /// In it, this message translates to:
  /// **'Profilo owner collegato a {pets} e pronto per la web app responsive.'**
  String profileSummaryBody(String pets);

  /// No description provided for @profilePetCount.
  ///
  /// In it, this message translates to:
  /// **'{count} pet'**
  String profilePetCount(int count);

  /// No description provided for @profileContactsTitle.
  ///
  /// In it, this message translates to:
  /// **'Contatti'**
  String get profileContactsTitle;

  /// No description provided for @profileEmailLabel.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In it, this message translates to:
  /// **'Telefono'**
  String get profilePhoneLabel;

  /// No description provided for @profilePhoneNotSet.
  ///
  /// In it, this message translates to:
  /// **'Non specificato'**
  String get profilePhoneNotSet;

  /// No description provided for @profileCityLabel.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get profileCityLabel;

  /// No description provided for @profileCityNotSet.
  ///
  /// In it, this message translates to:
  /// **'Non specificata'**
  String get profileCityNotSet;

  /// No description provided for @profileEveningThemeTitle.
  ///
  /// In it, this message translates to:
  /// **'Tema serale'**
  String get profileEveningThemeTitle;

  /// No description provided for @profileEveningThemeBody.
  ///
  /// In it, this message translates to:
  /// **'Anteprima di una palette piu soft per l uso serale.'**
  String get profileEveningThemeBody;

  /// No description provided for @profileAccountStatusTitle.
  ///
  /// In it, this message translates to:
  /// **'Stato account'**
  String get profileAccountStatusTitle;

  /// No description provided for @profileSessionLabel.
  ///
  /// In it, this message translates to:
  /// **'Sessione'**
  String get profileSessionLabel;

  /// No description provided for @profileSessionActive.
  ///
  /// In it, this message translates to:
  /// **'Attiva'**
  String get profileSessionActive;

  /// No description provided for @profilePrivacyLabel.
  ///
  /// In it, this message translates to:
  /// **'Privacy'**
  String get profilePrivacyLabel;

  /// No description provided for @profilePrivacyUpdated.
  ///
  /// In it, this message translates to:
  /// **'Aggiornata'**
  String get profilePrivacyUpdated;

  /// No description provided for @profileSupportLabel.
  ///
  /// In it, this message translates to:
  /// **'Supporto'**
  String get profileSupportLabel;

  /// No description provided for @profileSupportAvailable.
  ///
  /// In it, this message translates to:
  /// **'Disponibile'**
  String get profileSupportAvailable;

  /// No description provided for @profileSettingsButton.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get profileSettingsButton;

  /// No description provided for @profileLogoutButton.
  ///
  /// In it, this message translates to:
  /// **'Logout'**
  String get profileLogoutButton;

  /// No description provided for @profileTitle.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get profileTitle;

  /// No description provided for @profileIntro.
  ///
  /// In it, this message translates to:
  /// **'Dati owner, preferenze e dettagli account in un unico posto per la web app responsive.'**
  String get profileIntro;

  /// No description provided for @profileRoadmapTitle.
  ///
  /// In it, this message translates to:
  /// **'Prossimi step'**
  String get profileRoadmapTitle;

  /// No description provided for @profileRoadmapBody.
  ///
  /// In it, this message translates to:
  /// **'Qui possiamo far evolvere consensi, preferenze e collegamento account senza cambiare il flusso web.'**
  String get profileRoadmapBody;

  /// No description provided for @activitiesTitle.
  ///
  /// In it, this message translates to:
  /// **'Attività'**
  String get activitiesTitle;

  /// No description provided for @activitiesSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tutto quello che ruota attorno alla vita con i tuoi animali.'**
  String get activitiesSubtitle;

  /// No description provided for @activitiesNewsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Curiosità e attualità sugli animali domestici.'**
  String get activitiesNewsSubtitle;

  /// No description provided for @activitiesNearbyTitle.
  ///
  /// In it, this message translates to:
  /// **'Vicino a me'**
  String get activitiesNearbyTitle;

  /// No description provided for @activitiesNearbySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Veterinari, negozi e aree cani vicino a te.'**
  String get activitiesNearbySubtitle;

  /// No description provided for @activitiesEventsTitle.
  ///
  /// In it, this message translates to:
  /// **'Eventi'**
  String get activitiesEventsTitle;

  /// No description provided for @activitiesEventsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Fiere, esposizioni e iniziative per animali in tutta Italia.'**
  String get activitiesEventsSubtitle;

  /// No description provided for @activitiesGalleryTitle.
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get activitiesGalleryTitle;

  /// No description provided for @activitiesGallerySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Raccogli foto e ricordi dei tuoi animali.'**
  String get activitiesGallerySubtitle;

  /// No description provided for @activitiesMarketplaceTitle.
  ///
  /// In it, this message translates to:
  /// **'Mercatino dell\'usato'**
  String get activitiesMarketplaceTitle;

  /// No description provided for @activitiesMarketplaceSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Compra, vendi e scambia articoli per animali.'**
  String get activitiesMarketplaceSubtitle;

  /// No description provided for @activitiesPetFriendTitle.
  ///
  /// In it, this message translates to:
  /// **'Pet friend'**
  String get activitiesPetFriendTitle;

  /// No description provided for @activitiesPetFriendSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Incontri e compagnia tra animali e proprietari.'**
  String get activitiesPetFriendSubtitle;

  /// No description provided for @activitiesComingSoonBadge.
  ///
  /// In it, this message translates to:
  /// **'In arrivo'**
  String get activitiesComingSoonBadge;

  /// No description provided for @activitiesPetFriendDescription.
  ///
  /// In it, this message translates to:
  /// **'Incontra altri proprietari e organizza uscite tra animali con affinità simili.'**
  String get activitiesPetFriendDescription;

  /// No description provided for @remindersTitle.
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get remindersTitle;

  /// No description provided for @remindersSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Vaccini, trattamenti e visite da tenere sotto controllo.'**
  String get remindersSubtitle;

  /// No description provided for @remindersCreateButton.
  ///
  /// In it, this message translates to:
  /// **'Crea'**
  String get remindersCreateButton;

  /// No description provided for @remindersLoadingTitle.
  ///
  /// In it, this message translates to:
  /// **'Caricamento promemoria'**
  String get remindersLoadingTitle;

  /// No description provided for @remindersLoadingBody.
  ///
  /// In it, this message translates to:
  /// **'Sto leggendo date, ricorrenze e note del proprietario.'**
  String get remindersLoadingBody;

  /// No description provided for @remindersSyncErrorLabel.
  ///
  /// In it, this message translates to:
  /// **'Errore sync'**
  String get remindersSyncErrorLabel;

  /// No description provided for @remindersSyncErrorTitle.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione promemoria fallita.'**
  String get remindersSyncErrorTitle;

  /// No description provided for @remindersSyncErrorBody.
  ///
  /// In it, this message translates to:
  /// **'La sorgente demo e ancora disponibile. Riprova quando la rete torna su.'**
  String get remindersSyncErrorBody;

  /// No description provided for @remindersEmptyLabel.
  ///
  /// In it, this message translates to:
  /// **'Nessun promemoria'**
  String get remindersEmptyLabel;

  /// No description provided for @remindersEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'La lista dei promemoria e vuota.'**
  String get remindersEmptyTitle;

  /// No description provided for @remindersEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Crea il primo promemoria per vaccino o trattamento e resta in carreggiata.'**
  String get remindersEmptyBody;

  /// No description provided for @remindersNoMatchForFilters.
  ///
  /// In it, this message translates to:
  /// **'Nessun promemoria per questi filtri.'**
  String get remindersNoMatchForFilters;

  /// No description provided for @remindersFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get remindersFilterAll;

  /// No description provided for @remindersFilterEvents.
  ///
  /// In it, this message translates to:
  /// **'Eventi'**
  String get remindersFilterEvents;

  /// No description provided for @remindersFilterCourses.
  ///
  /// In it, this message translates to:
  /// **'Cicli'**
  String get remindersFilterCourses;

  /// No description provided for @remindersViewList.
  ///
  /// In it, this message translates to:
  /// **'Lista'**
  String get remindersViewList;

  /// No description provided for @remindersViewCalendar.
  ///
  /// In it, this message translates to:
  /// **'Calendario'**
  String get remindersViewCalendar;

  /// No description provided for @remindersNothingThisDay.
  ///
  /// In it, this message translates to:
  /// **'Nessuna attività in questo giorno.'**
  String get remindersNothingThisDay;

  /// No description provided for @remindersTodayCapitalized.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get remindersTodayCapitalized;

  /// No description provided for @remindersEditTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica promemoria'**
  String get remindersEditTitle;

  /// No description provided for @remindersEditSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna tipo, data e note.'**
  String get remindersEditSubtitle;

  /// No description provided for @remindersDosePickerHelp.
  ///
  /// In it, this message translates to:
  /// **'Orario della dose'**
  String get remindersDosePickerHelp;

  /// No description provided for @remindersDateRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci una data.'**
  String get remindersDateRequired;

  /// No description provided for @remindersDateInvalid.
  ///
  /// In it, this message translates to:
  /// **'Data non valida (gg/mm/aaaa).'**
  String get remindersDateInvalid;

  /// No description provided for @remindersFormKind.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get remindersFormKind;

  /// No description provided for @remindersFormTitleLabel.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get remindersFormTitleLabel;

  /// No description provided for @remindersFormTitleHint.
  ///
  /// In it, this message translates to:
  /// **'Es. Richiamo vaccinale'**
  String get remindersFormTitleHint;

  /// No description provided for @remindersFormTitleHintWithPet.
  ///
  /// In it, this message translates to:
  /// **'Es. Richiamo vaccinale di {petName}'**
  String remindersFormTitleHintWithPet(String petName);

  /// No description provided for @remindersTitleRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un titolo.'**
  String get remindersTitleRequired;

  /// No description provided for @remindersFieldDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get remindersFieldDate;

  /// No description provided for @remindersFieldNextDue.
  ///
  /// In it, this message translates to:
  /// **'Prossima scadenza'**
  String get remindersFieldNextDue;

  /// No description provided for @remindersFieldStartDate.
  ///
  /// In it, this message translates to:
  /// **'Data di inizio'**
  String get remindersFieldStartDate;

  /// No description provided for @remindersFieldTime.
  ///
  /// In it, this message translates to:
  /// **'Ora'**
  String get remindersFieldTime;

  /// No description provided for @remindersRepeats.
  ///
  /// In it, this message translates to:
  /// **'Si ripete'**
  String get remindersRepeats;

  /// No description provided for @remindersCustomNumberHint.
  ///
  /// In it, this message translates to:
  /// **'Numero'**
  String get remindersCustomNumberHint;

  /// No description provided for @remindersRecurrenceEndLabel.
  ///
  /// In it, this message translates to:
  /// **'Fine ricorrenza'**
  String get remindersRecurrenceEndLabel;

  /// No description provided for @remindersOccurrenceCountHint.
  ///
  /// In it, this message translates to:
  /// **'Numero di volte'**
  String get remindersOccurrenceCountHint;

  /// No description provided for @remindersLastDate.
  ///
  /// In it, this message translates to:
  /// **'Ultima data'**
  String get remindersLastDate;

  /// No description provided for @remindersCourseDuration.
  ///
  /// In it, this message translates to:
  /// **'Durata del ciclo'**
  String get remindersCourseDuration;

  /// No description provided for @remindersDoseTimes.
  ///
  /// In it, this message translates to:
  /// **'Orari delle dosi'**
  String get remindersDoseTimes;

  /// No description provided for @remindersAddDoseTime.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi orario'**
  String get remindersAddDoseTime;

  /// No description provided for @remindersNoDoseTimesNote.
  ///
  /// In it, this message translates to:
  /// **'Senza orari ricevi un avviso al giorno, alle 9:00.'**
  String get remindersNoDoseTimesNote;

  /// No description provided for @remindersFormNote.
  ///
  /// In it, this message translates to:
  /// **'Nota'**
  String get remindersFormNote;

  /// No description provided for @remindersFormNoteHint.
  ///
  /// In it, this message translates to:
  /// **'Es. Porta il libretto sanitario'**
  String get remindersFormNoteHint;

  /// No description provided for @remindersKindOptionRecurring.
  ///
  /// In it, this message translates to:
  /// **'Ricorrente'**
  String get remindersKindOptionRecurring;

  /// No description provided for @remindersKindOptionCourse.
  ///
  /// In it, this message translates to:
  /// **'Ciclo'**
  String get remindersKindOptionCourse;

  /// No description provided for @remindersDatePlaceholder.
  ///
  /// In it, this message translates to:
  /// **'gg/mm/aaaa'**
  String get remindersDatePlaceholder;

  /// No description provided for @remindersPreset7Days.
  ///
  /// In it, this message translates to:
  /// **'7 gg'**
  String get remindersPreset7Days;

  /// No description provided for @remindersPreset30Days.
  ///
  /// In it, this message translates to:
  /// **'30 gg'**
  String get remindersPreset30Days;

  /// No description provided for @remindersPreset6Months.
  ///
  /// In it, this message translates to:
  /// **'6 mesi'**
  String get remindersPreset6Months;

  /// No description provided for @remindersPreset12Months.
  ///
  /// In it, this message translates to:
  /// **'12 mesi'**
  String get remindersPreset12Months;

  /// No description provided for @remindersPresetCustom.
  ///
  /// In it, this message translates to:
  /// **'Personalizzato'**
  String get remindersPresetCustom;

  /// No description provided for @remindersEndAlways.
  ///
  /// In it, this message translates to:
  /// **'Sempre'**
  String get remindersEndAlways;

  /// No description provided for @remindersEndAfterN.
  ///
  /// In it, this message translates to:
  /// **'Per N volte'**
  String get remindersEndAfterN;

  /// No description provided for @remindersEndUntil.
  ///
  /// In it, this message translates to:
  /// **'Fino a una data'**
  String get remindersEndUntil;

  /// No description provided for @remindersUnitDays.
  ///
  /// In it, this message translates to:
  /// **'Giorni'**
  String get remindersUnitDays;

  /// No description provided for @remindersUnitMonths.
  ///
  /// In it, this message translates to:
  /// **'Mesi'**
  String get remindersUnitMonths;

  /// No description provided for @remindersOneDayLess.
  ///
  /// In it, this message translates to:
  /// **'Un giorno in meno'**
  String get remindersOneDayLess;

  /// No description provided for @remindersDurationRange.
  ///
  /// In it, this message translates to:
  /// **'Da {min} a {max} giorni.'**
  String remindersDurationRange(int min, int max);

  /// No description provided for @remindersDurationUnit.
  ///
  /// In it, this message translates to:
  /// **'{days, plural, =1{giorno} other{giorni}}'**
  String remindersDurationUnit(int days);

  /// No description provided for @remindersOneDayMore.
  ///
  /// In it, this message translates to:
  /// **'Un giorno in più'**
  String get remindersOneDayMore;

  /// No description provided for @remindersNotFoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Promemoria non trovato'**
  String get remindersNotFoundTitle;

  /// No description provided for @remindersNotFoundSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Questo promemoria non è più disponibile.'**
  String get remindersNotFoundSubtitle;

  /// No description provided for @remindersNotFoundLabel.
  ///
  /// In it, this message translates to:
  /// **'Non trovato'**
  String get remindersNotFoundLabel;

  /// No description provided for @remindersNotFoundPanelTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun promemoria da mostrare.'**
  String get remindersNotFoundPanelTitle;

  /// No description provided for @remindersNotFoundBody.
  ///
  /// In it, this message translates to:
  /// **'Potrebbe essere stato eliminato o non essere ancora sincronizzato.'**
  String get remindersNotFoundBody;

  /// No description provided for @remindersBackToList.
  ///
  /// In it, this message translates to:
  /// **'Torna alla lista'**
  String get remindersBackToList;

  /// No description provided for @remindersDetailTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio promemoria'**
  String get remindersDetailTitle;

  /// No description provided for @remindersDetailSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tipo, data e nota del promemoria.'**
  String get remindersDetailSubtitle;

  /// No description provided for @remindersNoNote.
  ///
  /// In it, this message translates to:
  /// **'Nessuna nota aggiunta.'**
  String get remindersNoNote;

  /// No description provided for @remindersSummaryTitle.
  ///
  /// In it, this message translates to:
  /// **'Riepilogo promemoria'**
  String get remindersSummaryTitle;

  /// No description provided for @remindersSummaryPet.
  ///
  /// In it, this message translates to:
  /// **'Animale'**
  String get remindersSummaryPet;

  /// No description provided for @remindersSummaryStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get remindersSummaryStatus;

  /// No description provided for @remindersDeleteButton.
  ///
  /// In it, this message translates to:
  /// **'Elimina promemoria'**
  String get remindersDeleteButton;

  /// No description provided for @remindersLoadingLabel.
  ///
  /// In it, this message translates to:
  /// **'Caricamento'**
  String get remindersLoadingLabel;

  /// No description provided for @remindersWait.
  ///
  /// In it, this message translates to:
  /// **'Attendi'**
  String get remindersWait;

  /// No description provided for @remindersCreateTitle.
  ///
  /// In it, this message translates to:
  /// **'Crea promemoria'**
  String get remindersCreateTitle;

  /// No description provided for @remindersCreateTitleForPet.
  ///
  /// In it, this message translates to:
  /// **'Nuovo promemoria per {petName}'**
  String remindersCreateTitleForPet(String petName);

  /// No description provided for @remindersCreateSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli il tipo, la data e i dettagli.'**
  String get remindersCreateSubtitle;

  /// No description provided for @settingsUnitSystemMetricLabel.
  ///
  /// In it, this message translates to:
  /// **'Metrico'**
  String get settingsUnitSystemMetricLabel;

  /// No description provided for @settingsUnitSystemUkLabel.
  ///
  /// In it, this message translates to:
  /// **'Regno Unito'**
  String get settingsUnitSystemUkLabel;

  /// No description provided for @settingsUnitSystemUsLabel.
  ///
  /// In it, this message translates to:
  /// **'USA'**
  String get settingsUnitSystemUsLabel;

  /// No description provided for @settingsUnitSystemMetricDescription.
  ///
  /// In it, this message translates to:
  /// **'km, kg, °C, litri'**
  String get settingsUnitSystemMetricDescription;

  /// No description provided for @settingsUnitSystemUkDescription.
  ///
  /// In it, this message translates to:
  /// **'miglia, libbre, °C, litri'**
  String get settingsUnitSystemUkDescription;

  /// No description provided for @settingsUnitSystemUsDescription.
  ///
  /// In it, this message translates to:
  /// **'miglia, libbre, °F, galloni USA'**
  String get settingsUnitSystemUsDescription;

  /// No description provided for @settingsVolumeLiters.
  ///
  /// In it, this message translates to:
  /// **'{liters} litri'**
  String settingsVolumeLiters(int liters);

  /// No description provided for @settingsUnitLitersName.
  ///
  /// In it, this message translates to:
  /// **'litri'**
  String get settingsUnitLitersName;

  /// No description provided for @settingsTextSizeSmall.
  ///
  /// In it, this message translates to:
  /// **'Piccolo'**
  String get settingsTextSizeSmall;

  /// No description provided for @settingsTextSizeNormal.
  ///
  /// In it, this message translates to:
  /// **'Normale'**
  String get settingsTextSizeNormal;

  /// No description provided for @settingsTextSizeLarge.
  ///
  /// In it, this message translates to:
  /// **'Grande'**
  String get settingsTextSizeLarge;

  /// No description provided for @settingsTextSizeExtraLarge.
  ///
  /// In it, this message translates to:
  /// **'Molto grande'**
  String get settingsTextSizeExtraLarge;

  /// No description provided for @settingsLocationPickerTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli sulla mappa'**
  String get settingsLocationPickerTitle;

  /// No description provided for @settingsLocationPickerHint.
  ///
  /// In it, this message translates to:
  /// **'Sposta la mappa finché il segnaposto è sul punto giusto, poi conferma.'**
  String get settingsLocationPickerHint;

  /// No description provided for @settingsLocationPickerConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma questo punto'**
  String get settingsLocationPickerConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// No description provided for @settingsNumericDatePattern.
  ///
  /// In it, this message translates to:
  /// **'dd/MM/yyyy'**
  String get settingsNumericDatePattern;

  /// No description provided for @settingsGuestInitial.
  ///
  /// In it, this message translates to:
  /// **'O'**
  String get settingsGuestInitial;

  /// No description provided for @settingsGuestName.
  ///
  /// In it, this message translates to:
  /// **'Ospite'**
  String get settingsGuestName;

  /// No description provided for @settingsNoActiveSession.
  ///
  /// In it, this message translates to:
  /// **'Nessuna sessione attiva'**
  String get settingsNoActiveSession;

  /// No description provided for @settingsSectionSubscription.
  ///
  /// In it, this message translates to:
  /// **'Abbonamento'**
  String get settingsSectionSubscription;

  /// No description provided for @settingsSubscriptionAndPayments.
  ///
  /// In it, this message translates to:
  /// **'Abbonamento e pagamenti'**
  String get settingsSubscriptionAndPayments;

  /// No description provided for @settingsTrialExpiresOn.
  ///
  /// In it, this message translates to:
  /// **'Prova · scade il {date}'**
  String settingsTrialExpiresOn(String date);

  /// No description provided for @settingsSectionPushNotifications.
  ///
  /// In it, this message translates to:
  /// **'Notifiche push'**
  String get settingsSectionPushNotifications;

  /// No description provided for @settingsNotificationsToggle.
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get settingsNotificationsToggle;

  /// No description provided for @settingsSectionLayout.
  ///
  /// In it, this message translates to:
  /// **'Layout'**
  String get settingsSectionLayout;

  /// No description provided for @settingsLayoutWeeksTitle.
  ///
  /// In it, this message translates to:
  /// **'Settimane visualizzate in Home'**
  String get settingsLayoutWeeksTitle;

  /// No description provided for @settingsLayoutWeeksSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Quante settimane mostrare nel calendario della Home.'**
  String get settingsLayoutWeeksSubtitle;

  /// No description provided for @settingsLayoutWeekStartTitle.
  ///
  /// In it, this message translates to:
  /// **'Inizio settimana'**
  String get settingsLayoutWeekStartTitle;

  /// No description provided for @settingsLayoutChatTextSizeTitle.
  ///
  /// In it, this message translates to:
  /// **'Dimensione del testo in chat'**
  String get settingsLayoutChatTextSizeTitle;

  /// No description provided for @settingsLayoutChatTextSizePreview.
  ///
  /// In it, this message translates to:
  /// **'Così vedrai i messaggi della chat.'**
  String get settingsLayoutChatTextSizePreview;

  /// No description provided for @settingsLayoutUnitsTitle.
  ///
  /// In it, this message translates to:
  /// **'Unità di misura'**
  String get settingsLayoutUnitsTitle;

  /// No description provided for @settingsSectionPhotosVideos.
  ///
  /// In it, this message translates to:
  /// **'Foto e video'**
  String get settingsSectionPhotosVideos;

  /// No description provided for @settingsGallerySaveTitle.
  ///
  /// In it, this message translates to:
  /// **'Salva le foto nella galleria'**
  String get settingsGallerySaveTitle;

  /// No description provided for @settingsGallerySaveSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Le foto e i video scattati con la fotocamera dell\'app vengono copiati nell\'album \"VetApp\" del telefono.'**
  String get settingsGallerySaveSubtitle;

  /// No description provided for @settingsSectionLocation.
  ///
  /// In it, this message translates to:
  /// **'Località'**
  String get settingsSectionLocation;

  /// No description provided for @settingsLocationIntro.
  ///
  /// In it, this message translates to:
  /// **'Usata per personalizzare eventi e news in base alla zona.'**
  String get settingsLocationIntro;

  /// No description provided for @settingsLocationReferenceTitle.
  ///
  /// In it, this message translates to:
  /// **'Posizione di riferimento'**
  String get settingsLocationReferenceTitle;

  /// No description provided for @settingsLocationModeCurrent.
  ///
  /// In it, this message translates to:
  /// **'Attuale'**
  String get settingsLocationModeCurrent;

  /// No description provided for @settingsLocationModeHome.
  ///
  /// In it, this message translates to:
  /// **'Residenza'**
  String get settingsLocationModeHome;

  /// No description provided for @settingsLocationCurrentTitle.
  ///
  /// In it, this message translates to:
  /// **'Posizione attuale'**
  String get settingsLocationCurrentTitle;

  /// No description provided for @settingsLocationDetecting.
  ///
  /// In it, this message translates to:
  /// **'Rilevamento in corso…'**
  String get settingsLocationDetecting;

  /// No description provided for @settingsLocationCurrentNotSet.
  ///
  /// In it, this message translates to:
  /// **'Non ancora impostata'**
  String get settingsLocationCurrentNotSet;

  /// No description provided for @settingsLocationRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get settingsLocationRefresh;

  /// No description provided for @settingsLocationHomeTitle.
  ///
  /// In it, this message translates to:
  /// **'Residenza abituale'**
  String get settingsLocationHomeTitle;

  /// No description provided for @settingsLocationHomeNotSet.
  ///
  /// In it, this message translates to:
  /// **'Non impostata'**
  String get settingsLocationHomeNotSet;

  /// No description provided for @settingsLocationSet.
  ///
  /// In it, this message translates to:
  /// **'Imposta'**
  String get settingsLocationSet;

  /// No description provided for @settingsLocationErrorPermissionDenied.
  ///
  /// In it, this message translates to:
  /// **'Permesso di localizzazione negato: abilitalo dalle impostazioni del dispositivo per usare la posizione attuale.'**
  String get settingsLocationErrorPermissionDenied;

  /// No description provided for @settingsLocationErrorServiceDisabled.
  ///
  /// In it, this message translates to:
  /// **'La localizzazione è disattivata sul dispositivo.'**
  String get settingsLocationErrorServiceDisabled;

  /// No description provided for @settingsLocationErrorTimeout.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a rilevare la posizione in tempo, riprova.'**
  String get settingsLocationErrorTimeout;

  /// No description provided for @settingsLocationErrorUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Localizzazione non disponibile su questo dispositivo/browser.'**
  String get settingsLocationErrorUnsupported;

  /// No description provided for @settingsSectionPermissions.
  ///
  /// In it, this message translates to:
  /// **'Permessi e consensi'**
  String get settingsSectionPermissions;

  /// No description provided for @settingsConsentsUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Non disponibili al momento'**
  String get settingsConsentsUnavailable;

  /// No description provided for @settingsConsentsTapToRetry.
  ///
  /// In it, this message translates to:
  /// **'Tocca per riprovare'**
  String get settingsConsentsTapToRetry;

  /// No description provided for @settingsConsentTerms.
  ///
  /// In it, this message translates to:
  /// **'Termini di servizio'**
  String get settingsConsentTerms;

  /// No description provided for @settingsConsentPrivacy.
  ///
  /// In it, this message translates to:
  /// **'Informativa privacy'**
  String get settingsConsentPrivacy;

  /// No description provided for @settingsConsentMarketingEmail.
  ///
  /// In it, this message translates to:
  /// **'Email di marketing'**
  String get settingsConsentMarketingEmail;

  /// No description provided for @settingsConsentAnalytics.
  ///
  /// In it, this message translates to:
  /// **'Analisi d\'uso'**
  String get settingsConsentAnalytics;

  /// No description provided for @settingsConsentAccepted.
  ///
  /// In it, this message translates to:
  /// **'Accettati v{version} il {date}'**
  String settingsConsentAccepted(String version, String date);

  /// No description provided for @settingsConsentToConfirm.
  ///
  /// In it, this message translates to:
  /// **'Da confermare'**
  String get settingsConsentToConfirm;

  /// No description provided for @settingsClinicalConsentSection.
  ///
  /// In it, this message translates to:
  /// **'Cartella clinica e assistente'**
  String get settingsClinicalConsentSection;

  /// No description provided for @settingsPrivacyPolicyFullTitle.
  ///
  /// In it, this message translates to:
  /// **'Informativa privacy completa'**
  String get settingsPrivacyPolicyFullTitle;

  /// No description provided for @settingsPrivacyPolicyFullSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Leggi, scarica o condividi il testo'**
  String get settingsPrivacyPolicyFullSubtitle;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In it, this message translates to:
  /// **'Assistenza'**
  String get settingsSectionSupport;

  /// No description provided for @settingsHelpCenterTitle.
  ///
  /// In it, this message translates to:
  /// **'Centro assistenza'**
  String get settingsHelpCenterTitle;

  /// No description provided for @settingsHelpCenterComingSoon.
  ///
  /// In it, this message translates to:
  /// **'Domande frequenti e guide rapide, presto disponibili direttamente qui.'**
  String get settingsHelpCenterComingSoon;

  /// No description provided for @settingsContactUs.
  ///
  /// In it, this message translates to:
  /// **'Contattaci'**
  String get settingsContactUs;

  /// No description provided for @settingsContactUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Il contatto dell’assistenza non è disponibile in questo momento. Riprova più tardi.'**
  String get settingsContactUnavailable;

  /// No description provided for @settingsContactWriteTo.
  ///
  /// In it, this message translates to:
  /// **'Scrivi a {email} per qualsiasi domanda.'**
  String settingsContactWriteTo(String email);

  /// No description provided for @settingsRateApp.
  ///
  /// In it, this message translates to:
  /// **'Valuta l\'app'**
  String get settingsRateApp;

  /// No description provided for @settingsRateAppThanks.
  ///
  /// In it, this message translates to:
  /// **'Grazie per il supporto! ⭐'**
  String get settingsRateAppThanks;

  /// No description provided for @settingsSectionInfo.
  ///
  /// In it, this message translates to:
  /// **'Info'**
  String get settingsSectionInfo;

  /// No description provided for @settingsDataSourcesTitle.
  ///
  /// In it, this message translates to:
  /// **'Fonti dati'**
  String get settingsDataSourcesTitle;

  /// No description provided for @settingsDataSourcesSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Da dove arrivano i luoghi del radar'**
  String get settingsDataSourcesSubtitle;

  /// No description provided for @settingsAppVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione app'**
  String get settingsAppVersion;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsLogout.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'Vuoi disconnetterti da questo account?'**
  String get settingsLogoutConfirmBody;

  /// No description provided for @settingsHomeCountryDefault.
  ///
  /// In it, this message translates to:
  /// **'Italia'**
  String get settingsHomeCountryDefault;

  /// No description provided for @settingsHomeAddressNotFound.
  ///
  /// In it, this message translates to:
  /// **'Non trovo questo indirizzo. Controlla i dati e riprova.'**
  String get settingsHomeAddressNotFound;

  /// No description provided for @settingsHomeAddressOrType.
  ///
  /// In it, this message translates to:
  /// **'Oppure scrivi l\'indirizzo:'**
  String get settingsHomeAddressOrType;

  /// No description provided for @settingsHomeAddressStreet.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo'**
  String get settingsHomeAddressStreet;

  /// No description provided for @settingsHomeAddressStreetRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci l\'indirizzo'**
  String get settingsHomeAddressStreetRequired;

  /// No description provided for @settingsHomeAddressPostalCode.
  ///
  /// In it, this message translates to:
  /// **'CAP'**
  String get settingsHomeAddressPostalCode;

  /// No description provided for @settingsHomeAddressPostalCodeRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il CAP'**
  String get settingsHomeAddressPostalCodeRequired;

  /// No description provided for @settingsHomeAddressCity.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get settingsHomeAddressCity;

  /// No description provided for @settingsHomeAddressCityRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la città'**
  String get settingsHomeAddressCityRequired;

  /// No description provided for @settingsHomeAddressCountry.
  ///
  /// In it, this message translates to:
  /// **'Nazione'**
  String get settingsHomeAddressCountry;

  /// No description provided for @settingsHomeAddressCountryRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la nazione'**
  String get settingsHomeAddressCountryRequired;

  /// No description provided for @settingsHomeAddressSearching.
  ///
  /// In it, this message translates to:
  /// **'Ricerca…'**
  String get settingsHomeAddressSearching;

  /// No description provided for @notificationsCategoryReminders.
  ///
  /// In it, this message translates to:
  /// **'Visite e vaccini'**
  String get notificationsCategoryReminders;

  /// No description provided for @notificationsCategoryMedicines.
  ///
  /// In it, this message translates to:
  /// **'Orari dei farmaci'**
  String get notificationsCategoryMedicines;

  /// No description provided for @notificationsCategoryBirthdays.
  ///
  /// In it, this message translates to:
  /// **'Compleanni'**
  String get notificationsCategoryBirthdays;

  /// No description provided for @notificationsChannelRemindersName.
  ///
  /// In it, this message translates to:
  /// **'Promemoria'**
  String get notificationsChannelRemindersName;

  /// No description provided for @notificationsChannelRemindersDescription.
  ///
  /// In it, this message translates to:
  /// **'Visite, vaccini e altri promemoria'**
  String get notificationsChannelRemindersDescription;

  /// No description provided for @notificationsChannelMedicinesName.
  ///
  /// In it, this message translates to:
  /// **'Farmaci'**
  String get notificationsChannelMedicinesName;

  /// No description provided for @notificationsChannelBirthdaysDescription.
  ///
  /// In it, this message translates to:
  /// **'Compleanni degli animali'**
  String get notificationsChannelBirthdaysDescription;

  /// No description provided for @notificationsReminderTodayBody.
  ///
  /// In it, this message translates to:
  /// **'{petName} · oggi alle {time}'**
  String notificationsReminderTodayBody(String petName, String time);

  /// No description provided for @notificationsReminderTomorrowTitle.
  ///
  /// In it, this message translates to:
  /// **'Domani: {title}'**
  String notificationsReminderTomorrowTitle(String title);

  /// No description provided for @notificationsReminderTomorrowBody.
  ///
  /// In it, this message translates to:
  /// **'{petName} · alle {time}'**
  String notificationsReminderTomorrowBody(String petName, String time);

  /// No description provided for @notificationsMedicineTitle.
  ///
  /// In it, this message translates to:
  /// **'Farmaco per {petName}'**
  String notificationsMedicineTitle(String petName);

  /// No description provided for @notificationsMedicineDayBody.
  ///
  /// In it, this message translates to:
  /// **'{title} · giorno {day} di {total}'**
  String notificationsMedicineDayBody(String title, int day, int total);

  /// No description provided for @notificationsMedicineDoseBody.
  ///
  /// In it, this message translates to:
  /// **'{title} · dose delle {time}'**
  String notificationsMedicineDoseBody(String title, String time);

  /// No description provided for @notificationsBirthdayTitle.
  ///
  /// In it, this message translates to:
  /// **'Buon compleanno, {petName}!'**
  String notificationsBirthdayTitle(String petName);

  /// No description provided for @notificationsBirthdayBody.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Oggi compie 1 anno.} other{Oggi compie {count} anni.}}'**
  String notificationsBirthdayBody(int count);

  /// No description provided for @notificationsBirthdayUpcomingTitle.
  ///
  /// In it, this message translates to:
  /// **'Compleanno in arrivo'**
  String get notificationsBirthdayUpcomingTitle;

  /// No description provided for @notificationsBirthdayUpcomingBody.
  ///
  /// In it, this message translates to:
  /// **'Tra una settimana è il compleanno di {petName}: pensa a un regalo.'**
  String notificationsBirthdayUpcomingBody(String petName);

  /// No description provided for @walksPageTitle.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata di {petName}'**
  String walksPageTitle(String petName);

  /// No description provided for @walksStatusInProgress.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata in corso'**
  String get walksStatusInProgress;

  /// No description provided for @walksStatusPaused.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata in pausa'**
  String get walksStatusPaused;

  /// No description provided for @walksStatDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza'**
  String get walksStatDistance;

  /// No description provided for @walksStatDuration.
  ///
  /// In it, this message translates to:
  /// **'Durata'**
  String get walksStatDuration;

  /// No description provided for @walksStatPhotos.
  ///
  /// In it, this message translates to:
  /// **'Foto'**
  String get walksStatPhotos;

  /// No description provided for @walksStatPauses.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Pausa} other{Pause}}'**
  String walksStatPauses(int count);

  /// No description provided for @walksActionPause.
  ///
  /// In it, this message translates to:
  /// **'Pausa'**
  String get walksActionPause;

  /// No description provided for @walksActionResume.
  ///
  /// In it, this message translates to:
  /// **'Riavvia'**
  String get walksActionResume;

  /// No description provided for @walksActionFinish.
  ///
  /// In it, this message translates to:
  /// **'Termina'**
  String get walksActionFinish;

  /// No description provided for @walksActionSaving.
  ///
  /// In it, this message translates to:
  /// **'Salvataggio...'**
  String get walksActionSaving;

  /// No description provided for @walksActionStarting.
  ///
  /// In it, this message translates to:
  /// **'Avvio...'**
  String get walksActionStarting;

  /// No description provided for @walksActionStart.
  ///
  /// In it, this message translates to:
  /// **'Avvia passeggiata'**
  String get walksActionStart;

  /// No description provided for @walksWaitingForGps.
  ///
  /// In it, this message translates to:
  /// **'In attesa di un segnale GPS preciso…'**
  String get walksWaitingForGps;

  /// No description provided for @walksCameraTooltip.
  ///
  /// In it, this message translates to:
  /// **'Foto o video'**
  String get walksCameraTooltip;

  /// No description provided for @walksCaptureTakePhoto.
  ///
  /// In it, this message translates to:
  /// **'Scatta foto'**
  String get walksCaptureTakePhoto;

  /// No description provided for @walksCaptureRecordVideo.
  ///
  /// In it, this message translates to:
  /// **'Registra video'**
  String get walksCaptureRecordVideo;

  /// No description provided for @walksCaptureVideoLimit.
  ///
  /// In it, this message translates to:
  /// **'Fino a {seconds} secondi'**
  String walksCaptureVideoLimit(int seconds);

  /// No description provided for @walksErrorOtherPetActive.
  ///
  /// In it, this message translates to:
  /// **'C\'è già una passeggiata in corso con un altro pet: terminala prima di iniziarne una nuova.'**
  String get walksErrorOtherPetActive;

  /// No description provided for @walksErrorLocationUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a rilevare la tua posizione: serve per tracciare il percorso. Controlla i permessi di localizzazione e riprova.'**
  String get walksErrorLocationUnavailable;

  /// No description provided for @walksPhotoPinSemantics.
  ///
  /// In it, this message translates to:
  /// **'Foto scattata durante la passeggiata'**
  String get walksPhotoPinSemantics;

  /// No description provided for @walksPhotoCaption.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata del {date}'**
  String walksPhotoCaption(String date);

  /// No description provided for @walksMapUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Percorso non disponibile'**
  String get walksMapUnavailable;

  /// No description provided for @walksNoMoveTitle.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata senza spostamento'**
  String get walksNoMoveTitle;

  /// No description provided for @walksNoMoveBody.
  ///
  /// In it, this message translates to:
  /// **'Non è stato registrato alcuno spostamento: la passeggiata non è stata salvata.'**
  String get walksNoMoveBody;

  /// No description provided for @walksNoMoveAck.
  ///
  /// In it, this message translates to:
  /// **'Ho capito'**
  String get walksNoMoveAck;

  /// No description provided for @walksFavoritePromptTitle.
  ///
  /// In it, this message translates to:
  /// **'Salva tra le preferite?'**
  String get walksFavoritePromptTitle;

  /// No description provided for @walksFavoritePromptBody.
  ///
  /// In it, this message translates to:
  /// **'Vuoi aggiungere questa passeggiata ({distance}) alle tue preferite ⭐?'**
  String walksFavoritePromptBody(String distance);

  /// No description provided for @walksFavoriteNoThanks.
  ///
  /// In it, this message translates to:
  /// **'No, grazie'**
  String get walksFavoriteNoThanks;

  /// No description provided for @walksFavoriteSave.
  ///
  /// In it, this message translates to:
  /// **'Salva ⭐'**
  String get walksFavoriteSave;

  /// No description provided for @walksFavoriteEvictTitle.
  ///
  /// In it, this message translates to:
  /// **'Hai già 5 preferite'**
  String get walksFavoriteEvictTitle;

  /// No description provided for @walksFavoriteEvictBody.
  ///
  /// In it, this message translates to:
  /// **'Scegli quale togliere dalle preferite per fare posto a quella appena conclusa.'**
  String get walksFavoriteEvictBody;

  /// No description provided for @walksSheetOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri passeggiata'**
  String get walksSheetOpen;

  /// No description provided for @walksSheetFinish.
  ///
  /// In it, this message translates to:
  /// **'Fine passeggiata'**
  String get walksSheetFinish;

  /// No description provided for @walksConfirmFinishTitle.
  ///
  /// In it, this message translates to:
  /// **'Terminare la passeggiata con {petName}?'**
  String walksConfirmFinishTitle(String petName);

  /// No description provided for @walksConfirmFinishBody.
  ///
  /// In it, this message translates to:
  /// **'Il percorso registrato finora verrà salvato.'**
  String get walksConfirmFinishBody;

  /// No description provided for @walksSavingSnackbar.
  ///
  /// In it, this message translates to:
  /// **'Salvo la passeggiata...'**
  String get walksSavingSnackbar;

  /// No description provided for @walksNotifPermTitle.
  ///
  /// In it, this message translates to:
  /// **'Vedi la passeggiata nelle notifiche'**
  String get walksNotifPermTitle;

  /// No description provided for @walksNotifPermBody.
  ///
  /// In it, this message translates to:
  /// **'Durante la passeggiata VetApp mostra una notifica fissa con tempo e distanza: da lì puoi metterla in pausa o terminarla anche con il telefono in tasca. Per vederla serve il permesso per le notifiche.\n\nLa passeggiata viene registrata comunque, anche se scegli \"Non ora\".'**
  String get walksNotifPermBody;

  /// No description provided for @walksNotifPermNotNow.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get walksNotifPermNotNow;

  /// No description provided for @walksNotifPermAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get walksNotifPermAllow;

  /// No description provided for @walksNotifTitleWithPet.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata con {petName}'**
  String walksNotifTitleWithPet(String petName);

  /// No description provided for @walksNotifTitleWithPetPaused.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata con {petName} · in pausa'**
  String walksNotifTitleWithPetPaused(String petName);

  /// No description provided for @walksNotifTitleNoPetPaused.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata in corso · in pausa'**
  String get walksNotifTitleNoPetPaused;

  /// No description provided for @walksNotifRunningText.
  ///
  /// In it, this message translates to:
  /// **'{distance} percorsi'**
  String walksNotifRunningText(String distance);

  /// No description provided for @walksNotifFallbackPausedText.
  ///
  /// In it, this message translates to:
  /// **'Il tracciamento è in pausa. Riprendi dall\'app quando vuoi.'**
  String get walksNotifFallbackPausedText;

  /// No description provided for @walksNotifFallbackRunningText.
  ///
  /// In it, this message translates to:
  /// **'VetApp sta tracciando il percorso della passeggiata.'**
  String get walksNotifFallbackRunningText;

  /// No description provided for @walksNotifChannelName.
  ///
  /// In it, this message translates to:
  /// **'Tracciamento passeggiata'**
  String get walksNotifChannelName;

  /// No description provided for @walksSyncFailed.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione non riuscita: modifica salvata solo sul telefono'**
  String get walksSyncFailed;

  /// No description provided for @walksFavoriteSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare la preferita: riprova.'**
  String get walksFavoriteSaveFailed;

  /// No description provided for @walksFavoriteRemoveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a togliere la preferita: riprova.'**
  String get walksFavoriteRemoveFailed;

  /// No description provided for @walksDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare la passeggiata: riprova.'**
  String get walksDeleteFailed;

  /// No description provided for @walksHighlightLongest.
  ///
  /// In it, this message translates to:
  /// **'Più lunga'**
  String get walksHighlightLongest;

  /// No description provided for @walksHighlightMostDurable.
  ///
  /// In it, this message translates to:
  /// **'Più duratura'**
  String get walksHighlightMostDurable;

  /// No description provided for @walksHighlightFavorite.
  ///
  /// In it, this message translates to:
  /// **'Preferita'**
  String get walksHighlightFavorite;

  /// No description provided for @walksDurationMinutes.
  ///
  /// In it, this message translates to:
  /// **'{minutes} min'**
  String walksDurationMinutes(int minutes);

  /// No description provided for @walksDurationHoursMinutes.
  ///
  /// In it, this message translates to:
  /// **'{hours}h {minutes}min'**
  String walksDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @walksBadgeLabelFirstWalk.
  ///
  /// In it, this message translates to:
  /// **'Prima passeggiata 🐾'**
  String get walksBadgeLabelFirstWalk;

  /// No description provided for @walksBadgeLabelDistance.
  ///
  /// In it, this message translates to:
  /// **'{km} km percorsi 🏃'**
  String walksBadgeLabelDistance(String km);

  /// No description provided for @walksBadgeLabelWalkCount.
  ///
  /// In it, this message translates to:
  /// **'{count} uscite 🎖️'**
  String walksBadgeLabelWalkCount(String count);

  /// No description provided for @walksBadgeLabel30Min.
  ///
  /// In it, this message translates to:
  /// **'30 minuti in una passeggiata ⏱️'**
  String get walksBadgeLabel30Min;

  /// No description provided for @walksBadgeLabel1Hour.
  ///
  /// In it, this message translates to:
  /// **'1 ora in una passeggiata ⏱️'**
  String get walksBadgeLabel1Hour;

  /// No description provided for @walksBadgeLabelStreak.
  ///
  /// In it, this message translates to:
  /// **'7 giorni di fila 🔥'**
  String get walksBadgeLabelStreak;

  /// No description provided for @walksBadgeLabelDawn.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata all\'alba 🌅'**
  String get walksBadgeLabelDawn;

  /// No description provided for @walksBadgeLabelNight.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata notturna 🌙'**
  String get walksBadgeLabelNight;

  /// No description provided for @walksBadgeEarnedBarrier.
  ///
  /// In it, this message translates to:
  /// **'Badge sbloccato'**
  String get walksBadgeEarnedBarrier;

  /// No description provided for @walksBadgeEarnedTitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Nuovo badge sbloccato!} other{Nuovi badge sbloccati!}}'**
  String walksBadgeEarnedTitle(int count);

  /// No description provided for @walksBadgeEarnedAction.
  ///
  /// In it, this message translates to:
  /// **'Evviva!'**
  String get walksBadgeEarnedAction;

  /// No description provided for @walksBadgeGalleryTitle.
  ///
  /// In it, this message translates to:
  /// **'Badge'**
  String get walksBadgeGalleryTitle;

  /// No description provided for @walksBadgeNameFirstWalk.
  ///
  /// In it, this message translates to:
  /// **'Prima passeggiata'**
  String get walksBadgeNameFirstWalk;

  /// No description provided for @walksBadgeDescFirstWalk.
  ///
  /// In it, this message translates to:
  /// **'Completa la tua prima passeggiata con questo pet.'**
  String get walksBadgeDescFirstWalk;

  /// No description provided for @walksBadgeNameKm.
  ///
  /// In it, this message translates to:
  /// **'{km} km'**
  String walksBadgeNameKm(String km);

  /// No description provided for @walksBadgeDescKm.
  ///
  /// In it, this message translates to:
  /// **'Percorri {km} km in totale.'**
  String walksBadgeDescKm(String km);

  /// No description provided for @walksBadgeName30Min.
  ///
  /// In it, this message translates to:
  /// **'30 minuti'**
  String get walksBadgeName30Min;

  /// No description provided for @walksBadgeDesc30Min.
  ///
  /// In it, this message translates to:
  /// **'Fai una passeggiata di almeno 30 minuti.'**
  String get walksBadgeDesc30Min;

  /// No description provided for @walksBadgeName1Hour.
  ///
  /// In it, this message translates to:
  /// **'1 ora'**
  String get walksBadgeName1Hour;

  /// No description provided for @walksBadgeDesc1Hour.
  ///
  /// In it, this message translates to:
  /// **'Fai una passeggiata di almeno un\'ora.'**
  String get walksBadgeDesc1Hour;

  /// No description provided for @walksBadgeNameStreak.
  ///
  /// In it, this message translates to:
  /// **'7 giorni di fila'**
  String get walksBadgeNameStreak;

  /// No description provided for @walksBadgeDescStreak.
  ///
  /// In it, this message translates to:
  /// **'Esci a passeggio per 7 giorni consecutivi.'**
  String get walksBadgeDescStreak;

  /// No description provided for @walksBadgeNameDawn.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata all\'alba'**
  String get walksBadgeNameDawn;

  /// No description provided for @walksBadgeDescDawn.
  ///
  /// In it, this message translates to:
  /// **'Fai una passeggiata tra le 5 e le 7 del mattino.'**
  String get walksBadgeDescDawn;

  /// No description provided for @walksBadgeNameNight.
  ///
  /// In it, this message translates to:
  /// **'Passeggiata notturna'**
  String get walksBadgeNameNight;

  /// No description provided for @walksBadgeDescNight.
  ///
  /// In it, this message translates to:
  /// **'Fai una passeggiata dopo le 21 o prima delle 5.'**
  String get walksBadgeDescNight;

  /// No description provided for @walksBadgeNameWalkCount.
  ///
  /// In it, this message translates to:
  /// **'{count} uscite'**
  String walksBadgeNameWalkCount(String count);

  /// No description provided for @walksBadgeDescWalkCount.
  ///
  /// In it, this message translates to:
  /// **'Completa {count} passeggiate in totale.'**
  String walksBadgeDescWalkCount(String count);

  /// No description provided for @settingsAccountProfile.
  ///
  /// In it, this message translates to:
  /// **'Il tuo profilo'**
  String get settingsAccountProfile;

  /// No description provided for @settingsAccountChangeEmail.
  ///
  /// In it, this message translates to:
  /// **'Cambia email'**
  String get settingsAccountChangeEmail;

  /// No description provided for @settingsAccountChangePassword.
  ///
  /// In it, this message translates to:
  /// **'Cambia password'**
  String get settingsAccountChangePassword;

  /// No description provided for @settingsAccountSupport.
  ///
  /// In it, this message translates to:
  /// **'Assistenza'**
  String get settingsAccountSupport;

  /// No description provided for @settingsAccountSupportSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scrivici una email'**
  String get settingsAccountSupportSubtitle;

  /// No description provided for @settingsAccountDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina account'**
  String get settingsAccountDelete;

  /// No description provided for @settingsAccountDeleteSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Cancella il tuo account e tutti i tuoi dati'**
  String get settingsAccountDeleteSubtitle;

  /// No description provided for @accountSupportSubject.
  ///
  /// In it, this message translates to:
  /// **'Assistenza VetApp (versione {version})'**
  String accountSupportSubject(String version);

  /// No description provided for @accountSupportBody.
  ///
  /// In it, this message translates to:
  /// **'Scrivi qui il tuo messaggio:\n\n\n\n—\nVersione app: {version}'**
  String accountSupportBody(String version);

  /// No description provided for @accountProfileTitle.
  ///
  /// In it, this message translates to:
  /// **'Il tuo profilo'**
  String get accountProfileTitle;

  /// No description provided for @accountProfileFirstName.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get accountProfileFirstName;

  /// No description provided for @accountProfileLastName.
  ///
  /// In it, this message translates to:
  /// **'Cognome'**
  String get accountProfileLastName;

  /// No description provided for @accountProfilePhone.
  ///
  /// In it, this message translates to:
  /// **'Telefono (facoltativo)'**
  String get accountProfilePhone;

  /// No description provided for @accountProfilePhoneHint.
  ///
  /// In it, this message translates to:
  /// **'+39 333 1234567'**
  String get accountProfilePhoneHint;

  /// No description provided for @accountProfileFirstNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il tuo nome.'**
  String get accountProfileFirstNameRequired;

  /// No description provided for @accountProfileLastNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il tuo cognome.'**
  String get accountProfileLastNameRequired;

  /// No description provided for @accountProfilePhoneInvalid.
  ///
  /// In it, this message translates to:
  /// **'Numero di telefono non valido.'**
  String get accountProfilePhoneInvalid;

  /// No description provided for @accountProfilePhotoAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi foto'**
  String get accountProfilePhotoAdd;

  /// No description provided for @accountProfilePhotoChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia foto'**
  String get accountProfilePhotoChange;

  /// No description provided for @accountProfilePhotoRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi foto'**
  String get accountProfilePhotoRemove;

  /// No description provided for @accountProfilePhotoFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare la foto. Riprova.'**
  String get accountProfilePhotoFailed;

  /// No description provided for @accountProfileSaved.
  ///
  /// In it, this message translates to:
  /// **'Profilo salvato.'**
  String get accountProfileSaved;

  /// No description provided for @accountProfileEmailLabel.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get accountProfileEmailLabel;

  /// No description provided for @accountProfileEmailChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia'**
  String get accountProfileEmailChange;

  /// No description provided for @accountEmailTitle.
  ///
  /// In it, this message translates to:
  /// **'Cambia email'**
  String get accountEmailTitle;

  /// No description provided for @accountEmailCurrent.
  ///
  /// In it, this message translates to:
  /// **'Email attuale'**
  String get accountEmailCurrent;

  /// No description provided for @accountEmailNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova email'**
  String get accountEmailNew;

  /// No description provided for @accountEmailSame.
  ///
  /// In it, this message translates to:
  /// **'È la tua email attuale.'**
  String get accountEmailSame;

  /// No description provided for @accountEmailSubmit.
  ///
  /// In it, this message translates to:
  /// **'Cambia email'**
  String get accountEmailSubmit;

  /// No description provided for @accountEmailApplied.
  ///
  /// In it, this message translates to:
  /// **'Email aggiornata: da ora accedi con {email}.'**
  String accountEmailApplied(String email);

  /// No description provided for @accountEmailConfirmationSent.
  ///
  /// In it, this message translates to:
  /// **'Ti abbiamo mandato un link di conferma al nuovo indirizzo ({email}). Aprilo per completare il cambio: fino ad allora continui ad accedere con l\'email attuale.'**
  String accountEmailConfirmationSent(String email);

  /// No description provided for @accountPasswordTitle.
  ///
  /// In it, this message translates to:
  /// **'Cambia password'**
  String get accountPasswordTitle;

  /// No description provided for @accountPasswordCurrent.
  ///
  /// In it, this message translates to:
  /// **'Password attuale'**
  String get accountPasswordCurrent;

  /// No description provided for @accountPasswordCurrentRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password attuale.'**
  String get accountPasswordCurrentRequired;

  /// No description provided for @accountPasswordCurrentWrong.
  ///
  /// In it, this message translates to:
  /// **'La password attuale non è corretta.'**
  String get accountPasswordCurrentWrong;

  /// No description provided for @accountPasswordNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova password'**
  String get accountPasswordNew;

  /// No description provided for @accountPasswordRepeat.
  ///
  /// In it, this message translates to:
  /// **'Ripeti la nuova password'**
  String get accountPasswordRepeat;

  /// No description provided for @accountPasswordSameAsOld.
  ///
  /// In it, this message translates to:
  /// **'La nuova password deve essere diversa da quella attuale.'**
  String get accountPasswordSameAsOld;

  /// No description provided for @accountPasswordSubmit.
  ///
  /// In it, this message translates to:
  /// **'Cambia password'**
  String get accountPasswordSubmit;

  /// No description provided for @accountPasswordChanged.
  ///
  /// In it, this message translates to:
  /// **'Password cambiata.'**
  String get accountPasswordChanged;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Elimina account'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteWarningTitle.
  ///
  /// In it, this message translates to:
  /// **'Questa azione è definitiva'**
  String get accountDeleteWarningTitle;

  /// No description provided for @accountDeleteWarningBody.
  ///
  /// In it, this message translates to:
  /// **'Verranno cancellati per sempre: i profili dei tuoi animali, le chat con l\'assistente, i promemoria, le passeggiate, le foto e i video, i referti e i documenti caricati, le misurazioni, i consensi, la posizione salvata e gli annunci che hai pubblicato nel mercatino. Non potremo recuperarli.'**
  String get accountDeleteWarningBody;

  /// No description provided for @accountDeletePasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Scrivi la tua password per confermare'**
  String get accountDeletePasswordLabel;

  /// No description provided for @accountDeletePasswordRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua password.'**
  String get accountDeletePasswordRequired;

  /// No description provided for @accountDeleteUnderstood.
  ///
  /// In it, this message translates to:
  /// **'Ho capito: il mio account e tutti i miei dati verranno cancellati per sempre.'**
  String get accountDeleteUnderstood;

  /// No description provided for @accountDeleteSubmit.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente il mio account'**
  String get accountDeleteSubmit;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare l\'account. Riprova tra poco; se il problema continua, scrivi all\'assistenza.'**
  String get accountDeleteFailed;

  /// No description provided for @accountDeleteDone.
  ///
  /// In it, this message translates to:
  /// **'Il tuo account è stato eliminato.'**
  String get accountDeleteDone;

  /// No description provided for @accountDeleteReauth.
  ///
  /// In it, this message translates to:
  /// **'Per sicurezza serve una conferma recente: riscrivi la password e riprova.'**
  String get accountDeleteReauth;

  /// No description provided for @petsValueSexUnknownShort.
  ///
  /// In it, this message translates to:
  /// **'Non so'**
  String get petsValueSexUnknownShort;

  /// No description provided for @petsValueActivitySedentary.
  ///
  /// In it, this message translates to:
  /// **'Sedentario'**
  String get petsValueActivitySedentary;

  /// No description provided for @petsValueActivityNormal.
  ///
  /// In it, this message translates to:
  /// **'Normale'**
  String get petsValueActivityNormal;

  /// No description provided for @petsValueActivityActive.
  ///
  /// In it, this message translates to:
  /// **'Attivo'**
  String get petsValueActivityActive;

  /// No description provided for @petsFormSterilized.
  ///
  /// In it, this message translates to:
  /// **'Sterilizzato / castrato'**
  String get petsFormSterilized;

  /// No description provided for @petsFormMicrochipLabel.
  ///
  /// In it, this message translates to:
  /// **'N. microchip'**
  String get petsFormMicrochipLabel;

  /// No description provided for @petsFormMicrochipHint.
  ///
  /// In it, this message translates to:
  /// **'15 cifre'**
  String get petsFormMicrochipHint;

  /// No description provided for @petsFormMicrochipInvalid.
  ///
  /// In it, this message translates to:
  /// **'Il microchip ha 15 cifre.'**
  String get petsFormMicrochipInvalid;

  /// No description provided for @petsFormCoatColorLabel.
  ///
  /// In it, this message translates to:
  /// **'Colore del mantello'**
  String get petsFormCoatColorLabel;

  /// No description provided for @petsFormCoatColorHint.
  ///
  /// In it, this message translates to:
  /// **'Es. nero, marrone'**
  String get petsFormCoatColorHint;

  /// No description provided for @petsFormColorLabel.
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get petsFormColorLabel;

  /// No description provided for @petsFormColorHint.
  ///
  /// In it, this message translates to:
  /// **'Es. verde, giallo'**
  String get petsFormColorHint;

  /// No description provided for @petsFormBodyConditionLabel.
  ///
  /// In it, this message translates to:
  /// **'Corporatura'**
  String get petsFormBodyConditionLabel;

  /// No description provided for @petsFormBodyConditionHint.
  ///
  /// In it, this message translates to:
  /// **'Seleziona corporatura'**
  String get petsFormBodyConditionHint;

  /// No description provided for @petsFormActivityLabel.
  ///
  /// In it, this message translates to:
  /// **'Attività'**
  String get petsFormActivityLabel;

  /// No description provided for @petsFormActivityHint.
  ///
  /// In it, this message translates to:
  /// **'Seleziona attività'**
  String get petsFormActivityHint;

  /// No description provided for @petsFormDogSizeLabelShort.
  ///
  /// In it, this message translates to:
  /// **'Taglia'**
  String get petsFormDogSizeLabelShort;

  /// No description provided for @petsWizardNext.
  ///
  /// In it, this message translates to:
  /// **'Prosegui'**
  String get petsWizardNext;

  /// No description provided for @petsWizardConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get petsWizardConfirm;

  /// No description provided for @petsWizardBack.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get petsWizardBack;

  /// No description provided for @petsWizardStepSemantics.
  ///
  /// In it, this message translates to:
  /// **'Passo {current} di {total}'**
  String petsWizardStepSemantics(int current, int total);

  /// No description provided for @petsWizardStep1Title.
  ///
  /// In it, this message translates to:
  /// **'Che animale è?'**
  String get petsWizardStep1Title;

  /// No description provided for @petsWizardStep1Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli il tipo di animale e la sua razza o specie'**
  String get petsWizardStep1Subtitle;

  /// No description provided for @petsWizardStep2Title.
  ///
  /// In it, this message translates to:
  /// **'Parlaci del tuo animale'**
  String get petsWizardStep2Title;

  /// No description provided for @petsWizardStep2Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Come si chiama?'**
  String get petsWizardStep2Subtitle;

  /// No description provided for @petsWizardStep3Title.
  ///
  /// In it, this message translates to:
  /// **'Informazioni generali'**
  String get petsWizardStep3Title;

  /// No description provided for @petsWizardStep3Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Dicci qualcosa in più sul tuo animale'**
  String get petsWizardStep3Subtitle;

  /// No description provided for @petsWizardStep4Title.
  ///
  /// In it, this message translates to:
  /// **'Informazioni finali'**
  String get petsWizardStep4Title;

  /// No description provided for @petsWizardStep4Subtitle.
  ///
  /// In it, this message translates to:
  /// **'Quasi finito!'**
  String get petsWizardStep4Subtitle;

  /// No description provided for @petsWizardPureBred.
  ///
  /// In it, this message translates to:
  /// **'Di razza'**
  String get petsWizardPureBred;

  /// No description provided for @petsWizardMixedBreed.
  ///
  /// In it, this message translates to:
  /// **'Meticcio'**
  String get petsWizardMixedBreed;

  /// No description provided for @petsWizardDoneTitle.
  ///
  /// In it, this message translates to:
  /// **'Profilo creato!'**
  String get petsWizardDoneTitle;

  /// No description provided for @petsWizardDoneMessage.
  ///
  /// In it, this message translates to:
  /// **'Complimenti, {name} è stato aggiunto ai tuoi animali.'**
  String petsWizardDoneMessage(String name);

  /// No description provided for @petsWizardAddAnother.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un altro animale'**
  String get petsWizardAddAnother;

  /// No description provided for @petsWizardFinish.
  ///
  /// In it, this message translates to:
  /// **'Fine'**
  String get petsWizardFinish;

  /// No description provided for @petsDataTitle.
  ///
  /// In it, this message translates to:
  /// **'Dati animale'**
  String get petsDataTitle;

  /// No description provided for @petsDataSectionIdentity.
  ///
  /// In it, this message translates to:
  /// **'Anagrafica'**
  String get petsDataSectionIdentity;

  /// No description provided for @petsDataSectionPhysical.
  ///
  /// In it, this message translates to:
  /// **'Caratteristiche fisiche'**
  String get petsDataSectionPhysical;

  /// No description provided for @petsDataSectionDocuments.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get petsDataSectionDocuments;

  /// No description provided for @petsDataNotProvided.
  ///
  /// In it, this message translates to:
  /// **'Non indicato'**
  String get petsDataNotProvided;

  /// No description provided for @petsDataMicrochipMissing.
  ///
  /// In it, this message translates to:
  /// **'Mancante'**
  String get petsDataMicrochipMissing;

  /// No description provided for @petsDataMicrochipMissingDogHint.
  ///
  /// In it, this message translates to:
  /// **'Per i cani il microchip è obbligatorio.'**
  String get petsDataMicrochipMissingDogHint;

  /// No description provided for @petsDataAddMicrochip.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi microchip'**
  String get petsDataAddMicrochip;

  /// No description provided for @petsDataWeightLabel.
  ///
  /// In it, this message translates to:
  /// **'Peso'**
  String get petsDataWeightLabel;

  /// No description provided for @petsDataSummarySterilized.
  ///
  /// In it, this message translates to:
  /// **'sterilizzato'**
  String get petsDataSummarySterilized;

  /// No description provided for @monitoringTitle.
  ///
  /// In it, this message translates to:
  /// **'Monitoraggio'**
  String get monitoringTitle;

  /// No description provided for @petsDetailTabMonitoring.
  ///
  /// In it, this message translates to:
  /// **'Monitoraggio'**
  String get petsDetailTabMonitoring;

  /// No description provided for @monitoringBcsGuideTitle.
  ///
  /// In it, this message translates to:
  /// **'Valuta la corporatura'**
  String get monitoringBcsGuideTitle;

  /// No description provided for @monitoringBcsGuideIntro.
  ///
  /// In it, this message translates to:
  /// **'Il peso da solo non basta a dire se un animale è magro o in carne: bisogna toccarlo e guardarlo. Segui i tre passaggi e scegli la descrizione che assomiglia di più a {petName}.'**
  String monitoringBcsGuideIntro(String petName);

  /// No description provided for @monitoringBcsStepTouch.
  ///
  /// In it, this message translates to:
  /// **'Tocca le costole'**
  String get monitoringBcsStepTouch;

  /// No description provided for @monitoringBcsStepAbove.
  ///
  /// In it, this message translates to:
  /// **'Guarda dall’alto'**
  String get monitoringBcsStepAbove;

  /// No description provided for @monitoringBcsStepSide.
  ///
  /// In it, this message translates to:
  /// **'Guarda di lato'**
  String get monitoringBcsStepSide;

  /// No description provided for @monitoringBcsViewAbove.
  ///
  /// In it, this message translates to:
  /// **'Dall’alto'**
  String get monitoringBcsViewAbove;

  /// No description provided for @monitoringBcsViewSide.
  ///
  /// In it, this message translates to:
  /// **'Di lato'**
  String get monitoringBcsViewSide;

  /// No description provided for @monitoringBcsRowTouch.
  ///
  /// In it, this message translates to:
  /// **'Al tatto'**
  String get monitoringBcsRowTouch;

  /// No description provided for @monitoringBcsRowAbove.
  ///
  /// In it, this message translates to:
  /// **'Dall’alto'**
  String get monitoringBcsRowAbove;

  /// No description provided for @monitoringBcsRowSide.
  ///
  /// In it, this message translates to:
  /// **'Di lato'**
  String get monitoringBcsRowSide;

  /// No description provided for @monitoringBcsGuideScale.
  ///
  /// In it, this message translates to:
  /// **'Nella scala della fonte: {range} su {max}'**
  String monitoringBcsGuideScale(String range, String max);

  /// No description provided for @monitoringBcsGuideChoose.
  ///
  /// In it, this message translates to:
  /// **'Scegli: {level}'**
  String monitoringBcsGuideChoose(String level);

  /// No description provided for @monitoringBcsGuideClear.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi la valutazione'**
  String get monitoringBcsGuideClear;

  /// No description provided for @monitoringBcsGuideDisclaimer.
  ///
  /// In it, this message translates to:
  /// **'È un’indicazione orientativa che non sostituisce la visita del veterinario. Le illustrazioni sono schematiche e originali di VetApp.'**
  String get monitoringBcsGuideDisclaimer;

  /// No description provided for @monitoringBcsGuideSource.
  ///
  /// In it, this message translates to:
  /// **'Fonte: {source}'**
  String monitoringBcsGuideSource(String source);

  /// No description provided for @monitoringBcsGuideTipFurry.
  ///
  /// In it, this message translates to:
  /// **'Nei cani e nei gatti col pelo lungo o folto la vista inganna: tocca sempre le costole. Per esempio, un cane peloso può sembrare in carne anche se sotto è magro, mentre un cucciolo o un cane molto muscoloso può sembrare «troppo in forma» ma avere un peso corretto.'**
  String get monitoringBcsGuideTipFurry;

  /// No description provided for @monitoringBcsGuideTipRabbit.
  ///
  /// In it, this message translates to:
  /// **'Nei conigli il pelo nasconde le ossa: tocca sempre schiena, costole e anca, la sola vista non basta. Un pelo folto può far sembrare grasso un coniglio normale, o normale uno magro.'**
  String get monitoringBcsGuideTipRabbit;

  /// No description provided for @monitoringBcsGuideAdviceTitle.
  ///
  /// In it, this message translates to:
  /// **'Consigli'**
  String get monitoringBcsGuideAdviceTitle;

  /// No description provided for @monitoringBcsGuideAdvice1.
  ///
  /// In it, this message translates to:
  /// **'Pesa {petName} ogni 2-4 settimane e annota il peso: le variazioni lente si notano più nei numeri che a occhio.'**
  String monitoringBcsGuideAdvice1(String petName);

  /// No description provided for @monitoringBcsGuideAdvice2.
  ///
  /// In it, this message translates to:
  /// **'Valuta sempre allo stesso modo: stesso posto, animale in piedi e tranquillo, stesse tre mosse (tatto, vista dall\'alto, vista di lato).'**
  String get monitoringBcsGuideAdvice2;

  /// No description provided for @monitoringBcsGuideAdvice3.
  ///
  /// In it, this message translates to:
  /// **'Nel dubbio, chiedi al veterinario: la corporatura si impara meglio con qualcuno che ti mostra come toccare.'**
  String get monitoringBcsGuideAdvice3;

  /// No description provided for @monitoringBcsGuideCaveatRabbit.
  ///
  /// In it, this message translates to:
  /// **'Per i conigli questa scala è meno affidabile: due persone possono dare punteggi diversi allo stesso coniglio. Se hai dubbi, chiedi al veterinario.'**
  String get monitoringBcsGuideCaveatRabbit;

  /// No description provided for @monitoringBcsSourceDog.
  ///
  /// In it, this message translates to:
  /// **'criteri della scala a 9 punti del WSAVA Global Nutrition Committee per i cani (Laflamme, 1997), riassunti con parole nostre e ridotti a 5 livelli da VetApp. Non è materiale ufficiale WSAVA.'**
  String get monitoringBcsSourceDog;

  /// No description provided for @monitoringBcsSourceCat.
  ///
  /// In it, this message translates to:
  /// **'criteri della scala a 9 punti del WSAVA Global Nutrition Committee per i gatti (Laflamme, 1997; validata da Bjornvad e colleghi, 2011), riassunti con parole nostre e ridotti a 5 livelli da VetApp. Non è materiale ufficiale WSAVA.'**
  String get monitoringBcsSourceCat;

  /// No description provided for @monitoringBcsSourceRabbit.
  ///
  /// In it, this message translates to:
  /// **'Rabbit Size-O-Meter a 5 livelli della PFMA (Pet Food Manufacturers’ Association), riassunto con parole nostre. L’affidabilità tra chi valuta è limitata (Halck e colleghi, Veterinary Record, 2025).'**
  String get monitoringBcsSourceRabbit;

  /// No description provided for @monitoringBcsNotAssessed.
  ///
  /// In it, this message translates to:
  /// **'Non valutata'**
  String get monitoringBcsNotAssessed;

  /// No description provided for @monitoringBcsAssess.
  ///
  /// In it, this message translates to:
  /// **'Valuta la corporatura'**
  String get monitoringBcsAssess;

  /// No description provided for @monitoringBcsReassess.
  ///
  /// In it, this message translates to:
  /// **'Rivaluta la corporatura'**
  String get monitoringBcsReassess;

  /// No description provided for @monitoringBcsGuideDog1Touch.
  ///
  /// In it, this message translates to:
  /// **'Costole, colonna e ossa del bacino si sentono subito sotto la pelle: non c\'è praticamente grasso e i muscoli sembrano ridotti. Un esempio: è come toccare le nocche di una mano chiusa a pugno, dove l\'osso è subito sotto la pelle e non c\'è nulla in mezzo.'**
  String get monitoringBcsGuideDog1Touch;

  /// No description provided for @monitoringBcsGuideDog1Above.
  ///
  /// In it, this message translates to:
  /// **'Vita molto stretta e scavata dietro le costole; le ossa dell\'anca e della schiena sporgono. Guardandolo dall\'alto il corpo ricorda una clessidra molto sottile.'**
  String get monitoringBcsGuideDog1Above;

  /// No description provided for @monitoringBcsGuideDog1Side.
  ///
  /// In it, this message translates to:
  /// **'Pancia molto rientrata, il profilo sale deciso verso le zampe posteriori. Le costole possono vedersi anche da lontano, soprattutto nei cani a pelo corto.'**
  String get monitoringBcsGuideDog1Side;

  /// No description provided for @monitoringBcsGuideDog2Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole si sentono senza premere, con pochissimo grasso sopra, e a volte si vedono. Un esempio: passando la mano sul fianco senti ogni costola come un gradino distinto, senza lo strato morbido che c\'è in un cane in forma.'**
  String get monitoringBcsGuideDog2Touch;

  /// No description provided for @monitoringBcsGuideDog2Above.
  ///
  /// In it, this message translates to:
  /// **'Vita ben marcata dietro le costole; le ossa del bacino cominciano a notarsi. Per trovarla, guarda il cane in piedi dall\'alto: il corpo si restringe in modo evidente dopo l\'ultima costola.'**
  String get monitoringBcsGuideDog2Above;

  /// No description provided for @monitoringBcsGuideDog2Side.
  ///
  /// In it, this message translates to:
  /// **'Pancia chiaramente rientrata. Nei cuccioli in crescita e nei cani molto atletici questo aspetto può essere normale: confrontalo con le costole al tatto.'**
  String get monitoringBcsGuideDog2Side;

  /// No description provided for @monitoringBcsGuideDog3Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole si sentono bene sotto un sottile strato di grasso, senza dover premere. Un esempio: è come toccare il dorso della mano aperta e distesa, dove senti i tendini sotto la pelle ma non l\'osso tagliente.'**
  String get monitoringBcsGuideDog3Touch;

  /// No description provided for @monitoringBcsGuideDog3Above.
  ///
  /// In it, this message translates to:
  /// **'Si vede una vita dietro le costole. Per trovarla, guarda il cane in piedi dall\'alto: tra il torace e il bacino il corpo si restringe leggermente, senza sporgere ai lati.'**
  String get monitoringBcsGuideDog3Above;

  /// No description provided for @monitoringBcsGuideDog3Side.
  ///
  /// In it, this message translates to:
  /// **'Il ventre sale con dolcezza dal petto verso le zampe posteriori. Nei cani a pelo lungo o folto la sagoma si capisce meglio passando le mani sul corpo che guardando.'**
  String get monitoringBcsGuideDog3Side;

  /// No description provided for @monitoringBcsGuideDog4Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole si sentono con un po\' di fatica: lo strato di grasso è più spesso, soprattutto sulla schiena vicino alla coda. Un esempio: è come toccare il dorso della mano quando le dita sono chiuse a pugno morbido, con più carne sopra le ossa.'**
  String get monitoringBcsGuideDog4Touch;

  /// No description provided for @monitoringBcsGuideDog4Above.
  ///
  /// In it, this message translates to:
  /// **'La vita si intravede appena oppure non si vede più. Dall\'alto il corpo appare quasi rettangolare, senza il restringimento dietro le costole.'**
  String get monitoringBcsGuideDog4Above;

  /// No description provided for @monitoringBcsGuideDog4Side.
  ///
  /// In it, this message translates to:
  /// **'Il rientro della pancia è poco evidente. Attenzione a non confondere il pelo folto con il grasso: tocca sempre le costole prima di decidere.'**
  String get monitoringBcsGuideDog4Side;

  /// No description provided for @monitoringBcsGuideDog5Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole non si sentono, o solo premendo forte, sotto un grosso strato di grasso; si accumula su schiena e base della coda. Un esempio: è come cercare le ossa sul palmo della mano, dove sotto la pelle c\'è solo uno spesso cuscinetto morbido.'**
  String get monitoringBcsGuideDog5Touch;

  /// No description provided for @monitoringBcsGuideDog5Above.
  ///
  /// In it, this message translates to:
  /// **'Nessuna vita: il corpo è largo e tondeggiante, la pancia può sembrare gonfia. Dall\'alto il cane appare più largo sui fianchi che sul torace.'**
  String get monitoringBcsGuideDog5Above;

  /// No description provided for @monitoringBcsGuideDog5Side.
  ///
  /// In it, this message translates to:
  /// **'Nessun rientro: la pancia è tonda o scende verso il basso. Un cane così si stanca presto e fa fatica a muoversi: parlane con il veterinario.'**
  String get monitoringBcsGuideDog5Side;

  /// No description provided for @monitoringBcsGuideCat1Touch.
  ///
  /// In it, this message translates to:
  /// **'Costole e vertebre della schiena si sentono senza alcuno strato di grasso; nei gatti a pelo corto le costole si vedono. Un esempio: è come toccare le nocche di una mano chiusa a pugno, ossa subito sotto la pelle.'**
  String get monitoringBcsGuideCat1Touch;

  /// No description provided for @monitoringBcsGuideCat1Above.
  ///
  /// In it, this message translates to:
  /// **'Vita molto stretta dietro le costole. Guardandolo dall\'alto il corpo è sottile come una clessidra molto stretta.'**
  String get monitoringBcsGuideCat1Above;

  /// No description provided for @monitoringBcsGuideCat1Side.
  ///
  /// In it, this message translates to:
  /// **'Pancia molto rientrata, nessun cuscinetto di grasso sotto il ventre. Anche i muscoli ai lati della colonna sembrano ridotti.'**
  String get monitoringBcsGuideCat1Side;

  /// No description provided for @monitoringBcsGuideCat2Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole si sentono facilmente con pochissimo grasso e le vertebre della schiena si notano. Un esempio: passando la mano sul fianco senti ogni costola distinta, senza il velo morbido che c\'è in un gatto in forma.'**
  String get monitoringBcsGuideCat2Touch;

  /// No description provided for @monitoringBcsGuideCat2Above.
  ///
  /// In it, this message translates to:
  /// **'Vita ben visibile dietro le costole. Guardalo dall\'alto mentre sta in piedi: il corpo si restringe in modo evidente dopo la gabbia toracica.'**
  String get monitoringBcsGuideCat2Above;

  /// No description provided for @monitoringBcsGuideCat2Side.
  ///
  /// In it, this message translates to:
  /// **'Pancia un po\' rientrata, con poco o nessun cuscinetto di grasso. Nei gatti anziani la magrezza può nascondere un problema di salute: se è recente, chiedi al veterinario.'**
  String get monitoringBcsGuideCat2Side;

  /// No description provided for @monitoringBcsGuideCat3Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole si sentono con un velo di grasso sopra. Un esempio: è come toccare il dorso della mano aperta e distesa, dove senti i tendini sotto la pelle ma non l\'osso tagliente.'**
  String get monitoringBcsGuideCat3Touch;

  /// No description provided for @monitoringBcsGuideCat3Above.
  ///
  /// In it, this message translates to:
  /// **'Corpo ben proporzionato, con una vita visibile dietro le costole. Dall\'alto il gatto ha una leggera clessidra, senza sporgere ai lati.'**
  String get monitoringBcsGuideCat3Above;

  /// No description provided for @monitoringBcsGuideCat3Side.
  ///
  /// In it, this message translates to:
  /// **'Il profilo del ventre è morbido, con un cuscinetto di grasso appena accennato. Nei gatti a pelo lungo la sagoma si capisce meglio con le mani che con gli occhi.'**
  String get monitoringBcsGuideCat3Side;

  /// No description provided for @monitoringBcsGuideCat4Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole sono più difficili da sentire: bisogna premere un po\', perché c\'è più grasso. Un esempio: è come toccare il dorso della mano quando le dita sono chiuse a pugno morbido, con più carne sopra le ossa.'**
  String get monitoringBcsGuideCat4Touch;

  /// No description provided for @monitoringBcsGuideCat4Above.
  ///
  /// In it, this message translates to:
  /// **'La vita si vede poco o non si vede. Dall\'alto il corpo appare quasi rettangolare, senza il restringimento dietro le costole.'**
  String get monitoringBcsGuideCat4Above;

  /// No description provided for @monitoringBcsGuideCat4Side.
  ///
  /// In it, this message translates to:
  /// **'Pancia arrotondata, con un cuscinetto di grasso moderato sotto il ventre. Quando cammina il cuscinetto oscilla leggermente: nei gatti in forma è appena accennato.'**
  String get monitoringBcsGuideCat4Side;

  /// No description provided for @monitoringBcsGuideCat5Touch.
  ///
  /// In it, this message translates to:
  /// **'Le costole non si sentono sotto un grosso strato di grasso, che si accumula anche sulla schiena e, nei casi estremi, su muso e zampe. Un esempio: è come cercare le ossa sul palmo della mano, dove c\'è solo un cuscinetto morbido.'**
  String get monitoringBcsGuideCat5Touch;

  /// No description provided for @monitoringBcsGuideCat5Above.
  ///
  /// In it, this message translates to:
  /// **'Nessuna vita: il corpo è largo. Dall\'alto appare più largo sui fianchi che sul torace.'**
  String get monitoringBcsGuideCat5Above;

  /// No description provided for @monitoringBcsGuideCat5Side.
  ///
  /// In it, this message translates to:
  /// **'Pancia tonda o penzolante, con un cuscinetto di grasso evidente. Il gatto fatica a curarsi il pelo sulla schiena e sul posteriore: parlane con il veterinario.'**
  String get monitoringBcsGuideCat5Side;

  /// No description provided for @monitoringBcsGuideRabbit1Touch.
  ///
  /// In it, this message translates to:
  /// **'Colonna, costole e ossa dell\'anca sporgono e sono taglienti sotto la pelle: non c\'è grasso e i muscoli sono ridotti. Un esempio: è come toccare le nocche di una mano chiusa a pugno, con l\'osso subito sotto la pelle.'**
  String get monitoringBcsGuideRabbit1Touch;

  /// No description provided for @monitoringBcsGuideRabbit1Above.
  ///
  /// In it, this message translates to:
  /// **'Schiena e fianchi scavati, le ossa dell\'anca si notano. Dall\'alto il corpo sembra stretto e spigoloso.'**
  String get monitoringBcsGuideRabbit1Above;

  /// No description provided for @monitoringBcsGuideRabbit1Side.
  ///
  /// In it, this message translates to:
  /// **'Il posteriore (la groppa) è incavato, curva verso l\'interno. Un coniglio così magro va fatto vedere presto al veterinario.'**
  String get monitoringBcsGuideRabbit1Side;

  /// No description provided for @monitoringBcsGuideRabbit2Touch.
  ///
  /// In it, this message translates to:
  /// **'Costole, colonna e anca si sentono facilmente, con poco grasso sopra. Un esempio: passando la mano sulla schiena senti le vertebre come una fila di piccole sporgenze ben distinte.'**
  String get monitoringBcsGuideRabbit2Touch;

  /// No description provided for @monitoringBcsGuideRabbit2Above.
  ///
  /// In it, this message translates to:
  /// **'Fianchi sottili, con la colonna poco coperta. Dall\'alto il corpo è più stretto di quanto ti aspetteresti.'**
  String get monitoringBcsGuideRabbit2Above;

  /// No description provided for @monitoringBcsGuideRabbit2Side.
  ///
  /// In it, this message translates to:
  /// **'Il posteriore è piatto. Nei conigli a pelo lungo il pelo nasconde la magrezza: tocca sempre schiena e anca.'**
  String get monitoringBcsGuideRabbit2Side;

  /// No description provided for @monitoringBcsGuideRabbit3Touch.
  ///
  /// In it, this message translates to:
  /// **'Costole e colonna si sentono con facilità ma hanno contorni morbidi e arrotondati, non taglienti. Un esempio: è come toccare il dorso della mano aperta e distesa, dove senti le ossa sotto una pelle morbida.'**
  String get monitoringBcsGuideRabbit3Touch;

  /// No description provided for @monitoringBcsGuideRabbit3Above.
  ///
  /// In it, this message translates to:
  /// **'Corpo ben proporzionato, senza rigonfiamenti ai fianchi. Dall\'alto la sagoma è uniforme, dal collo alla coda.'**
  String get monitoringBcsGuideRabbit3Above;

  /// No description provided for @monitoringBcsGuideRabbit3Side.
  ///
  /// In it, this message translates to:
  /// **'Il posteriore è piatto e la pancia non sporge. La schiena forma una curva regolare e non appare né incavata né rigonfia.'**
  String get monitoringBcsGuideRabbit3Side;

  /// No description provided for @monitoringBcsGuideRabbit4Touch.
  ///
  /// In it, this message translates to:
  /// **'Per sentire costole, colonna e anca bisogna premere: ci sono strati di grasso. Un esempio: è come toccare il dorso della mano quando le dita sono chiuse a pugno morbido, con più carne sopra le ossa.'**
  String get monitoringBcsGuideRabbit4Touch;

  /// No description provided for @monitoringBcsGuideRabbit4Above.
  ///
  /// In it, this message translates to:
  /// **'Fianchi pieni e arrotondati. Dall\'alto il corpo appare più largo di quanto ti aspetteresti.'**
  String get monitoringBcsGuideRabbit4Above;

  /// No description provided for @monitoringBcsGuideRabbit4Side.
  ///
  /// In it, this message translates to:
  /// **'Il posteriore è arrotondato. Spesso si nota anche un leggero rigonfiamento sotto il mento, soprattutto nelle femmine.'**
  String get monitoringBcsGuideRabbit4Side;

  /// No description provided for @monitoringBcsGuideRabbit5Touch.
  ///
  /// In it, this message translates to:
  /// **'Colonna e anca si sentono a fatica e le costole per niente, sotto un grosso strato di grasso. Un esempio: è come cercare le ossa sul palmo della mano, dove c\'è solo un cuscinetto morbido.'**
  String get monitoringBcsGuideRabbit5Touch;

  /// No description provided for @monitoringBcsGuideRabbit5Above.
  ///
  /// In it, this message translates to:
  /// **'Corpo largo e pieno, con il posteriore che sporge. Dall\'alto la sagoma è molto tondeggiante.'**
  String get monitoringBcsGuideRabbit5Above;

  /// No description provided for @monitoringBcsGuideRabbit5Side.
  ///
  /// In it, this message translates to:
  /// **'La pancia scende e forma un cuscinetto di grasso sotto il ventre. Un coniglio così in carne fatica a pulirsi e può avere problemi di pelle sotto la coda: chiedi al veterinario.'**
  String get monitoringBcsGuideRabbit5Side;

  /// No description provided for @monitoringAddMeasurement.
  ///
  /// In it, this message translates to:
  /// **'Nuova misurazione'**
  String get monitoringAddMeasurement;

  /// No description provided for @monitoringCurrentWeight.
  ///
  /// In it, this message translates to:
  /// **'Peso attuale'**
  String get monitoringCurrentWeight;

  /// No description provided for @monitoringMeasuredOn.
  ///
  /// In it, this message translates to:
  /// **'Misurato il {date}'**
  String monitoringMeasuredOn(String date);

  /// No description provided for @monitoringChangeSince.
  ///
  /// In it, this message translates to:
  /// **'{change} dal {date}'**
  String monitoringChangeSince(String change, String date);

  /// No description provided for @monitoringEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna misurazione ancora'**
  String get monitoringEmptyTitle;

  /// No description provided for @monitoringEmptyBody.
  ///
  /// In it, this message translates to:
  /// **'Registra il peso di {petName} per seguirne l\'andamento nel tempo.'**
  String monitoringEmptyBody(String petName);

  /// No description provided for @monitoringBcsTitle.
  ///
  /// In it, this message translates to:
  /// **'Corporatura'**
  String get monitoringBcsTitle;

  /// No description provided for @monitoringBcsAsOf.
  ///
  /// In it, this message translates to:
  /// **'Dalla misurazione del {date}'**
  String monitoringBcsAsOf(String date);

  /// No description provided for @monitoringBcsNone.
  ///
  /// In it, this message translates to:
  /// **'Tocca «Valuta la corporatura» per vederla qui.'**
  String get monitoringBcsNone;

  /// No description provided for @monitoringBcsVeryThin.
  ///
  /// In it, this message translates to:
  /// **'Molto magro'**
  String get monitoringBcsVeryThin;

  /// No description provided for @monitoringBcsThin.
  ///
  /// In it, this message translates to:
  /// **'Magro'**
  String get monitoringBcsThin;

  /// No description provided for @monitoringBcsNormal.
  ///
  /// In it, this message translates to:
  /// **'Normale'**
  String get monitoringBcsNormal;

  /// No description provided for @monitoringBcsSlightlyOverweight.
  ///
  /// In it, this message translates to:
  /// **'Leggermente sovrappeso'**
  String get monitoringBcsSlightlyOverweight;

  /// No description provided for @monitoringBcsOverweight.
  ///
  /// In it, this message translates to:
  /// **'Sovrappeso'**
  String get monitoringBcsOverweight;

  /// No description provided for @monitoringChartTitleWeight.
  ///
  /// In it, this message translates to:
  /// **'Andamento peso'**
  String get monitoringChartTitleWeight;

  /// No description provided for @monitoringChartTitleGrowth.
  ///
  /// In it, this message translates to:
  /// **'Curva di crescita'**
  String get monitoringChartTitleGrowth;

  /// No description provided for @monitoringChartGrowthHint.
  ///
  /// In it, this message translates to:
  /// **'Il peso di {petName} in base all\'età, senza curve di riferimento: solo le sue misurazioni.'**
  String monitoringChartGrowthHint(String petName);

  /// No description provided for @monitoringChartSinglePoint.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un\'altra misurazione per vedere l\'andamento.'**
  String get monitoringChartSinglePoint;

  /// No description provided for @monitoringChartGrowthHintReference.
  ///
  /// In it, this message translates to:
  /// **'Il peso di {petName} in base all’età, confrontato con l’area di riferimento.'**
  String monitoringChartGrowthHintReference(String petName);

  /// No description provided for @monitoringGrowthLegend.
  ///
  /// In it, this message translates to:
  /// **'Area scura: dal 25° al 75° percentile (la metà centrale). Area chiara: dal 3° al 97°. Linea tratteggiata: mediana.'**
  String get monitoringGrowthLegend;

  /// No description provided for @monitoringGrowthSourcePuppy.
  ///
  /// In it, this message translates to:
  /// **'Riferimento: cani sani con peso adulto {sizeLabel}. Derivato da dati CC BY 4.0 di Salt C. et al., PLOS ONE 2017; non sono le curve ufficiali WALTHAM.'**
  String monitoringGrowthSourcePuppy(String sizeLabel);

  /// No description provided for @monitoringGrowthSourceKitten.
  ///
  /// In it, this message translates to:
  /// **'Riferimento: gattini domestici a pelo corto non sterilizzati (USA). Derivato da dati CC BY 3.0 di Salt C. et al., PLOS ONE 2022; non sono le curve ufficiali WALTHAM.'**
  String get monitoringGrowthSourceKitten;

  /// No description provided for @monitoringGrowthDisclaimer.
  ///
  /// In it, this message translates to:
  /// **'È un riferimento, non una diagnosi: ogni animale cresce con il suo ritmo. Se il peso di {petName} esce spesso dall’area o cambia all’improvviso, parlane con il veterinario.'**
  String monitoringGrowthDisclaimer(String petName);

  /// No description provided for @monitoringGrowthExpectedAdult.
  ///
  /// In it, this message translates to:
  /// **'Peso adulto atteso: {range}'**
  String monitoringGrowthExpectedAdult(String range);

  /// No description provided for @monitoringGrowthChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia'**
  String get monitoringGrowthChange;

  /// No description provided for @monitoringGrowthPromptTitle.
  ///
  /// In it, this message translates to:
  /// **'Mostra l’area di riferimento'**
  String get monitoringGrowthPromptTitle;

  /// No description provided for @monitoringGrowthPromptBody.
  ///
  /// In it, this message translates to:
  /// **'Per confrontare {petName} con cuccioli sani serve il peso che avrà da adulto: scegli la fascia più probabile (razza, genitori, veterinario).'**
  String monitoringGrowthPromptBody(String petName);

  /// No description provided for @monitoringGrowthPromptButton.
  ///
  /// In it, this message translates to:
  /// **'Scegli il peso adulto'**
  String get monitoringGrowthPromptButton;

  /// No description provided for @monitoringGrowthNoReferenceHeavy.
  ///
  /// In it, this message translates to:
  /// **'Per i cani sopra i 40 kg non ci sono curve di riferimento affidabili: le razze molto grandi crescono in modi molto diversi.'**
  String get monitoringGrowthNoReferenceHeavy;

  /// No description provided for @monitoringGrowthSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Peso adulto atteso di {petName}'**
  String monitoringGrowthSheetTitle(String petName);

  /// No description provided for @monitoringGrowthClassUnder.
  ///
  /// In it, this message translates to:
  /// **'Meno di {max}'**
  String monitoringGrowthClassUnder(String max);

  /// No description provided for @monitoringGrowthClassBetween.
  ///
  /// In it, this message translates to:
  /// **'Da {min} a {max}'**
  String monitoringGrowthClassBetween(String min, String max);

  /// No description provided for @monitoringGrowthClassOver.
  ///
  /// In it, this message translates to:
  /// **'Più di {min}'**
  String monitoringGrowthClassOver(String min);

  /// No description provided for @monitoringGrowthClassUnknown.
  ///
  /// In it, this message translates to:
  /// **'Non lo so: nessuna area di riferimento'**
  String get monitoringGrowthClassUnknown;

  /// No description provided for @monitoringAxisAgeMonths.
  ///
  /// In it, this message translates to:
  /// **'Età (mesi)'**
  String get monitoringAxisAgeMonths;

  /// No description provided for @monitoringAxisWeight.
  ///
  /// In it, this message translates to:
  /// **'Peso ({unit})'**
  String monitoringAxisWeight(String unit);

  /// No description provided for @monitoringTooltipAge.
  ///
  /// In it, this message translates to:
  /// **'{months, plural, =1{1 mese} other{{months} mesi}}'**
  String monitoringTooltipAge(int months);

  /// No description provided for @monitoringHistoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get monitoringHistoryTitle;

  /// No description provided for @monitoringDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare la misurazione?'**
  String get monitoringDeleteTitle;

  /// No description provided for @monitoringDeleteMessage.
  ///
  /// In it, this message translates to:
  /// **'Il peso del {date} verrà tolto dallo storico.'**
  String monitoringDeleteMessage(String date);

  /// No description provided for @monitoringSheetTitleNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova misurazione'**
  String get monitoringSheetTitleNew;

  /// No description provided for @monitoringSheetTitleEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica misurazione'**
  String get monitoringSheetTitleEdit;

  /// No description provided for @monitoringFieldDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get monitoringFieldDate;

  /// No description provided for @monitoringFieldWeightKg.
  ///
  /// In it, this message translates to:
  /// **'Peso (kg)'**
  String get monitoringFieldWeightKg;

  /// No description provided for @monitoringFieldWeightLb.
  ///
  /// In it, this message translates to:
  /// **'Peso (lb)'**
  String get monitoringFieldWeightLb;

  /// No description provided for @monitoringFieldWeightHintKg.
  ///
  /// In it, this message translates to:
  /// **'Es. 10,5'**
  String get monitoringFieldWeightHintKg;

  /// No description provided for @monitoringFieldWeightHintLb.
  ///
  /// In it, this message translates to:
  /// **'Es. 22,5'**
  String get monitoringFieldWeightHintLb;

  /// No description provided for @monitoringFieldNote.
  ///
  /// In it, this message translates to:
  /// **'Nota (facoltativa)'**
  String get monitoringFieldNote;

  /// No description provided for @monitoringErrorWeight.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un peso valido, maggiore di zero.'**
  String get monitoringErrorWeight;

  /// No description provided for @monitoringErrorDateFuture.
  ///
  /// In it, this message translates to:
  /// **'La data non può essere nel futuro.'**
  String get monitoringErrorDateFuture;

  /// No description provided for @monitoringErrorDateBirth.
  ///
  /// In it, this message translates to:
  /// **'La data è precedente alla nascita di {petName}.'**
  String monitoringErrorDateBirth(String petName);

  /// No description provided for @monitoringSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare la misurazione: riprova.'**
  String get monitoringSaveFailed;

  /// No description provided for @monitoringDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare la misurazione: riprova.'**
  String get monitoringDeleteFailed;

  /// No description provided for @monitoringActivityTitle.
  ///
  /// In it, this message translates to:
  /// **'Attività'**
  String get monitoringActivityTitle;

  /// No description provided for @monitoringActivitySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Le passeggiate di {petName} nelle ultime settimane.'**
  String monitoringActivitySubtitle(String petName);

  /// No description provided for @monitoringActivityDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza'**
  String get monitoringActivityDistance;

  /// No description provided for @monitoringActivityTime.
  ///
  /// In it, this message translates to:
  /// **'Tempo'**
  String get monitoringActivityTime;

  /// No description provided for @monitoringActivityStatWalks.
  ///
  /// In it, this message translates to:
  /// **'Passeggiate'**
  String get monitoringActivityStatWalks;

  /// No description provided for @monitoringActivityEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna passeggiata negli ultimi 3 mesi. Registra una passeggiata dalla scheda Passeggiate per vedere qui l\'attività di {petName}.'**
  String monitoringActivityEmpty(String petName);

  /// No description provided for @monitoringActivityWeekOf.
  ///
  /// In it, this message translates to:
  /// **'Settimana dal {date}'**
  String monitoringActivityWeekOf(String date);

  /// No description provided for @monitoringActivityWalkCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 passeggiata} other{{count} passeggiate}}'**
  String monitoringActivityWalkCount(int count);

  /// No description provided for @medCatVisit.
  ///
  /// In it, this message translates to:
  /// **'Visite'**
  String get medCatVisit;

  /// No description provided for @medCatExam.
  ///
  /// In it, this message translates to:
  /// **'Esami'**
  String get medCatExam;

  /// No description provided for @medCatVaccine.
  ///
  /// In it, this message translates to:
  /// **'Vaccini'**
  String get medCatVaccine;

  /// No description provided for @medCatTherapy.
  ///
  /// In it, this message translates to:
  /// **'Terapie'**
  String get medCatTherapy;

  /// No description provided for @medCatDocument.
  ///
  /// In it, this message translates to:
  /// **'Documenti'**
  String get medCatDocument;

  /// No description provided for @medCatCondition.
  ///
  /// In it, this message translates to:
  /// **'Patologie'**
  String get medCatCondition;

  /// No description provided for @medCatVisitOne.
  ///
  /// In it, this message translates to:
  /// **'Visita'**
  String get medCatVisitOne;

  /// No description provided for @medCatExamOne.
  ///
  /// In it, this message translates to:
  /// **'Esame'**
  String get medCatExamOne;

  /// No description provided for @medCatVaccineOne.
  ///
  /// In it, this message translates to:
  /// **'Vaccino'**
  String get medCatVaccineOne;

  /// No description provided for @medCatTherapyOne.
  ///
  /// In it, this message translates to:
  /// **'Terapia'**
  String get medCatTherapyOne;

  /// No description provided for @medCatDocumentOne.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get medCatDocumentOne;

  /// No description provided for @medCatCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 registrato} other{{count} registrati}}'**
  String medCatCount(int count);

  /// No description provided for @medSubCheckup.
  ///
  /// In it, this message translates to:
  /// **'Visita di controllo'**
  String get medSubCheckup;

  /// No description provided for @medSubSpecialist.
  ///
  /// In it, this message translates to:
  /// **'Visita specialistica'**
  String get medSubSpecialist;

  /// No description provided for @medSubFirstVisit.
  ///
  /// In it, this message translates to:
  /// **'Prima visita'**
  String get medSubFirstVisit;

  /// No description provided for @medSubEmergency.
  ///
  /// In it, this message translates to:
  /// **'Urgenza'**
  String get medSubEmergency;

  /// No description provided for @medSubPostSurgery.
  ///
  /// In it, this message translates to:
  /// **'Controllo post-operatorio'**
  String get medSubPostSurgery;

  /// No description provided for @medSubBlood.
  ///
  /// In it, this message translates to:
  /// **'Analisi del sangue'**
  String get medSubBlood;

  /// No description provided for @medSubUrine.
  ///
  /// In it, this message translates to:
  /// **'Esame delle urine'**
  String get medSubUrine;

  /// No description provided for @medSubStool.
  ///
  /// In it, this message translates to:
  /// **'Esame delle feci'**
  String get medSubStool;

  /// No description provided for @medSubXray.
  ///
  /// In it, this message translates to:
  /// **'Radiografia'**
  String get medSubXray;

  /// No description provided for @medSubUltrasound.
  ///
  /// In it, this message translates to:
  /// **'Ecografia'**
  String get medSubUltrasound;

  /// No description provided for @medSubAntiparasitic.
  ///
  /// In it, this message translates to:
  /// **'Antiparassitario'**
  String get medSubAntiparasitic;

  /// No description provided for @medSubMedication.
  ///
  /// In it, this message translates to:
  /// **'Farmaco'**
  String get medSubMedication;

  /// No description provided for @medSubOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get medSubOther;

  /// No description provided for @medAddTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa vuoi aggiungere?'**
  String get medAddTitle;

  /// No description provided for @medAddAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get medAddAction;

  /// No description provided for @medCatConditionOne.
  ///
  /// In it, this message translates to:
  /// **'Patologia'**
  String get medCatConditionOne;

  /// No description provided for @medHistoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Storico'**
  String get medHistoryTitle;

  /// No description provided for @medHistorySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tutti gli eventi registrati, mese per mese.'**
  String get medHistorySubtitle;

  /// No description provided for @medHistoryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun evento registrato'**
  String get medHistoryEmpty;

  /// No description provided for @medHistoryPrevMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese precedente'**
  String get medHistoryPrevMonth;

  /// No description provided for @medHistoryNextMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese successivo'**
  String get medHistoryNextMonth;

  /// No description provided for @medHistoryDayTitle.
  ///
  /// In it, this message translates to:
  /// **'Eventi del {date}'**
  String medHistoryDayTitle(String date);

  /// No description provided for @medHistoryDayEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun evento in questo giorno'**
  String get medHistoryDayEmpty;

  /// No description provided for @medHistoryDayA11y.
  ///
  /// In it, this message translates to:
  /// **'{date}: {count, plural, =0{nessun evento} =1{1 evento} other{{count} eventi}}'**
  String medHistoryDayA11y(String date, int count);

  /// No description provided for @medHistorySend.
  ///
  /// In it, this message translates to:
  /// **'Invia storico'**
  String get medHistorySend;

  /// No description provided for @medHistorySendAll.
  ///
  /// In it, this message translates to:
  /// **'Tutto lo storico (PDF)'**
  String get medHistorySendAll;

  /// No description provided for @medHistorySendAllSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Un PDF con tutti gli eventi in ordine di data'**
  String get medHistorySendAllSubtitle;

  /// No description provided for @medHistorySendFiles.
  ///
  /// In it, this message translates to:
  /// **'Singoli file'**
  String get medHistorySendFiles;

  /// No description provided for @medHistoryPreparing.
  ///
  /// In it, this message translates to:
  /// **'Preparo il PDF…'**
  String get medHistoryPreparing;

  /// No description provided for @medHistoryExportFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a preparare il PDF. Riprova.'**
  String get medHistoryExportFailed;

  /// No description provided for @medHistoryConditionsMissing.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a leggere le patologie: nel PDF non ci sono.'**
  String get medHistoryConditionsMissing;

  /// No description provided for @medPdfTitle.
  ///
  /// In it, this message translates to:
  /// **'Storico clinico di {petName}'**
  String medPdfTitle(String petName);

  /// No description provided for @medPdfSpeciesBreed.
  ///
  /// In it, this message translates to:
  /// **'Specie e razza'**
  String get medPdfSpeciesBreed;

  /// No description provided for @medPdfBirthDate.
  ///
  /// In it, this message translates to:
  /// **'Data di nascita'**
  String get medPdfBirthDate;

  /// No description provided for @medPdfExportDate.
  ///
  /// In it, this message translates to:
  /// **'Data di esportazione'**
  String get medPdfExportDate;

  /// No description provided for @medPdfColDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get medPdfColDate;

  /// No description provided for @medPdfColCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get medPdfColCategory;

  /// No description provided for @medPdfColTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get medPdfColTitle;

  /// No description provided for @medPdfColNotes.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get medPdfColNotes;

  /// No description provided for @medPdfNoDate.
  ///
  /// In it, this message translates to:
  /// **'Senza data'**
  String get medPdfNoDate;

  /// No description provided for @medPdfEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun evento registrato.'**
  String get medPdfEmpty;

  /// No description provided for @medPdfPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina {page} di {pages}'**
  String medPdfPage(int page, int pages);

  /// No description provided for @medPdfConditionOngoing.
  ///
  /// In it, this message translates to:
  /// **'In corso'**
  String get medPdfConditionOngoing;

  /// No description provided for @medPdfConditionResolved.
  ///
  /// In it, this message translates to:
  /// **'Risolta'**
  String get medPdfConditionResolved;

  /// No description provided for @medPdfConditionResolvedOn.
  ///
  /// In it, this message translates to:
  /// **'Risolta il {date}'**
  String medPdfConditionResolvedOn(String date);

  /// No description provided for @medPdfConditionTherapy.
  ///
  /// In it, this message translates to:
  /// **'Terapia: {therapy}'**
  String medPdfConditionTherapy(String therapy);

  /// No description provided for @medNewVisit.
  ///
  /// In it, this message translates to:
  /// **'Nuova visita'**
  String get medNewVisit;

  /// No description provided for @medNewExam.
  ///
  /// In it, this message translates to:
  /// **'Nuovo esame'**
  String get medNewExam;

  /// No description provided for @medNewVaccine.
  ///
  /// In it, this message translates to:
  /// **'Nuovo vaccino'**
  String get medNewVaccine;

  /// No description provided for @medNewTherapy.
  ///
  /// In it, this message translates to:
  /// **'Nuova terapia'**
  String get medNewTherapy;

  /// No description provided for @medNewDocument.
  ///
  /// In it, this message translates to:
  /// **'Nuovo documento'**
  String get medNewDocument;

  /// No description provided for @medNewCondition.
  ///
  /// In it, this message translates to:
  /// **'Nuova patologia'**
  String get medNewCondition;

  /// No description provided for @medEmptyVisitTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna visita registrata'**
  String get medEmptyVisitTitle;

  /// No description provided for @medEmptyVisitBody.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi le visite di {petName} per ritrovare controlli e indicazioni del veterinario in un posto solo.'**
  String medEmptyVisitBody(String petName);

  /// No description provided for @medEmptyVisitAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi la prima visita'**
  String get medEmptyVisitAction;

  /// No description provided for @medEmptyExamTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun esame registrato'**
  String get medEmptyExamTitle;

  /// No description provided for @medEmptyExamBody.
  ///
  /// In it, this message translates to:
  /// **'Carica gli esami di {petName}, come analisi del sangue o radiografie, per averli sempre a portata di mano.'**
  String medEmptyExamBody(String petName);

  /// No description provided for @medEmptyExamAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi il primo esame'**
  String get medEmptyExamAction;

  /// No description provided for @medEmptyVaccineTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun vaccino registrato'**
  String get medEmptyVaccineTitle;

  /// No description provided for @medEmptyVaccineBody.
  ///
  /// In it, this message translates to:
  /// **'Tieni qui i vaccini e i richiami di {petName}, con la data di ogni somministrazione.'**
  String medEmptyVaccineBody(String petName);

  /// No description provided for @medEmptyVaccineAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi il primo vaccino'**
  String get medEmptyVaccineAction;

  /// No description provided for @medEmptyTherapyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna terapia registrata'**
  String get medEmptyTherapyTitle;

  /// No description provided for @medEmptyTherapyBody.
  ///
  /// In it, this message translates to:
  /// **'Annota le terapie di {petName}: farmaci, antiparassitari e cure in corso o passate.'**
  String medEmptyTherapyBody(String petName);

  /// No description provided for @medEmptyTherapyAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi la prima terapia'**
  String get medEmptyTherapyAction;

  /// No description provided for @medEmptyDocumentTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento caricato'**
  String get medEmptyDocumentTitle;

  /// No description provided for @medEmptyDocumentBody.
  ///
  /// In it, this message translates to:
  /// **'Carica referti, certificati e altri documenti di {petName} per condividerli con il veterinario.'**
  String medEmptyDocumentBody(String petName);

  /// No description provided for @medEmptyDocumentAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi il primo documento'**
  String get medEmptyDocumentAction;

  /// No description provided for @medEmptyConditionTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna patologia registrata'**
  String get medEmptyConditionTitle;

  /// No description provided for @medEmptyConditionBody.
  ///
  /// In it, this message translates to:
  /// **'Annota le malattie di {petName}, in corso o già risolte, con date e terapia.'**
  String medEmptyConditionBody(String petName);

  /// No description provided for @medEmptyConditionAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi la prima patologia'**
  String get medEmptyConditionAction;

  /// No description provided for @medFieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get medFieldTitle;

  /// No description provided for @medFieldCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get medFieldCategory;

  /// No description provided for @medFieldType.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get medFieldType;

  /// No description provided for @medFieldTypeNone.
  ///
  /// In it, this message translates to:
  /// **'Non specificato'**
  String get medFieldTypeNone;

  /// No description provided for @medFieldEventDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get medFieldEventDate;

  /// No description provided for @medFieldNotes.
  ///
  /// In it, this message translates to:
  /// **'Note'**
  String get medFieldNotes;

  /// No description provided for @medFieldNotesHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi una nota facoltativa.'**
  String get medFieldNotesHint;

  /// No description provided for @medFieldFile.
  ///
  /// In it, this message translates to:
  /// **'Allegato'**
  String get medFieldFile;

  /// No description provided for @medAttachAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi file'**
  String get medAttachAdd;

  /// No description provided for @medAttachChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia file'**
  String get medAttachChange;

  /// No description provided for @medEditDetailsTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica dettagli'**
  String get medEditDetailsTitle;

  /// No description provided for @medTitleRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un titolo o allega un file.'**
  String get medTitleRequired;

  /// No description provided for @medDateInvalid.
  ///
  /// In it, this message translates to:
  /// **'Data non valida (gg/mm/aaaa).'**
  String get medDateInvalid;

  /// No description provided for @medDatePlaceholder.
  ///
  /// In it, this message translates to:
  /// **'gg/mm/aaaa'**
  String get medDatePlaceholder;

  /// No description provided for @medSuggestHint.
  ///
  /// In it, this message translates to:
  /// **'Dal titolo sembra: {category}. Vuoi classificarlo così?'**
  String medSuggestHint(String category);

  /// No description provided for @medSuggestApply.
  ///
  /// In it, this message translates to:
  /// **'Sì, classifica'**
  String get medSuggestApply;

  /// No description provided for @medSuggestPill.
  ///
  /// In it, this message translates to:
  /// **'Forse: {category}'**
  String medSuggestPill(String category);

  /// No description provided for @medActionClassifyAs.
  ///
  /// In it, this message translates to:
  /// **'Classifica come {category}'**
  String medActionClassifyAs(String category);

  /// No description provided for @medActionEditDetails.
  ///
  /// In it, this message translates to:
  /// **'Modifica dettagli'**
  String get medActionEditDetails;

  /// No description provided for @medCondName.
  ///
  /// In it, this message translates to:
  /// **'Nome della patologia'**
  String get medCondName;

  /// No description provided for @medCondNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi il nome della patologia.'**
  String get medCondNameRequired;

  /// No description provided for @medCondStarted.
  ///
  /// In it, this message translates to:
  /// **'Data di inizio'**
  String get medCondStarted;

  /// No description provided for @medCondStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get medCondStatus;

  /// No description provided for @medCondOngoing.
  ///
  /// In it, this message translates to:
  /// **'In corso'**
  String get medCondOngoing;

  /// No description provided for @medCondResolved.
  ///
  /// In it, this message translates to:
  /// **'Risolta'**
  String get medCondResolved;

  /// No description provided for @medCondEnded.
  ///
  /// In it, this message translates to:
  /// **'Data di fine'**
  String get medCondEnded;

  /// No description provided for @medCondEndBeforeStart.
  ///
  /// In it, this message translates to:
  /// **'La data di fine è precedente a quella di inizio.'**
  String get medCondEndBeforeStart;

  /// No description provided for @medCondTherapy.
  ///
  /// In it, this message translates to:
  /// **'Terapia'**
  String get medCondTherapy;

  /// No description provided for @medCondTherapyHint.
  ///
  /// In it, this message translates to:
  /// **'Farmaci, dosi, durata…'**
  String get medCondTherapyHint;

  /// No description provided for @medCondAttachment.
  ///
  /// In it, this message translates to:
  /// **'Ricetta o documenti'**
  String get medCondAttachment;

  /// No description provided for @medCondSince.
  ///
  /// In it, this message translates to:
  /// **'Dal {date}'**
  String medCondSince(String date);

  /// No description provided for @medCondPeriod.
  ///
  /// In it, this message translates to:
  /// **'{start} – {end}'**
  String medCondPeriod(String start, String end);

  /// No description provided for @medCondSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a salvare la patologia. Riprova.'**
  String get medCondSaveFailed;

  /// No description provided for @medCondDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a eliminare la patologia. Riprova.'**
  String get medCondDeleteFailed;

  /// No description provided for @medCondDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa patologia?'**
  String get medCondDeleteTitle;

  /// No description provided for @medCondDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'«{name}» verrà eliminata.'**
  String medCondDeleteBody(String name);

  /// No description provided for @medCondLoadError.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere le patologie. Controlla la connessione e riprova.'**
  String get medCondLoadError;

  /// No description provided for @medCondUploadFailed.
  ///
  /// In it, this message translates to:
  /// **'Non sono riuscito a caricare il file. Riprova.'**
  String get medCondUploadFailed;

  /// No description provided for @medCondOpenFile.
  ///
  /// In it, this message translates to:
  /// **'Apri allegato'**
  String get medCondOpenFile;

  /// No description provided for @medicalRecordSourceFromReminder.
  ///
  /// In it, this message translates to:
  /// **'Da un promemoria'**
  String get medicalRecordSourceFromReminder;

  /// No description provided for @reminderCatGrooming.
  ///
  /// In it, this message translates to:
  /// **'Toelettatura'**
  String get reminderCatGrooming;

  /// No description provided for @reminderCatOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get reminderCatOther;

  /// No description provided for @remindersFormCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get remindersFormCategory;

  /// No description provided for @remindersFormSubtype.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get remindersFormSubtype;

  /// No description provided for @remindersFormSubtypeNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get remindersFormSubtypeNone;

  /// No description provided for @remindersDoneTitle.
  ///
  /// In it, this message translates to:
  /// **'Fatto?'**
  String get remindersDoneTitle;

  /// No description provided for @remindersDoneRecordHint.
  ///
  /// In it, this message translates to:
  /// **'Registralo nello storico di {pet}.'**
  String remindersDoneRecordHint(String pet);

  /// No description provided for @remindersDonePlainHint.
  ///
  /// In it, this message translates to:
  /// **'Lo segno come fatto?'**
  String get remindersDonePlainHint;

  /// No description provided for @remindersDoneFieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get remindersDoneFieldTitle;

  /// No description provided for @remindersDoneFieldDate.
  ///
  /// In it, this message translates to:
  /// **'Quando è successo'**
  String get remindersDoneFieldDate;

  /// No description provided for @remindersDoneFieldNotes.
  ///
  /// In it, this message translates to:
  /// **'Note (facoltative)'**
  String get remindersDoneFieldNotes;

  /// No description provided for @remindersDoneConfirmRecord.
  ///
  /// In it, this message translates to:
  /// **'Sì, registra'**
  String get remindersDoneConfirmRecord;

  /// No description provided for @remindersDoneConfirmPlain.
  ///
  /// In it, this message translates to:
  /// **'Sì, fatto'**
  String get remindersDoneConfirmPlain;

  /// No description provided for @remindersDonePostpone.
  ///
  /// In it, this message translates to:
  /// **'Rimanda'**
  String get remindersDonePostpone;

  /// No description provided for @remindersDoneNotDone.
  ///
  /// In it, this message translates to:
  /// **'Non fatto'**
  String get remindersDoneNotDone;

  /// No description provided for @remindersDoneRecorded.
  ///
  /// In it, this message translates to:
  /// **'Registrato nello storico di {pet}.'**
  String remindersDoneRecorded(String pet);

  /// No description provided for @remindersDoneMarked.
  ///
  /// In it, this message translates to:
  /// **'Segnato come fatto.'**
  String get remindersDoneMarked;

  /// No description provided for @remindersDoneDismissed.
  ///
  /// In it, this message translates to:
  /// **'Segnato come non fatto.'**
  String get remindersDoneDismissed;

  /// No description provided for @remindersDonePostponed.
  ///
  /// In it, this message translates to:
  /// **'Te lo richiedo domani.'**
  String get remindersDonePostponed;

  /// No description provided for @remindersDoneTooltip.
  ///
  /// In it, this message translates to:
  /// **'Segna come fatto'**
  String get remindersDoneTooltip;

  /// No description provided for @remindersNotifPermTitle.
  ///
  /// In it, this message translates to:
  /// **'Vuoi ricevere gli avvisi?'**
  String get remindersNotifPermTitle;

  /// No description provided for @remindersNotifPermBody.
  ///
  /// In it, this message translates to:
  /// **'Per avvisarti quando un promemoria scade, VetApp ha bisogno del permesso per le notifiche. Puoi cambiarlo in ogni momento da Impostazioni.'**
  String get remindersNotifPermBody;

  /// No description provided for @remindersNotifPermNotNow.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get remindersNotifPermNotNow;

  /// No description provided for @remindersNotifPermAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get remindersNotifPermAllow;

  /// No description provided for @remindersNotifOffBanner.
  ///
  /// In it, this message translates to:
  /// **'Le notifiche sono disattivate: i promemoria non suoneranno'**
  String get remindersNotifOffBanner;

  /// No description provided for @remindersNotifOffAction.
  ///
  /// In it, this message translates to:
  /// **'Attiva'**
  String get remindersNotifOffAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

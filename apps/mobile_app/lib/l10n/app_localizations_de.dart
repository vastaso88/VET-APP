// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get petsConsentFullText =>
      'Um Ihnen genauer raten zu können, darf der Assistent die Krankenakte Ihres Tieres lesen. Wenn Sie eine Frage stellen, kann er die drei neuesten Einträge lesen, mit Titel, Kategorie (Besuch, Untersuchung, Impfung, Therapie oder Dokument), Datum des Ereignisses, Beschreibung und Text der angehängten Dokumente, auch wenn sie nichts mit der Frage zu tun haben. Er kann außerdem frühere Erkrankungen lesen, die noch andauern, mit Name und Beginndatum, höchstens fünf. Wenn Sie um die Erklärung einer Untersuchung bitten, kann er die dazugehörigen Dokumente lesen, höchstens zwei. Von einem sehr langen Dokument liest er nur den Anfang. Was er liest, wird an den externen Anbieter für künstliche Intelligenz gesendet, der die Antwort verfasst. Quokka verwendet es nur, um Ihnen zu antworten. Sie können die Einwilligung jederzeit im Tierprofil oder in den Einstellungen widerrufen: Der Widerruf gilt für alle folgenden Anfragen.';

  @override
  String get appTitle => 'VET APP';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonSkip => 'Überspringen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonLoading => 'Wird geladen…';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonContinue => 'Fortfahren';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonShare => 'Teilen';

  @override
  String get languagePickerTitle => 'Wählen Sie Ihre Sprache';

  @override
  String get languagePickerSubtitle =>
      'Sie können sie jederzeit in den Einstellungen ändern.';

  @override
  String get languageSectionTitle => 'Sprache';

  @override
  String get languageSectionHint =>
      'Wenn Sie die Sprache ändern, ändern sich auch die Standard-Maßeinheiten, sofern Sie diese nicht selbst gewählt haben.';

  @override
  String get authBannerCheckFieldsTitle => 'Felder prüfen';

  @override
  String get authLoginFieldsInvalidMessage =>
      'Bitte geben Sie eine gültige E-Mail-Adresse und ein Passwort mit mindestens 6 Zeichen ein.';

  @override
  String get authLoginLoadingTitle => 'Anmeldung läuft';

  @override
  String get authLoginLoadingMessage => 'Ihre Zugangsdaten werden geprüft.';

  @override
  String get authLoginSuccessTitle => 'Angemeldet';

  @override
  String get authLoginSuccessMessage =>
      'Die Sitzung ist bereit. Sie werden zur Hauptansicht weitergeleitet.';

  @override
  String get authLoginFailureTitle => 'Anmeldung fehlgeschlagen';

  @override
  String get authLoginTitle => 'Willkommen zurück.';

  @override
  String get authLoginSubtitle =>
      'Melden Sie sich an, um Ihre Tiere, Erinnerungen und Dokumente wiederzufinden.';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authEmailHint => 'name@domain.de';

  @override
  String get authEmailRequired => 'Bitte geben Sie Ihre E-Mail-Adresse ein.';

  @override
  String get authEmailInvalid => 'Ungültige E-Mail-Adresse.';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authPasswordHint => 'Mindestens 6 Zeichen';

  @override
  String get authPasswordRequiredLogin => 'Bitte geben Sie Ihr Passwort ein.';

  @override
  String get authPasswordRequiredNew => 'Bitte geben Sie ein Passwort ein.';

  @override
  String get authPasswordMinLength => 'Mindestens 6 Zeichen.';

  @override
  String get authPasswordShow => 'Passwort anzeigen';

  @override
  String get authPasswordHide => 'Passwort verbergen';

  @override
  String get authRememberMe => 'Angemeldet bleiben';

  @override
  String get authForgotPasswordLink => 'Passwort vergessen?';

  @override
  String get authLoginButton => 'Anmelden';

  @override
  String get authNoAccountRegisterLink => 'Noch kein Konto? Registrieren';

  @override
  String get authTermsOfServiceLabel => 'Nutzungsbedingungen';

  @override
  String get authPrivacyPolicyLabel => 'Datenschutzerklärung';

  @override
  String authTermsAcceptance(String terms, String privacy) {
    return 'Ich akzeptiere die $terms und die $privacy';
  }

  @override
  String get authRegisterCheckTitle => 'Noch eine letzte Prüfung';

  @override
  String get authRegisterTermsRequired =>
      'Sie müssen Datenschutz und Haftungsausschluss akzeptieren, um fortzufahren.';

  @override
  String get authRegisterFieldsInvalid =>
      'Bitte prüfen Sie die Felder: Name, E-Mail und Passwort müssen gültig sein.';

  @override
  String get authRegisterLoadingTitle => 'Konto wird erstellt';

  @override
  String get authRegisterLoadingMessage =>
      'Ihr Konto wird erstellt und die erste Sitzung vorbereitet.';

  @override
  String get authRegisterSuccessTitle => 'Konto bereit';

  @override
  String get authRegisterSuccessMessage =>
      'Registrierung abgeschlossen. Sie werden zur Startseite weitergeleitet.';

  @override
  String get authRegisterFailureTitle => 'Konto nicht erstellt';

  @override
  String get authRegisterTitle => 'Erstellen Sie Ihr Profil.';

  @override
  String get authRegisterSubtitle =>
      'Nur wenige Angaben, um Gesundheit und Dokumente Ihrer Tiere zu verwalten.';

  @override
  String get authNameLabel => 'Name';

  @override
  String get authNameHint => 'Ihr Name';

  @override
  String get authNameRequired => 'Bitte geben Sie Ihren Namen ein.';

  @override
  String get authConfirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get authConfirmPasswordHint => 'Passwort wiederholen';

  @override
  String get authPasswordsMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get authRegisterButton => 'Konto erstellen';

  @override
  String get authHaveAccountLoginLink => 'Sie haben schon ein Konto? Anmelden';

  @override
  String get authResetInvalidTitle => 'Ungültige E-Mail';

  @override
  String get authResetInvalidMessage =>
      'Bitte geben Sie eine korrekte E-Mail-Adresse ein, um fortzufahren.';

  @override
  String get authResetLoadingTitle => 'Wird gesendet';

  @override
  String get authResetLoadingMessage =>
      'Ihre Anfrage zur Passwortwiederherstellung wird vorbereitet.';

  @override
  String get authResetSuccessTitle => 'E-Mail gesendet';

  @override
  String get authResetSuccessMessage =>
      'Wenn das Konto existiert, erhalten Sie einen Link zur Wiederherstellung des Zugangs.';

  @override
  String get authResetFailureTitle => 'Senden fehlgeschlagen';

  @override
  String get authResetTitle => 'Zugang wiederherstellen.';

  @override
  String get authResetSubtitle =>
      'Geben Sie Ihre E-Mail-Adresse ein: Wir senden Ihnen einen Link zum Zurücksetzen des Passworts.';

  @override
  String get authResetSendButton => 'Link senden';

  @override
  String get authBackToLoginLink => 'Zurück zur Anmeldung';

  @override
  String get authSetPasswordLoadingTitle => 'Wird aktualisiert';

  @override
  String get authSetPasswordLoadingMessage =>
      'Ihr neues Passwort wird gespeichert.';

  @override
  String get authSetPasswordFailureTitle => 'Aktualisierung fehlgeschlagen';

  @override
  String get authSetPasswordTitle => 'Neues Passwort festlegen.';

  @override
  String get authSetPasswordSubtitle =>
      'Wählen Sie ein neues Passwort für Ihr Konto.';

  @override
  String get authNewPasswordLabel => 'Neues Passwort';

  @override
  String get authSetPasswordSaveButton => 'Neues Passwort speichern';

  @override
  String get authLegalShareTooltip => 'Teilen oder herunterladen';

  @override
  String get authLegalLoadError =>
      'Der Text kann gerade nicht geladen werden. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get authLegalPreparingNotice =>
      'Der vollständige Text der Datenschutzerklärung ist in Vorbereitung und wird hier bald verfügbar sein, mit der Möglichkeit zum Herunterladen.';

  @override
  String get authHubTitle => 'Quokka: Ihre Tiere immer griffbereit';

  @override
  String get authHubSubtitle =>
      'Melden Sie sich in Ihrem Konto an oder erstellen Sie in wenigen Sekunden ein neues.';

  @override
  String get authHubCreateAccount => 'Konto erstellen';

  @override
  String get authHubPrivacyNote =>
      'Ihre Daten bleiben privat und werden nur zur Verwaltung des Profils Ihres Tieres verwendet.';

  @override
  String get authErrorEmailExists =>
      'Mit dieser E-Mail-Adresse gibt es bereits ein Konto. Versuchen Sie, sich anzumelden.';

  @override
  String get authErrorWeakPassword =>
      'Das Passwort ist zu schwach: Verwenden Sie mindestens 6 Zeichen, am besten mit Zahlen oder Großbuchstaben.';

  @override
  String get authErrorEmailInvalid =>
      'Die E-Mail-Adresse scheint nicht gültig zu sein.';

  @override
  String get authErrorNoConnection =>
      'Keine Verbindung. Prüfen Sie Ihr Netzwerk und versuchen Sie es erneut.';

  @override
  String get authErrorLinkExpired =>
      'Der Link ist nicht mehr gültig oder wurde bereits verwendet. Fordern Sie auf dem Wiederherstellungsbildschirm einen neuen an.';

  @override
  String get authErrorRateLimit =>
      'Sie haben in kurzer Zeit zu viele E-Mails angefordert. Warten Sie ein paar Minuten und versuchen Sie es erneut.';

  @override
  String get authErrorInvalidCredentials =>
      'E-Mail oder Passwort nicht korrekt.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Bitte bestätigen Sie zuerst Ihre E-Mail-Adresse: Sehen Sie in Ihr Postfach und öffnen Sie den Link, den wir Ihnen geschickt haben.';

  @override
  String get authErrorEmailNotFound =>
      'Mit dieser E-Mail-Adresse existiert kein Konto.';

  @override
  String get authErrorGeneric =>
      'Etwas ist nicht wie erwartet gelaufen. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get authNetworkTimeout =>
      'Die Anfrage hat zu lange gedauert. Bitte versuchen Sie es erneut.';

  @override
  String get authNetworkUnexpected =>
      'Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.';

  @override
  String get consentsErrorLoad =>
      'Ihre Einwilligungen konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get consentsErrorSave =>
      'Ihre Auswahl konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get billingErrorStatus =>
      'Ihr Abo konnte nicht geprüft werden. Bitte versuchen Sie es erneut.';

  @override
  String get billingErrorSelectPlan =>
      'Der gewählte Tarif konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get billingIncludedPets => 'Profile Ihrer Tiere';

  @override
  String get billingIncludedAssistant =>
      'Assistent für Fragen zu Gesundheit, Verhalten und Alltag';

  @override
  String get billingIncludedChatMedia => 'Fotos, PDFs und Sprachdiktat im Chat';

  @override
  String get billingIncludedReminders => 'Erinnerungen';

  @override
  String get billingIncludedNearbyServices => 'Tierservices in der Nähe';

  @override
  String get billingFreePlaceholder =>
      'Grenzen des Free-Tarifs: noch festzulegen';

  @override
  String get billingPlusPlaceholder =>
      'Zusatzfunktionen des Plus-Tarifs: noch festzulegen';

  @override
  String get billingProPlaceholder =>
      'Zusatzfunktionen des Pro-Tarifs: noch festzulegen';

  @override
  String get billingPlanBadgeRecommended => 'Empfohlen';

  @override
  String get billingIncludedInAllPlans => 'In allen Tarifen enthalten';

  @override
  String get billingPriceFree => 'Kostenlos';

  @override
  String billingPricePerMonth(String amount) {
    return '$amount/Monat';
  }

  @override
  String billingPricePerMonthYearly(String amount) {
    return '$amount/Monat, jährlich abgerechnet';
  }

  @override
  String get billingTitle => 'Abo und Zahlungen';

  @override
  String billingPlanSwitched(String plan) {
    return 'Sie nutzen jetzt den Tarif $plan.';
  }

  @override
  String get billingPaymentHistory => 'Zahlungsverlauf';

  @override
  String get billingPaymentHistoryComingSoon =>
      'Ihre Rechnungen und Belege können Sie hier einsehen.';

  @override
  String get billingComparePlans => 'Tarife vergleichen';

  @override
  String get billingPaymentMethodsSection => 'Zahlungsmethoden';

  @override
  String get billingInvoicingSection => 'Abrechnung';

  @override
  String get billingTrialBannerTitle => 'Kostenlose Testphase läuft';

  @override
  String billingTrialBannerDaysLeft(int days) {
    return 'Sie haben noch $days Tage gratis, keine Karte nötig. Wählen Sie jederzeit einen Tarif, spätestens zum Ende der Testphase.';
  }

  @override
  String get billingTrialBannerEnding =>
      'Die kostenlose Testphase endet bald: Wählen Sie einen Tarif, um Quokka weiter zu nutzen.';

  @override
  String get billingDeveloperBanner =>
      'Entwicklerkonto: unbegrenzter Zugang, kein Tarif nötig.';

  @override
  String get billingCurrentPlanLabel => 'Ihr Tarif';

  @override
  String billingRenewalOn(String date) {
    return 'Verlängerung am $date';
  }

  @override
  String get billingCycleMonthly => 'Monatlich';

  @override
  String get billingCycleYearly => 'Jährlich';

  @override
  String get billingCurrentPlanButton => 'Aktueller Tarif';

  @override
  String get billingBackToFree => 'Zurück zu Free';

  @override
  String billingSwitchToPlan(String plan) {
    return 'Zu $plan wechseln';
  }

  @override
  String billingCardExpires(String expiry) {
    return 'Gültig bis $expiry';
  }

  @override
  String billingCardExpiresDefault(String expiry) {
    return 'Gültig bis $expiry · Standard';
  }

  @override
  String get billingSetDefault => 'Als Standard festlegen';

  @override
  String get billingRemove => 'Entfernen';

  @override
  String get billingAddPaymentMethod => 'Zahlungsmethode hinzufügen';

  @override
  String get billingCardBrandLabel => 'Kartenanbieter';

  @override
  String get billingCardLast4Label => 'Letzte 4 Ziffern';

  @override
  String get billingCardLast4Error => 'Bitte 4 Ziffern eingeben';

  @override
  String get billingExpiryMonthLabel => 'Monat';

  @override
  String get billingExpiryYearLabel => 'Jahr';

  @override
  String get billingPaywallTitle => 'Ihre kostenlose Testphase ist beendet.';

  @override
  String get billingPaywallSubtitle =>
      'Wählen Sie, wie es mit Quokka weitergeht. Den Tarif können Sie jederzeit in den Einstellungen ändern.';

  @override
  String billingChoosePlan(String plan) {
    return '$plan wählen';
  }

  @override
  String billingTrialDialogTitle(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Noch $daysLeft Testtage',
      one: 'Letzter Testtag',
    );
    return '$_temp0';
  }

  @override
  String get billingTrialDialogBody =>
      'Im Free-Tarif sind einige Funktionen eingeschränkt. Wechseln Sie zu Plus oder Pro, um nach der Testphase alles ohne Einschränkung zu nutzen.';

  @override
  String get billingTrialDialogLater => 'Später';

  @override
  String get billingTrialDialogSeePlans => 'Tarife ansehen';

  @override
  String get firstRunWelcomeTitle => 'Willkommen bei Quokka.';

  @override
  String get firstRunPlanIntroSubtitle =>
      'Wählen Sie Ihren Start: Sie können 10 Tage lang alles kostenlos und ohne Karte testen oder gleich einen Tarif wählen.';

  @override
  String get firstRunPlanOrChoose => 'ODER GLEICH EINEN TARIF WÄHLEN';

  @override
  String get firstRunTrialCardTitle => '10 Tage gratis testen';

  @override
  String get firstRunTrialCardBody =>
      'Keine Karte nötig. Nach den 10 Tagen bitten wir Sie, einen Tarif zu wählen, um weiterzumachen.';

  @override
  String get firstRunTrialStartButton => 'Testphase starten';

  @override
  String get firstRunPlanSelectButton => 'Wählen';

  @override
  String get firstRunAddPetTitle => 'Fügen Sie Ihr erstes Tier hinzu';

  @override
  String get firstRunAddPetBody =>
      'Das dauert nur ein paar Minuten: Name, Tierart und ein paar Details. Sie können es auch später unter Tiere tun.';

  @override
  String get firstRunAddPetNow => 'Jetzt hinzufügen';

  @override
  String get firstRunAddPetLater => 'Vorerst überspringen';

  @override
  String get firstRunNotificationsTitle => 'Keine Erinnerung verpassen';

  @override
  String get firstRunNotificationsBody =>
      'Aktivieren Sie Benachrichtigungen für fällige Impfungen, Medikamente und Termine. Jederzeit in den Einstellungen änderbar.';

  @override
  String get firstRunNotificationsEnable => 'Benachrichtigungen aktivieren';

  @override
  String get firstRunNotificationsLater => 'Nicht jetzt';

  @override
  String get firstRunTutorialPetsTitle => 'Ein Profil für jedes Tier';

  @override
  String get firstRunTutorialPetsBody =>
      'Tierart und Rasse, Gewicht, medizinische Notizen und Dokumente: alles übersichtlich für jedes Tier, immer griffbereit.';

  @override
  String get firstRunTutorialAssistantTitle => 'Fragen Sie Ihren Assistenten';

  @override
  String get firstRunTutorialAssistantBody =>
      'Stellen Sie Fragen zur Gesundheit Ihrer Tiere und erhalten Sie Antworten, die auf deren Situation zugeschnitten sind.';

  @override
  String get firstRunTutorialRemindersTitle => 'Keine vergessenen Termine mehr';

  @override
  String get firstRunTutorialRemindersBody =>
      'Impfungen, Medikamente und Tierarztbesuche: Legen Sie eine Erinnerung fest, und Quokka benachrichtigt Sie zur richtigen Zeit.';

  @override
  String get firstRunTutorialStart => 'Los geht\'s';

  @override
  String get chatLoadingTitle => 'Wir öffnen die Unterhaltung';

  @override
  String get chatLoadingSubtitle =>
      'Der Verlauf und der letzte verfügbare Kontext werden geladen.';

  @override
  String get chatEmptyTitle => 'Die Unterhaltung ist leer';

  @override
  String get chatEmptySubtitle =>
      'Schreiben Sie die erste Nachricht, um mit dem Assistenten zu starten.';

  @override
  String get chatEmptyAction => 'Jetzt schreiben';

  @override
  String chatEmptyGreeting(String pet) {
    return 'Hallo, ich habe eine Frage zu $pet.';
  }

  @override
  String get chatErrorTitle => 'Unterhaltung nicht verfügbar';

  @override
  String get chatErrorSubtitle =>
      'Beim Abrufen des Verlaufs ist etwas schiefgelaufen.';

  @override
  String get chatErrorAction => 'Zurück zu den Chats';

  @override
  String get chatMessageEditAction => 'Nachricht bearbeiten';

  @override
  String get chatMessageEditHint =>
      'Die Antwort und die folgenden Nachrichten werden ersetzt.';

  @override
  String chatComposerHint(String pet) {
    return 'Stellen Sie eine Frage zu $pet';
  }

  @override
  String chatNewConversationOnPet(String pet) {
    return 'Neue Unterhaltung zu $pet';
  }

  @override
  String get chatNewConversationPrompt =>
      'Schreiben Sie unten, was Sie beobachten – ich antworte sofort.';

  @override
  String get chatTypingText => 'Schreibt gerade eine Antwort...';

  @override
  String get chatTypingSlowText =>
      'Das dauert etwas länger als sonst, die Antwort kommt gleich...';

  @override
  String chatDefaultTitle(String pet) {
    return 'Chat mit $pet';
  }

  @override
  String get chatListeningText => 'Ich höre zu… Zum Beenden tippen';

  @override
  String get chatTranscribingText => 'Ich schreibe mit…';

  @override
  String get chatEditingLabel => 'Nachricht bearbeiten';

  @override
  String get chatListeningHint => 'Ich höre zu...';

  @override
  String get chatTranscribingHint => 'Ich schreibe die Nachricht mit...';

  @override
  String get chatAddPhotoTooltip => 'Foto hinzufügen';

  @override
  String get chatStopRecordingTooltip => 'Beenden und transkribieren';

  @override
  String get chatVoiceMessageTooltip => 'Sprachnachricht';

  @override
  String get chatMicPermissionNeeded =>
      'Für das Mikrofon wird eine Berechtigung benötigt.';

  @override
  String get chatMicStartFailed =>
      'Ich kann das Mikrofon nicht starten. Versuchen Sie es erneut.';

  @override
  String get chatRecordingFailed =>
      'Die Aufnahme hat nicht geklappt. Versuchen Sie es erneut.';

  @override
  String get chatRecordingReadFailed =>
      'Ich konnte die Aufnahme nicht lesen. Versuchen Sie es erneut.';

  @override
  String get chatPhotoAnalyzing => 'Ich sehe mir das Foto an...';

  @override
  String get chatPhotoReady => 'Foto bereit zum Senden';

  @override
  String get chatRemovePhotoTooltip => 'Foto entfernen';

  @override
  String chatRecordingSemantics(String listening, int minutes, String seconds) {
    return '$listening, $minutes Minuten und $seconds Sekunden';
  }

  @override
  String get chatCancelEditTooltip => 'Bearbeitung abbrechen';

  @override
  String get chatMenuTooltip => 'Chat-Optionen';

  @override
  String get chatMenuRename => 'Umbenennen';

  @override
  String get chatMenuExport => 'Chat exportieren';

  @override
  String get chatMenuSummary => 'Zusammenfassung';

  @override
  String get chatExportOpenFirst =>
      'Öffnen Sie den Chat, um ihn zu exportieren.';

  @override
  String get chatSenderYou => 'Sie';

  @override
  String get chatSenderAssistant => 'Assistent';

  @override
  String get chatRenameTitle => 'Chat umbenennen';

  @override
  String get chatRenameFieldLabel => 'Titel';

  @override
  String get chatSummaryLoading => 'Ich erstelle die Zusammenfassung…';

  @override
  String get chatSummaryTitle => 'Zusammenfassung für die Tierarztpraxis';

  @override
  String get chatSummaryDisclaimer =>
      'Diese Zusammenfassung wird automatisch erstellt und ist keine Diagnose. Für medizinische Entscheidungen wenden Sie sich bitte an einen Tierarzt.';

  @override
  String get chatSummaryEmpty => 'Keine Zusammenfassung verfügbar.';

  @override
  String get chatDeleteTitle => 'Diesen Chat löschen?';

  @override
  String get chatDeleteBody =>
      'Die Unterhaltung und ihre Nachrichten werden gelöscht.';

  @override
  String get chatFallbackPetName => 'Ihrem Tier';

  @override
  String get chatNewConversation => 'Neue Unterhaltung';

  @override
  String chatNewConversationTitle(String pet) {
    return '$pet - neue Unterhaltung';
  }

  @override
  String chatSavedConversationTitle(String pet) {
    return '$pet - Unterhaltung';
  }

  @override
  String chatRetitled(String subject) {
    return 'Chat - $subject';
  }

  @override
  String get chatStatusSaved => 'Unterhaltung gespeichert';

  @override
  String get chatStatusSent => 'Nachricht gesendet';

  @override
  String get chatStatusEdited => 'Nachricht bearbeitet';

  @override
  String get chatStatusReplyReady => 'Antwort bereit';

  @override
  String get chatTimeYesterday => 'gestern';

  @override
  String get chatTimeNow => 'jetzt';

  @override
  String get chatSummaryNotYet =>
      'Die Zusammenfassung ist nach Ihrer ersten Nachricht verfügbar.';

  @override
  String get chatEditMessageMissing =>
      'Diese Nachricht ist nicht mehr in der Unterhaltung.';

  @override
  String get chatEmptyThreadPreview => 'Neue Unterhaltung, bereit zur Nutzung.';

  @override
  String chatDemoReplyAppetite(String pet) {
    return 'Bei $pet würde ich Appetit, Trinkverhalten und Energie in den nächsten 24 Stunden im Auge behalten. Wenn es schlimmer wird, sprechen Sie besser mit einem Tierarzt.';
  }

  @override
  String get chatDemoReplyVomiting =>
      'Bei Erbrechen oder Durchfall sollten Sie die Flüssigkeitsaufnahme beobachten und einen Tierarzt kontaktieren, wenn die Symptome wiederkehren oder stark werden.';

  @override
  String chatDemoReplyVaccine(String pet) {
    return 'Ich helfe Ihnen gern, die Auffrischimpfung von $pet einzuplanen und eine gut sichtbare Erinnerung auf der Startseite anzulegen.';
  }

  @override
  String chatDemoReplyWeight(String pet) {
    return 'Beim Gewicht von $pet können wir regelmäßige Kontrollen festlegen und es mit dem letzten Tierarztbesuch vergleichen, um zu sehen, ob sich der Trend wirklich ändert.';
  }

  @override
  String chatDemoReplyDefault(String pet) {
    return 'Notiert: Zu $pet erstelle ich Ihnen eine kurze Zusammenfassung, damit Sie sofort einen praktischen, gut lesbaren Plan haben.';
  }

  @override
  String get chatErrorContactAssistant =>
      'Ich konnte den Assistenten nicht erreichen. Versuchen Sie es erneut.';

  @override
  String get chatErrorAssistantTimeout =>
      'Der Assistent hat nicht rechtzeitig geantwortet. Tippen Sie auf Wiederholen: Ist die Antwort schon fertig, hole ich sie ab.';

  @override
  String get chatErrorGeneric =>
      'Etwas ist schiefgelaufen. Versuchen Sie es erneut.';

  @override
  String get chatErrorRequestTimeout =>
      'Zeitüberschreitung bei der Anfrage. Versuchen Sie es erneut.';

  @override
  String get chatErrorEditFailed =>
      'Ich konnte die Nachricht nicht bearbeiten. Versuchen Sie es erneut.';

  @override
  String get chatErrorEditNetwork =>
      'Ich konnte die Nachricht nicht bearbeiten. Prüfen Sie Ihre Verbindung.';

  @override
  String chatErrorMessageTooLong(int max) {
    return 'Die Nachricht ist zu lang: Sie können höchstens $max Zeichen schreiben. Kürzen Sie sie und senden Sie sie erneut.';
  }

  @override
  String chatInputLimitReached(int max) {
    return 'Sie haben das Limit von $max Zeichen erreicht.';
  }

  @override
  String get chatErrorPetBootstrap =>
      'Ich konnte das Tierprofil nicht vorbereiten.';

  @override
  String get chatErrorTitleEmpty => 'Der Titel darf nicht leer sein.';

  @override
  String get chatErrorRenameFailed =>
      'Ich konnte den Chat nicht umbenennen. Versuchen Sie es erneut.';

  @override
  String get chatErrorRenameNetwork =>
      'Ich konnte den Chat nicht umbenennen. Prüfen Sie Ihre Verbindung.';

  @override
  String get chatErrorSummaryEmpty =>
      'Schreiben Sie mindestens eine Nachricht, um eine Zusammenfassung zu erhalten.';

  @override
  String get chatErrorSummaryModel =>
      'Das Modell hat nicht geantwortet. Versuchen Sie es gleich noch einmal.';

  @override
  String get chatErrorSummaryFailed =>
      'Ich konnte die Zusammenfassung nicht erstellen. Versuchen Sie es erneut.';

  @override
  String get chatErrorSummaryNetwork =>
      'Ich konnte die Zusammenfassung nicht erstellen. Prüfen Sie Ihre Verbindung.';

  @override
  String get chatErrorDeleteFailed =>
      'Ich konnte den Chat auf dem Server nicht löschen.';

  @override
  String get chatErrorListChats => 'Ich konnte Ihre Chats nicht laden.';

  @override
  String get chatErrorListPets => 'Ich konnte Ihre Tiere nicht laden.';

  @override
  String chatErrorConversationLimit(String max) {
    return 'Sie haben die maximale Zahl an Unterhaltungen ($max) für dieses Tier erreicht. Schließen Sie eine, um eine neue zu erstellen.';
  }

  @override
  String get chatErrorConversationNotFound =>
      'Diese Unterhaltung gibt es nicht mehr.';

  @override
  String get chatErrorAttachmentOffline =>
      'Sie sind offline oder die Verbindung ist instabil. Versuchen Sie es erneut, wenn Sie wieder online sind.';

  @override
  String get chatErrorAttachmentDownload =>
      'Ich konnte die Datei nicht herunterladen.';

  @override
  String get chatErrorAttachmentTooLarge =>
      'Die Datei ist zu groß (max. 4 MB).';

  @override
  String get chatErrorAttachmentUnsupported =>
      'Dieser Dateityp wird nicht unterstützt. Sie können Fotos (JPG, PNG, WEBP) oder PDFs hochladen.';

  @override
  String get chatErrorPdfTooManyPages =>
      'Das PDF überschreitet die erlaubten 30 Seiten.';

  @override
  String get chatErrorPdfUnreadable =>
      'Ich kann dieses PDF nicht lesen: Es ist möglicherweise beschädigt oder passwortgeschützt.';

  @override
  String get chatErrorAttachmentUpload =>
      'Ich konnte die Datei nicht hochladen. Versuchen Sie es erneut.';

  @override
  String get chatErrorTranscribe =>
      'Ich konnte die Sprachnachricht nicht transkribieren.';

  @override
  String get chatSeedConv1Title => 'Moka - Appetit und Kontrolle';

  @override
  String get chatSeedConv1Subtitle =>
      'Leicht verminderter Appetit, Beobachtung und Aktionsplan.';

  @override
  String get chatSeedConv1Preview =>
      'Wenn Moka munter bleibt, können wir bis morgen beobachten, aber notieren Sie Appetit und Trinkmenge.';

  @override
  String get chatSeedConv1Status => 'Aktueller Tierkontext';

  @override
  String get chatSeedConv1Msg1 =>
      'Erzählen Sie ruhig, was Sie beobachten: Appetit, Energie, Trinken und Kot helfen uns sofort einzuschätzen, ob ein Tierarztbesuch nötig ist oder Beobachten reicht.';

  @override
  String get chatSeedConv1Msg2 =>
      'Seit gestern frisst es weniger als sonst, bleibt aber munter. Soll ich mir gleich Sorgen machen?';

  @override
  String get chatSeedConv1Msg3 =>
      'Wenn es kein Erbrechen, keine Mattigkeit und keine deutlichen Schmerzen gibt, genügt es in der Regel, 24 Stunden zu beobachten und Appetit, Trinken und Kot zu notieren. Wenn etwas schlimmer wird, kontaktieren Sie einen Tierarzt.';

  @override
  String get chatSeedConv1Msg4 =>
      'Zur Sicherheit noch ein kleiner Plan: kleine Mahlzeiten, immer frisches Wasser und die Temperatur messen, wenn es matter wirkt als sonst.';

  @override
  String get chatSeedConv2Title => 'Moka - Impferinnerung';

  @override
  String get chatSeedConv2Subtitle =>
      'Jährliche Auffrischung mit Hinweis zum Parasitenschutz.';

  @override
  String get chatSeedConv2Preview =>
      'Ich habe die Auffrischung und die Folgeerinnerung für nächste Woche schon eingetragen.';

  @override
  String get chatSeedConv2Status => 'Erinnerung aktiv';

  @override
  String get chatSeedConv2Msg1 =>
      'Ich habe die Auffrischung eingerichtet und einen Hinweis zum Parasitenschutz ergänzt. Wenn Sie möchten, können wir auch den nächsten Kontrolltermin abstimmen.';

  @override
  String get chatSeedConv2Msg2 =>
      'Perfekt, erinnern Sie mich auch eine Woche vorher?';

  @override
  String get chatSeedConv2Msg3 =>
      'Gern. Ich erstelle Ihnen auch eine sichtbare Notiz mit dem nächsten Termin, damit Sie ihn gleich auf der Startseite finden.';

  @override
  String get chatSeedConv3Title => 'Moka - Untersuchungsbericht';

  @override
  String get chatSeedConv3Subtitle =>
      'Zusammenfassung der Kontrolle, leichte Behandlung und nächster Schritt.';

  @override
  String get chatSeedConv3Preview =>
      'Ich kann den Bericht in drei Punkten zusammenfassen: Befund, Behandlung und nächste Kontrolle.';

  @override
  String get chatSeedConv3Status => 'Bericht hochgeladen';

  @override
  String get chatSeedConv3Msg1 =>
      'Ich kann den Bericht in drei Punkten zusammenfassen: klinischer Befund, Behandlung und nächste Kontrollen. Wenn Sie möchten, erstelle ich auch eine Kurzfassung zum Teilen.';

  @override
  String get chatSeedConv3Msg2 => 'Ja, geben Sie mir die Kurzfassung.';

  @override
  String get chatSeedConv3Msg3 =>
      'Kurz gesagt: stabiler Befund, leichte Behandlung für wenige Tage und Kontrolltermin bereits geplant.';

  @override
  String get chatSeedAgo2Min => 'vor 2 Min.';

  @override
  String get chatSeedAgo3Days => 'vor 3 Tg.';

  @override
  String get marketplacePermissionDenied =>
      'Nur wer die Anzeige veröffentlicht hat, kann sie bearbeiten oder löschen.';

  @override
  String get marketplaceCategoryKennelsCarriers =>
      'Körbchen, Betten und Transportboxen';

  @override
  String get marketplaceCategoryLeashesCollars =>
      'Leinen, Halsbänder und Geschirre';

  @override
  String get marketplaceCategoryToys => 'Spielzeug';

  @override
  String get marketplaceCategoryClothing => 'Kleidung';

  @override
  String get marketplaceCategoryFeeding => 'Näpfe und Fütterung';

  @override
  String get marketplaceCategoryHygieneGrooming => 'Hygiene und Pflege';

  @override
  String get marketplaceCategoryAquariumsTerrariums => 'Aquarien und Terrarien';

  @override
  String get marketplaceCategoryCagesAviaries => 'Käfige und Volieren';

  @override
  String get marketplaceOther => 'Sonstiges';

  @override
  String get marketplaceConditionNew => 'Neu';

  @override
  String get marketplaceConditionLikeNew => 'Wie neu';

  @override
  String get marketplaceConditionGood => 'Gut';

  @override
  String get marketplaceConditionWorn => 'Gebraucht';

  @override
  String get marketplaceSpeciesAll => 'Alle Tierarten';

  @override
  String get marketplaceSpeciesDog => 'Hund';

  @override
  String get marketplaceSpeciesCat => 'Katze';

  @override
  String get marketplaceSpeciesSmallMammal => 'Kleinsäuger';

  @override
  String get marketplaceSpeciesBird => 'Vogel';

  @override
  String get marketplaceSpeciesReptileAmphibian => 'Reptilien und Amphibien';

  @override
  String get marketplaceSpeciesFish => 'Fisch';

  @override
  String get marketplacePriceGift => 'Zu verschenken';

  @override
  String get marketplaceDemoBedTitle => 'Gepolstertes Körbchen (Demo)';

  @override
  String get marketplaceDemoBedDescription => 'Wenig benutzt, mittlere Größe.';

  @override
  String get marketplaceDemoBedArea => 'Zentrum, Mailand';

  @override
  String get marketplaceDemoScratcherTitle =>
      'Kratzbaum mit zwei Etagen (Demo)';

  @override
  String get marketplaceDemoScratcherArea => 'Città Studi, Mailand';

  @override
  String get marketplacePageTitle => 'Gebrauchtmarkt';

  @override
  String get marketplaceMapAction => 'Karte';

  @override
  String get marketplaceNewListing => 'Neue Anzeige';

  @override
  String get marketplaceIntro =>
      'Kaufen, verkaufen und verschenken Sie Tierbedarf mit anderen Tierhaltern.';

  @override
  String get marketplaceRules =>
      'Der Gebrauchtmarkt bietet nur Artikel für Tiere. Tiere dürfen hier in keinem Land verkauft, verschenkt oder getauscht werden.';

  @override
  String get marketplaceNoAnimalsMessage =>
      'Auf dem Gebrauchtmarkt werden nur Artikel für Tiere verkauft, keine Tiere.';

  @override
  String get marketplaceBackendUnavailable =>
      'Der Gebrauchtmarkt ist gerade nicht erreichbar. Versuchen Sie es gleich noch einmal.';

  @override
  String get marketplaceEmptyFiltered =>
      'Derzeit keine Anzeigen mit diesen Filtern.';

  @override
  String get marketplaceNeedsLocation =>
      'Der Gebrauchtmarkt zeigt nur Anzeigen in Ihrer Nähe. Legen Sie Ihren Standort unter Einstellungen → Standort fest, um sie zu sehen.';

  @override
  String get marketplaceSetLocationAction => 'Standort festlegen';

  @override
  String get marketplaceDistanceOther => 'Andere';

  @override
  String marketplaceDistanceOtherValue(String distance) {
    return 'Andere: $distance';
  }

  @override
  String get marketplaceDistanceDialogTitle => 'Maximale Entfernung';

  @override
  String marketplaceDistanceDialogHelp(int min, int max, String unit) {
    return 'Geben Sie eine ganze Zahl von $min bis $max $unit ein.';
  }

  @override
  String marketplaceDistanceDialogInvalid(int min, int max, String unit) {
    return 'Ungültiger Wert: Geben Sie eine ganze Zahl von $min bis $max $unit ein.';
  }

  @override
  String get marketplaceLoadError =>
      'Ich kann die Anzeigen nicht laden. Prüfen Sie Ihre Verbindung.';

  @override
  String get marketplaceFilterAllCategories => 'Alle';

  @override
  String get marketplaceFilterAllSpecies => 'Alle Tiere';

  @override
  String get marketplaceReportListing => 'Anzeige melden';

  @override
  String get marketplaceReasonSpam => 'Spam';

  @override
  String get marketplaceReasonScam => 'Betrug';

  @override
  String get marketplaceReasonProhibitedItem => 'Nicht erlaubter Artikel';

  @override
  String get marketplaceReasonInappropriate => 'Unangemessener Inhalt';

  @override
  String get marketplaceReasonSellsAnimals => 'Verkauft Tiere';

  @override
  String get marketplaceReportRemoved =>
      'Danke, die Anzeige wurde nach den eingegangenen Meldungen entfernt.';

  @override
  String get marketplaceReportSent => 'Meldung gesendet, danke.';

  @override
  String get marketplaceDeleteConfirmTitle => 'Anzeige löschen?';

  @override
  String marketplaceDeleteConfirmBody(String title) {
    return '„$title“ und die zugehörigen Fotos werden gelöscht. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get marketplaceDeleteFailed =>
      'Ich konnte die Anzeige nicht löschen. Versuchen Sie es erneut.';

  @override
  String get marketplaceDeleted => 'Anzeige gelöscht.';

  @override
  String marketplaceDetailApproxZone(String city) {
    return '$city · ungefähre Gegend';
  }

  @override
  String marketplaceDetailForSpecies(String species) {
    return 'Für: $species';
  }

  @override
  String get marketplaceEditListing => 'Anzeige bearbeiten';

  @override
  String get marketplaceDeleting => 'Wird gelöscht...';

  @override
  String get marketplaceDeleteListing => 'Anzeige löschen';

  @override
  String get marketplaceReporting => 'Meldung wird gesendet...';

  @override
  String get marketplaceMapTitle => 'Karte des Gebrauchtmarkts';

  @override
  String marketplaceListingsCount(int count) {
    return '$count Anzeigen';
  }

  @override
  String marketplaceMapClusterTitle(int count) {
    return '$count Anzeigen in dieser Gegend';
  }

  @override
  String get marketplaceMapEmpty => 'Keine Anzeigen mit diesen Filtern.';

  @override
  String marketplaceMapSummary(int count) {
    return '$count Anzeigen · ungefähre Positionen (ca. 1 km)';
  }

  @override
  String get marketplaceLocationErrorWithHome =>
      'Ich kann Ihren Standort nicht ermitteln. Prüfen Sie die Standortberechtigungen oder nutzen Sie Ihre Wohnadresse.';

  @override
  String get marketplaceLocationErrorNoHome =>
      'Ich kann Ihren Standort nicht ermitteln. Er wird benötigt, um die Anzeige in der richtigen Gegend (nur ungefähr) zu zeigen. Prüfen Sie die Standortberechtigungen und versuchen Sie es erneut.';

  @override
  String get marketplaceCameraOpenError =>
      'Die Kamera lässt sich nicht öffnen.';

  @override
  String get marketplaceGalleryOpenError =>
      'Die Galerie lässt sich nicht öffnen.';

  @override
  String marketplacePhotosSkipped(int count) {
    return '$count nicht lesbare Fotos wurden übersprungen.';
  }

  @override
  String marketplacePhotosMaxReached(int max) {
    return 'Sie können höchstens $max Fotos hinzufügen.';
  }

  @override
  String get marketplaceZoneWait =>
      'Warten Sie, bis die Gegend gefunden wurde, und versuchen Sie es dann erneut.';

  @override
  String get marketplaceSaveFailed =>
      'Die Anzeige konnte nicht gespeichert werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get marketplacePriceRequired =>
      'Geben Sie einen Preis ein oder wählen Sie „Zu verschenken“';

  @override
  String get marketplacePriceInvalid => 'Geben Sie einen gültigen Preis ein';

  @override
  String get marketplacePriceNegative => 'Der Preis darf nicht negativ sein';

  @override
  String get marketplacePriceZero =>
      'Wählen Sie „Zu verschenken“, um es kostenlos abzugeben';

  @override
  String get marketplacePriceTooHigh => 'Preis zu hoch';

  @override
  String get marketplaceFieldTitle => 'Titel';

  @override
  String get marketplaceTitleRequired => 'Geben Sie einen Titel ein';

  @override
  String get marketplaceFieldDescription => 'Beschreibung (optional)';

  @override
  String get marketplaceFieldCategory => 'Kategorie';

  @override
  String get marketplaceCategoryRequired => 'Wählen Sie eine Kategorie';

  @override
  String get marketplaceConditionLabel => 'Zustand';

  @override
  String get marketplaceSpeciesLabel => 'Für welche Tiere';

  @override
  String get marketplaceSpeciesRequired =>
      'Geben Sie an, für welche Tiere es ist, oder wählen Sie „Alle Tierarten“';

  @override
  String get marketplaceGiftSubtitle =>
      'Sie schenken es jemandem, der es braucht';

  @override
  String marketplaceFieldPrice(String currency) {
    return 'Preis ($currency)';
  }

  @override
  String get marketplaceSaving => 'Wird gespeichert...';

  @override
  String get marketplaceSaveChanges => 'Änderungen speichern';

  @override
  String get marketplacePublish => 'Anzeige veröffentlichen';

  @override
  String marketplacePhotosTitle(int count, int max) {
    return 'Fotos ($count/$max)';
  }

  @override
  String get marketplaceTakePhoto => 'Foto aufnehmen';

  @override
  String get marketplaceFromGallery => 'Aus der Galerie';

  @override
  String get marketplacePhotosPrivacy =>
      'Vor dem Hochladen entfernen wir versteckte Daten aus den Fotos (Standort, Gerät, Datum).';

  @override
  String get marketplaceLocationTitle => 'Standort';

  @override
  String get marketplaceLocationKeep => 'Aktuelle Gegend der Anzeige';

  @override
  String get marketplaceLocationNow => 'Wo ich gerade bin';

  @override
  String get marketplaceLocationHome => 'Wohnort';

  @override
  String get marketplaceLocationHomeHint =>
      'Um den Wohnort zu nutzen, legen Sie ihn unter Einstellungen → Standort fest.';

  @override
  String get marketplaceLocationSearching => 'Ich suche Ihre Gegend...';

  @override
  String get marketplaceZoneLabel =>
      'Angezeigte Gegend (Stadtteil oder Gemeinde)';

  @override
  String get marketplaceZoneHelper => 'Keine Straße oder Hausnummer';

  @override
  String get marketplacePrivacyApproxOnMap =>
      'Auf der Karte erscheint die Anzeige an einem ungefähren Punkt (etwa 1 km), nie an Ihrer Adresse.';

  @override
  String get marketplacePrivacyApproxAlways =>
      'Zum Schutz Ihrer Privatsphäre ist der Standort der Anzeige immer ungefähr (etwa 1 km), nie Ihre genaue Adresse.';

  @override
  String get medicalActionOpen => 'Öffnen';

  @override
  String get medicalActionSend => 'Senden';

  @override
  String get medicalActionRename => 'Umbenennen';

  @override
  String get medicalFileUnavailable =>
      'Die Datei ist gerade nicht verfügbar. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get medicalPdfOpenFailed =>
      'Das PDF konnte nicht geöffnet werden. Versuchen Sie es erneut oder nutzen Sie „Senden“.';

  @override
  String get medicalNoPdfAppTitle => 'Keine App zum Öffnen von PDFs';

  @override
  String get medicalNoPdfAppBody =>
      'Auf diesem Gerät gibt es keine App, die PDFs öffnet. Sie können die Datei an eine App senden, die sie öffnen kann.';

  @override
  String get medicalPreparingFiles => 'Dateien zum Senden werden vorbereitet…';

  @override
  String get medicalNoFilesToSend =>
      'Keine Dateien zum Senden verfügbar. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String medicalFilesMissing(int count) {
    return '$count nicht verfügbare Dateien wurden nicht einbezogen.';
  }

  @override
  String get medicalDeleteConfirmTitle => 'Dokument löschen?';

  @override
  String medicalDeleteConfirmBody(String title) {
    return '„$title“ wird endgültig gelöscht.';
  }

  @override
  String get medicalDeleting => 'Befund wird gelöscht…';

  @override
  String get medicalRenameTitle => 'Befund umbenennen';

  @override
  String get medicalRenameFieldLabel => 'Dateiname';

  @override
  String get medicalDefaultRecordTitle => 'Tierärztlicher Befund';

  @override
  String get medicalSaveNoSession =>
      'Zugriff nicht verfügbar: Versuchen Sie es nach erneuter Anmeldung noch einmal.';

  @override
  String medicalSavePetNotSynced(String petName) {
    return 'Das Profil von $petName ist nicht mit dem Server synchronisiert. Beheben Sie das, bevor Sie Befunde hochladen.';
  }

  @override
  String get medicalSaveFailed =>
      'Der Befund konnte nicht auf dem Server gespeichert werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get medicalRenameFailed =>
      'Der Befund konnte nicht umbenannt werden. Versuchen Sie es erneut.';

  @override
  String get medicalDeleteFailed =>
      'Der Befund konnte nicht gelöscht werden. Versuchen Sie es erneut.';

  @override
  String get medicalRecordMetaNotUploaded =>
      'Datei nicht auf den Server hochgeladen';

  @override
  String get medicalRecordMetaAnalysisFailed =>
      'Datei gespeichert, automatisches Lesen fehlgeschlagen';

  @override
  String get medicalRecordMetaUploadedNow => 'Gerade von Ihnen hochgeladen';

  @override
  String get medicalRecordBadgeNotUploaded => 'Nicht hochgeladen';

  @override
  String get medicalRecordBadgeNew => 'Neu';

  @override
  String get medicalRecordSourceLocalOnly => 'Nur auf diesem Handy';

  @override
  String get medicalRecordSourceUploadedByYou => 'Von Ihnen hochgeladen';

  @override
  String get medicalTimelineImported => 'Importiert';

  @override
  String get medicalTimelineUpload => 'Wird geladen';

  @override
  String get medicalTimelineFailed => 'Fehlgeschlagen';

  @override
  String get medicalTimelineCompleted => 'Abgeschlossen';

  @override
  String get medicalTimelineReadyToSend => 'Bereit zum Senden';

  @override
  String get medicalTimelineAvailable => 'Verfügbar';

  @override
  String get medicalUploadTitle => 'Dokument hochladen';

  @override
  String medicalUploadForPet(String petName) {
    return 'Für $petName · PDF, JPG oder PNG';
  }

  @override
  String get medicalUploadAction => 'Hochladen';

  @override
  String get medicalUploadPickPrompt => 'Tippen, um eine Datei zu wählen';

  @override
  String get medicalUploadPickHint => 'PDF, JPG oder PNG von Ihrem Gerät';

  @override
  String get medicalUploadChange => 'Ändern';

  @override
  String get medicalUploadFailedTitle => 'Die Datei wurde nicht hochgeladen';

  @override
  String medicalUploadFailedBody(String reason) {
    return '$reason Alternativ können Sie den Befund nur auf diesem Handy speichern: Er wird als „Nicht hochgeladen“ markiert und ist auf anderen Geräten nicht verfügbar.';
  }

  @override
  String get medicalUploadFailedDefaultReason =>
      'Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get medicalUploadSaveLocalOnly => 'Nur auf dem Handy speichern';

  @override
  String get medicalUploadDemoSubtitle =>
      'Laden Sie ein PDF, JPG oder PNG hoch und ergänzen Sie die Metadaten.';

  @override
  String get medicalUploadDemoAction => 'Details';

  @override
  String get medicalUploadDemoCardBody =>
      'Erfolgreich hochgeladen und bereit zur Prüfung der Metadaten.';

  @override
  String get medicalListTitle => 'Befunde';

  @override
  String get medicalListSubtitle =>
      'Befunde, Notizen und Anhänge von Moka in einem übersichtlichen Archiv.';

  @override
  String get medicalListSyncTitle => 'Befunde werden synchronisiert';

  @override
  String get medicalListSyncBody =>
      'Ich hole Dokumente und Metadaten von Supabase oder aus der Demo-Quelle.';

  @override
  String get medicalListLoadErrorTitle => 'Archiv konnte nicht geladen werden';

  @override
  String get medicalListLoadErrorBody =>
      'Prüfen Sie Ihre Verbindung und versuchen Sie es erneut oder fahren Sie mit der Demo-Ansicht fort.';

  @override
  String get medicalListEmptyTitle => 'Noch keine Dokumente';

  @override
  String get medicalListEmptyBody =>
      'Laden Sie den ersten Befund hoch, um Ihr Dokumentenarchiv aufzubauen.';

  @override
  String get medicalListUploadFirst => 'Erste Datei hochladen';

  @override
  String medicalListSummaryAllTitle(int count) {
    return '$count aktive Dokumente';
  }

  @override
  String medicalListSummaryPetTitle(int count, String petName) {
    return '$count Dokumente von $petName';
  }

  @override
  String get medicalListSummaryAllBody =>
      '1 Befund bereit zum Teilen, 1 Untersuchung zur Prüfung und 1 archivierte Notiz.';

  @override
  String medicalListSummaryPetBody(String petName) {
    return 'Filter aktiv für das Profil von $petName. Öffnen Sie die wichtigsten Dokumente ohne Ablenkung.';
  }

  @override
  String get medicalListNextActionTitle => 'Nächster Schritt';

  @override
  String get medicalListNextActionAllBody =>
      'Öffnen Sie den Impfbefund von Moka und teilen Sie ihn mit Francesco.';

  @override
  String medicalListNextActionPetBody(String petName) {
    return 'Teilen Sie das neueste Dokument von $petName und behalten Sie die Notiz im Profil.';
  }

  @override
  String medicalListEmptyPetTitle(String petName) {
    return 'Keine Dokumente für $petName';
  }

  @override
  String get medicalListEmptyPetBody =>
      'Ändern Sie den Filter oder laden Sie ein neues Dokument für dieses Tier hoch.';

  @override
  String get medicalListRemoveFilter => 'Filter entfernen';

  @override
  String medicalFilterAll(int count) {
    return 'Alle ($count)';
  }

  @override
  String get medicalMetaType => 'Typ';

  @override
  String get medicalMetaDate => 'Datum';

  @override
  String get medicalMetaSource => 'Quelle';

  @override
  String get medicalMetaFormat => 'Format';

  @override
  String get medicalStatePreviewPill => 'Vorschau-Status';

  @override
  String get medicalStateLoadingPill => 'Wird geladen';

  @override
  String get medicalChecklistFormat => 'Unterstütztes Dateiformat';

  @override
  String get medicalChecklistMetadata => 'Metadaten extrahiert';

  @override
  String get medicalChecklistLinkedPet => 'Mit dem aktiven Tier verknüpft';

  @override
  String get homeGreeting => 'Guten Morgen';

  @override
  String get homeAgendaTitle => 'Anstehende Aktivitäten';

  @override
  String get homeAgendaLoadingSubtitle =>
      'Einmalige und wiederkehrende, für alle Tiere.';

  @override
  String homeAgendaSummary(int count) {
    return '$count Aktivitäten in den nächsten 10 Tagen';
  }

  @override
  String get homeNewsTitle => 'Wissenswertes für Ihre Tiere';

  @override
  String get homeNewsSubtitle =>
      'Für Sie ausgewählte Neuigkeiten aus der Tierwelt.';

  @override
  String get homeNewsUnavailable =>
      'Wissenswertes ist gerade nicht verfügbar. Versuchen Sie es später erneut.';

  @override
  String get homeNewsMore => 'Weitere Neuigkeiten entdecken';

  @override
  String get homeNearbyTitle => 'In meiner Nähe';

  @override
  String get homeSponsorBanner => 'Platz für unsere Partner.';

  @override
  String get homeSectionLoading => 'Wird geladen...';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabPets => 'Tiere';

  @override
  String get shellTabActivities => 'Aktivitäten';

  @override
  String get shellTabSettings => 'Einstellungen';

  @override
  String get shellRailFooter => 'Ein warmer, klinischer Raum';

  @override
  String get shellInterruptedWalkTitle => 'Spaziergang unterbrochen';

  @override
  String shellInterruptedWalkBody(String distance) {
    return 'Ein Spaziergang läuft noch ($distance bisher). Möchten Sie ihn fortsetzen?';
  }

  @override
  String get shellInterruptedWalkDiscard => 'Verwerfen';

  @override
  String get shellInterruptedWalkResume => 'Fortsetzen';

  @override
  String shellWalkPausedBanner(String distance) {
    return 'Spaziergang pausiert · $distance';
  }

  @override
  String shellWalkActiveBanner(String elapsed, String distance) {
    return 'Spaziergang läuft · $elapsed · $distance';
  }

  @override
  String get splashMessageWalks =>
      'Zeichnen Sie Ihre Spaziergänge mit Ihrem Hund auf!';

  @override
  String get splashMessageVet =>
      'Fragen Sie den virtuellen Tierarzt, rund um die Uhr';

  @override
  String get splashMessageReminders =>
      'Nie wieder einen Termin vergessen: Erinnerungen und Kalender';

  @override
  String get splashMessageRecords => 'Halten Sie Befunde immer griffbereit';

  @override
  String get splashMessageNearby =>
      'Entdecken Sie tierfreundliche Angebote in Ihrer Nähe';

  @override
  String get splashMessageNews => 'Verfolgen Sie Neuigkeiten aus der Tierwelt';

  @override
  String get splashMessageProfiles =>
      'Ein Profil für jeden Freund auf vier Pfoten (oder mit Flossen!)';

  @override
  String get splashMessageHealthBook =>
      'Das Gesundheitsheft in der Tasche, nie wieder lose Zettel';

  @override
  String get splashMessageVaccines =>
      'Impfungen, Entwurmung, Tierarztbesuche: Wir erinnern Sie daran';

  @override
  String get splashMessageSpecies =>
      'Hund, Katze, Kaninchen, Papagei oder Goldfisch: Hier ist Platz für alle';

  @override
  String get sharedGuestName => 'Gast';

  @override
  String get sharedComingSoon => 'Demnächst';

  @override
  String get sharedLoadingLabel => 'Wird geladen';

  @override
  String get sharedAttachmentTooLarge => 'Die Datei ist zu groß (max. 4 MB).';

  @override
  String get sharedAttachmentInvalidPdf =>
      'Diese Datei scheint kein gültiges PDF zu sein.';

  @override
  String get sharedAiGenerated => 'KI-generiert';

  @override
  String get sharedAiNotReviewed => 'Automatische Antwort, nicht geprüft';

  @override
  String get petsAgeLessThanMonth => 'Weniger als ein Monat';

  @override
  String petsAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Monate',
      one: '$count Monat',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: '$count Jahr',
    );
    return '$_temp0';
  }

  @override
  String petsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Profile',
      one: '$count Profil',
    );
    return '$_temp0';
  }

  @override
  String petsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tierarten',
      one: '$count Tierart',
    );
    return '$_temp0';
  }

  @override
  String petsFishCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fische',
      one: '$count Fisch',
    );
    return '$_temp0';
  }

  @override
  String petsAquariumSummary(String species, String fish) {
    return '$species · $fish';
  }

  @override
  String get petsBreedUnspecified => 'Rasse nicht angegeben';

  @override
  String get petsSpeciesUnspecified => 'Tierart nicht angegeben';

  @override
  String petsBreedOtherWithSize(String size) {
    return 'Andere · Größe $size';
  }

  @override
  String get petsHabitatAquarium => 'Aquarium';

  @override
  String get petsHabitatTerrarium => 'Terrarium';

  @override
  String get petsHabitatAviary => 'Voliere';

  @override
  String get petsHabitatGeneric => 'Lebensraum';

  @override
  String get petsCreateTitle => 'Tierprofil erstellen';

  @override
  String get petsCreateLoading => 'Formular wird vorbereitet...';

  @override
  String get petsCreateErrorTitle => 'Formular nicht verfügbar';

  @override
  String get petsCreateErrorDefault =>
      'Ein neues Tierprofil kann gerade nicht erstellt werden.';

  @override
  String get petsCreateFormTitle => 'Neues Profil';

  @override
  String get petsCreateSubmit => 'Tierprofil speichern';

  @override
  String get petsCreateUnsyncedSnack =>
      'Profil auf dem Handy gespeichert, aber nicht auf dem Server. Öffnen Sie es in der Liste und tippen Sie auf „Erneut versuchen“.';

  @override
  String petsEditTitle(String name) {
    return '$name bearbeiten';
  }

  @override
  String get petsEditLoading => 'Bearbeitungsformular wird geladen...';

  @override
  String get petsEditErrorTitle => 'Bearbeiten nicht verfügbar';

  @override
  String get petsEditErrorDefault =>
      'Dieses Tierprofil kann nicht zur Bearbeitung geöffnet werden.';

  @override
  String get petsEditFormTitle => 'Profilentwurf';

  @override
  String get petsEditSubmit => 'Änderungen speichern';

  @override
  String get petsEditUnsyncedSnack =>
      'Änderungen auf dem Handy gespeichert, aber nicht auf dem Server. Öffnen Sie das Profil und tippen Sie auf „Erneut versuchen“.';

  @override
  String get petsEditDeleteTitle => 'Dieses Profil entfernen?';

  @override
  String petsEditDeleteMessage(String name) {
    return 'Das Profil von „$name“ wird endgültig gelöscht, samt aller Daten.';
  }

  @override
  String get petsEditDeleteConfirm => 'Entfernen';

  @override
  String get petsEditDeleteAction => 'Profil entfernen';

  @override
  String get petsEditMemorialTitle => 'In die Erinnerungen verschieben?';

  @override
  String petsEditMemorialMessage(String name) {
    return '„$name“ verschwindet aus der Tierliste und wird mit Profil und Fotos im Bereich Erinnerungen aufbewahrt.';
  }

  @override
  String get petsEditMemorialConfirm => 'Verschieben';

  @override
  String get petsEditMemorialAction => 'In die Erinnerungen verschieben';

  @override
  String get petsFormAddSpecies => 'Tierart hinzufügen';

  @override
  String get petsFormIdentityColor => 'Kennfarbe';

  @override
  String get petsFormNameLabel => 'Name';

  @override
  String get petsFormNameHint => 'Moka';

  @override
  String get petsFormNameError => 'Geben Sie den Namen des Tieres ein.';

  @override
  String get petsFormSpeciesLabel => 'Tierart';

  @override
  String get petsFormSpeciesHint => 'Tierart auswählen';

  @override
  String get petsFormSpeciesError => 'Wählen Sie eine Tierart.';

  @override
  String get petsFormProfileType => 'Was möchten Sie erfassen?';

  @override
  String get petsFormFishSingleTitle => 'Fisch';

  @override
  String get petsFormFishSingleBody =>
      'Ein einzelner Fisch, nach Art gewählt (z. B. Kampffisch, Goldfisch)';

  @override
  String get petsFormFishAquariumBody =>
      'Ein Becken mit mehreren Arten und mehreren Tieren, Männchen und Weibchen';

  @override
  String get petsFormAquariumPopulation => 'Besatz des Aquariums';

  @override
  String get petsFormNoSpeciesYet => 'Noch keine Art hinzugefügt.';

  @override
  String get petsFormAquariumNeedsSpecies =>
      'Fügen Sie dem Aquarium mindestens eine Art hinzu.';

  @override
  String get petsFormBreedLabel => 'Rasse';

  @override
  String get petsFormBreedSelectSpeciesFirst => 'Wählen Sie zuerst die Tierart';

  @override
  String get petsFormBreedSpeciesLabel => 'Art';

  @override
  String get petsFormBreedRequired => 'Wählen Sie die Rasse.';

  @override
  String get petsFormBreedSpeciesRequired => 'Wählen Sie die Art.';

  @override
  String get petsFormBreedTextRequired => 'Geben Sie die Rasse ein.';

  @override
  String get petsFormBreedSpeciesTextRequired => 'Geben Sie die Art ein.';

  @override
  String get petsFormBreedSpeciesPlaceholder => 'Art auswählen';

  @override
  String get petsFormOtherSpeciesDialogTitle => 'Welche Art?';

  @override
  String get petsFormBreedPlaceholder => 'Rasse auswählen';

  @override
  String get petsFormBreedSearchHint => 'Rasse suchen';

  @override
  String get petsFormBreedSearchHintScientific =>
      'Suchen (auch nach wissenschaftlichem Namen)';

  @override
  String get petsFormOtherBreedLabel => 'Welche Rasse?';

  @override
  String get petsFormOtherBreedHint => 'z. B. Pudel-Mischling';

  @override
  String get petsFormOtherSpeciesLabel => 'Welche Art?';

  @override
  String get petsFormOtherSpeciesHint =>
      'z. B. gebräuchlicher oder wissenschaftlicher Name';

  @override
  String get petsFormDogSizeLabel => 'Größe (optional)';

  @override
  String get petsFormDogSizeHint => 'Größe auswählen';

  @override
  String get petsFormBirthDateLabel => 'Geburtsdatum';

  @override
  String get petsFormBirthDateHint => 'TT/MM/JJJJ';

  @override
  String get petsFormBirthDateRequired => 'Wählen Sie das Geburtsdatum aus.';

  @override
  String get petsFormBirthDateInvalid => 'Ungültiges Datum (TT/MM/JJJJ).';

  @override
  String get petsFormBirthDateFuture =>
      'Das Geburtsdatum darf nicht in der Zukunft liegen.';

  @override
  String get petsFormSexLabel => 'Geschlecht';

  @override
  String get petsFormSexHint => 'Auswählen';

  @override
  String get petsFormSexUnknown => 'Unbekannt';

  @override
  String get petsFormWeightLabelKg => 'Gewicht (optional, kg)';

  @override
  String get petsFormWeightLabelLb => 'Gewicht (optional, lb)';

  @override
  String get petsFormWeightHintKg => 'z. B. 18,4';

  @override
  String get petsFormWeightLabelG => 'Gewicht (optional, g)';

  @override
  String get petsFormWeightHintG => 'z. B. 35';

  @override
  String get petsFormWeightHintLb => 'z. B. 40,5';

  @override
  String get petsFormWeightInvalid => 'Geben Sie ein gültiges Gewicht ein.';

  @override
  String get petsFormWeightPositive => 'Das Gewicht muss größer als null sein.';

  @override
  String get petsFormNotesLabel => 'Notizen';

  @override
  String get petsFormNotesHint =>
      'Fügen Sie kurze Notizen zu Ernährung, Medikamenten oder Verhalten hinzu.';

  @override
  String get petsFormSaving => 'Wird gespeichert…';

  @override
  String get petsFormPhotoAdd => 'Foto hinzufügen';

  @override
  String get petsFormPhotoChange => 'Foto ändern';

  @override
  String get petsFormPhotoRemove => 'Entfernen';

  @override
  String get petsFormHabitatLength => 'Länge';

  @override
  String get petsFormHabitatWidth => 'Breite';

  @override
  String get petsFormHabitatHeight => 'Höhe';

  @override
  String get petsFormHabitatUsGallons => 'US-Gallonen';

  @override
  String get petsFormHabitatLiters => 'Liter';

  @override
  String get petsFormHabitatVolumeHint => 'Aus den Maßen berechnet, änderbar';

  @override
  String get petsFormHabitatTemperature => 'Temperatur';

  @override
  String get petsFormHabitatTemperatureHintF => 'z. B. 75-79°F';

  @override
  String get petsFormHabitatTemperatureHintC => 'z. B. 24-26°C';

  @override
  String get petsFormHabitatSubstrate => 'Bodengrund';

  @override
  String get petsFormHabitatSubstrateHint => 'z. B. feiner Kies, Kokosfaser';

  @override
  String get petsFormHabitatEquipment => 'Ausstattung';

  @override
  String get petsFormHabitatEquipmentHint =>
      'Filter, Beleuchtung, Heizung, Pflanzen, UVB-Lampe, Sitzstangen...';

  @override
  String get petsDetailTitleFallback => 'Tierdetails';

  @override
  String get petsDetailGalleryTooltip => 'Fotogalerie';

  @override
  String get petsDetailLoading => 'Tierdetails werden geladen...';

  @override
  String get petsDetailErrorTitle => 'Tierdetails nicht verfügbar';

  @override
  String get petsDetailErrorDefault =>
      'Dieses Tierprofil ist im Moment nicht verfügbar.';

  @override
  String get petsDetailBackToList => 'Zurück zur Liste';

  @override
  String get petsDetailEmptyTitle => 'Kein Tier ausgewählt';

  @override
  String get petsDetailEmptySubtitle =>
      'Wählen Sie ein Profil aus der Liste, um Details, Chats und Befunde zu sehen.';

  @override
  String get petsDetailTabReminders => 'Erinnerungen';

  @override
  String get petsDetailTabChat => 'Chat';

  @override
  String get petsDetailTabRecords => 'Befunde';

  @override
  String get petsDetailTabWalks => 'Spaziergänge';

  @override
  String get petsDetailHabitatTapForDetails => 'Für Details tippen';

  @override
  String get petsDetailHabitatDimensions => 'Maße';

  @override
  String get petsDetailHabitatVolume => 'Volumen';

  @override
  String get petsDetailPopulation => 'Besatz';

  @override
  String get petsDetailRemindersNew => 'Neue Erinnerung';

  @override
  String petsDetailRemindersEmpty(String petName) {
    return 'Noch keine Erinnerungen für $petName.';
  }

  @override
  String get petsDetailChatNew => 'Neuer Chat';

  @override
  String petsDetailChatEmpty(String petName) {
    return 'Noch keine Unterhaltungen für $petName.';
  }

  @override
  String petsDetailChatDeleteFailed(String error) {
    return 'Chat hier entfernt, aber nicht auf dem Server: $error';
  }

  @override
  String get petsDetailChatDeleteTitle => 'Diesen Chat löschen?';

  @override
  String petsDetailChatDeleteMessage(String title) {
    return '\"$title\" wird endgültig gelöscht.';
  }

  @override
  String get petsDetailChatLimitTitle => 'Chat-Limit erreicht';

  @override
  String petsDetailChatLimitMessage(int max, String petName) {
    return 'Für $petName sind höchstens $max aktive Unterhaltungen möglich. Löschen Sie einen bestehenden Chat, um einen neuen zu starten.';
  }

  @override
  String get petsDetailChatLimitOk => 'Verstanden';

  @override
  String get petsDetailRecordsSendTitle => 'Datei senden';

  @override
  String get petsDetailRecordsSendSubtitle =>
      'Wählen Sie ein Dokument, das Sie per E-Mail, WhatsApp oder anderweitig senden möchten.';

  @override
  String petsDetailRecordShareText(String title, String source, String date) {
    return '📄 $title\n$source · $date\n\nGeteilt von Quokka';
  }

  @override
  String get petsDetailShareUnavailable =>
      'Teilen ist auf diesem Gerät nicht verfügbar.';

  @override
  String get petsDetailRecordsUpload => 'Datei hochladen';

  @override
  String get petsDetailRecordsSend => 'Senden';

  @override
  String petsDetailRecordsEmpty(String petName) {
    return 'Noch keine Dokumente für $petName.';
  }

  @override
  String get petsDetailRecordsLoadError =>
      'Die Befunde können nicht geladen werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String petsDetailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '$count ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get petsDetailWalksStart => 'Spaziergang starten';

  @override
  String get petsDetailWalksBadges => 'Abzeichen';

  @override
  String petsDetailWalksEmpty(String petName) {
    return 'Noch keine Spaziergänge für $petName.';
  }

  @override
  String get petsDetailWalksRecords => 'Rekorde 🏆';

  @override
  String get petsDetailWalksFavorites => 'Favoriten ⭐';

  @override
  String get petsDetailWalksRecent => 'Zuletzt';

  @override
  String get petsDetailWalkLongest => 'Längste Strecke';

  @override
  String get petsDetailWalkLongestDuration => 'Längste Dauer';

  @override
  String get petsDetailWalkLongestAndDuration =>
      'Längste Strecke · Längste Dauer';

  @override
  String petsDetailWalkStatusActive(String distance, String elapsed) {
    return 'Spaziergang läuft · $distance · $elapsed';
  }

  @override
  String petsDetailWalkStatusPaused(String distance, String elapsed) {
    return 'Pausiert · $distance · $elapsed';
  }

  @override
  String get petsDetailWalkUnfavoriteTitle => 'Aus Favoriten entfernen?';

  @override
  String get petsDetailWalkUnfavoriteMessage =>
      'Ist er nicht auch ein Rekord oder unter den letzten 3 Spaziergängen, kann die Karte bei der nächsten automatischen Bereinigung verloren gehen.';

  @override
  String get petsDetailWalkUnfavoriteConfirm => 'Aus Favoriten entfernen';

  @override
  String get petsDetailWalkDeleteTitle => 'Diesen Spaziergang löschen?';

  @override
  String petsDetailWalkDeleteMessage(String date, String distance) {
    return 'Der Spaziergang vom $date ($distance) wird endgültig gelöscht.';
  }

  @override
  String petsDetailWalkSteps(int count) {
    return '~$count Schritte';
  }

  @override
  String get petsDetailUnsyncedBanner =>
      'Nicht synchronisiert: Die Änderungen sind nur auf diesem Telefon.';

  @override
  String get petsDetailUnsyncedRetryFailed =>
      'Noch keine Verbindung zum Server. Versuchen Sie es später erneut.';

  @override
  String get petsScaffoldBadge => 'Tier';

  @override
  String get petsLoadingDefaultLabel => 'Tiere werden geladen...';

  @override
  String get petsLoadingSubtitle =>
      'Einen Augenblick bitte, wir bereiten den Bildschirm vor.';

  @override
  String get petsDemoDeleteFailed =>
      'Das Profil konnte nicht gelöscht werden. Versuchen Sie es erneut.';

  @override
  String get petsDemoNewProfileNote =>
      'Kürzlich angelegtes Profil, bereit für den nächsten Tierarztbesuch.';

  @override
  String get petsDemoNextVisitToPlan => 'Zu planen';

  @override
  String get petsValueSpeciesDog => 'Hund';

  @override
  String get petsValueSpeciesCat => 'Katze';

  @override
  String get petsValueSpeciesSmallMammals => 'Kleinsäuger';

  @override
  String get petsValueSpeciesBird => 'Vogel';

  @override
  String get petsValueSpeciesReptiles => 'Reptilien und Amphibien';

  @override
  String get petsValueSpeciesFish => 'Fisch';

  @override
  String get petsValueSpeciesOther => 'Sonstiges';

  @override
  String get petsValueSpeciesAll => 'Alle';

  @override
  String get petsValueSexMale => 'Männlich';

  @override
  String get petsValueSexFemale => 'Weiblich';

  @override
  String get petsValueSexMaleIntact => 'Männlich, unkastriert';

  @override
  String get petsValueSexMaleNeutered => 'Männlich, kastriert';

  @override
  String get petsValueSexFemaleIntact => 'Weiblich, unsterilisiert';

  @override
  String get petsValueSexFemaleSpayed => 'Weiblich, sterilisiert';

  @override
  String get petsValueDogSizeToy => 'Toy';

  @override
  String get petsValueDogSizeSmall => 'Klein';

  @override
  String get petsValueDogSizeMedium => 'Mittel';

  @override
  String get petsValueDogSizeLarge => 'Groß';

  @override
  String get petsValueDogSizeGiant => 'Riesig';

  @override
  String get petsListTitle => 'Tiere';

  @override
  String get petsListMemoriesTooltip => 'Andenken';

  @override
  String get petsListLoading => 'Tierliste wird geladen...';

  @override
  String get petsListErrorTitle => 'Tiere nicht verfügbar';

  @override
  String get petsListErrorDefault =>
      'Die Tierprofile können im Moment nicht geladen werden.';

  @override
  String get petsListEmptyTitle => 'Noch keine Tiere';

  @override
  String get petsListEmptySubtitle =>
      'Legen Sie das erste Profil an, um Gesundheit, Notizen und Termine im Blick zu behalten.';

  @override
  String get petsListEmptyAction => 'Tier anlegen';

  @override
  String get petsListFilterEmpty => 'Keine Tiere für diesen Filter.';

  @override
  String get petsMemoriesRemoveTitle => 'Endgültig entfernen?';

  @override
  String petsMemoriesRemoveBody(String name) {
    return 'Das Andenken an \"$name\" wird gelöscht und kann nicht wiederhergestellt werden.';
  }

  @override
  String get petsMemoriesRemoveConfirm => 'Entfernen';

  @override
  String get petsMemoriesTitle => 'Andenken';

  @override
  String get petsMemoriesSubtitle =>
      'Die Profile der Tiere, die Ihren Weg begleitet haben.';

  @override
  String get petsMemoriesEmpty => 'Noch keine Andenken gespeichert.';

  @override
  String petsMemoriesWithUsUntil(String date) {
    return 'Bei uns bis $date';
  }

  @override
  String petsMemoriesWithUsRange(String from, String to) {
    return 'Bei uns vom $from bis $to';
  }

  @override
  String get petsMemoriesComingSoon =>
      'Bald: Ihre schönsten gemeinsamen Momente, wie die längsten Spaziergänge oder erreichte Meilensteine, gesammelt an einem Ort.';

  @override
  String get petsMediaGalleryTitle => 'Galerie';

  @override
  String get petsMediaFoldersLoading => 'Ordner werden geladen…';

  @override
  String get petsMediaFoldersEmpty =>
      'Fügen Sie ein Tier hinzu, um dafür einen Fotoordner anzulegen.';

  @override
  String get petsMediaFolderCounting => 'Fotos werden gezählt…';

  @override
  String petsMediaCountPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
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
  String get petsMediaDeleteVideoTitle => 'Dieses Video löschen?';

  @override
  String get petsMediaDeletePhotoTitle => 'Dieses Foto löschen?';

  @override
  String get petsMediaDeleteVideoBody =>
      'Das Video wird endgültig aus der Galerie entfernt.';

  @override
  String get petsMediaDeletePhotoBody =>
      'Das Foto wird endgültig aus der Galerie entfernt.';

  @override
  String get petsMediaOperationFailed =>
      'Der Vorgang konnte nicht abgeschlossen werden. Versuchen Sie es erneut.';

  @override
  String get petsMediaSetAsProfile => 'Als Profilfoto festlegen';

  @override
  String get petsMediaDeleteVideoAction => 'Video löschen';

  @override
  String get petsMediaDeletePhotoAction => 'Foto löschen';

  @override
  String get petsMediaImportFromGallery => 'Aus Galerie importieren';

  @override
  String get petsMediaImportFromGalleryHint => 'Fotos und Videos, auch mehrere';

  @override
  String get petsMediaTakePhoto => 'Foto aufnehmen';

  @override
  String get petsMediaRecordVideo => 'Video aufnehmen';

  @override
  String petsMediaRecordVideoLimit(int seconds) {
    return 'Bis zu $seconds Sekunden';
  }

  @override
  String petsMediaGalleryOf(String name) {
    return 'Galerie von $name';
  }

  @override
  String get petsMediaGalleryEmpty =>
      'Noch keine Fotos oder Videos. Nutzen Sie unten die Schaltfläche \"Hinzufügen\".';

  @override
  String get petsMediaVideoPlaybackFailed =>
      'Dieses Video kann nicht abgespielt werden.';

  @override
  String get petsMediaVideoLoading => 'Video wird geladen...';

  @override
  String get petsMediaCancelling => 'Wird abgebrochen...';

  @override
  String get petsMediaPreparingFile => 'Datei wird vorbereitet...';

  @override
  String petsMediaPreparingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien werden vorbereitet...',
      one: 'Datei wird vorbereitet...',
    );
    return '$_temp0';
  }

  @override
  String get petsMediaUploadingFile => 'Datei wird hochgeladen...';

  @override
  String petsMediaUploadingProgress(int current, int total) {
    return '$current von $total wird hochgeladen...';
  }

  @override
  String get petsMediaUploadingVideo => 'Video wird hochgeladen...';

  @override
  String petsMediaUploadingVideoOf(int current, int total) {
    return 'Video $current von $total wird hochgeladen...';
  }

  @override
  String petsMediaReducingVideo(int percent) {
    return 'Video wird verkleinert... $percent%';
  }

  @override
  String petsMediaReducingVideoOf(int current, int total, int percent) {
    return 'Video $current von $total wird verkleinert... $percent%';
  }

  @override
  String petsMediaImportJoin(String first, String second) {
    return '$first und $second';
  }

  @override
  String petsMediaImportDone(String list) {
    return 'Hochgeladen: $list';
  }

  @override
  String get petsMediaImportCancelled => 'Hochladen abgebrochen.';

  @override
  String petsMediaImportCancelledWith(String done) {
    return 'Hochladen abgebrochen. $done.';
  }

  @override
  String get petsMediaImportNothingToAdd => 'Nichts hinzuzufügen.';

  @override
  String petsMediaImportProblemMore(String problem, int count) {
    return '$problem ($count weitere nicht hinzugefügt)';
  }

  @override
  String petsMediaImportDoneWithProblem(String done, String problem) {
    return '$done. $problem';
  }

  @override
  String petsMediaPhotoAddedTo(String name) {
    return 'Foto zur Galerie von $name hinzugefügt';
  }

  @override
  String petsMediaVideoAddedTo(String name) {
    return 'Video zur Galerie von $name hinzugefügt';
  }

  @override
  String petsMediaImportFileFailed(String file) {
    return '$file konnte nicht hochgeladen werden.';
  }

  @override
  String get petsMediaImportUnnamedFile => 'eine Datei';

  @override
  String get petsMediaPhotoSaveOffline =>
      'Fotos können ohne Verbindung nicht gespeichert werden.';

  @override
  String get petsMediaVideoSaveOffline =>
      'Videos können ohne Verbindung nicht gespeichert werden.';

  @override
  String petsMediaImportRefused(String file, String message) {
    return '$file: $message';
  }

  @override
  String get petsMediaVideoUnsupportedFormat =>
      'Videoformat nicht unterstützt: Verwenden Sie eine MP4- oder MOV-Datei.';

  @override
  String petsMediaVideoTooBigSource(int size, int max) {
    return 'Video zu groß ($size MB): Maximal sind $max MB erlaubt.';
  }

  @override
  String petsMediaVideoTooBigBrowser(int size, int max) {
    return 'Video zu groß ($size MB): Im Browser sind maximal $max MB erlaubt. In der App auf dem Telefon werden Videos automatisch verkleinert.';
  }

  @override
  String get petsMediaVideoUnreadable =>
      'Dieses Video kann nicht gelesen werden.';

  @override
  String petsMediaVideoTooLong(int seconds) {
    return 'Video zu lang: Maximal $seconds Sekunden erlaubt.';
  }

  @override
  String petsMediaVideoTooBigReduced(int size, int max) {
    return 'Auch verkleinert ist das Video $size MB groß (maximal $max MB): Versuchen Sie es mit einem kürzeren Clip.';
  }

  @override
  String petsMediaVideoTooBigNotReduced(int size, int max) {
    return 'Das Video konnte nicht verkleinert werden und ist $size MB groß (maximal $max MB): Versuchen Sie es mit einem kürzeren Clip.';
  }

  @override
  String petsConsentSemanticsExpanded(String name) {
    return 'Einwilligung zum Lesen der Krankenakte von $name. Tippen, um den vollständigen Text zu schließen';
  }

  @override
  String petsConsentSemanticsCollapsed(String name) {
    return 'Einwilligung zum Lesen der Krankenakte von $name. Tippen, um den vollständigen Text zu lesen';
  }

  @override
  String petsConsentCardTitle(String name) {
    return 'Krankenakte von $name';
  }

  @override
  String get petsConsentReadHow => 'Nutzung ansehen';

  @override
  String petsConsentSwitchSemantics(String name) {
    return 'Dem Assistenten erlauben, die Krankenakte von $name zu lesen';
  }

  @override
  String get petsConsentWithoutConsent =>
      'Ohne Einwilligung sieht der Assistent weder die Titel noch den Inhalt der Befunde.';

  @override
  String get petsConsentSaveFailed =>
      'Die Einwilligung konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get petsConsentStatusUnavailable =>
      'Status der Einwilligung nicht verfügbar: Bitte prüfen Sie Ihre Verbindung.';

  @override
  String get petsConsentSlowConnection =>
      'Langsame Verbindung. Die Einwilligung wurde nicht gespeichert, bitte erneut versuchen.';

  @override
  String get petsConsentOffline =>
      'Sie sind offline: Die Einwilligung wurde nicht gespeichert. Versuchen Sie es mit Verbindung erneut.';

  @override
  String get placesDetailBarrierFence => 'Eingezäunt';

  @override
  String get placesDetailBarrierWall => 'Von einer Mauer umgeben';

  @override
  String get placesDetailBarrierHedge => 'Von einer Hecke begrenzt';

  @override
  String get placesDetailSurfaceGrass => 'Rasenboden';

  @override
  String get placesDetailSurfaceGround => 'Erdboden';

  @override
  String get placesDetailSurfaceSand => 'Sandboden';

  @override
  String get placesDetailSurfaceGravel => 'Kiesboden';

  @override
  String get placesDetailSurfaceAsphalt => 'Asphaltierter Boden';

  @override
  String get placesDetailSurfacePaved => 'Gepflasterter Boden';

  @override
  String get placesDetailAccessFree => 'Frei zugänglich';

  @override
  String get placesDetailAccessPermissive => 'Zutritt erlaubt';

  @override
  String get placesDetailAccessCustomers => 'Nur für Kunden';

  @override
  String get placesDetailAccessPrivate => 'Privatbereich';

  @override
  String get placesDetailWheelchairYes => 'Rollstuhlgerecht';

  @override
  String get placesDetailWheelchairLimited => 'Teilweise rollstuhlgerecht';

  @override
  String get placesDetailWheelchairNo => 'Nicht rollstuhlgerecht';

  @override
  String get placesDetailDrinkingWaterYes => 'Trinkwasser';

  @override
  String get placesDetailDrinkingWaterNo => 'Kein Trinkwasser';

  @override
  String get placesDetailLitYes => 'Beleuchtet';

  @override
  String get placesDetailLitNo => 'Nicht beleuchtet';

  @override
  String get placesDetailDogUnleashed => 'Hunde dürfen ohne Leine laufen';

  @override
  String get placesDetailAdoptionYes => 'Tiervermittlung möglich';

  @override
  String get placesDetailAdoptionNo => 'Keine Tiervermittlung';

  @override
  String placesPendingDogPark(String progress) {
    return 'Von Nutzern gemeldet, bitte prüfen Sie, ob es ein öffentlicher Bereich ist ($progress)';
  }

  @override
  String placesPendingPlace(String progress) {
    return 'Von Nutzern gemeldet · wartet auf Bestätigung ($progress)';
  }

  @override
  String placesMailRemoveSubject(String id) {
    return 'Hundeauslauf aus dem Radar entfernen ($id)';
  }

  @override
  String placesMailRemoveBody(String name, String position, String id) {
    return 'Dieser von Nutzern gemeldete Bereich ist kein öffentlicher Hundeauslauf.\n\nName: $name\nPosition: $position\nKennung: $id\n\nGrund: ';
  }

  @override
  String get placesWithdrawTitle => 'Meldung zurückziehen?';

  @override
  String get placesWithdrawBody =>
      'Die Meldung wird gelöscht und ist für niemanden mehr sichtbar.';

  @override
  String get placesWithdrawConfirm => 'Zurückziehen';

  @override
  String get placesWithdrawnSnack => 'Meldung zurückgezogen.';

  @override
  String get placesVoteConfirmedSnack => 'Danke, Bestätigung gespeichert.';

  @override
  String get placesVoteDeniedSnack => 'Danke, gespeichert.';

  @override
  String placesRatedSnack(int stars) {
    return 'Bewertung gespeichert: $stars von 5.';
  }

  @override
  String get placesReportsInactiveSnack =>
      'Meldungen sind derzeit nicht aktiv.';

  @override
  String get placesReportProblemTitle => 'Was stimmt an diesem Ort nicht?';

  @override
  String get placesReportAlreadyKnown =>
      'Das wurde schon gemeldet: Ihre Meldung zählt als Bestätigung.';

  @override
  String get placesReportSent =>
      'Meldung gesendet. Sie gilt, sobald andere Nutzer sie bestätigen.';

  @override
  String get placesSheetPendingQuestion => 'Gibt es diesen Ort wirklich hier?';

  @override
  String get placesSheetNotPublicWrite =>
      'Kein öffentlicher Bereich? Schreiben Sie uns';

  @override
  String placesSheetClosedReported(String progress) {
    return 'Als geschlossen gemeldet ($progress)';
  }

  @override
  String get placesSheetClosedQuestion => 'Ist er wirklich geschlossen?';

  @override
  String placesSheetOpeningHours(String hours) {
    return 'Angegebene Öffnungszeiten: $hours';
  }

  @override
  String get placesActionCall => 'Anrufen';

  @override
  String get placesActionDirections => 'Route';

  @override
  String get placesActionWebsite => 'Website';

  @override
  String get placesDisclaimerCommunity =>
      'Von Nutzern gemeldeter Ort: keine Garantie, bitte vor dem Besuch prüfen.';

  @override
  String get placesDisclaimerClinic =>
      'Rufen Sie im Notfall vor der Abfahrt an: Öffnungszeiten und Kontaktdaten stammen aus offenen Datenquellen und werden von Quokka nicht überprüft.';

  @override
  String get placesDisclaimerGeneric =>
      'Öffnungszeiten und Kontaktdaten stammen aus offenen Datenquellen und werden von Quokka nicht überprüft.';

  @override
  String placesSourceLine(String source) {
    return 'Quelle: $source';
  }

  @override
  String placesAlsoIn(String sources) {
    return 'Auch enthalten in: $sources';
  }

  @override
  String get placesReportProblemAction => 'Problem melden';

  @override
  String get placesBannerWithdrawing => 'Meldung wird zurückgezogen…';

  @override
  String get placesBannerYouReported =>
      'Sie haben das gemeldet: Es braucht die Bestätigung anderer Nutzer.';

  @override
  String get placesBannerConfirmedSaving =>
      'Sie haben bestätigt. Wird gespeichert…';

  @override
  String get placesBannerConfirmedChange =>
      'Sie haben bestätigt. Sie können Ihre Meinung ändern.';

  @override
  String get placesBannerDeniedSaving =>
      'Sie haben angegeben, dass es nicht stimmt. Wird gespeichert…';

  @override
  String get placesBannerDeniedChange =>
      'Sie haben angegeben, dass es nicht stimmt. Sie können Ihre Meinung ändern.';

  @override
  String get placesBannerWithdrawButton => 'Meine Meldung zurückziehen';

  @override
  String get placesBannerConfirm => 'Stimmt';

  @override
  String get placesBannerDeny => 'Stimmt nicht';

  @override
  String placesVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen',
      one: '$count Stimme',
    );
    return '$_temp0';
  }

  @override
  String placesRatingAverage(String average, String votes) {
    return 'Community-Bewertung: $average von 5 · $votes';
  }

  @override
  String get placesRatingNone => 'Community-Bewertung: noch keine Stimmen';

  @override
  String placesRatingBelowThreshold(String votes) {
    return 'Community-Bewertung: $votes · der Durchschnitt erscheint ab 3 Stimmen';
  }

  @override
  String placesRateStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sterne geben',
      one: '$count Stern geben',
    );
    return '$_temp0';
  }

  @override
  String placesRatingSaving(int stars) {
    return 'Ihre Bewertung: $stars von 5. Wird gespeichert…';
  }

  @override
  String placesRatingYours(int stars) {
    return 'Ihre Bewertung: $stars von 5. Tippen Sie auf einen Stern, um sie zu ändern.';
  }

  @override
  String get placesRatingPrompt =>
      'Wie ist dieser Hundeauslauf? Tippen Sie auf einen Stern, um zu bewerten.';

  @override
  String get placesExpiryToday => 'Läuft heute ab, wenn niemand bestätigt.';

  @override
  String placesExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Läuft in $days Tagen ab, wenn niemand bestätigt.',
      one: 'Läuft in $days Tag ab, wenn niemand bestätigt.',
    );
    return '$_temp0';
  }

  @override
  String get placesProblemClosed => 'Geschlossen oder existiert nicht mehr';

  @override
  String get placesProblemDuplicate => 'Doppelt vorhanden (gleicher Ort)';

  @override
  String get placesProblemWrongPosition => 'Die Position ist falsch';

  @override
  String get placesCategoryVeterinary => 'Tierärzte';

  @override
  String get placesCategoryShop => 'Geschäfte';

  @override
  String get placesCategoryDogPark => 'Hundeausläufe';

  @override
  String get placesCategoryShelter => 'Tierheime und Vermittlung';

  @override
  String get placesCategoryAssociation => 'Vereine';

  @override
  String get placesCategoryGrooming => 'Tierpflege';

  @override
  String get placesCategoryHotel => 'Tierpensionen';

  @override
  String get placesCategorySchool => 'Training';

  @override
  String get placesCategoryPetSitting => 'Tiersitter';

  @override
  String get placesCategoryBreeder => 'Zuchten';

  @override
  String get placesCategoryOther => 'Weitere Services';

  @override
  String get placesTypeVeterinary => 'Tierarzt';

  @override
  String get placesTypeGrooming => 'Tierpflege';

  @override
  String get placesTypeShop => 'Zoohandlung';

  @override
  String get placesTypeSchool => 'Training';

  @override
  String get placesTypePetSitting => 'Tiersitter';

  @override
  String get placesTypeBreeder => 'Zucht';

  @override
  String get placesTypeHotel => 'Tierpension';

  @override
  String get placesTypeDogPark => 'Hundeauslauf';

  @override
  String get placesTypeShelter => 'Tierheim';

  @override
  String get placesTypeAssociation => 'Tierschutzverein';

  @override
  String get placesTypeOther => 'Tierservice';

  @override
  String get placesHours247 => 'Laut Angabe rund um die Uhr geöffnet';

  @override
  String get placesHoursHolidays => 'Feiertage';

  @override
  String get placesHoursClosed => 'geschlossen';

  @override
  String get placesSourcesTitle => 'Datenquellen';

  @override
  String get placesSourcesIntro =>
      'Die Orte im Radar stammen aus offenen Datenquellen, nicht von Quokka. Jeder Eintrag nennt seine Quelle. Öffnungszeiten und Kontaktdaten sind möglicherweise nicht aktuell.';

  @override
  String get placesSourcesNoContact =>
      'Falsche Angabe entdeckt? Nutzen Sie „Problem melden“ im Eintrag des Ortes.';

  @override
  String placesSourcesContact(String email) {
    return 'Falsche Angabe entdeckt, oder Sie sind Inhaber und möchten einen Eintrag korrigieren oder entfernen lassen? Schreiben Sie an $email.';
  }

  @override
  String placesSourceLicense(String license) {
    return 'Lizenz: $license';
  }

  @override
  String placesSourceVersion(String release, String date) {
    return 'Version $release, importiert am $date';
  }

  @override
  String get placesSourceLicenseLink => 'Lizenz und Bedingungen';

  @override
  String get placesSourceOsmDescription =>
      'Freie Karte, von Freiwilligen gepflegt. Quelle der Hundeausläufe und eines Teils der Tierärzte, Geschäfte und weiteren Services, mit den Angaben der Freiwilligen.';

  @override
  String get placesSourceOvertureDescription =>
      'Offenes Verzeichnis von Unternehmen. Quelle für Tierärzte, Tierpflege, Geschäfte, Tierpensionen und Hundetrainer, die OpenStreetMap nicht kennt.';

  @override
  String get placesSourceBolognaDescription =>
      'Offizielle Liste der Hundeauslaufflächen der Stadt Bologna.';

  @override
  String get placesSourceTorinoDescription =>
      'Offizielle Liste der Hundeausläufe der Stadt Turin.';

  @override
  String get placesSourceMilanoDescription =>
      'Offizielle Liste der Hundeausläufe der Stadt Mailand.';

  @override
  String get placesSourceBolognaAttribution =>
      'Comune di Bologna, Aree sgambatura cani (opendata.comune.bologna.it), Lizenz CC BY 4.0';

  @override
  String get placesSourceTorinoAttribution =>
      'Comune di Torino, Aree Cani (aperto.comune.torino.it), Lizenz CC BY 4.0, Daten von 2019';

  @override
  String get placesSourceMilanoAttribution =>
      'Comune di Milano, Territorio: localizzazione delle aree cani (dati.comune.milano.it), Lizenz CC BY 4.0. Enthält bearbeitete Daten (CC BY 3.0) von dati.gov.it';

  @override
  String get placesSourceLicenseCcBy =>
      'Creative Commons Namensnennung 4.0 (CC BY 4.0)';

  @override
  String get placesSourceUsersName => 'Quokka-Nutzer';

  @override
  String get placesSourceUsersDescription =>
      'Von Nutzern gemeldete und von anderen Nutzern bestätigte Orte.';

  @override
  String get placesSourceUsersAttribution => 'Von Quokka-Nutzern gemeldet';

  @override
  String placesMapTitle(String radius) {
    return 'Karte · $radius';
  }

  @override
  String placesMapClusterSemantics(int count) {
    return '$count Orte nah beieinander';
  }

  @override
  String placesMapMarkerPending(String category, String label) {
    return '$category, wartet auf Bestätigung: $label';
  }

  @override
  String placesMapMarker(String category, String label) {
    return '$category: $label';
  }

  @override
  String get placesReportTitle => 'Fehlenden Ort melden';

  @override
  String get placesReportUnavailable =>
      'Meldungen sind derzeit nicht verfügbar. Bitte versuchen Sie es später erneut.';

  @override
  String get placesReportWhatIs => 'Was ist es?';

  @override
  String get placesReportNameOptional => 'Name (optional)';

  @override
  String get placesReportNameLabel => 'Name auf dem Schild';

  @override
  String get placesReportNameHelper =>
      'Nur der Name: keine Telefonnummern, Adressen oder Personennamen.';

  @override
  String get placesReportWhere => 'Wo befindet es sich?';

  @override
  String get placesReportMapHint =>
      'Verschieben Sie die Karte, bis der Marker auf dem Ort liegt. Die Adresse wird aus der Position ermittelt.';

  @override
  String get placesReportSubmit => 'Meldung senden';

  @override
  String placesReportFootnote(int days) {
    return 'Die Meldung ist für alle als „wartet auf Bestätigung“ sichtbar und wird endgültig, sobald andere Nutzer sie bestätigen. Wenn sie innerhalb von $days Tagen niemand bestätigt, wird sie automatisch gelöscht. Sie können sie jederzeit in ihrem Eintrag zurückziehen. Ihr Name wird nicht angezeigt.';
  }

  @override
  String placesReportSentExpiry(int days) {
    return 'Meldung gesendet. Wenn sie innerhalb von $days Tagen niemand bestätigt, wird sie gelöscht.';
  }

  @override
  String get placesRulesTitle => 'Bevor Sie melden oder bewerten';

  @override
  String get placesRulesCheckbox =>
      'Ich habe die Regeln gelesen und melde oder bewerte in gutem Glauben.';

  @override
  String get placesRulesAccept => 'Akzeptieren';

  @override
  String get placesRulesFallback =>
      'Melden Sie nur, was Sie persönlich überprüft haben. Geben Sie bei Betrieben nur den Namen auf dem Schild an, ohne Telefonnummern, private Adressen oder Daten anderer Personen. Meldungen bleiben offen, bis andere Nutzer sie bestätigen. Falsche oder wiederholte Meldungen können zur Sperrung des Kontos führen. Meldungen und Bewertungen werden ohne Ihren Namen veröffentlicht.';

  @override
  String get placesErrSignedOutContribute =>
      'Melden Sie sich an, um zu melden oder zu bewerten.';

  @override
  String get placesErrOperationFailed =>
      'Der Vorgang konnte nicht abgeschlossen werden. Bitte versuchen Sie es erneut.';

  @override
  String get placesErrTimeout =>
      'Die Anfrage hat zu lange gedauert. Bitte versuchen Sie es erneut.';

  @override
  String get placesErrNotConfigured =>
      'Vorschau ohne Backend: Die angezeigten Orte sind Beispieldaten.';

  @override
  String get placesErrSignedOut =>
      'Melden Sie sich an, um Tierservices in Ihrer Nähe zu sehen.';

  @override
  String get placesErrPreparing =>
      'Die Services dieser Gegend werden noch vorbereitet. Bitte versuchen Sie es gleich noch einmal.';

  @override
  String get placesErrSessionExpired =>
      'Die Sitzung ist nicht mehr gültig: Melden Sie sich ab und wieder an, um Services in der Nähe zu sehen.';

  @override
  String get placesErrLoadFailed =>
      'Die Services in der Nähe konnten nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get placesBackendRulesRequired =>
      'Um zu melden oder zu bewerten, akzeptieren Sie zuerst die Regeln für Meldungen und Bewertungen.';

  @override
  String get placesBackendReportClosed =>
      'Diese Meldung wurde bereits geschlossen.';

  @override
  String get placesBackendReportExpired =>
      'Diese Meldung ist abgelaufen: Niemand hat sie bestätigt.';

  @override
  String get placesBackendOwnReportVote =>
      'Sie können Ihre eigene Meldung nicht bestätigen.';

  @override
  String get placesBackendKindNotActive => 'Diese Meldungsart ist nicht aktiv.';

  @override
  String get placesBackendCategoryNotReportable =>
      'Diese Kategorie kann nicht gemeldet werden.';

  @override
  String get placesBackendTargetRequired =>
      'Geben Sie den Ort an, auf den sich die Meldung bezieht.';

  @override
  String get placesBackendPendingUseDeny =>
      'Nutzen Sie bei einem Ort, der auf Bestätigung wartet, „Stimmt nicht“ in seinem Eintrag.';

  @override
  String get placesBackendAlreadyReported =>
      'Sie haben diese Meldung bereits gemacht.';

  @override
  String placesBackendDailyLimit(int count) {
    return 'Sie können höchstens $count Meldungen pro Tag machen.';
  }

  @override
  String get placesBackendReportNotFound => 'Meldung nicht gefunden.';

  @override
  String get placesBackendWithdrawOwnOnly =>
      'Sie können nur Ihre eigene Meldung zurückziehen.';

  @override
  String get placesBackendWithdrawClosed =>
      'Diese Meldung ist bereits abgeschlossen und kann nicht mehr zurückgezogen werden.';

  @override
  String get placesBackendRatingsOff => 'Bewertungen sind nicht aktiv.';

  @override
  String get placesBackendRatePublicOnly =>
      'Nur öffentliche Hundeauslaufplätze können bewertet werden.';

  @override
  String get placesBackendDogParkNotFound =>
      'Hundeauslaufplatz nicht gefunden.';

  @override
  String get placesBackendContributionsOff =>
      'Meldungen und Bewertungen sind noch nicht aktiv.';

  @override
  String get placesBackendNameRequired =>
      'Geben Sie den Namen des Betriebs ein, wie er auf dem Schild steht.';

  @override
  String placesBackendNameTooLong(int count) {
    return 'Der Name darf höchstens $count Zeichen lang sein.';
  }

  @override
  String get placesBackendNameNoContacts =>
      'Geben Sie im Namen keine Telefonnummern, E-Mail-Adressen oder Websites an.';

  @override
  String get placesBackendNameBlockedWords =>
      'Der Name enthält nicht zulässige Wörter.';

  @override
  String get eventsTitle => 'Veranstaltungen';

  @override
  String get eventsSearching => 'Ich suche Veranstaltungen...';

  @override
  String get eventsAllRegions => 'Alle Regionen';

  @override
  String get eventsAllTypes => 'Alle Arten';

  @override
  String get eventsReset => 'Zurücksetzen';

  @override
  String get eventsDisclaimer =>
      'Termine und Orte können sich ändern: Prüfen Sie immer die Website des Veranstalters.';

  @override
  String get eventsPickRegionTitle => 'Region';

  @override
  String get eventsPickTypeTitle => 'Art der Veranstaltung';

  @override
  String get eventsPickDatesHelp => 'Zeitraum wählen';

  @override
  String get eventsPickDatesSave => 'Übernehmen';

  @override
  String get eventsStatusCancelled => 'Abgesagt';

  @override
  String get eventsStatusPostponed => 'Verschoben';

  @override
  String eventsOrganizedBy(String name) {
    return 'Veranstalter: $name';
  }

  @override
  String get eventsSuggestAction => 'Veranstaltung melden';

  @override
  String get eventsSuggestTitle => 'Veranstaltung melden';

  @override
  String get eventsSuggestIntro =>
      'Kennen Sie eine Tiermesse oder Tierveranstaltung, die Sie hier nicht finden? Füllen Sie die Angaben aus: Wir prüfen sie auf der Website des Veranstalters, bevor wir sie veröffentlichen.';

  @override
  String get eventsSuggestPrivacy =>
      'Schreiben Sie nur Angaben zur Veranstaltung: keine Namen von Personen, E-Mail-Adressen oder Telefonnummern.';

  @override
  String get eventsSuggestFieldTitle => 'Name der Veranstaltung';

  @override
  String get eventsSuggestFieldType => 'Art der Veranstaltung';

  @override
  String get eventsSuggestFieldDates => 'Datum';

  @override
  String get eventsSuggestPickDates => 'Datum wählen';

  @override
  String get eventsSuggestFieldCity => 'Stadt';

  @override
  String get eventsSuggestFieldProvince => 'Provinz (Kürzel, z. B. MO)';

  @override
  String get eventsSuggestFieldVenue =>
      'Ort, zum Beispiel das Messegelände (optional)';

  @override
  String get eventsSuggestFieldLink => 'Link zur Seite der Veranstaltung';

  @override
  String get eventsSuggestRequired => 'Pflichtfeld';

  @override
  String get eventsSuggestInvalidLink =>
      'Geben Sie eine Adresse ein, die mit http:// oder https:// beginnt';

  @override
  String get eventsSuggestInvalidProvince =>
      'Verwenden Sie das Kürzel aus zwei Buchstaben';

  @override
  String get eventsSuggestSend => 'Meldung senden';

  @override
  String get eventsSuggestThanks =>
      'Danke! Wir prüfen die Veranstaltung, bevor wir sie veröffentlichen.';

  @override
  String get eventsSuggestNeedLogin =>
      'Melden Sie sich an, um eine Veranstaltung zu melden.';

  @override
  String get eventsSuggestLimit =>
      'Sie haben heute schon Ihre Meldungen gesendet: Versuchen Sie es morgen wieder.';

  @override
  String get eventsSuggestError =>
      'Die Meldung konnte nicht gesendet werden. Bitte versuchen Sie es später erneut.';

  @override
  String get eventsLoadError =>
      'Ich kann die Veranstaltungen nicht laden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String eventsWindowDefault(int days) {
    return 'Nächste $days Tage';
  }

  @override
  String get eventsEmptyFiltered =>
      'Keine Veranstaltungen mit diesen Filtern im gewählten Zeitraum';

  @override
  String eventsEmptyDefault(int days) {
    return 'Keine Veranstaltungen in den nächsten $days Tagen';
  }

  @override
  String get eventsEmptyPeriod => 'Keine Veranstaltungen im gewählten Zeitraum';

  @override
  String get eventsCountryOnlyNote =>
      'Wir zeigen nur Veranstaltungen aus Ihrem Land, dem Land der Sprache, die Sie in der App gewählt haben.';

  @override
  String get eventsLevelLocal => 'Lokal';

  @override
  String get eventsLevelProvincial => 'Provinz';

  @override
  String get eventsLevelRegional => 'Regional';

  @override
  String get eventsLevelNational => 'National';

  @override
  String get eventsLevelInternational => 'International';

  @override
  String get eventsTypePetFair => 'Tiermesse';

  @override
  String get eventsTypeDogShow => 'Hundeausstellung';

  @override
  String get eventsTypeBreedGathering => 'Rassetreffen';

  @override
  String get eventsTypeCatShow => 'Katzenausstellung';

  @override
  String get eventsTypeWorkTrial => 'Arbeitsprüfung';

  @override
  String get eventsTypeDogSport => 'Hundesport';

  @override
  String get eventsTypeAdoptionDay => 'Adoptionstag';

  @override
  String get eventsTypeShelterOpenDay => 'Tag der offenen Tür im Tierheim';

  @override
  String get eventsTypeMicrochipDay => 'Mikrochip-Tag';

  @override
  String get eventsTypeVaccinationCampaign => 'Impfaktion';

  @override
  String get eventsTypeGroupWalk => 'Gruppenspaziergang';

  @override
  String get eventsTypeCourseSeminar => 'Kurs oder Seminar';

  @override
  String get eventsTypeMarket => 'Flohmarkt';

  @override
  String get eventsTypeCharityEvent => 'Wohltätigkeitsveranstaltung';

  @override
  String get eventsTypeAquariumExpo => 'Aquaristik';

  @override
  String get eventsTypeReptileExpo => 'Terraristik';

  @override
  String get eventsTypeBirdShow => 'Ornithologie';

  @override
  String get eventsTypeEquestrian => 'Reitsport';

  @override
  String get eventsTypeOther => 'Sonstiges';

  @override
  String get localActivitiesKindEvent => 'Veranstaltung';

  @override
  String get localActivitiesKindService => 'Service';

  @override
  String get localEventsTitle => 'In meiner Nähe';

  @override
  String get localEventsLocating => 'Ich suche Ihren Standort…';

  @override
  String get localEventsSearchingAround =>
      'Ich suche, was in Ihrer Nähe ist. Beim ersten Mal in einer Gegend kann es bis zu einer Minute dauern.';

  @override
  String get localEventsConsentTitle => 'Ihren Standort verwenden?';

  @override
  String get localEventsConsentBody =>
      'Um Ihnen zu zeigen, was in der Nähe ist, nutzt Quokka den Standort Ihres Telefons nur, solange Sie die App verwenden. Alternativ können Sie eine Adresse angeben.';

  @override
  String get localEventsConsentChooseAddress => 'Adresse wählen';

  @override
  String get localEventsConsentAllow => 'Erlauben';

  @override
  String get localEventsReportMissing => 'Melden! Ein Ort fehlt';

  @override
  String get localEventsServicesHeader => 'Services in der Gegend';

  @override
  String get localEventsClinicsHeader => 'Kliniken und Praxen';

  @override
  String get localEventsNoClinics =>
      'Keine Klinik mit diesen Filtern gefunden.';

  @override
  String get localEventsNoServices =>
      'Kein Service mit diesen Filtern gefunden.';

  @override
  String get localEventsAll => 'Alle';

  @override
  String get localEventsMapFullscreen => 'Karte im Vollbild öffnen';

  @override
  String get localEventsNoLocationTitle => 'Standort festlegen';

  @override
  String get localEventsNoLocationBody =>
      'Um Ihnen zu zeigen, was in der Nähe ist, brauchen wir Ihren Standort. Erlauben Sie den Standortzugriff oder geben Sie Ihre Wohnadresse unter Einstellungen → Standort an.';

  @override
  String get localEventsOpenSettings => 'Einstellungen öffnen';

  @override
  String localEventsSearchingRadius(String radius) {
    return 'Ich suche Services im Umkreis von $radius. Beim ersten Mal in einer Gegend kann es bis zu einer Minute dauern.';
  }

  @override
  String get localEventsSearchingNearby =>
      'Ich suche Services in Ihrer Gegend. Beim ersten Mal kann es einige Sekunden dauern.';

  @override
  String get localEventsCoverageLimited =>
      'Die Daten zu den Diensten in dieser Gegend werden noch vorbereitet: Sie sehen möglicherweise nur wenige Orte oder müssen länger warten.';

  @override
  String get localEventsCoverageUnsupported =>
      'Der Radar deckt dieses Land noch nicht ab: Sie sehen nur, was OpenStreetMap kennt, ohne weitere Prüfungen.';

  @override
  String get localEventsStale =>
      'Ich konnte die Services dieser Gegend nicht aktualisieren: Sie sehen die zuletzt verfügbaren Daten, die möglicherweise nicht aktuell sind.';

  @override
  String localEventsPartialRadius(String radius) {
    return 'Aktuell sind Services im Umkreis von $radius verfügbar. Versuchen Sie es gleich noch einmal für den vollen Umkreis.';
  }

  @override
  String get localEventsShowLess => 'Weniger anzeigen';

  @override
  String localEventsShowAllCount(int count) {
    return 'Alle anzeigen ($count)';
  }

  @override
  String localEventsShowAllCategory(String category, int count) {
    return 'Alle anzeigen: $category ($count)';
  }

  @override
  String localEventsCategoryNone(String category, String radius) {
    return '$category: keine im Umkreis von $radius';
  }

  @override
  String localEventsCategoryCount(String category, int count) {
    return '$category ($count)';
  }

  @override
  String localEventsSectionExpand(String section) {
    return '$section öffnen';
  }

  @override
  String localEventsSectionCollapse(String section) {
    return '$section schließen';
  }

  @override
  String localEventsCallTooltip(String name) {
    return '$name anrufen';
  }

  @override
  String localEventsDirectionsTooltip(String name) {
    return 'Route zu $name';
  }

  @override
  String get remindersRelativeToday => 'heute';

  @override
  String get remindersRelativeTomorrow => 'morgen';

  @override
  String get remindersRelativeYesterday => 'gestern';

  @override
  String remindersRelativeInDays(int days) {
    return 'in $days Tagen';
  }

  @override
  String remindersRelativeDaysAgo(int days) {
    return 'vor $days Tagen';
  }

  @override
  String get remindersKindEvent => 'Termin';

  @override
  String remindersKindRecurring(String interval, String end) {
    return 'Wiederholt · $interval$end';
  }

  @override
  String remindersCourseStarts(String day) {
    return 'Beginnt $day';
  }

  @override
  String get remindersCourseCompleted => 'Abgeschlossen';

  @override
  String remindersCourseDayOf(int day, int total) {
    return 'Tag $day von $total';
  }

  @override
  String remindersKindCourse(int days) {
    return 'Kur · $days Tage';
  }

  @override
  String remindersKindCourseWithTimes(int days, String times) {
    return 'Kur · $days Tage · $times';
  }

  @override
  String remindersIntervalEveryDays(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: 'alle $value Tage',
      one: 'jeden Tag',
    );
    return '$_temp0';
  }

  @override
  String remindersIntervalEveryMonths(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: 'alle $value Monate',
      one: 'jeden Monat',
    );
    return '$_temp0';
  }

  @override
  String remindersEndAfterTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-mal',
      one: '$count-mal',
    );
    return ' · $_temp0';
  }

  @override
  String remindersEndUntilDate(String date) {
    return ' · bis $date';
  }

  @override
  String get remindersMenuTooltip => 'Optionen für Erinnerung';

  @override
  String get remindersMenuMarkDone => 'Als erledigt markieren';

  @override
  String get remindersDeleteConfirmTitle => 'Diese Erinnerung löschen?';

  @override
  String remindersDeleteConfirmBody(String title) {
    return '\"$title\" wird endgültig gelöscht.';
  }

  @override
  String get remindersErrorPetNotSynced =>
      'Das Tierprofil ist nicht mit dem Server synchronisiert: Beheben Sie das, bevor Sie Erinnerungen anlegen.';

  @override
  String get remindersErrorSaveFailed =>
      'Ich konnte die Erinnerung nicht speichern. Versuchen Sie es erneut.';

  @override
  String get remindersErrorDeleteFailed =>
      'Ich konnte die Erinnerung nicht löschen. Versuchen Sie es erneut.';

  @override
  String get petNewsTitle => 'News';

  @override
  String get petNewsLoading => 'Ich lade die News...';

  @override
  String get petNewsEmpty =>
      'Zurzeit sind für diese Kategorie keine News verfügbar.';

  @override
  String get petNewsEmptyLocal =>
      'Zurzeit gibt es keine News in Ihrer Sprache und für Ihr Land. News aus anderen Ländern zeigen wir nicht.';

  @override
  String get petNewsCategoryAll => 'Alle';

  @override
  String get petNewsCategoryDog => 'Hund';

  @override
  String get petNewsCategoryCat => 'Katze';

  @override
  String get petNewsCategorySmallMammals => 'Kleinsäuger';

  @override
  String get petNewsCategoryBird => 'Vogel';

  @override
  String get petNewsCategoryReptiles => 'Reptilien und Amphibien';

  @override
  String get petNewsCategoryFish => 'Fisch';

  @override
  String get petNewsCategoryOther => 'Sonstiges';

  @override
  String get petNewsCategoryGeneral => 'Allgemein';

  @override
  String get profileLogoutDialogTitle => 'Abmelden';

  @override
  String get profileLogoutDialogBody =>
      'Möchten Sie sich von diesem Konto abmelden?';

  @override
  String get profileGuestName => 'Gast';

  @override
  String get profileNoActiveSession => 'Keine Sitzung';

  @override
  String profileSummaryBody(String pets) {
    return 'Besitzerprofil, verknüpft mit $pets, bereit für die responsive Web-App.';
  }

  @override
  String profilePetCount(int count) {
    return 'Tiere: $count';
  }

  @override
  String get profileContactsTitle => 'Kontakt';

  @override
  String get profileEmailLabel => 'E-Mail';

  @override
  String get profilePhoneLabel => 'Telefon';

  @override
  String get profilePhoneNotSet => 'Keine Angabe';

  @override
  String get profileCityLabel => 'Stadt';

  @override
  String get profileCityNotSet => 'Keine Angabe';

  @override
  String get profileEveningThemeTitle => 'Abend-Design';

  @override
  String get profileEveningThemeBody =>
      'Vorschau einer sanfteren Farbpalette für den Abend.';

  @override
  String get profileAccountStatusTitle => 'Kontostatus';

  @override
  String get profileSessionLabel => 'Sitzung';

  @override
  String get profileSessionActive => 'Aktiv';

  @override
  String get profilePrivacyLabel => 'Datenschutz';

  @override
  String get profilePrivacyUpdated => 'Aktualisiert';

  @override
  String get profileSupportLabel => 'Support';

  @override
  String get profileSupportAvailable => 'Verfügbar';

  @override
  String get profileSettingsButton => 'Einstellungen';

  @override
  String get profileLogoutButton => 'Abmelden';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileIntro =>
      'Besitzerdaten, Einstellungen und Kontodetails an einem Ort für die responsive Web-App.';

  @override
  String get profileRoadmapTitle => 'Nächste Schritte';

  @override
  String get profileRoadmapBody =>
      'Hier können wir Einwilligungen, Einstellungen und die Kontoverknüpfung weiterentwickeln, ohne den Web-Ablauf zu ändern.';

  @override
  String get activitiesTitle => 'Aktivitäten';

  @override
  String get activitiesSubtitle => 'Alles rund ums Leben mit Ihren Tieren.';

  @override
  String get activitiesNewsSubtitle =>
      'Wissenswertes und Aktuelles über Haustiere.';

  @override
  String get activitiesNearbyTitle => 'In meiner Nähe';

  @override
  String get activitiesNearbySubtitle =>
      'Tierärzte, Geschäfte und Hundeauslaufplätze in Ihrer Nähe.';

  @override
  String get activitiesEventsTitle => 'Veranstaltungen';

  @override
  String get activitiesEventsSubtitle =>
      'Messen, Ausstellungen und Aktionen für Tiere in Ihrem Land.';

  @override
  String get activitiesGalleryTitle => 'Galerie';

  @override
  String get activitiesGallerySubtitle =>
      'Sammeln Sie Fotos und Erinnerungen Ihrer Tiere.';

  @override
  String get activitiesMarketplaceTitle => 'Gebrauchtmarkt';

  @override
  String get activitiesMarketplaceSubtitle =>
      'Kaufen, verkaufen und tauschen Sie Tierzubehör.';

  @override
  String get activitiesPetFriendTitle => 'Pet Friend';

  @override
  String get activitiesPetFriendSubtitle =>
      'Treffen und Gesellschaft für Tiere und Besitzer.';

  @override
  String get activitiesComingSoonBadge => 'Demnächst';

  @override
  String get activitiesPetFriendDescription =>
      'Lernen Sie andere Tierbesitzer kennen und planen Sie Ausflüge für Tiere mit ähnlichem Wesen.';

  @override
  String get remindersTitle => 'Erinnerungen';

  @override
  String get remindersSubtitle =>
      'Impfungen, Behandlungen und Untersuchungen im Blick behalten.';

  @override
  String get remindersCreateButton => 'Neu';

  @override
  String get remindersLoadingTitle => 'Erinnerungen werden geladen';

  @override
  String get remindersLoadingBody =>
      'Ich lese Daten, Wiederholungen und Notizen des Besitzers.';

  @override
  String get remindersSyncErrorLabel => 'Sync-Fehler';

  @override
  String get remindersSyncErrorTitle =>
      'Synchronisierung der Erinnerungen fehlgeschlagen.';

  @override
  String get remindersSyncErrorBody =>
      'Die Demo-Quelle ist weiterhin verfügbar. Versuchen Sie es erneut, sobald das Netz wieder da ist.';

  @override
  String get remindersEmptyLabel => 'Keine Erinnerungen';

  @override
  String get remindersEmptyTitle => 'Die Erinnerungsliste ist leer.';

  @override
  String get remindersEmptyBody =>
      'Legen Sie die erste Erinnerung für eine Impfung oder Behandlung an und behalten Sie den Überblick.';

  @override
  String get remindersNoMatchForFilters => 'Keine Erinnerung für diese Filter.';

  @override
  String get remindersFilterAll => 'Alle';

  @override
  String get remindersFilterEvents => 'Termine';

  @override
  String get remindersFilterCourses => 'Kuren';

  @override
  String get remindersViewList => 'Liste';

  @override
  String get remindersViewCalendar => 'Kalender';

  @override
  String get remindersNothingThisDay => 'Keine Aktivitäten an diesem Tag.';

  @override
  String get remindersTodayCapitalized => 'Heute';

  @override
  String get remindersEditTitle => 'Erinnerung bearbeiten';

  @override
  String get remindersEditSubtitle => 'Art, Datum und Notizen aktualisieren.';

  @override
  String get remindersDosePickerHelp => 'Uhrzeit der Dosis';

  @override
  String get remindersDateRequired => 'Geben Sie ein Datum ein.';

  @override
  String get remindersDateInvalid => 'Ungültiges Datum (TT/MM/JJJJ).';

  @override
  String get remindersFormKind => 'Art';

  @override
  String get remindersFormTitleLabel => 'Titel';

  @override
  String get remindersFormTitleHint => 'z. B. Auffrischimpfung';

  @override
  String remindersFormTitleHintWithPet(String petName) {
    return 'z. B. Auffrischimpfung von $petName';
  }

  @override
  String get remindersTitleRequired => 'Geben Sie einen Titel ein.';

  @override
  String get remindersFieldDate => 'Datum';

  @override
  String get remindersFieldNextDue => 'Nächster Termin';

  @override
  String get remindersFieldStartDate => 'Startdatum';

  @override
  String get remindersFieldTime => 'Uhrzeit';

  @override
  String get remindersRepeats => 'Wiederholung';

  @override
  String get remindersCustomNumberHint => 'Anzahl';

  @override
  String get remindersRecurrenceEndLabel => 'Ende der Wiederholung';

  @override
  String get remindersOccurrenceCountHint => 'Anzahl der Wiederholungen';

  @override
  String get remindersLastDate => 'Letztes Datum';

  @override
  String get remindersCourseDuration => 'Dauer der Kur';

  @override
  String get remindersDoseTimes => 'Uhrzeiten der Dosen';

  @override
  String get remindersAddDoseTime => 'Uhrzeit hinzufügen';

  @override
  String get remindersNoDoseTimesNote =>
      'Ohne Uhrzeiten erhalten Sie einmal täglich um 9:00 Uhr eine Benachrichtigung.';

  @override
  String get remindersFormNote => 'Notiz';

  @override
  String get remindersFormNoteHint => 'z. B. Impfpass mitbringen';

  @override
  String get remindersKindOptionRecurring => 'Wiederholt';

  @override
  String get remindersKindOptionCourse => 'Kur';

  @override
  String get remindersDatePlaceholder => 'TT/MM/JJJJ';

  @override
  String get remindersPreset7Days => '7 Tage';

  @override
  String get remindersPreset30Days => '30 Tage';

  @override
  String get remindersPreset6Months => '6 Monate';

  @override
  String get remindersPreset12Months => '12 Monate';

  @override
  String get remindersPresetCustom => 'Eigene';

  @override
  String get remindersEndAlways => 'Immer';

  @override
  String get remindersEndAfterN => 'N-mal';

  @override
  String get remindersEndUntil => 'Bis zu einem Datum';

  @override
  String get remindersUnitDays => 'Tage';

  @override
  String get remindersUnitMonths => 'Monate';

  @override
  String get remindersOneDayLess => 'Einen Tag weniger';

  @override
  String remindersDurationRange(int min, int max) {
    return '$min bis $max Tage.';
  }

  @override
  String remindersDurationUnit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tage',
      one: 'Tag',
    );
    return '$_temp0';
  }

  @override
  String get remindersOneDayMore => 'Einen Tag mehr';

  @override
  String get remindersNotFoundTitle => 'Erinnerung nicht gefunden';

  @override
  String get remindersNotFoundSubtitle =>
      'Diese Erinnerung ist nicht mehr verfügbar.';

  @override
  String get remindersNotFoundLabel => 'Nicht gefunden';

  @override
  String get remindersNotFoundPanelTitle => 'Keine Erinnerung anzuzeigen.';

  @override
  String get remindersNotFoundBody =>
      'Sie wurde möglicherweise gelöscht oder noch nicht synchronisiert.';

  @override
  String get remindersBackToList => 'Zurück zur Liste';

  @override
  String get remindersDetailTitle => 'Erinnerungsdetails';

  @override
  String get remindersDetailSubtitle => 'Art, Datum und Notiz der Erinnerung.';

  @override
  String get remindersNoNote => 'Keine Notiz hinzugefügt.';

  @override
  String get remindersSummaryTitle => 'Übersicht der Erinnerung';

  @override
  String get remindersSummaryPet => 'Tier';

  @override
  String get remindersSummaryStatus => 'Status';

  @override
  String get remindersDeleteButton => 'Erinnerung löschen';

  @override
  String get remindersLoadingLabel => 'Wird geladen';

  @override
  String get remindersWait => 'Bitte warten';

  @override
  String get remindersCreateTitle => 'Erinnerung erstellen';

  @override
  String remindersCreateTitleForPet(String petName) {
    return 'Neue Erinnerung für $petName';
  }

  @override
  String get remindersCreateSubtitle => 'Wählen Sie Art, Datum und Details.';

  @override
  String get settingsUnitSystemMetricLabel => 'Metrisch';

  @override
  String get settingsUnitSystemUkLabel => 'Vereinigtes Königreich';

  @override
  String get settingsUnitSystemUsLabel => 'USA';

  @override
  String get settingsUnitSystemMetricDescription => 'km, kg, °C, Liter';

  @override
  String get settingsUnitSystemUkDescription => 'Meilen, Pfund, °C, Liter';

  @override
  String get settingsUnitSystemUsDescription =>
      'Meilen, Pfund, °F, US-Gallonen';

  @override
  String settingsVolumeLiters(int liters) {
    return '$liters Liter';
  }

  @override
  String get settingsUnitLitersName => 'Liter';

  @override
  String get settingsTextSizeSmall => 'Klein';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Groß';

  @override
  String get settingsTextSizeExtraLarge => 'Sehr groß';

  @override
  String get settingsLocationPickerTitle => 'Auf der Karte wählen';

  @override
  String get settingsLocationPickerHint =>
      'Verschieben Sie die Karte, bis die Markierung am richtigen Punkt sitzt, und bestätigen Sie dann.';

  @override
  String get settingsLocationPickerConfirm => 'Diesen Punkt bestätigen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsNumericDatePattern => 'dd.MM.yyyy';

  @override
  String get settingsGuestInitial => 'G';

  @override
  String get settingsGuestName => 'Gast';

  @override
  String get settingsNoActiveSession => 'Keine Sitzung';

  @override
  String get settingsSectionSubscription => 'Abo';

  @override
  String get settingsSubscriptionAndPayments => 'Abo und Zahlungen';

  @override
  String settingsTrialExpiresOn(String date) {
    return 'Testphase · endet am $date';
  }

  @override
  String get settingsSectionPushNotifications => 'Push-Benachrichtigungen';

  @override
  String get settingsNotificationsToggle => 'Benachrichtigungen';

  @override
  String get settingsSectionLayout => 'Layout';

  @override
  String get settingsLayoutWeeksTitle => 'Wochen auf der Startseite';

  @override
  String get settingsLayoutWeeksSubtitle =>
      'Anzahl der Wochen im Startseiten-Kalender.';

  @override
  String get settingsLayoutWeekStartTitle => 'Wochenbeginn';

  @override
  String get settingsLayoutChatTextSizeTitle => 'Textgröße im Chat';

  @override
  String get settingsLayoutChatTextSizePreview =>
      'So sehen Sie die Chat-Nachrichten.';

  @override
  String get settingsLayoutUnitsTitle => 'Maßeinheiten';

  @override
  String get settingsSectionPhotosVideos => 'Fotos und Videos';

  @override
  String get settingsGallerySaveTitle => 'Fotos in der Galerie speichern';

  @override
  String get settingsGallerySaveSubtitle =>
      'Fotos und Videos, die Sie mit der Kamera der App aufnehmen, werden in das Album „Quokka“ auf Ihrem Telefon kopiert.';

  @override
  String get settingsSectionLocation => 'Standort';

  @override
  String get settingsLocationIntro =>
      'Wird verwendet, um Veranstaltungen und News an Ihre Gegend anzupassen.';

  @override
  String get settingsLocationReferenceTitle => 'Referenzstandort';

  @override
  String get settingsLocationModeCurrent => 'Aktuell';

  @override
  String get settingsLocationModeHome => 'Zuhause';

  @override
  String get settingsLocationCurrentTitle => 'Aktueller Standort';

  @override
  String get settingsLocationDetecting => 'Standort wird ermittelt…';

  @override
  String get settingsLocationCurrentNotSet => 'Noch nicht festgelegt';

  @override
  String get settingsLocationRefresh => 'Aktualisieren';

  @override
  String get settingsLocationHomeTitle => 'Üblicher Wohnort';

  @override
  String get settingsLocationHomeNotSet => 'Nicht festgelegt';

  @override
  String get settingsLocationSet => 'Festlegen';

  @override
  String get settingsLocationErrorPermissionDenied =>
      'Standortberechtigung verweigert: Aktivieren Sie sie in den Geräteeinstellungen, um Ihren aktuellen Standort zu nutzen.';

  @override
  String get settingsLocationErrorServiceDisabled =>
      'Die Ortungsdienste sind auf dem Gerät deaktiviert.';

  @override
  String get settingsLocationErrorTimeout =>
      'Der Standort konnte nicht rechtzeitig ermittelt werden. Bitte versuchen Sie es erneut.';

  @override
  String get settingsLocationErrorUnsupported =>
      'Die Standortermittlung ist auf diesem Gerät/Browser nicht verfügbar.';

  @override
  String get settingsSectionPermissions => 'Berechtigungen und Einwilligungen';

  @override
  String get settingsConsentsUnavailable => 'Derzeit nicht verfügbar';

  @override
  String get settingsConsentsTapToRetry => 'Zum Wiederholen tippen';

  @override
  String get settingsConsentTerms => 'Nutzungsbedingungen';

  @override
  String get settingsConsentPrivacy => 'Datenschutzerklärung';

  @override
  String get settingsConsentMarketingEmail => 'Marketing-E-Mails';

  @override
  String get settingsConsentAnalytics => 'Nutzungsanalyse';

  @override
  String settingsConsentAccepted(String version, String date) {
    return 'Akzeptiert v$version am $date';
  }

  @override
  String get settingsConsentToConfirm => 'Zu bestätigen';

  @override
  String get settingsClinicalConsentSection => 'Krankenakte und Assistent';

  @override
  String get settingsPrivacyPolicyFullTitle =>
      'Vollständige Datenschutzerklärung';

  @override
  String get settingsPrivacyPolicyFullSubtitle =>
      'Text lesen, herunterladen oder teilen';

  @override
  String get settingsSectionSupport => 'Hilfe';

  @override
  String get settingsHelpCenterTitle => 'Hilfe-Center';

  @override
  String get settingsHelpCenterComingSoon =>
      'Häufige Fragen und Kurzanleitungen finden Sie bald direkt hier.';

  @override
  String get settingsContactUs => 'Kontakt';

  @override
  String get settingsContactUnavailable =>
      'Der Kontakt zum Support ist im Moment nicht verfügbar. Bitte versuchen Sie es später erneut.';

  @override
  String settingsContactWriteTo(String email) {
    return 'Schreiben Sie bei Fragen an $email.';
  }

  @override
  String get settingsRateApp => 'App bewerten';

  @override
  String get settingsRateAppThanks => 'Danke für Ihre Unterstützung! ⭐';

  @override
  String get settingsSectionInfo => 'Info';

  @override
  String get settingsDataSourcesTitle => 'Datenquellen';

  @override
  String get settingsDataSourcesSubtitle => 'Woher die Orte im Radar stammen';

  @override
  String get settingsAppVersion => 'App-Version';

  @override
  String get settingsSectionAccount => 'Konto';

  @override
  String get settingsLogout => 'Abmelden';

  @override
  String get settingsLogoutConfirmBody =>
      'Möchten Sie sich von diesem Konto abmelden?';

  @override
  String get settingsHomeCountryDefault => 'Deutschland';

  @override
  String get settingsHomeAddressNotFound =>
      'Diese Adresse wurde nicht gefunden. Prüfen Sie die Angaben und versuchen Sie es erneut.';

  @override
  String get settingsHomeAddressOrType => 'Oder Adresse eingeben:';

  @override
  String get settingsHomeAddressStreet => 'Adresse';

  @override
  String get settingsHomeAddressStreetRequired => 'Adresse eingeben';

  @override
  String get settingsHomeAddressPostalCode => 'PLZ';

  @override
  String get settingsHomeAddressPostalCodeRequired => 'PLZ eingeben';

  @override
  String get settingsHomeAddressCity => 'Stadt';

  @override
  String get settingsHomeAddressCityRequired => 'Stadt eingeben';

  @override
  String get settingsHomeAddressCountry => 'Land';

  @override
  String get settingsHomeAddressCountryRequired => 'Land eingeben';

  @override
  String get settingsHomeAddressSearching => 'Suche…';

  @override
  String get notificationsCategoryReminders => 'Termine und Impfungen';

  @override
  String get notificationsCategoryMedicines => 'Medikamentenzeiten';

  @override
  String get notificationsCategoryBirthdays => 'Geburtstage';

  @override
  String get notificationsChannelRemindersName => 'Erinnerungen';

  @override
  String get notificationsChannelRemindersDescription =>
      'Termine, Impfungen und andere Erinnerungen';

  @override
  String get notificationsChannelMedicinesName => 'Medikamente';

  @override
  String get notificationsChannelBirthdaysDescription =>
      'Geburtstage der Tiere';

  @override
  String notificationsReminderTodayBody(String petName, String time) {
    return '$petName · heute um $time Uhr';
  }

  @override
  String notificationsReminderTomorrowTitle(String title) {
    return 'Morgen: $title';
  }

  @override
  String notificationsReminderTomorrowBody(String petName, String time) {
    return '$petName · um $time Uhr';
  }

  @override
  String notificationsMedicineTitle(String petName) {
    return 'Medikament für $petName';
  }

  @override
  String notificationsMedicineDayBody(String title, int day, int total) {
    return '$title · Tag $day von $total';
  }

  @override
  String notificationsMedicineDoseBody(String title, String time) {
    return '$title · Dosis um $time Uhr';
  }

  @override
  String notificationsBirthdayTitle(String petName) {
    return 'Alles Gute zum Geburtstag, $petName!';
  }

  @override
  String notificationsBirthdayBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wird heute $count Jahre alt.',
      one: 'Wird heute $count Jahr alt.',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBirthdayUpcomingTitle => 'Geburtstag steht bevor';

  @override
  String notificationsBirthdayUpcomingBody(String petName) {
    return 'In einer Woche hat $petName Geburtstag: Denken Sie an ein Geschenk.';
  }

  @override
  String walksPageTitle(String petName) {
    return 'Spaziergang mit $petName';
  }

  @override
  String get walksStatusInProgress => 'Spaziergang läuft';

  @override
  String get walksStatusPaused => 'Spaziergang pausiert';

  @override
  String get walksStatDistance => 'Strecke';

  @override
  String get walksStatDuration => 'Dauer';

  @override
  String get walksStatPhotos => 'Fotos';

  @override
  String walksStatPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pausen',
      one: 'Pause',
    );
    return '$_temp0';
  }

  @override
  String get walksActionPause => 'Pause';

  @override
  String get walksActionResume => 'Fortsetzen';

  @override
  String get walksActionFinish => 'Beenden';

  @override
  String get walksActionSaving => 'Speichern...';

  @override
  String get walksActionStarting => 'Start...';

  @override
  String get walksActionStart => 'Spaziergang starten';

  @override
  String get walksWaitingForGps => 'Warte auf ein genaues GPS-Signal…';

  @override
  String get walksCameraTooltip => 'Foto oder Video';

  @override
  String get walksCaptureTakePhoto => 'Foto aufnehmen';

  @override
  String get walksCaptureRecordVideo => 'Video aufnehmen';

  @override
  String walksCaptureVideoLimit(int seconds) {
    return 'Bis zu $seconds Sekunden';
  }

  @override
  String get walksErrorOtherPetActive =>
      'Es läuft bereits ein Spaziergang mit einem anderen Tier. Beenden Sie ihn, bevor Sie einen neuen starten.';

  @override
  String get walksErrorLocationUnavailable =>
      'Ich kann Ihren Standort nicht ermitteln. Er wird benötigt, um die Strecke aufzuzeichnen. Prüfen Sie die Standortberechtigungen und versuchen Sie es erneut.';

  @override
  String get walksPhotoPinSemantics =>
      'Foto, das während des Spaziergangs aufgenommen wurde';

  @override
  String walksPhotoCaption(String date) {
    return 'Spaziergang vom $date';
  }

  @override
  String get walksMapUnavailable => 'Strecke nicht verfügbar';

  @override
  String get walksNoMoveTitle => 'Spaziergang ohne Bewegung';

  @override
  String get walksNoMoveBody =>
      'Es wurde keine Bewegung aufgezeichnet. Der Spaziergang wurde nicht gespeichert.';

  @override
  String get walksNoMoveAck => 'Verstanden';

  @override
  String get walksFavoritePromptTitle => 'Als Favorit speichern?';

  @override
  String walksFavoritePromptBody(String distance) {
    return 'Möchten Sie diesen Spaziergang ($distance) zu Ihren Favoriten hinzufügen ⭐?';
  }

  @override
  String get walksFavoriteNoThanks => 'Nein, danke';

  @override
  String get walksFavoriteSave => 'Speichern ⭐';

  @override
  String get walksFavoriteEvictTitle => 'Sie haben bereits 5 Favoriten';

  @override
  String get walksFavoriteEvictBody =>
      'Wählen Sie einen Favoriten zum Entfernen aus, um Platz für den gerade beendeten Spaziergang zu schaffen.';

  @override
  String get walksSheetOpen => 'Spaziergang öffnen';

  @override
  String get walksSheetFinish => 'Spaziergang beenden';

  @override
  String walksConfirmFinishTitle(String petName) {
    return 'Spaziergang mit $petName beenden?';
  }

  @override
  String get walksConfirmFinishBody =>
      'Die bisher aufgezeichnete Strecke wird gespeichert.';

  @override
  String get walksSavingSnackbar => 'Spaziergang wird gespeichert...';

  @override
  String get walksNotifPermTitle =>
      'Spaziergang in den Benachrichtigungen sehen';

  @override
  String get walksNotifPermBody =>
      'Während des Spaziergangs zeigt Quokka eine dauerhafte Benachrichtigung mit Zeit und Strecke an. Dort können Sie ihn pausieren oder beenden, auch wenn das Telefon in der Tasche steckt. Um sie zu sehen, wird die Berechtigung für Benachrichtigungen benötigt.\n\nDer Spaziergang wird trotzdem aufgezeichnet, auch wenn Sie „Nicht jetzt“ wählen.';

  @override
  String get walksNotifPermNotNow => 'Nicht jetzt';

  @override
  String get walksNotifPermAllow => 'Erlauben';

  @override
  String walksNotifTitleWithPet(String petName) {
    return 'Spaziergang mit $petName';
  }

  @override
  String walksNotifTitleWithPetPaused(String petName) {
    return 'Spaziergang mit $petName · pausiert';
  }

  @override
  String get walksNotifTitleNoPetPaused => 'Spaziergang läuft · pausiert';

  @override
  String walksNotifRunningText(String distance) {
    return '$distance zurückgelegt';
  }

  @override
  String get walksNotifFallbackPausedText =>
      'Die Aufzeichnung ist pausiert. Setzen Sie sie in der App fort, wann Sie möchten.';

  @override
  String get walksNotifFallbackRunningText =>
      'Quokka zeichnet die Strecke Ihres Spaziergangs auf.';

  @override
  String get walksNotifChannelName => 'Spaziergang-Aufzeichnung';

  @override
  String get walksSyncFailed =>
      'Synchronisierung fehlgeschlagen: Änderung nur auf dem Telefon gespeichert';

  @override
  String get walksFavoriteSaveFailed =>
      'Der Favorit konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get walksFavoriteRemoveFailed =>
      'Der Favorit konnte nicht entfernt werden. Bitte versuchen Sie es erneut.';

  @override
  String get walksDeleteFailed =>
      'Der Spaziergang konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get walksHighlightLongest => 'Längster';

  @override
  String get walksHighlightMostDurable => 'Ausdauerndster';

  @override
  String get walksHighlightFavorite => 'Favorit';

  @override
  String walksDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String walksDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get walksBadgeLabelFirstWalk => 'Erster Spaziergang 🐾';

  @override
  String walksBadgeLabelDistance(String km) {
    return '$km km gelaufen 🏃';
  }

  @override
  String walksBadgeLabelWalkCount(String count) {
    return '$count Spaziergänge 🎖️';
  }

  @override
  String get walksBadgeLabel30Min => '30 Minuten in einem Spaziergang ⏱️';

  @override
  String get walksBadgeLabel1Hour => '1 Stunde in einem Spaziergang ⏱️';

  @override
  String get walksBadgeLabelStreak => '7 Tage in Folge 🔥';

  @override
  String get walksBadgeLabelDawn => 'Spaziergang im Morgengrauen 🌅';

  @override
  String get walksBadgeLabelNight => 'Nachtspaziergang 🌙';

  @override
  String get walksBadgeEarnedBarrier => 'Abzeichen freigeschaltet';

  @override
  String walksBadgeEarnedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Neue Abzeichen freigeschaltet!',
      one: 'Neues Abzeichen freigeschaltet!',
    );
    return '$_temp0';
  }

  @override
  String get walksBadgeEarnedAction => 'Hurra!';

  @override
  String get walksBadgeGalleryTitle => 'Abzeichen';

  @override
  String get walksBadgeNameFirstWalk => 'Erster Spaziergang';

  @override
  String get walksBadgeDescFirstWalk =>
      'Schließen Sie Ihren ersten Spaziergang mit diesem Tier ab.';

  @override
  String walksBadgeNameKm(String km) {
    return '$km km';
  }

  @override
  String walksBadgeDescKm(String km) {
    return 'Legen Sie insgesamt $km km zurück.';
  }

  @override
  String get walksBadgeName30Min => '30 Minuten';

  @override
  String get walksBadgeDesc30Min =>
      'Machen Sie einen Spaziergang von mindestens 30 Minuten.';

  @override
  String get walksBadgeName1Hour => '1 Stunde';

  @override
  String get walksBadgeDesc1Hour =>
      'Machen Sie einen Spaziergang von mindestens einer Stunde.';

  @override
  String get walksBadgeNameStreak => '7 Tage in Folge';

  @override
  String get walksBadgeDescStreak =>
      'Gehen Sie 7 Tage hintereinander spazieren.';

  @override
  String get walksBadgeNameDawn => 'Spaziergang im Morgengrauen';

  @override
  String get walksBadgeDescDawn =>
      'Machen Sie einen Spaziergang zwischen 5 und 7 Uhr morgens.';

  @override
  String get walksBadgeNameNight => 'Nachtspaziergang';

  @override
  String get walksBadgeDescNight =>
      'Machen Sie einen Spaziergang nach 21 Uhr oder vor 5 Uhr.';

  @override
  String walksBadgeNameWalkCount(String count) {
    return '$count Spaziergänge';
  }

  @override
  String walksBadgeDescWalkCount(String count) {
    return 'Schließen Sie insgesamt $count Spaziergänge ab.';
  }

  @override
  String get settingsAccountProfile => 'Ihr Profil';

  @override
  String get settingsAccountChangeEmail => 'E-Mail ändern';

  @override
  String get settingsAccountChangePassword => 'Passwort ändern';

  @override
  String get settingsAccountSupport => 'Support';

  @override
  String get settingsAccountSupportSubtitle => 'Schreiben Sie uns eine E-Mail';

  @override
  String get settingsAccountDelete => 'Konto löschen';

  @override
  String get settingsAccountDeleteSubtitle =>
      'Ihr Konto und alle Ihre Daten löschen';

  @override
  String accountSupportSubject(String version) {
    return 'Quokka-Support (Version $version)';
  }

  @override
  String accountSupportBody(String version) {
    return 'Schreiben Sie hier Ihre Nachricht:\n\n\n\n—\nApp-Version: $version';
  }

  @override
  String get accountProfileTitle => 'Ihr Profil';

  @override
  String get accountProfileFirstName => 'Vorname';

  @override
  String get accountProfileLastName => 'Nachname';

  @override
  String get accountProfilePhone => 'Telefon (optional)';

  @override
  String get accountProfilePhoneHint => '+49 151 12345678';

  @override
  String get accountProfileFirstNameRequired => 'Geben Sie Ihren Vornamen ein.';

  @override
  String get accountProfileLastNameRequired => 'Geben Sie Ihren Nachnamen ein.';

  @override
  String get accountProfilePhoneInvalid => 'Ungültige Telefonnummer.';

  @override
  String get accountProfilePhotoAdd => 'Foto hinzufügen';

  @override
  String get accountProfilePhotoChange => 'Foto ändern';

  @override
  String get accountProfilePhotoRemove => 'Foto entfernen';

  @override
  String get accountProfilePhotoFailed =>
      'Das Foto konnte nicht hochgeladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get accountProfileSaved => 'Profil gespeichert.';

  @override
  String get accountProfileEmailLabel => 'E-Mail';

  @override
  String get accountProfileEmailChange => 'Ändern';

  @override
  String get accountEmailTitle => 'E-Mail ändern';

  @override
  String get accountEmailCurrent => 'Aktuelle E-Mail';

  @override
  String get accountEmailNew => 'Neue E-Mail';

  @override
  String get accountEmailSame => 'Das ist Ihre aktuelle E-Mail-Adresse.';

  @override
  String get accountEmailSubmit => 'E-Mail ändern';

  @override
  String accountEmailApplied(String email) {
    return 'E-Mail aktualisiert: Ab jetzt melden Sie sich mit $email an.';
  }

  @override
  String accountEmailConfirmationSent(String email) {
    return 'Wir haben einen Bestätigungslink an die neue Adresse ($email) geschickt. Öffnen Sie ihn, um die Änderung abzuschließen: Bis dahin melden Sie sich weiterhin mit der aktuellen E-Mail-Adresse an.';
  }

  @override
  String get accountPasswordTitle => 'Passwort ändern';

  @override
  String get accountPasswordCurrent => 'Aktuelles Passwort';

  @override
  String get accountPasswordCurrentRequired =>
      'Geben Sie das aktuelle Passwort ein.';

  @override
  String get accountPasswordCurrentWrong =>
      'Das aktuelle Passwort ist nicht korrekt.';

  @override
  String get accountPasswordNew => 'Neues Passwort';

  @override
  String get accountPasswordRepeat => 'Neues Passwort wiederholen';

  @override
  String get accountPasswordSameAsOld =>
      'Das neue Passwort muss sich vom aktuellen unterscheiden.';

  @override
  String get accountPasswordSubmit => 'Passwort ändern';

  @override
  String get accountPasswordChanged => 'Passwort geändert.';

  @override
  String get accountDeleteTitle => 'Konto löschen';

  @override
  String get accountDeleteWarningTitle => 'Diese Aktion ist endgültig';

  @override
  String get accountDeleteWarningBody =>
      'Folgendes wird für immer gelöscht: die Profile Ihrer Tiere, die Chats mit dem Assistenten, die Erinnerungen, die Spaziergänge, die Fotos und Videos, die hochgeladenen Befunde und Dokumente, die Messungen, die Einwilligungen, der gespeicherte Standort und die Anzeigen, die Sie auf dem Flohmarkt veröffentlicht haben. Wir können sie nicht wiederherstellen.';

  @override
  String get accountDeletePasswordLabel =>
      'Geben Sie zur Bestätigung Ihr Passwort ein';

  @override
  String get accountDeletePasswordRequired => 'Geben Sie Ihr Passwort ein.';

  @override
  String get accountDeleteUnderstood =>
      'Ich habe verstanden: Mein Konto und alle meine Daten werden für immer gelöscht.';

  @override
  String get accountDeleteSubmit => 'Mein Konto endgültig löschen';

  @override
  String get accountDeleteFailed =>
      'Das Konto konnte nicht gelöscht werden. Versuchen Sie es gleich noch einmal; wenn das Problem bestehen bleibt, schreiben Sie an den Support.';

  @override
  String get accountDeleteDone => 'Ihr Konto wurde gelöscht.';

  @override
  String get accountDeleteReauth =>
      'Aus Sicherheitsgründen ist eine aktuelle Bestätigung nötig: Geben Sie das Passwort erneut ein und versuchen Sie es noch einmal.';

  @override
  String get petsValueSexUnknownShort => 'Unbekannt';

  @override
  String get petsValueActivitySedentary => 'Wenig aktiv';

  @override
  String get petsValueActivityNormal => 'Normal';

  @override
  String get petsValueActivityActive => 'Aktiv';

  @override
  String get petsFormSterilized => 'Kastriert / sterilisiert';

  @override
  String get petsFormMicrochipLabel => 'Mikrochip-Nr.';

  @override
  String get petsFormMicrochipHint => '15 Ziffern';

  @override
  String get petsFormMicrochipInvalid => 'Der Mikrochip hat 15 Ziffern.';

  @override
  String get petsFormCoatColorLabel => 'Fellfarbe';

  @override
  String get petsFormCoatColorHint => 'z. B. schwarz, braun';

  @override
  String get petsFormColorLabel => 'Farbe';

  @override
  String get petsFormColorHint => 'z. B. grün, gelb';

  @override
  String get petsFormBodyConditionLabel => 'Körperbau';

  @override
  String get petsFormBodyConditionHint => 'Körperbau auswählen';

  @override
  String get petsFormActivityLabel => 'Aktivität';

  @override
  String get petsFormActivityHint => 'Aktivität auswählen';

  @override
  String get petsFormDogSizeLabelShort => 'Größe';

  @override
  String get petsWizardNext => 'Weiter';

  @override
  String get petsWizardConfirm => 'Bestätigen';

  @override
  String get petsWizardBack => 'Zurück';

  @override
  String petsWizardStepSemantics(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get petsWizardStep1Title => 'Welches Tier ist es?';

  @override
  String get petsWizardStep1Subtitle =>
      'Wählen Sie die Tierart und die Rasse oder Art';

  @override
  String get petsWizardStep2Title => 'Erzählen Sie uns von Ihrem Tier';

  @override
  String get petsWizardStep2Subtitle => 'Wie heißt es?';

  @override
  String get petsWizardStep3Title => 'Allgemeine Angaben';

  @override
  String get petsWizardStep3Subtitle =>
      'Sagen Sie uns etwas mehr über Ihr Tier';

  @override
  String get petsWizardStep4Title => 'Letzte Angaben';

  @override
  String get petsWizardStep4Subtitle => 'Fast geschafft!';

  @override
  String get petsWizardPureBred => 'Reinrassig';

  @override
  String get petsWizardMixedBreed => 'Mischling';

  @override
  String get petsWizardDoneTitle => 'Profil erstellt!';

  @override
  String petsWizardDoneMessage(String name) {
    return 'Glückwunsch, $name wurde zu Ihren Tieren hinzugefügt.';
  }

  @override
  String get petsWizardAddAnother => 'Weiteres Tier hinzufügen';

  @override
  String get petsWizardFinish => 'Fertig';

  @override
  String get petsDataTitle => 'Tierdaten';

  @override
  String get petsDataSectionIdentity => 'Stammdaten';

  @override
  String get petsDataSectionPhysical => 'Körperliche Merkmale';

  @override
  String get petsDataSectionDocuments => 'Dokumente';

  @override
  String get petsDataNotProvided => 'Nicht angegeben';

  @override
  String get petsDataMicrochipMissing => 'Fehlt';

  @override
  String get petsDataMicrochipMissingDogHint =>
      'Für Hunde ist der Mikrochip Pflicht.';

  @override
  String get petsDataAddMicrochip => 'Mikrochip hinzufügen';

  @override
  String get petsDataWeightLabel => 'Gewicht';

  @override
  String get petsDataSummarySterilized => 'kastriert/sterilisiert';

  @override
  String get monitoringTitle => 'Monitoring';

  @override
  String get petsDetailTabMonitoring => 'Monitoring';

  @override
  String get monitoringBcsGuideTitle => 'Körperbau einschätzen';

  @override
  String monitoringBcsGuideIntro(String petName) {
    return 'Das Gewicht allein verrät nicht, ob ein Tier zu dünn oder gut genährt ist: Man muss es abtasten und ansehen. Folgen Sie den drei Schritten und wählen Sie die Beschreibung, die $petName am ehesten ähnelt.';
  }

  @override
  String get monitoringBcsStepTouch => 'Rippen abtasten';

  @override
  String get monitoringBcsStepAbove => 'Von oben ansehen';

  @override
  String get monitoringBcsStepSide => 'Von der Seite ansehen';

  @override
  String get monitoringBcsViewAbove => 'Von oben';

  @override
  String get monitoringBcsViewSide => 'Von der Seite';

  @override
  String get monitoringBcsRowTouch => 'Tastbefund';

  @override
  String get monitoringBcsRowAbove => 'Von oben';

  @override
  String get monitoringBcsRowSide => 'Von der Seite';

  @override
  String monitoringBcsGuideScale(String range, String max) {
    return 'Auf der Skala der Quelle: $range von $max';
  }

  @override
  String monitoringBcsGuideChoose(String level) {
    return 'Wählen: $level';
  }

  @override
  String get monitoringBcsGuideClear => 'Einschätzung entfernen';

  @override
  String get monitoringBcsGuideDisclaimer =>
      'Das ist ein Richtwert und ersetzt nicht den Besuch in der Tierarztpraxis. Die Illustrationen sind schematisch und stammen von Quokka.';

  @override
  String monitoringBcsGuideSource(String source) {
    return 'Quelle: $source';
  }

  @override
  String get monitoringBcsGuideTipFurry =>
      'Bei Hunden und Katzen mit langem oder dichtem Fell täuscht der Blick: Tasten Sie immer die Rippen ab. Ein Hund mit viel Fell kann gut genährt wirken, obwohl er darunter dünn ist, während ein Welpe oder ein sehr muskulöser Hund „zu sportlich“ wirken kann, aber ein richtiges Gewicht hat.';

  @override
  String get monitoringBcsGuideTipRabbit =>
      'Bei Kaninchen verdeckt das Fell die Knochen: Tasten Sie immer Rücken, Rippen und Hüfte ab, der Blick allein reicht nicht. Dichtes Fell kann ein normales Kaninchen dick und ein dünnes normal aussehen lassen.';

  @override
  String get monitoringBcsGuideAdviceTitle => 'Tipps';

  @override
  String monitoringBcsGuideAdvice1(String petName) {
    return 'Wiegen Sie $petName alle 2 bis 4 Wochen und notieren Sie das Gewicht: Langsame Veränderungen erkennt man besser an den Zahlen als mit bloßem Auge.';
  }

  @override
  String get monitoringBcsGuideAdvice2 =>
      'Schätzen Sie immer auf dieselbe Weise ein: gleicher Ort, Tier steht ruhig, dieselben drei Schritte (Tasten, Ansicht von oben, Ansicht von der Seite).';

  @override
  String get monitoringBcsGuideAdvice3 =>
      'Fragen Sie im Zweifel in der Tierarztpraxis nach: Den Körperbau lernt man am besten, wenn jemand zeigt, wie man tastet.';

  @override
  String get monitoringBcsGuideCaveatRabbit =>
      'Bei Kaninchen ist diese Skala weniger zuverlässig: Zwei Personen können dasselbe Kaninchen unterschiedlich bewerten. Fragen Sie im Zweifel in der Tierarztpraxis nach.';

  @override
  String get monitoringBcsSourceDog =>
      'Kriterien der 9-Punkte-Skala des WSAVA Global Nutrition Committee für Hunde (Laflamme, 1997), von uns mit eigenen Worten zusammengefasst und von Quokka auf 5 Stufen verkürzt. Kein offizielles WSAVA-Material.';

  @override
  String get monitoringBcsSourceCat =>
      'Kriterien der 9-Punkte-Skala des WSAVA Global Nutrition Committee für Katzen (Laflamme, 1997; validiert von Bjornvad und Kollegen, 2011), von uns mit eigenen Worten zusammengefasst und von Quokka auf 5 Stufen verkürzt. Kein offizielles WSAVA-Material.';

  @override
  String get monitoringBcsSourceRabbit =>
      'Rabbit Size-O-Meter mit 5 Stufen der PFMA (Pet Food Manufacturers’ Association), von uns mit eigenen Worten zusammengefasst. Die Übereinstimmung zwischen den Beurteilenden ist begrenzt (Halck und Kollegen, Veterinary Record, 2025).';

  @override
  String get monitoringBcsNotAssessed => 'Nicht eingeschätzt';

  @override
  String get monitoringBcsAssess => 'Körperbau einschätzen';

  @override
  String get monitoringBcsReassess => 'Körperbau neu einschätzen';

  @override
  String get monitoringBcsGuideDog1Touch =>
      'Rippen, Wirbelsäule und Beckenknochen sind direkt unter der Haut zu spüren: Es ist praktisch kein Fett vorhanden und die Muskulatur wirkt reduziert. Ein Beispiel: Es fühlt sich an wie die Knöchel einer geballten Faust, wo der Knochen gleich unter der Haut liegt und nichts dazwischen ist.';

  @override
  String get monitoringBcsGuideDog1Above =>
      'Sehr schmale, eingefallene Taille hinter den Rippen; Hüft- und Rückenknochen stehen hervor. Von oben erinnert der Körper an eine sehr schmale Sanduhr.';

  @override
  String get monitoringBcsGuideDog1Side =>
      'Bauch stark eingezogen, die Linie steigt deutlich zu den Hinterbeinen an. Die Rippen sind schon von Weitem zu sehen, vor allem bei kurzhaarigen Hunden.';

  @override
  String get monitoringBcsGuideDog2Touch =>
      'Die Rippen sind ohne Druck zu spüren, mit sehr wenig Fett darüber, und manchmal zu sehen. Ein Beispiel: Wenn Sie mit der Hand über die Flanke streichen, spüren Sie jede Rippe als eigene Stufe, ohne die weiche Schicht, die ein Hund in guter Verfassung hat.';

  @override
  String get monitoringBcsGuideDog2Above =>
      'Deutlich ausgeprägte Taille hinter den Rippen; die Beckenknochen fallen langsam auf. So finden Sie sie: Betrachten Sie den stehenden Hund von oben, hinter der letzten Rippe wird der Körper deutlich schmaler.';

  @override
  String get monitoringBcsGuideDog2Side =>
      'Bauch deutlich eingezogen. Bei wachsenden Welpen und sehr sportlichen Hunden kann das normal sein: Vergleichen Sie es mit dem Tastbefund an den Rippen.';

  @override
  String get monitoringBcsGuideDog3Touch =>
      'Die Rippen sind unter einer dünnen Fettschicht gut zu spüren, ohne dass man drücken muss. Ein Beispiel: Es fühlt sich an wie der Rücken der offenen, flachen Hand, wo man die Sehnen unter der Haut spürt, aber keinen scharfen Knochen.';

  @override
  String get monitoringBcsGuideDog3Above =>
      'Hinter den Rippen ist eine Taille zu sehen. So finden Sie sie: Betrachten Sie den stehenden Hund von oben, zwischen Brustkorb und Becken wird der Körper leicht schmaler, ohne seitlich hervorzustehen.';

  @override
  String get monitoringBcsGuideDog3Side =>
      'Der Bauch steigt sanft von der Brust zu den Hinterbeinen an. Bei langhaarigen oder dichtbehaarten Hunden erkennt man die Körperform besser, wenn man mit den Händen über den Körper streicht, als wenn man nur hinsieht.';

  @override
  String get monitoringBcsGuideDog4Touch =>
      'Die Rippen sind nur mit etwas Mühe zu spüren: Die Fettschicht ist dicker, vor allem auf dem Rücken nahe der Rute. Ein Beispiel: Es fühlt sich an wie der Handrücken bei locker geschlossener Faust, mit mehr Gewebe über den Knochen.';

  @override
  String get monitoringBcsGuideDog4Above =>
      'Die Taille ist kaum noch zu erahnen oder nicht mehr zu sehen. Von oben wirkt der Körper fast rechteckig, ohne Verschmälerung hinter den Rippen.';

  @override
  String get monitoringBcsGuideDog4Side =>
      'Der eingezogene Bauch ist kaum zu erkennen. Verwechseln Sie dichtes Fell nicht mit Fett: Tasten Sie immer die Rippen ab, bevor Sie entscheiden.';

  @override
  String get monitoringBcsGuideDog5Touch =>
      'Die Rippen sind unter einer dicken Fettschicht nicht oder nur bei starkem Druck zu spüren; das Fett sammelt sich auf Rücken und Rutenansatz. Ein Beispiel: Es ist, als suchten Sie die Knochen in der Handfläche, wo unter der Haut nur ein dickes, weiches Polster liegt.';

  @override
  String get monitoringBcsGuideDog5Above =>
      'Keine Taille: Der Körper ist breit und rundlich, der Bauch kann aufgebläht wirken. Von oben erscheint der Hund an den Flanken breiter als am Brustkorb.';

  @override
  String get monitoringBcsGuideDog5Side =>
      'Kein Einzug: Der Bauch ist rund oder hängt nach unten. Ein solcher Hund wird schnell müde und bewegt sich mühsam: Sprechen Sie mit Ihrer Tierarztpraxis darüber.';

  @override
  String get monitoringBcsGuideCat1Touch =>
      'Rippen und Rückenwirbel sind ohne jede Fettschicht zu spüren; bei kurzhaarigen Katzen sind die Rippen zu sehen. Ein Beispiel: Es fühlt sich an wie die Knöchel einer geballten Faust, die Knochen direkt unter der Haut.';

  @override
  String get monitoringBcsGuideCat1Above =>
      'Sehr schmale Taille hinter den Rippen. Von oben ist der Körper dünn wie eine sehr schmale Sanduhr.';

  @override
  String get monitoringBcsGuideCat1Side =>
      'Bauch stark eingezogen, kein Fettpolster unter dem Bauch. Auch die Muskeln seitlich der Wirbelsäule wirken reduziert.';

  @override
  String get monitoringBcsGuideCat2Touch =>
      'Die Rippen sind leicht zu spüren, mit sehr wenig Fett, und die Rückenwirbel fallen auf. Ein Beispiel: Wenn Sie mit der Hand über die Flanke streichen, spüren Sie jede Rippe einzeln, ohne den weichen Schleier, den eine Katze in guter Verfassung hat.';

  @override
  String get monitoringBcsGuideCat2Above =>
      'Taille hinter den Rippen gut sichtbar. Sehen Sie die stehende Katze von oben an: Hinter dem Brustkorb wird der Körper deutlich schmaler.';

  @override
  String get monitoringBcsGuideCat2Side =>
      'Bauch leicht eingezogen, mit wenig oder gar keinem Fettpolster. Bei älteren Katzen kann Magerkeit ein Gesundheitsproblem verbergen: Wenn sie neu aufgetreten ist, fragen Sie in der Tierarztpraxis nach.';

  @override
  String get monitoringBcsGuideCat3Touch =>
      'Die Rippen sind unter einem dünnen Fettschleier zu spüren. Ein Beispiel: Es fühlt sich an wie der Rücken der offenen, flachen Hand, wo man die Sehnen unter der Haut spürt, aber keinen scharfen Knochen.';

  @override
  String get monitoringBcsGuideCat3Above =>
      'Gut proportionierter Körper mit sichtbarer Taille hinter den Rippen. Von oben zeigt die Katze eine leichte Sanduhrform, ohne seitlich hervorzustehen.';

  @override
  String get monitoringBcsGuideCat3Side =>
      'Die Bauchlinie ist weich, mit einem kaum angedeuteten Fettpolster. Bei langhaarigen Katzen erkennt man die Körperform besser mit den Händen als mit den Augen.';

  @override
  String get monitoringBcsGuideCat4Touch =>
      'Die Rippen sind schwerer zu spüren: Man muss etwas drücken, weil mehr Fett vorhanden ist. Ein Beispiel: Es fühlt sich an wie der Handrücken bei locker geschlossener Faust, mit mehr Gewebe über den Knochen.';

  @override
  String get monitoringBcsGuideCat4Above =>
      'Die Taille ist kaum oder nicht zu sehen. Von oben wirkt der Körper fast rechteckig, ohne Verschmälerung hinter den Rippen.';

  @override
  String get monitoringBcsGuideCat4Side =>
      'Abgerundeter Bauch mit einem mäßigen Fettpolster unter dem Bauch. Beim Gehen schwingt das Polster leicht mit: Bei Katzen in guter Verfassung ist es nur angedeutet.';

  @override
  String get monitoringBcsGuideCat5Touch =>
      'Die Rippen sind unter einer dicken Fettschicht nicht zu spüren; das Fett sammelt sich auch auf dem Rücken und, in extremen Fällen, an Schnauze und Pfoten. Ein Beispiel: Es ist, als suchten Sie die Knochen in der Handfläche, wo nur ein weiches Polster liegt.';

  @override
  String get monitoringBcsGuideCat5Above =>
      'Keine Taille: Der Körper ist breit. Von oben erscheint die Katze an den Flanken breiter als am Brustkorb.';

  @override
  String get monitoringBcsGuideCat5Side =>
      'Runder oder hängender Bauch mit deutlichem Fettpolster. Die Katze kann das Fell auf dem Rücken und am Hinterteil nur mühsam pflegen: Sprechen Sie mit Ihrer Tierarztpraxis darüber.';

  @override
  String get monitoringBcsGuideRabbit1Touch =>
      'Wirbelsäule, Rippen und Hüftknochen stehen hervor und fühlen sich unter der Haut scharf an: Es ist kein Fett vorhanden und die Muskeln sind reduziert. Ein Beispiel: Es fühlt sich an wie die Knöchel einer geballten Faust, mit dem Knochen direkt unter der Haut.';

  @override
  String get monitoringBcsGuideRabbit1Above =>
      'Rücken und Flanken eingefallen, die Hüftknochen fallen auf. Von oben wirkt der Körper schmal und kantig.';

  @override
  String get monitoringBcsGuideRabbit1Side =>
      'Das Hinterteil (die Kruppe) ist eingefallen und wölbt sich nach innen. Ein so mageres Kaninchen sollte bald in der Tierarztpraxis vorgestellt werden.';

  @override
  String get monitoringBcsGuideRabbit2Touch =>
      'Rippen, Wirbelsäule und Hüfte sind leicht zu spüren, mit wenig Fett darüber. Ein Beispiel: Wenn Sie mit der Hand über den Rücken streichen, spüren Sie die Wirbel als Reihe kleiner, deutlich getrennter Erhebungen.';

  @override
  String get monitoringBcsGuideRabbit2Above =>
      'Schmale Flanken, die Wirbelsäule ist wenig bedeckt. Von oben ist der Körper schmaler, als man erwarten würde.';

  @override
  String get monitoringBcsGuideRabbit2Side =>
      'Das Hinterteil ist flach. Bei langhaarigen Kaninchen verdeckt das Fell die Magerkeit: Tasten Sie immer Rücken und Hüfte ab.';

  @override
  String get monitoringBcsGuideRabbit3Touch =>
      'Rippen und Wirbelsäule sind leicht zu spüren, haben aber weiche, abgerundete Konturen, nicht scharfe. Ein Beispiel: Es fühlt sich an wie der Rücken der offenen, flachen Hand, wo man die Knochen unter weicher Haut spürt.';

  @override
  String get monitoringBcsGuideRabbit3Above =>
      'Gut proportionierter Körper, ohne Wölbungen an den Flanken. Von oben ist die Silhouette gleichmäßig, vom Hals bis zur Blume.';

  @override
  String get monitoringBcsGuideRabbit3Side =>
      'Das Hinterteil ist flach und der Bauch steht nicht vor. Der Rücken bildet eine regelmäßige Rundung und wirkt weder eingefallen noch aufgewölbt.';

  @override
  String get monitoringBcsGuideRabbit4Touch =>
      'Um Rippen, Wirbelsäule und Hüfte zu spüren, muss man drücken: Es sind Fettschichten vorhanden. Ein Beispiel: Es fühlt sich an wie der Handrücken bei locker geschlossener Faust, mit mehr Gewebe über den Knochen.';

  @override
  String get monitoringBcsGuideRabbit4Above =>
      'Volle, abgerundete Flanken. Von oben wirkt der Körper breiter, als man erwarten würde.';

  @override
  String get monitoringBcsGuideRabbit4Side =>
      'Das Hinterteil ist abgerundet. Oft fällt auch eine leichte Wölbung unter dem Kinn auf, vor allem bei Weibchen.';

  @override
  String get monitoringBcsGuideRabbit5Touch =>
      'Wirbelsäule und Hüfte sind kaum und die Rippen gar nicht zu spüren, unter einer dicken Fettschicht. Ein Beispiel: Es ist, als suchten Sie die Knochen in der Handfläche, wo nur ein weiches Polster liegt.';

  @override
  String get monitoringBcsGuideRabbit5Above =>
      'Breiter, voller Körper, das Hinterteil steht hervor. Von oben ist die Silhouette sehr rundlich.';

  @override
  String get monitoringBcsGuideRabbit5Side =>
      'Der Bauch hängt und bildet ein Fettpolster unter dem Bauch. Ein so gut genährtes Kaninchen kann sich nur mühsam putzen und Hautprobleme unter der Blume bekommen: Fragen Sie in der Tierarztpraxis nach.';

  @override
  String get monitoringAddMeasurement => 'Neue Messung';

  @override
  String get monitoringCurrentWeight => 'Aktuelles Gewicht';

  @override
  String monitoringMeasuredOn(String date) {
    return 'Gemessen am $date';
  }

  @override
  String monitoringChangeSince(String change, String date) {
    return '$change seit $date';
  }

  @override
  String get monitoringEmptyTitle => 'Noch keine Messung';

  @override
  String monitoringEmptyBody(String petName) {
    return 'Erfassen Sie das Gewicht von $petName, um den Verlauf über die Zeit zu verfolgen.';
  }

  @override
  String get monitoringBcsTitle => 'Körperbau';

  @override
  String monitoringBcsAsOf(String date) {
    return 'Seit der Messung vom $date';
  }

  @override
  String get monitoringBcsNone =>
      'Tippen Sie auf „Körperbau einschätzen“, um ihn hier zu sehen.';

  @override
  String get monitoringBcsVeryThin => 'Sehr mager';

  @override
  String get monitoringBcsThin => 'Mager';

  @override
  String get monitoringBcsNormal => 'Normal';

  @override
  String get monitoringBcsSlightlyOverweight => 'Leicht übergewichtig';

  @override
  String get monitoringBcsOverweight => 'Übergewichtig';

  @override
  String get monitoringChartTitleWeight => 'Gewichtsverlauf';

  @override
  String get monitoringChartTitleGrowth => 'Wachstumskurve';

  @override
  String monitoringChartGrowthHint(String petName) {
    return 'Das Gewicht von $petName nach Alter, ohne Referenzkurven: nur die eigenen Messungen.';
  }

  @override
  String get monitoringChartSinglePoint =>
      'Fügen Sie eine weitere Messung hinzu, um den Verlauf zu sehen.';

  @override
  String monitoringChartGrowthHintReference(String petName) {
    return 'Das Gewicht von $petName nach Alter, im Vergleich zum Referenzbereich.';
  }

  @override
  String get monitoringGrowthLegend =>
      'Dunkler Bereich: vom 25. bis zum 75. Perzentil (die mittlere Hälfte). Heller Bereich: vom 3. bis zum 97. Perzentil. Gestrichelte Linie: Median.';

  @override
  String monitoringGrowthSourcePuppy(String sizeLabel) {
    return 'Referenz: gesunde Hunde mit Erwachsenengewicht $sizeLabel. Abgeleitet von Daten unter CC BY 4.0 von Salt C. et al., PLOS ONE 2017; keine offiziellen WALTHAM-Kurven.';
  }

  @override
  String get monitoringGrowthSourceKitten =>
      'Referenz: nicht kastrierte Kurzhaar-Hauskatzenwelpen (USA). Abgeleitet von Daten unter CC BY 3.0 von Salt C. et al., PLOS ONE 2022; keine offiziellen WALTHAM-Kurven.';

  @override
  String monitoringGrowthDisclaimer(String petName) {
    return 'Das ist eine Referenz, keine Diagnose: Jedes Tier wächst in seinem eigenen Tempo. Wenn das Gewicht von $petName häufig aus dem Bereich fällt oder sich plötzlich ändert, sprechen Sie mit Ihrer Tierarztpraxis.';
  }

  @override
  String monitoringGrowthExpectedAdult(String range) {
    return 'Erwartetes Erwachsenengewicht: $range';
  }

  @override
  String get monitoringGrowthChange => 'Ändern';

  @override
  String get monitoringGrowthPromptTitle => 'Referenzbereich anzeigen';

  @override
  String monitoringGrowthPromptBody(String petName) {
    return 'Um $petName mit gesunden Welpen zu vergleichen, brauchen wir das Gewicht als Erwachsener: Wählen Sie die wahrscheinlichste Spanne (Rasse, Elterntiere, Tierarztpraxis).';
  }

  @override
  String get monitoringGrowthPromptButton => 'Erwachsenengewicht wählen';

  @override
  String get monitoringGrowthNoReferenceHeavy =>
      'Für Hunde über 40 kg gibt es keine verlässlichen Referenzkurven: Sehr große Rassen wachsen sehr unterschiedlich.';

  @override
  String monitoringGrowthSheetTitle(String petName) {
    return 'Erwartetes Erwachsenengewicht von $petName';
  }

  @override
  String monitoringGrowthClassUnder(String max) {
    return 'Weniger als $max';
  }

  @override
  String monitoringGrowthClassBetween(String min, String max) {
    return '$min bis $max';
  }

  @override
  String monitoringGrowthClassOver(String min) {
    return 'Mehr als $min';
  }

  @override
  String get monitoringGrowthClassUnknown =>
      'Weiß ich nicht: kein Referenzbereich';

  @override
  String get monitoringAxisAgeMonths => 'Alter (Monate)';

  @override
  String monitoringAxisWeight(String unit) {
    return 'Gewicht ($unit)';
  }

  @override
  String monitoringTooltipAge(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months Monate',
      one: '1 Monat',
    );
    return '$_temp0';
  }

  @override
  String get monitoringHistoryTitle => 'Verlauf';

  @override
  String get monitoringDeleteTitle => 'Messung löschen?';

  @override
  String monitoringDeleteMessage(String date) {
    return 'Das Gewicht vom $date wird aus dem Verlauf entfernt.';
  }

  @override
  String get monitoringSheetTitleNew => 'Neue Messung';

  @override
  String get monitoringSheetTitleEdit => 'Messung bearbeiten';

  @override
  String get monitoringFieldDate => 'Datum';

  @override
  String get monitoringFieldWeightKg => 'Gewicht (kg)';

  @override
  String get monitoringFieldWeightLb => 'Gewicht (lb)';

  @override
  String get monitoringFieldWeightHintKg => 'z. B. 10,5';

  @override
  String get monitoringFieldWeightHintLb => 'z. B. 22,5';

  @override
  String get monitoringFieldNote => 'Notiz (optional)';

  @override
  String get monitoringErrorWeight =>
      'Geben Sie ein gültiges Gewicht größer als null ein.';

  @override
  String get monitoringErrorDateFuture =>
      'Das Datum darf nicht in der Zukunft liegen.';

  @override
  String monitoringErrorDateBirth(String petName) {
    return 'Das Datum liegt vor der Geburt von $petName.';
  }

  @override
  String get monitoringSaveFailed =>
      'Die Messung konnte nicht gespeichert werden: Bitte versuchen Sie es erneut.';

  @override
  String get monitoringDeleteFailed =>
      'Die Messung konnte nicht gelöscht werden: Bitte versuchen Sie es erneut.';

  @override
  String get monitoringActivityTitle => 'Aktivität';

  @override
  String monitoringActivitySubtitle(String petName) {
    return 'Die Spaziergänge von $petName in den letzten Wochen.';
  }

  @override
  String get monitoringActivityDistance => 'Strecke';

  @override
  String get monitoringActivityTime => 'Dauer';

  @override
  String get monitoringActivityStatWalks => 'Spaziergänge';

  @override
  String monitoringActivityEmpty(String petName) {
    return 'Keine Spaziergänge in den letzten 3 Monaten. Zeichnen Sie einen Spaziergang im Tab Spaziergänge auf, um hier die Aktivität von $petName zu sehen.';
  }

  @override
  String monitoringActivityWeekOf(String date) {
    return 'Woche ab $date';
  }

  @override
  String monitoringActivityWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spaziergänge',
      one: '1 Spaziergang',
    );
    return '$_temp0';
  }

  @override
  String get medCatVisit => 'Besuche';

  @override
  String get medCatExam => 'Untersuchungen';

  @override
  String get medCatVaccine => 'Impfungen';

  @override
  String get medCatTherapy => 'Therapien';

  @override
  String get medCatDocument => 'Dokumente';

  @override
  String get medCatCondition => 'Erkrankungen';

  @override
  String get medCatVisitOne => 'Besuch';

  @override
  String get medCatExamOne => 'Untersuchung';

  @override
  String get medCatVaccineOne => 'Impfung';

  @override
  String get medCatTherapyOne => 'Therapie';

  @override
  String get medCatDocumentOne => 'Dokument';

  @override
  String medCatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erfasst',
      one: '1 erfasst',
    );
    return '$_temp0';
  }

  @override
  String get medSubCheckup => 'Kontrolluntersuchung';

  @override
  String get medSubSpecialist => 'Facharztbesuch';

  @override
  String get medSubFirstVisit => 'Erstbesuch';

  @override
  String get medSubEmergency => 'Notfall';

  @override
  String get medSubPostSurgery => 'Nachkontrolle nach OP';

  @override
  String get medSubBlood => 'Blutuntersuchung';

  @override
  String get medSubUrine => 'Urinuntersuchung';

  @override
  String get medSubStool => 'Kotuntersuchung';

  @override
  String get medSubXray => 'Röntgen';

  @override
  String get medSubUltrasound => 'Ultraschall';

  @override
  String get medSubAntiparasitic => 'Antiparasitikum';

  @override
  String get medSubMedication => 'Medikament';

  @override
  String get medSubOther => 'Sonstiges';

  @override
  String get medAddTitle => 'Was möchten Sie hinzufügen?';

  @override
  String get medAddAction => 'Hinzufügen';

  @override
  String get medCatConditionOne => 'Erkrankung';

  @override
  String get medHistoryTitle => 'Verlauf';

  @override
  String get medHistorySubtitle =>
      'Alle erfassten Ereignisse, Monat für Monat.';

  @override
  String get medHistoryEmpty => 'Keine Ereignisse erfasst';

  @override
  String get medHistoryPrevMonth => 'Vorheriger Monat';

  @override
  String get medHistoryNextMonth => 'Nächster Monat';

  @override
  String medHistoryDayTitle(String date) {
    return 'Ereignisse vom $date';
  }

  @override
  String get medHistoryDayEmpty => 'Keine Ereignisse an diesem Tag';

  @override
  String medHistoryDayA11y(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse',
      one: '1 Ereignis',
      zero: 'keine Ereignisse',
    );
    return '$date: $_temp0';
  }

  @override
  String get medHistorySend => 'Verlauf senden';

  @override
  String get medHistorySendAll => 'Gesamter Verlauf (PDF)';

  @override
  String get medHistorySendAllSubtitle =>
      'Ein PDF mit allen Ereignissen in zeitlicher Reihenfolge';

  @override
  String get medHistorySendFiles => 'Einzelne Dateien';

  @override
  String get medHistoryPreparing => 'PDF wird vorbereitet…';

  @override
  String get medHistoryExportFailed =>
      'Das PDF konnte nicht erstellt werden. Bitte versuchen Sie es erneut.';

  @override
  String get medHistoryConditionsMissing =>
      'Die Erkrankungen konnten nicht gelesen werden: Im PDF fehlen sie.';

  @override
  String medPdfTitle(String petName) {
    return 'Krankengeschichte von $petName';
  }

  @override
  String get medPdfSpeciesBreed => 'Tierart und Rasse';

  @override
  String get medPdfBirthDate => 'Geburtsdatum';

  @override
  String get medPdfExportDate => 'Exportdatum';

  @override
  String get medPdfColDate => 'Datum';

  @override
  String get medPdfColCategory => 'Kategorie';

  @override
  String get medPdfColTitle => 'Titel';

  @override
  String get medPdfColNotes => 'Notizen';

  @override
  String get medPdfNoDate => 'Ohne Datum';

  @override
  String get medPdfEmpty => 'Keine Ereignisse erfasst.';

  @override
  String medPdfPage(int page, int pages) {
    return 'Seite $page von $pages';
  }

  @override
  String get medPdfConditionOngoing => 'Andauernd';

  @override
  String get medPdfConditionResolved => 'Abgeheilt';

  @override
  String medPdfConditionResolvedOn(String date) {
    return 'Abgeheilt am $date';
  }

  @override
  String medPdfConditionTherapy(String therapy) {
    return 'Therapie: $therapy';
  }

  @override
  String get medNewVisit => 'Neuer Besuch';

  @override
  String get medNewExam => 'Neue Untersuchung';

  @override
  String get medNewVaccine => 'Neue Impfung';

  @override
  String get medNewTherapy => 'Neue Therapie';

  @override
  String get medNewDocument => 'Neues Dokument';

  @override
  String get medNewCondition => 'Neue Erkrankung';

  @override
  String get medEmptyVisitTitle => 'Kein Besuch erfasst';

  @override
  String medEmptyVisitBody(String petName) {
    return 'Tragen Sie die Besuche von $petName ein, um Kontrollen und Hinweise der Tierarztpraxis an einem Ort wiederzufinden.';
  }

  @override
  String get medEmptyVisitAction => 'Ersten Besuch hinzufügen';

  @override
  String get medEmptyExamTitle => 'Keine Untersuchung erfasst';

  @override
  String medEmptyExamBody(String petName) {
    return 'Laden Sie die Untersuchungen von $petName hoch, etwa Blutuntersuchungen oder Röntgenbilder, um sie immer griffbereit zu haben.';
  }

  @override
  String get medEmptyExamAction => 'Erste Untersuchung hinzufügen';

  @override
  String get medEmptyVaccineTitle => 'Keine Impfung erfasst';

  @override
  String medEmptyVaccineBody(String petName) {
    return 'Halten Sie hier die Impfungen und Auffrischungen von $petName fest, mit dem Datum jeder Verabreichung.';
  }

  @override
  String get medEmptyVaccineAction => 'Erste Impfung hinzufügen';

  @override
  String get medEmptyTherapyTitle => 'Keine Therapie erfasst';

  @override
  String medEmptyTherapyBody(String petName) {
    return 'Notieren Sie die Therapien von $petName: Medikamente, Antiparasitika und laufende oder frühere Behandlungen.';
  }

  @override
  String get medEmptyTherapyAction => 'Erste Therapie hinzufügen';

  @override
  String get medEmptyDocumentTitle => 'Kein Dokument hochgeladen';

  @override
  String medEmptyDocumentBody(String petName) {
    return 'Laden Sie Befunde, Zeugnisse und andere Dokumente von $petName hoch, um sie mit der Tierarztpraxis zu teilen.';
  }

  @override
  String get medEmptyDocumentAction => 'Erstes Dokument hinzufügen';

  @override
  String get medEmptyConditionTitle => 'Keine Erkrankung erfasst';

  @override
  String medEmptyConditionBody(String petName) {
    return 'Notieren Sie die Erkrankungen von $petName, andauernde oder bereits abgeheilte, mit Daten und Therapie.';
  }

  @override
  String get medEmptyConditionAction => 'Erste Erkrankung hinzufügen';

  @override
  String get medFieldTitle => 'Titel';

  @override
  String get medFieldCategory => 'Kategorie';

  @override
  String get medFieldType => 'Art';

  @override
  String get medFieldTypeNone => 'Nicht angegeben';

  @override
  String get medFieldEventDate => 'Datum';

  @override
  String get medFieldNotes => 'Notizen';

  @override
  String get medFieldNotesHint => 'Schreiben Sie eine optionale Notiz.';

  @override
  String get medFieldFile => 'Anhang';

  @override
  String get medAttachAdd => 'Datei hinzufügen';

  @override
  String get medAttachChange => 'Datei ändern';

  @override
  String get medEditDetailsTitle => 'Details bearbeiten';

  @override
  String get medTitleRequired =>
      'Geben Sie einen Titel ein oder hängen Sie eine Datei an.';

  @override
  String get medDateInvalid => 'Ungültiges Datum (TT/MM/JJJJ).';

  @override
  String get medDatePlaceholder => 'TT/MM/JJJJ';

  @override
  String medSuggestHint(String category) {
    return 'Dem Titel nach: $category. Möchten Sie es so einordnen?';
  }

  @override
  String get medSuggestApply => 'Ja, einordnen';

  @override
  String medSuggestPill(String category) {
    return 'Vielleicht: $category';
  }

  @override
  String medActionClassifyAs(String category) {
    return 'Einordnen als $category';
  }

  @override
  String get medActionEditDetails => 'Details bearbeiten';

  @override
  String get medCondName => 'Name der Erkrankung';

  @override
  String get medCondNameRequired => 'Geben Sie den Namen der Erkrankung ein.';

  @override
  String get medCondStarted => 'Beginndatum';

  @override
  String get medCondStatus => 'Status';

  @override
  String get medCondOngoing => 'Andauernd';

  @override
  String get medCondResolved => 'Abgeheilt';

  @override
  String get medCondEnded => 'Enddatum';

  @override
  String get medCondEndBeforeStart => 'Das Enddatum liegt vor dem Beginndatum.';

  @override
  String get medCondTherapy => 'Therapie';

  @override
  String get medCondTherapyHint => 'Medikamente, Dosen, Dauer…';

  @override
  String get medCondAttachment => 'Rezept oder Dokumente';

  @override
  String medCondSince(String date) {
    return 'Seit $date';
  }

  @override
  String medCondPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get medCondSaveFailed =>
      'Die Erkrankung konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get medCondDeleteFailed =>
      'Die Erkrankung konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get medCondDeleteTitle => 'Diese Erkrankung löschen?';

  @override
  String medCondDeleteBody(String name) {
    return '„$name“ wird gelöscht.';
  }

  @override
  String get medCondLoadError =>
      'Die Erkrankungen konnten nicht gelesen werden. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get medCondUploadFailed =>
      'Die Datei konnte nicht hochgeladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get medCondOpenFile => 'Anhang öffnen';

  @override
  String get medicalRecordSourceFromReminder => 'Aus einer Erinnerung';

  @override
  String get reminderCatGrooming => 'Tierpflege';

  @override
  String get reminderCatOther => 'Sonstiges';

  @override
  String get remindersFormCategory => 'Kategorie';

  @override
  String get remindersFormSubtype => 'Art';

  @override
  String get remindersFormSubtypeNone => 'Keine';

  @override
  String get remindersDoneTitle => 'Erledigt?';

  @override
  String remindersDoneRecordHint(String pet) {
    return 'Im Verlauf von $pet erfassen.';
  }

  @override
  String get remindersDonePlainHint => 'Als erledigt markieren?';

  @override
  String get remindersDoneFieldTitle => 'Titel';

  @override
  String get remindersDoneFieldDate => 'Wann es passiert ist';

  @override
  String get remindersDoneFieldNotes => 'Notizen (optional)';

  @override
  String get remindersDoneConfirmRecord => 'Ja, erfassen';

  @override
  String get remindersDoneConfirmPlain => 'Ja, erledigt';

  @override
  String get remindersDonePostpone => 'Verschieben';

  @override
  String get remindersDoneNotDone => 'Nicht erledigt';

  @override
  String remindersDoneRecorded(String pet) {
    return 'Im Verlauf von $pet erfasst.';
  }

  @override
  String get remindersDoneMarked => 'Als erledigt markiert.';

  @override
  String get remindersDoneDismissed => 'Als nicht erledigt markiert.';

  @override
  String get remindersDonePostponed => 'Ich frage morgen noch einmal nach.';

  @override
  String get remindersDoneTooltip => 'Als erledigt markieren';

  @override
  String get remindersNotifPermTitle =>
      'Möchten Sie Benachrichtigungen erhalten?';

  @override
  String get remindersNotifPermBody =>
      'Damit wir Sie benachrichtigen können, wenn eine Erinnerung fällig ist, benötigt Quokka die Berechtigung für Benachrichtigungen. Sie können dies jederzeit in den Einstellungen ändern.';

  @override
  String get remindersNotifPermNotNow => 'Nicht jetzt';

  @override
  String get remindersNotifPermAllow => 'Erlauben';

  @override
  String get remindersNotifOffBanner =>
      'Benachrichtigungen sind deaktiviert: Erinnerungen geben keinen Ton aus';

  @override
  String get remindersNotifOffAction => 'Aktivieren';

  @override
  String get authPhoneLabel => 'Telefonnummer (optional)';

  @override
  String get authPhoneHelp =>
      'Optional. Die Nummer bleibt in Ihrem Profil, und Sie können sie jederzeit ändern oder entfernen.';

  @override
  String get phonePickerTitle => 'Ländervorwahl wählen';

  @override
  String phonePickerSemantics(String country, String dial) {
    return 'Ländervorwahl: $country (+$dial)';
  }
}

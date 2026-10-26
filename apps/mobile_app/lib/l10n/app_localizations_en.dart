// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get petsConsentFullText =>
      'To give you more precise advice, the assistant can read your pet\'s medical records. When you ask a question, it can read the three most recent entries, with title, category (visit, test, vaccine, therapy or document), event date, description and the text of attached documents, even if they are not related to your question. It can also read earlier conditions that are still ongoing, with the name and start date, up to five. If you ask it to explain a test, it can read the documents related to it, up to two. For a very long document it reads only the beginning. What it reads is sent to the external artificial intelligence provider that writes the answer. VetApp uses it only to answer you. You can withdraw your consent at any time from your pet\'s profile or from Settings: this applies to subsequent requests.';

  @override
  String get appTitle => 'VET APP';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonShare => 'Share';

  @override
  String get languagePickerTitle => 'Choose your language';

  @override
  String get languagePickerSubtitle => 'You can change it anytime in Settings.';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSectionHint =>
      'Changing language also changes the default measurement units, unless you already chose them.';

  @override
  String get authBannerCheckFieldsTitle => 'Check the fields';

  @override
  String get authLoginFieldsInvalidMessage =>
      'Enter a valid email and a password of at least 6 characters.';

  @override
  String get authLoginLoadingTitle => 'Signing in';

  @override
  String get authLoginLoadingMessage => 'Checking your credentials.';

  @override
  String get authLoginSuccessTitle => 'Signed in';

  @override
  String get authLoginSuccessMessage =>
      'Your session is ready. Opening the app.';

  @override
  String get authLoginFailureTitle => 'Sign-in failed';

  @override
  String get authLoginTitle => 'Welcome back.';

  @override
  String get authLoginSubtitle =>
      'Sign in to find your pets, reminders and documents.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'name@domain.com';

  @override
  String get authEmailRequired => 'Enter your email.';

  @override
  String get authEmailInvalid => 'Invalid email address.';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'At least 6 characters';

  @override
  String get authPasswordRequiredLogin => 'Enter your password.';

  @override
  String get authPasswordRequiredNew => 'Enter a password.';

  @override
  String get authPasswordMinLength => 'At least 6 characters.';

  @override
  String get authPasswordShow => 'Show password';

  @override
  String get authPasswordHide => 'Hide password';

  @override
  String get authRememberMe => 'Stay signed in';

  @override
  String get authForgotPasswordLink => 'Forgot your password?';

  @override
  String get authLoginButton => 'Sign in';

  @override
  String get authNoAccountRegisterLink => 'No account yet? Sign up';

  @override
  String get authTermsOfServiceLabel => 'Terms of service';

  @override
  String get authPrivacyPolicyLabel => 'Privacy policy';

  @override
  String authTermsAcceptance(String terms, String privacy) {
    return 'I accept the $terms and $privacy';
  }

  @override
  String get authRegisterCheckTitle => 'One last check';

  @override
  String get authRegisterTermsRequired =>
      'Accept the privacy policy and disclaimer to continue.';

  @override
  String get authRegisterFieldsInvalid =>
      'Check the fields: name, email and password must be valid.';

  @override
  String get authRegisterLoadingTitle => 'Creating account';

  @override
  String get authRegisterLoadingMessage =>
      'Creating your account and preparing your session.';

  @override
  String get authRegisterSuccessTitle => 'Account ready';

  @override
  String get authRegisterSuccessMessage =>
      'Registration complete. Taking you to the home page.';

  @override
  String get authRegisterFailureTitle => 'Account not created';

  @override
  String get authRegisterTitle => 'Create your profile.';

  @override
  String get authRegisterSubtitle =>
      'A few details to start managing your pets\' health and documents.';

  @override
  String get authNameLabel => 'Name';

  @override
  String get authNameHint => 'Your name';

  @override
  String get authNameRequired => 'Enter your name.';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authConfirmPasswordHint => 'Repeat the password';

  @override
  String get authPasswordsMismatch => 'The passwords do not match.';

  @override
  String get authRegisterButton => 'Create account';

  @override
  String get authHaveAccountLoginLink => 'Already have an account? Sign in';

  @override
  String get authResetInvalidTitle => 'Invalid email';

  @override
  String get authResetInvalidMessage =>
      'Enter a valid email address to continue.';

  @override
  String get authResetLoadingTitle => 'Sending';

  @override
  String get authResetLoadingMessage =>
      'Preparing your password recovery request.';

  @override
  String get authResetSuccessTitle => 'Email sent';

  @override
  String get authResetSuccessMessage =>
      'If the account exists, you will receive a password recovery link.';

  @override
  String get authResetFailureTitle => 'Could not send email';

  @override
  String get authResetTitle => 'Recover your access.';

  @override
  String get authResetSubtitle =>
      'Enter your email and we will send you a link to reset your password.';

  @override
  String get authResetSendButton => 'Send link';

  @override
  String get authBackToLoginLink => 'Back to sign in';

  @override
  String get authSetPasswordLoadingTitle => 'Updating';

  @override
  String get authSetPasswordLoadingMessage => 'Saving your new password.';

  @override
  String get authSetPasswordFailureTitle => 'Update failed';

  @override
  String get authSetPasswordTitle => 'Set a new password.';

  @override
  String get authSetPasswordSubtitle =>
      'Choose a new password for your account.';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authSetPasswordSaveButton => 'Save new password';

  @override
  String get authLegalShareTooltip => 'Share or download';

  @override
  String get authLegalLoadError =>
      'I can\'t load the text right now. Try again shortly.';

  @override
  String get authLegalPreparingNotice =>
      'The full privacy policy is being prepared and will be available here soon, with a download option.';

  @override
  String get authHubTitle => 'VetApp: your pets within paw\'s reach';

  @override
  String get authHubSubtitle =>
      'Sign in to your account or create a new one in seconds.';

  @override
  String get authHubCreateAccount => 'Create an account';

  @override
  String get authHubPrivacyNote =>
      'Your data stays private and is used only to manage your pet\'s profile.';

  @override
  String get authErrorEmailExists =>
      'An account already exists with this email. Try signing in.';

  @override
  String get authErrorWeakPassword =>
      'The password is too weak: use at least 6 characters, preferably with numbers or uppercase letters.';

  @override
  String get authErrorEmailInvalid =>
      'The email address does not appear to be valid.';

  @override
  String get authErrorNoConnection =>
      'No connection. Check your network and try again.';

  @override
  String get authErrorLinkExpired =>
      'The link is no longer valid or has already been used. Request a new one from the recovery screen.';

  @override
  String get authErrorRateLimit =>
      'You requested too many emails in a short time. Wait a few minutes and try again.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirm your email first: check your inbox and open the link we sent you.';

  @override
  String get authErrorEmailNotFound => 'No account exists with this email.';

  @override
  String get authErrorGeneric =>
      'Something did not go as expected. Try again shortly.';

  @override
  String get authNetworkTimeout => 'The request took too long. Try again.';

  @override
  String get authNetworkUnexpected => 'Something went wrong. Try again.';

  @override
  String get consentsErrorLoad =>
      'I couldn\'t load your consent preferences. Try again.';

  @override
  String get consentsErrorSave => 'I couldn\'t save your choice. Try again.';

  @override
  String get billingErrorStatus =>
      'I couldn\'t check your subscription. Try again.';

  @override
  String get billingErrorSelectPlan =>
      'I couldn\'t save your chosen plan. Try again.';

  @override
  String get billingIncludedPets => 'Your pets\' profiles';

  @override
  String get billingIncludedAssistant =>
      'An assistant for health, behavior and routine questions';

  @override
  String get billingIncludedChatMedia =>
      'Photos, PDFs and voice dictation in chat';

  @override
  String get billingIncludedReminders => 'Reminders';

  @override
  String get billingIncludedNearbyServices => 'Nearby pet services';

  @override
  String get billingFreePlaceholder => 'Free plan limits: to be defined';

  @override
  String get billingPlusPlaceholder => 'Plus extra features: to be defined';

  @override
  String get billingProPlaceholder => 'Pro extra features: to be defined';

  @override
  String get billingPlanBadgeRecommended => 'Recommended';

  @override
  String get billingIncludedInAllPlans => 'Included in every plan';

  @override
  String get billingPriceFree => 'Free';

  @override
  String billingPricePerMonth(String amount) {
    return '$amount/month';
  }

  @override
  String billingPricePerMonthYearly(String amount) {
    return '$amount/month, billed yearly';
  }

  @override
  String get billingTitle => 'Subscription and payments';

  @override
  String billingPlanSwitched(String plan) {
    return 'You are now on the $plan plan.';
  }

  @override
  String get billingPaymentHistory => 'Payment history';

  @override
  String get billingPaymentHistoryComingSoon =>
      'Your invoices and receipts will be available here.';

  @override
  String get billingComparePlans => 'Compare plans';

  @override
  String get billingPaymentMethodsSection => 'Payment methods';

  @override
  String get billingInvoicingSection => 'Billing';

  @override
  String get billingTrialBannerTitle => 'Free trial active';

  @override
  String billingTrialBannerDaysLeft(int days) {
    return 'You have $days free days left, no card required. Choose a plan anytime or when the trial ends.';
  }

  @override
  String get billingTrialBannerEnding =>
      'Your free trial is about to end: choose a plan to keep using VetApp.';

  @override
  String get billingDeveloperBanner =>
      'Developer account: unlimited access, no plan required.';

  @override
  String get billingCurrentPlanLabel => 'Your plan';

  @override
  String billingRenewalOn(String date) {
    return 'Renews on $date';
  }

  @override
  String get billingCycleMonthly => 'Monthly';

  @override
  String get billingCycleYearly => 'Yearly';

  @override
  String get billingCurrentPlanButton => 'Current plan';

  @override
  String get billingBackToFree => 'Back to Free';

  @override
  String billingSwitchToPlan(String plan) {
    return 'Switch to $plan';
  }

  @override
  String billingCardExpires(String expiry) {
    return 'Expires $expiry';
  }

  @override
  String billingCardExpiresDefault(String expiry) {
    return 'Expires $expiry · Default';
  }

  @override
  String get billingSetDefault => 'Set as default';

  @override
  String get billingRemove => 'Remove';

  @override
  String get billingAddPaymentMethod => 'Add payment method';

  @override
  String get billingCardBrandLabel => 'Card network';

  @override
  String get billingCardLast4Label => 'Last 4 digits';

  @override
  String get billingCardLast4Error => 'Enter 4 digits';

  @override
  String get billingExpiryMonthLabel => 'Month';

  @override
  String get billingExpiryYearLabel => 'Year';

  @override
  String get billingPaywallTitle => 'Your free trial has ended.';

  @override
  String get billingPaywallSubtitle =>
      'Choose how to continue with VetApp. You can change plan anytime in Settings.';

  @override
  String billingChoosePlan(String plan) {
    return 'Choose $plan';
  }

  @override
  String billingTrialDialogTitle(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'You have $daysLeft trial days left',
      one: 'Last trial day',
    );
    return '$_temp0';
  }

  @override
  String get billingTrialDialogBody =>
      'Some features are limited on the Free plan. Switch to Plus or Pro for unlimited access when your trial ends.';

  @override
  String get billingTrialDialogLater => 'Later';

  @override
  String get billingTrialDialogSeePlans => 'View plans';

  @override
  String get firstRunWelcomeTitle => 'Welcome to VetApp.';

  @override
  String get firstRunPlanIntroSubtitle =>
      'Choose how to start: try everything free for 10 days with no card, or choose a plan now.';

  @override
  String get firstRunPlanOrChoose => 'OR CHOOSE A PLAN NOW';

  @override
  String get firstRunTrialCardTitle => 'Free trial — 10 days';

  @override
  String get firstRunTrialCardBody =>
      'No card required. At the end of the 10 days, we will ask you to choose a plan to continue.';

  @override
  String get firstRunTrialStartButton => 'Start free trial';

  @override
  String get firstRunPlanSelectButton => 'Choose';

  @override
  String get firstRunAddPetTitle => 'Add your first pet';

  @override
  String get firstRunAddPetBody =>
      'It only takes a couple of minutes: name, species and a few details. You can also do it later from Pets.';

  @override
  String get firstRunAddPetNow => 'Add now';

  @override
  String get firstRunAddPetLater => 'Skip for now';

  @override
  String get firstRunNotificationsTitle => 'Do not miss your reminders';

  @override
  String get firstRunNotificationsBody =>
      'Enable notifications for alerts about vaccines, medicines and upcoming visits. You can change this at any time in Settings.';

  @override
  String get firstRunNotificationsEnable => 'Enable notifications';

  @override
  String get firstRunNotificationsLater => 'Not now';

  @override
  String get firstRunTutorialPetsTitle => 'A profile for every pet';

  @override
  String get firstRunTutorialPetsBody =>
      'Species and breed, weight, medical notes and documents: everything organized for each pet, always close at hand.';

  @override
  String get firstRunTutorialAssistantTitle => 'Ask your assistant';

  @override
  String get firstRunTutorialAssistantBody =>
      'Ask questions about your pets\' health and receive answers tailored to their specific situation.';

  @override
  String get firstRunTutorialRemindersTitle => 'Never miss another deadline';

  @override
  String get firstRunTutorialRemindersBody =>
      'Vaccines, medicines and visits: set a reminder and VetApp will notify you at the right time.';

  @override
  String get firstRunTutorialStart => 'Start';

  @override
  String get chatLoadingTitle => 'Opening the conversation';

  @override
  String get chatLoadingSubtitle =>
      'Loading the thread and the latest available context.';

  @override
  String get chatEmptyTitle => 'The conversation is empty';

  @override
  String get chatEmptySubtitle =>
      'Write your first message to start talking with the assistant.';

  @override
  String get chatEmptyAction => 'Write now';

  @override
  String chatEmptyGreeting(String pet) {
    return 'Hi, I have a question about $pet.';
  }

  @override
  String get chatErrorTitle => 'Conversation unavailable';

  @override
  String get chatErrorSubtitle =>
      'Something went wrong while retrieving the thread.';

  @override
  String get chatErrorAction => 'Back to chats';

  @override
  String get chatMessageEditAction => 'Edit message';

  @override
  String get chatMessageEditHint =>
      'The reply and subsequent messages will be replaced.';

  @override
  String chatComposerHint(String pet) {
    return 'Ask a question about $pet';
  }

  @override
  String chatNewConversationOnPet(String pet) {
    return 'New conversation about $pet';
  }

  @override
  String get chatNewConversationPrompt =>
      'Describe what you are observing below and I will reply right away.';

  @override
  String get chatTypingText => 'Writing a response…';

  @override
  String get chatTypingSlowText =>
      'This is taking longer than usual. Your reply will arrive shortly...';

  @override
  String chatDefaultTitle(String pet) {
    return 'Chat with $pet';
  }

  @override
  String get chatListeningText => 'Listening… tap to stop';

  @override
  String get chatTranscribingText => 'Transcribing…';

  @override
  String get chatEditingLabel => 'Editing message';

  @override
  String get chatListeningHint => 'Listening…';

  @override
  String get chatTranscribingHint => 'Transcribing the message…';

  @override
  String get chatAddPhotoTooltip => 'Add a photo';

  @override
  String get chatStopRecordingTooltip => 'Stop and transcribe';

  @override
  String get chatVoiceMessageTooltip => 'Voice message';

  @override
  String get chatMicPermissionNeeded => 'Microphone permission is required.';

  @override
  String get chatMicStartFailed => 'I can\'t start the microphone. Try again.';

  @override
  String get chatRecordingFailed => 'The recording failed. Try again.';

  @override
  String get chatRecordingReadFailed =>
      'The recording could not be read. Try again.';

  @override
  String get chatPhotoAnalyzing => 'Looking at the photo…';

  @override
  String get chatPhotoReady => 'Photo ready to send';

  @override
  String get chatRemovePhotoTooltip => 'Remove photo';

  @override
  String chatRecordingSemantics(String listening, int minutes, String seconds) {
    return '$listening, $minutes minutes and $seconds seconds';
  }

  @override
  String get chatCancelEditTooltip => 'Cancel edit';

  @override
  String get chatMenuTooltip => 'Chat options';

  @override
  String get chatMenuRename => 'Rename';

  @override
  String get chatMenuExport => 'Export chat';

  @override
  String get chatMenuSummary => 'Summary';

  @override
  String get chatExportOpenFirst => 'Open the chat to export it.';

  @override
  String get chatSenderYou => 'You';

  @override
  String get chatSenderAssistant => 'Assistant';

  @override
  String get chatRenameTitle => 'Rename chat';

  @override
  String get chatRenameFieldLabel => 'Title';

  @override
  String get chatSummaryLoading => 'Preparing the summary…';

  @override
  String get chatSummaryTitle => 'Summary for the veterinarian';

  @override
  String get chatSummaryDisclaimer =>
      'This summary is automatically generated and is not a diagnosis. Consult your veterinarian for clinical decisions.';

  @override
  String get chatSummaryEmpty => 'No summary available.';

  @override
  String get chatDeleteTitle => 'Delete this chat?';

  @override
  String get chatDeleteBody =>
      'The conversation and its messages will be deleted.';

  @override
  String get chatFallbackPetName => 'your pet';

  @override
  String get chatNewConversation => 'New conversation';

  @override
  String chatNewConversationTitle(String pet) {
    return '$pet - new conversation';
  }

  @override
  String chatSavedConversationTitle(String pet) {
    return '$pet - conversation';
  }

  @override
  String chatRetitled(String subject) {
    return 'Chat - $subject';
  }

  @override
  String get chatStatusSaved => 'Conversation saved';

  @override
  String get chatStatusSent => 'Message sent';

  @override
  String get chatStatusEdited => 'Message edited';

  @override
  String get chatStatusReplyReady => 'Reply ready';

  @override
  String get chatTimeYesterday => 'yesterday';

  @override
  String get chatTimeNow => 'now';

  @override
  String get chatSummaryNotYet =>
      'The summary will be available after your first message.';

  @override
  String get chatEditMessageMissing =>
      'This message is no longer in the conversation.';

  @override
  String get chatEmptyThreadPreview => 'New thread ready to use.';

  @override
  String chatDemoReplyAppetite(String pet) {
    return 'For $pet, I would monitor appetite, water intake and energy for the next 24 hours. If things get worse, contact the veterinarian.';
  }

  @override
  String get chatDemoReplyVomiting =>
      'If there is vomiting or diarrhea, monitor hydration and contact the veterinarian if symptoms recur or become severe.';

  @override
  String chatDemoReplyVaccine(String pet) {
    return 'I can help schedule $pet\'s booster and add a clear reminder to your home screen.';
  }

  @override
  String chatDemoReplyWeight(String pet) {
    return 'We can schedule regular weight checks for $pet and compare them with the last visit to see whether the trend really changes.';
  }

  @override
  String chatDemoReplyDefault(String pet) {
    return 'Noted: I will prepare a short summary for $pet so you have a practical, readable plan.';
  }

  @override
  String get chatErrorContactAssistant =>
      'I couldn\'t contact the assistant. Try again.';

  @override
  String get chatErrorAssistantTimeout =>
      'The assistant did not reply in time. Tap Retry: if the reply is already ready, I will retrieve it.';

  @override
  String get chatErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get chatErrorRequestTimeout => 'The request timed out. Try again.';

  @override
  String get chatErrorEditFailed => 'I couldn\'t edit the message. Try again.';

  @override
  String get chatErrorEditNetwork =>
      'I couldn\'t edit the message. Check your connection.';

  @override
  String chatErrorMessageTooLong(int max) {
    return 'That message is too long: you can write up to $max characters. Shorten it and send it again.';
  }

  @override
  String chatInputLimitReached(int max) {
    return 'You have reached the limit of $max characters.';
  }

  @override
  String get chatErrorPetBootstrap => 'I couldn\'t prepare the pet profile.';

  @override
  String get chatErrorTitleEmpty => 'The title cannot be empty.';

  @override
  String get chatErrorRenameFailed => 'I couldn\'t rename the chat. Try again.';

  @override
  String get chatErrorRenameNetwork =>
      'I couldn\'t rename the chat. Check your connection.';

  @override
  String get chatErrorSummaryEmpty =>
      'Write at least one message to get a summary.';

  @override
  String get chatErrorSummaryModel =>
      'The model did not reply. Try again shortly.';

  @override
  String get chatErrorSummaryFailed =>
      'I couldn\'t prepare the summary. Try again.';

  @override
  String get chatErrorSummaryNetwork =>
      'I couldn\'t prepare the summary. Check your connection.';

  @override
  String get chatErrorDeleteFailed =>
      'I couldn\'t delete the chat on the server.';

  @override
  String get chatErrorListChats => 'I couldn\'t load your chats.';

  @override
  String get chatErrorListPets => 'I couldn\'t load your pets.';

  @override
  String chatErrorConversationLimit(String max) {
    return 'You have reached the maximum number of conversations ($max) for this pet. Close one to create a new one.';
  }

  @override
  String get chatErrorConversationNotFound =>
      'This conversation no longer exists.';

  @override
  String get chatErrorAttachmentOffline =>
      'You are offline or the connection is unstable. Try again when you are back online.';

  @override
  String get chatErrorAttachmentDownload => 'I couldn\'t download the file.';

  @override
  String get chatErrorAttachmentTooLarge => 'The file is too large (max 4 MB).';

  @override
  String get chatErrorAttachmentUnsupported =>
      'This file type is not supported. You can upload photos (JPG, PNG, WEBP) or PDFs.';

  @override
  String get chatErrorPdfTooManyPages => 'The PDF exceeds the 30-page limit.';

  @override
  String get chatErrorPdfUnreadable =>
      'I can\'t read this PDF: it may be damaged or password-protected.';

  @override
  String get chatErrorAttachmentUpload =>
      'I couldn\'t upload the file. Try again.';

  @override
  String get chatErrorTranscribe => 'I couldn\'t transcribe the voice message.';

  @override
  String get chatSeedConv1Title => 'Moka - appetite and check-up';

  @override
  String get chatSeedConv1Subtitle =>
      'Slight drop in appetite, monitoring and action plan.';

  @override
  String get chatSeedConv1Preview =>
      'If still lively, we can observe until tomorrow, but record appetite and water intake.';

  @override
  String get chatSeedConv1Status => 'Active pet context';

  @override
  String get chatSeedConv1Msg1 =>
      'Tell me what you are noticing: appetite, energy, water and stools help us understand whether a visit is needed or monitoring is enough.';

  @override
  String get chatSeedConv1Msg2 =>
      'Since yesterday, my pet has been eating less but is still lively. Should I worry immediately?';

  @override
  String get chatSeedConv1Msg3 =>
      'Without vomiting, lethargy or obvious pain, monitoring for 24 hours and noting appetite, water and stools is generally useful. Contact the veterinarian if anything worsens.';

  @override
  String get chatSeedConv1Msg4 =>
      'Here is a short plan: small meals, water always available and check the temperature if your pet seems less energetic than usual.';

  @override
  String get chatSeedConv2Title => 'Moka - vaccine reminder';

  @override
  String get chatSeedConv2Subtitle =>
      'Annual booster with a parasite treatment note.';

  @override
  String get chatSeedConv2Preview =>
      'I have scheduled the booster and a follow-up reminder for next week.';

  @override
  String get chatSeedConv2Status => 'Active reminder';

  @override
  String get chatSeedConv2Msg1 =>
      'I have scheduled the booster and added a parasite treatment note. We can also align the next check-up.';

  @override
  String get chatSeedConv2Msg2 =>
      'Great, can you also notify me one week before?';

  @override
  String get chatSeedConv2Msg3 =>
      'Of course. I will also prepare a visual note with the closest deadline so you can find it on the home screen.';

  @override
  String get chatSeedConv3Title => 'Moka - visit report';

  @override
  String get chatSeedConv3Subtitle =>
      'Check-up summary, mild treatment and next action.';

  @override
  String get chatSeedConv3Preview =>
      'I can summarize the report in three points: condition, treatment and next check-up.';

  @override
  String get chatSeedConv3Status => 'Report uploaded';

  @override
  String get chatSeedConv3Msg1 =>
      'I can summarize the report in three points: clinical condition, treatment and next check-ups. I can also prepare a short version to share.';

  @override
  String get chatSeedConv3Msg2 => 'Yes, give me the short version.';

  @override
  String get chatSeedConv3Msg3 =>
      'Briefly: stable condition, mild treatment for a few days and a follow-up already scheduled.';

  @override
  String get chatSeedAgo2Min => '2 min ago';

  @override
  String get chatSeedAgo3Days => '3 days ago';

  @override
  String get marketplacePermissionDenied =>
      'Only the person who posted the listing can edit or delete it.';

  @override
  String get marketplaceCategoryKennelsCarriers => 'Beds, kennels and carriers';

  @override
  String get marketplaceCategoryLeashesCollars =>
      'Leashes, collars and harnesses';

  @override
  String get marketplaceCategoryToys => 'Toys';

  @override
  String get marketplaceCategoryClothing => 'Clothing';

  @override
  String get marketplaceCategoryFeeding => 'Bowls and feeding';

  @override
  String get marketplaceCategoryHygieneGrooming => 'Hygiene and grooming';

  @override
  String get marketplaceCategoryAquariumsTerrariums =>
      'Aquariums and terrariums';

  @override
  String get marketplaceCategoryCagesAviaries => 'Cages and aviaries';

  @override
  String get marketplaceOther => 'Other';

  @override
  String get marketplaceConditionNew => 'New';

  @override
  String get marketplaceConditionLikeNew => 'Like new';

  @override
  String get marketplaceConditionGood => 'Good';

  @override
  String get marketplaceConditionWorn => 'Used';

  @override
  String get marketplaceSpeciesAll => 'All species';

  @override
  String get marketplaceSpeciesDog => 'Dog';

  @override
  String get marketplaceSpeciesCat => 'Cat';

  @override
  String get marketplaceSpeciesSmallMammal => 'Small mammals';

  @override
  String get marketplaceSpeciesBird => 'Bird';

  @override
  String get marketplaceSpeciesReptileAmphibian => 'Reptiles and amphibians';

  @override
  String get marketplaceSpeciesFish => 'Fish';

  @override
  String get marketplacePriceGift => 'Free gift';

  @override
  String get marketplaceDemoBedTitle => 'Padded pet bed (demo)';

  @override
  String get marketplaceDemoBedDescription => 'Lightly used, medium size.';

  @override
  String get marketplaceDemoBedArea => 'City center, Milan';

  @override
  String get marketplaceDemoScratcherTitle =>
      'Two-level scratching post (demo)';

  @override
  String get marketplaceDemoScratcherArea => 'Città Studi, Milan';

  @override
  String get marketplacePageTitle => 'Second-hand marketplace';

  @override
  String get marketplaceMapAction => 'Map';

  @override
  String get marketplaceNewListing => 'New listing';

  @override
  String get marketplaceIntro =>
      'Buy, sell and give away pet items with other owners.';

  @override
  String get marketplaceRules =>
      'The marketplace only has items for animals. Animals cannot be sold, given away or swapped here, in any country.';

  @override
  String get marketplaceNoAnimalsMessage =>
      'Only items for animals are sold on the marketplace, not animals.';

  @override
  String get marketplaceBackendUnavailable =>
      'The marketplace can\'t be reached right now. Try again in a moment.';

  @override
  String get marketplaceEmptyFiltered => 'No listings match these filters yet.';

  @override
  String get marketplaceNeedsLocation =>
      'The marketplace only shows ads near you. Set your location in Settings → Location to see them.';

  @override
  String get marketplaceSetLocationAction => 'Set your location';

  @override
  String get marketplaceDistanceOther => 'Other';

  @override
  String marketplaceDistanceOtherValue(String distance) {
    return 'Other: $distance';
  }

  @override
  String get marketplaceDistanceDialogTitle => 'Maximum distance';

  @override
  String marketplaceDistanceDialogHelp(int min, int max, String unit) {
    return 'Enter a whole number from $min to $max $unit.';
  }

  @override
  String marketplaceDistanceDialogInvalid(int min, int max, String unit) {
    return 'Invalid value: enter a whole number from $min to $max $unit.';
  }

  @override
  String get marketplaceLoadError =>
      'I can\'t load the listings. Check your connection.';

  @override
  String get marketplaceFilterAllCategories => 'All';

  @override
  String get marketplaceFilterAllSpecies => 'All pets';

  @override
  String get marketplaceReportListing => 'Report listing';

  @override
  String get marketplaceReasonSpam => 'Spam';

  @override
  String get marketplaceReasonScam => 'Scam';

  @override
  String get marketplaceReasonProhibitedItem => 'Prohibited item';

  @override
  String get marketplaceReasonInappropriate => 'Inappropriate content';

  @override
  String get marketplaceReasonSellsAnimals => 'Sells animals';

  @override
  String get marketplaceReportRemoved =>
      'Thank you, the listing has been removed following reports.';

  @override
  String get marketplaceReportSent => 'Report sent, thank you.';

  @override
  String get marketplaceDeleteConfirmTitle => 'Delete the listing?';

  @override
  String marketplaceDeleteConfirmBody(String title) {
    return '\"$title\" and its photos will be deleted. This cannot be undone.';
  }

  @override
  String get marketplaceDeleteFailed =>
      'I couldn\'t delete the listing. Try again.';

  @override
  String get marketplaceDeleted => 'Listing deleted.';

  @override
  String marketplaceDetailApproxZone(String city) {
    return '$city · approximate area';
  }

  @override
  String marketplaceDetailForSpecies(String species) {
    return 'For: $species';
  }

  @override
  String get marketplaceEditListing => 'Edit listing';

  @override
  String get marketplaceDeleting => 'Deleting...';

  @override
  String get marketplaceDeleteListing => 'Delete listing';

  @override
  String get marketplaceReporting => 'Sending report…';

  @override
  String get marketplaceMapTitle => 'Marketplace map';

  @override
  String marketplaceListingsCount(int count) {
    return '$count listings';
  }

  @override
  String marketplaceMapClusterTitle(int count) {
    return '$count listings in this area';
  }

  @override
  String get marketplaceMapEmpty => 'No listings match these filters.';

  @override
  String marketplaceMapSummary(int count) {
    return '$count listings · approximate positions (about 1 km)';
  }

  @override
  String get marketplaceLocationErrorWithHome =>
      'I can\'t detect your location. Check location permissions or use your home address.';

  @override
  String get marketplaceLocationErrorNoHome =>
      'I can\'t detect your location. It is needed to show the listing in the correct approximate area. Check location permissions and try again.';

  @override
  String get marketplaceCameraOpenError => 'I can\'t open the camera.';

  @override
  String get marketplaceGalleryOpenError => 'I can\'t open the gallery.';

  @override
  String marketplacePhotosSkipped(int count) {
    return '$count unreadable photos were skipped.';
  }

  @override
  String marketplacePhotosMaxReached(int max) {
    return 'You can add at most $max photos.';
  }

  @override
  String get marketplaceZoneWait =>
      'Wait until the area has been found, then try again.';

  @override
  String get marketplaceSaveFailed =>
      'I couldn\'t save the listing. Check your connection and try again.';

  @override
  String get marketplacePriceRequired =>
      'Enter a price or choose \"Free gift\"';

  @override
  String get marketplacePriceInvalid => 'Enter a valid price';

  @override
  String get marketplacePriceNegative => 'The price cannot be negative';

  @override
  String get marketplacePriceZero => 'Choose \"Free gift\" to give it away';

  @override
  String get marketplacePriceTooHigh => 'Price too high';

  @override
  String get marketplaceFieldTitle => 'Title';

  @override
  String get marketplaceTitleRequired => 'Enter a title';

  @override
  String get marketplaceFieldDescription => 'Description (optional)';

  @override
  String get marketplaceFieldCategory => 'Category';

  @override
  String get marketplaceCategoryRequired => 'Choose a category';

  @override
  String get marketplaceConditionLabel => 'Condition';

  @override
  String get marketplaceSpeciesLabel => 'For which pets';

  @override
  String get marketplaceSpeciesRequired =>
      'Specify the pets it is for, or choose \"All species\"';

  @override
  String get marketplaceGiftSubtitle => 'Give it to someone who needs it';

  @override
  String marketplaceFieldPrice(String currency) {
    return 'Price ($currency)';
  }

  @override
  String get marketplaceSaving => 'Saving…';

  @override
  String get marketplaceSaveChanges => 'Save changes';

  @override
  String get marketplacePublish => 'Publish listing';

  @override
  String marketplacePhotosTitle(int count, int max) {
    return 'Photos ($count/$max)';
  }

  @override
  String get marketplaceTakePhoto => 'Take photo';

  @override
  String get marketplaceFromGallery => 'From gallery';

  @override
  String get marketplacePhotosPrivacy =>
      'Before uploading, we remove hidden photo data (location, device and date).';

  @override
  String get marketplaceLocationTitle => 'Location';

  @override
  String get marketplaceLocationKeep => 'Current listing area';

  @override
  String get marketplaceLocationNow => 'Where I am now';

  @override
  String get marketplaceLocationHome => 'Home';

  @override
  String get marketplaceLocationHomeHint =>
      'Set your home address in Settings → Location to use it.';

  @override
  String get marketplaceLocationSearching => 'Finding your area...';

  @override
  String get marketplaceZoneLabel => 'Displayed area (neighborhood or town)';

  @override
  String get marketplaceZoneHelper => 'No street or house number';

  @override
  String get marketplacePrivacyApproxOnMap =>
      'The listing appears on the map at an approximate point (about 1 km), never at your address.';

  @override
  String get marketplacePrivacyApproxAlways =>
      'For your privacy, the listing location is always approximate (about 1 km), never your exact address.';

  @override
  String get medicalActionOpen => 'Open';

  @override
  String get medicalActionSend => 'Send';

  @override
  String get medicalActionRename => 'Rename';

  @override
  String get medicalFileUnavailable =>
      'The file is unavailable right now. Check your connection and try again.';

  @override
  String get medicalPdfOpenFailed =>
      'I couldn\'t open the PDF. Try again or use Send.';

  @override
  String get medicalNoPdfAppTitle => 'No app available to open the PDF';

  @override
  String get medicalNoPdfAppBody =>
      'There is no app on this device to open PDFs. You can send the file to an app that opens it.';

  @override
  String get medicalPreparingFiles => 'Preparing files to send…';

  @override
  String get medicalNoFilesToSend =>
      'No files available to send. Check your connection and try again.';

  @override
  String medicalFilesMissing(int count) {
    return '$count unavailable files were not included.';
  }

  @override
  String get medicalDeleteConfirmTitle => 'Delete this document?';

  @override
  String medicalDeleteConfirmBody(String title) {
    return '\"$title\" will be permanently deleted.';
  }

  @override
  String get medicalDeleting => 'Deleting the report…';

  @override
  String get medicalRenameTitle => 'Rename report';

  @override
  String get medicalRenameFieldLabel => 'File name';

  @override
  String get medicalDefaultRecordTitle => 'Clinical report';

  @override
  String get medicalSaveNoSession =>
      'Access unavailable: try again after signing in again.';

  @override
  String medicalSavePetNotSynced(String petName) {
    return '$petName\'s profile is not synced with the server. Fix it before uploading reports.';
  }

  @override
  String get medicalSaveFailed =>
      'I couldn\'t save the report on the server. Check your connection and try again.';

  @override
  String get medicalRenameFailed => 'I couldn\'t rename the report. Try again.';

  @override
  String get medicalDeleteFailed => 'I couldn\'t delete the report. Try again.';

  @override
  String get medicalRecordMetaNotUploaded => 'File not uploaded to the server';

  @override
  String get medicalRecordMetaAnalysisFailed =>
      'File saved, automatic reading failed';

  @override
  String get medicalRecordMetaUploadedNow => 'Uploaded by you just now';

  @override
  String get medicalRecordBadgeNotUploaded => 'Not uploaded';

  @override
  String get medicalRecordBadgeNew => 'New';

  @override
  String get medicalRecordSourceLocalOnly => 'Only on this phone';

  @override
  String get medicalRecordSourceUploadedByYou => 'Uploaded by you';

  @override
  String get medicalTimelineImported => 'Imported';

  @override
  String get medicalTimelineUpload => 'Uploading';

  @override
  String get medicalTimelineFailed => 'Failed';

  @override
  String get medicalTimelineCompleted => 'Completed';

  @override
  String get medicalTimelineReadyToSend => 'Ready to send';

  @override
  String get medicalTimelineAvailable => 'Available';

  @override
  String get medicalUploadTitle => 'Upload document';

  @override
  String medicalUploadForPet(String petName) {
    return 'For $petName · PDF, JPG or PNG';
  }

  @override
  String get medicalUploadAction => 'Upload';

  @override
  String get medicalUploadPickPrompt => 'Tap to choose a file';

  @override
  String get medicalUploadPickHint => 'PDF, JPG or PNG from your device';

  @override
  String get medicalUploadChange => 'Change';

  @override
  String get medicalUploadFailedTitle => 'The file was not uploaded';

  @override
  String medicalUploadFailedBody(String reason) {
    return '$reason Alternatively, save the report only on this phone: it will be marked \"Not uploaded\" and will not be available on other devices.';
  }

  @override
  String get medicalUploadFailedDefaultReason =>
      'Check your connection and try again.';

  @override
  String get medicalUploadSaveLocalOnly => 'Save on phone only';

  @override
  String get medicalUploadDemoSubtitle =>
      'Upload a PDF, JPG or PNG and complete the metadata.';

  @override
  String get medicalUploadDemoAction => 'Details';

  @override
  String get medicalUploadDemoCardBody =>
      'Uploaded successfully and ready for metadata review.';

  @override
  String get medicalListTitle => 'Records';

  @override
  String get medicalListSubtitle =>
      'Moka\'s reports, notes and attachments in one clear archive.';

  @override
  String get medicalListSyncTitle => 'Record synchronization';

  @override
  String get medicalListSyncBody =>
      'Retrieving documents and metadata from Supabase or the demo source.';

  @override
  String get medicalListLoadErrorTitle => 'Unable to load the archive';

  @override
  String get medicalListLoadErrorBody =>
      'Check your connection and retry, or continue with the demo fallback.';

  @override
  String get medicalListEmptyTitle => 'No documents yet';

  @override
  String get medicalListEmptyBody =>
      'Upload the first report to start your document archive.';

  @override
  String get medicalListUploadFirst => 'Upload the first file';

  @override
  String medicalListSummaryAllTitle(int count) {
    return '$count active documents';
  }

  @override
  String medicalListSummaryPetTitle(int count, String petName) {
    return '$count documents for $petName';
  }

  @override
  String get medicalListSummaryAllBody =>
      '1 report ready to share, 1 test to review and 1 archived note.';

  @override
  String medicalListSummaryPetBody(String petName) {
    return 'Filters active for $petName\'s profile. Open useful documents without clutter.';
  }

  @override
  String get medicalListNextActionTitle => 'Next action';

  @override
  String get medicalListNextActionAllBody =>
      'Open Moka\'s vaccination report and share it with Francesco.';

  @override
  String medicalListNextActionPetBody(String petName) {
    return 'Share $petName\'s latest document and keep the note in the profile.';
  }

  @override
  String medicalListEmptyPetTitle(String petName) {
    return 'No documents for $petName';
  }

  @override
  String get medicalListEmptyPetBody =>
      'Change the filter or upload a new document for this pet.';

  @override
  String get medicalListRemoveFilter => 'Remove filter';

  @override
  String medicalFilterAll(int count) {
    return 'All ($count)';
  }

  @override
  String get medicalMetaType => 'Type';

  @override
  String get medicalMetaDate => 'Date';

  @override
  String get medicalMetaSource => 'Source';

  @override
  String get medicalMetaFormat => 'Format';

  @override
  String get medicalStatePreviewPill => 'Preview state';

  @override
  String get medicalStateLoadingPill => 'Uploading';

  @override
  String get medicalChecklistFormat => 'Supported file format';

  @override
  String get medicalChecklistMetadata => 'Metadata extracted';

  @override
  String get medicalChecklistLinkedPet => 'Linked to the active pet';

  @override
  String get homeGreeting => 'Good morning';

  @override
  String get homeAgendaTitle => 'Upcoming activities';

  @override
  String get homeAgendaLoadingSubtitle =>
      'One-off and recurring activities for all pets.';

  @override
  String homeAgendaSummary(int count) {
    return '$count activities in the next 10 days';
  }

  @override
  String get homeNewsTitle => 'Stories for your pets';

  @override
  String get homeNewsSubtitle => 'Pet news selected for you.';

  @override
  String get homeNewsUnavailable =>
      'Stories are unavailable right now. Try again later.';

  @override
  String get homeNewsMore => 'Discover more news';

  @override
  String get homeNearbyTitle => 'Near me';

  @override
  String get homeSponsorBanner => 'Space reserved for our partners.';

  @override
  String get homeSectionLoading => 'Loading…';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabPets => 'Pets';

  @override
  String get shellTabActivities => 'Activities';

  @override
  String get shellTabSettings => 'Settings';

  @override
  String get shellRailFooter => 'A welcoming clinical space';

  @override
  String get shellInterruptedWalkTitle => 'Interrupted walk';

  @override
  String shellInterruptedWalkBody(String distance) {
    return 'A walk is still in progress ($distance so far). Do you want to resume it?';
  }

  @override
  String get shellInterruptedWalkDiscard => 'Discard';

  @override
  String get shellInterruptedWalkResume => 'Resume';

  @override
  String shellWalkPausedBanner(String distance) {
    return 'Walk paused · $distance';
  }

  @override
  String shellWalkActiveBanner(String elapsed, String distance) {
    return 'Walk in progress · $elapsed · $distance';
  }

  @override
  String get splashMessageWalks => 'Record your walks with your dog!';

  @override
  String get splashMessageVet => 'Ask the virtual veterinarian, 24 hours a day';

  @override
  String get splashMessageReminders =>
      'Never miss a deadline: reminders and calendar';

  @override
  String get splashMessageRecords => 'Keep reports at your fingertips';

  @override
  String get splashMessageNearby => 'Discover nearby pet-friendly activities';

  @override
  String get splashMessageNews => 'Follow news from the animal world';

  @override
  String get splashMessageProfiles =>
      'A profile for every four-legged friend (or one with fins!)';

  @override
  String get splashMessageHealthBook =>
      'Your health record in your pocket, with no scattered papers';

  @override
  String get splashMessageVaccines =>
      'Vaccines, deworming, visits: we will remind you';

  @override
  String get splashMessageSpecies =>
      'Dog, cat, rabbit, parrot or goldfish: everyone is welcome here';

  @override
  String get sharedGuestName => 'Guest';

  @override
  String get sharedComingSoon => 'Coming soon';

  @override
  String get sharedLoadingLabel => 'Uploading';

  @override
  String get sharedAttachmentTooLarge => 'The file is too large (max 4 MB).';

  @override
  String get sharedAttachmentInvalidPdf =>
      'This file does not look like a valid PDF.';

  @override
  String get sharedAiGenerated => 'AI-generated';

  @override
  String get sharedAiNotReviewed => 'Automatic reply, not reviewed';

  @override
  String get petsAgeLessThanMonth => 'Less than one month';

  @override
  String petsAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String petsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return '$_temp0';
  }

  @override
  String petsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count species',
      one: '1 species',
    );
    return '$_temp0';
  }

  @override
  String petsFishCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fish',
      one: '1 fish',
    );
    return '$_temp0';
  }

  @override
  String petsAquariumSummary(String species, String fish) {
    return '$species · $fish';
  }

  @override
  String get petsBreedUnspecified => 'Breed not specified';

  @override
  String get petsSpeciesUnspecified => 'Species not specified';

  @override
  String petsBreedOtherWithSize(String size) {
    return 'Other · $size size';
  }

  @override
  String get petsHabitatAquarium => 'Aquarium';

  @override
  String get petsHabitatTerrarium => 'Terrarium';

  @override
  String get petsHabitatAviary => 'Aviary';

  @override
  String get petsHabitatGeneric => 'Habitat';

  @override
  String get petsCreateTitle => 'Create a pet profile';

  @override
  String get petsCreateLoading => 'Preparing the creation form…';

  @override
  String get petsCreateErrorTitle => 'Creation form unavailable';

  @override
  String get petsCreateErrorDefault =>
      'A new pet profile cannot be created right now.';

  @override
  String get petsCreateFormTitle => 'New profile';

  @override
  String get petsCreateSubmit => 'Save pet profile';

  @override
  String get petsCreateUnsyncedSnack =>
      'Profile saved on this phone but not on the server. Open it from the list and tap Retry.';

  @override
  String petsEditTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get petsEditLoading => 'Loading the edit form…';

  @override
  String get petsEditErrorTitle => 'Editing unavailable';

  @override
  String get petsEditErrorDefault =>
      'This pet profile cannot be opened for editing.';

  @override
  String get petsEditFormTitle => 'Profile draft';

  @override
  String get petsEditSubmit => 'Save changes';

  @override
  String get petsEditUnsyncedSnack =>
      'Changes saved on this phone but not on the server. Open the profile and tap Retry.';

  @override
  String get petsEditDeleteTitle => 'Remove this profile?';

  @override
  String petsEditDeleteMessage(String name) {
    return 'The profile of \"$name\" will be permanently deleted along with its data.';
  }

  @override
  String get petsEditDeleteConfirm => 'Remove';

  @override
  String get petsEditDeleteAction => 'Remove profile';

  @override
  String get petsEditMemorialTitle => 'Move to memories?';

  @override
  String petsEditMemorialMessage(String name) {
    return '\"$name\" will leave the Pets list and be kept in Memories with their profile and photos.';
  }

  @override
  String get petsEditMemorialConfirm => 'Move';

  @override
  String get petsEditMemorialAction => 'Move to memories';

  @override
  String get petsFormAddSpecies => 'Add species';

  @override
  String get petsFormIdentityColor => 'Identification color';

  @override
  String get petsFormNameLabel => 'Name';

  @override
  String get petsFormNameHint => 'Moka';

  @override
  String get petsFormNameError => 'Enter the pet\'s name.';

  @override
  String get petsFormSpeciesLabel => 'Animal type';

  @override
  String get petsFormSpeciesHint => 'Select the animal type';

  @override
  String get petsFormSpeciesError => 'Select the animal type.';

  @override
  String get petsFormProfileType => 'What do you want to add?';

  @override
  String get petsFormFishSingleTitle => 'Fish';

  @override
  String get petsFormFishSingleBody =>
      'A single fish, chosen by species (e.g. betta, goldfish)';

  @override
  String get petsFormFishAquariumBody =>
      'A tank with several species and several fish, males and females';

  @override
  String get petsFormAquariumPopulation => 'Aquarium population';

  @override
  String get petsFormNoSpeciesYet => 'No species added yet.';

  @override
  String get petsFormAquariumNeedsSpecies =>
      'Add at least one species to the aquarium.';

  @override
  String get petsFormBreedLabel => 'Breed';

  @override
  String get petsFormBreedSelectSpeciesFirst => 'Select the animal type first';

  @override
  String get petsFormBreedSpeciesLabel => 'Species';

  @override
  String get petsFormBreedRequired => 'Choose the breed.';

  @override
  String get petsFormBreedSpeciesRequired => 'Choose the species.';

  @override
  String get petsFormBreedTextRequired => 'Enter the breed.';

  @override
  String get petsFormBreedSpeciesTextRequired => 'Enter the species.';

  @override
  String get petsFormBreedSpeciesPlaceholder => 'Select a species';

  @override
  String get petsFormOtherSpeciesDialogTitle => 'Which species?';

  @override
  String get petsFormBreedPlaceholder => 'Select a breed';

  @override
  String get petsFormBreedSearchHint => 'Search for a breed';

  @override
  String get petsFormBreedSearchHintScientific =>
      'Search (including scientific names)';

  @override
  String get petsFormOtherBreedLabel => 'Which breed?';

  @override
  String get petsFormOtherBreedHint => 'E.g. poodle mix';

  @override
  String get petsFormOtherSpeciesLabel => 'Which species?';

  @override
  String get petsFormOtherSpeciesHint => 'E.g. common or scientific name';

  @override
  String get petsFormDogSizeLabel => 'Size (optional)';

  @override
  String get petsFormDogSizeHint => 'Select a size';

  @override
  String get petsFormBirthDateLabel => 'Date of birth';

  @override
  String get petsFormBirthDateHint => 'dd/mm/yyyy';

  @override
  String get petsFormBirthDateRequired => 'Select the date of birth.';

  @override
  String get petsFormBirthDateInvalid => 'Invalid date (dd/mm/yyyy).';

  @override
  String get petsFormBirthDateFuture =>
      'The birth date cannot be in the future.';

  @override
  String get petsFormSexLabel => 'Sex';

  @override
  String get petsFormSexHint => 'Select';

  @override
  String get petsFormSexUnknown => 'Unknown';

  @override
  String get petsFormWeightLabelKg => 'Weight (optional, kg)';

  @override
  String get petsFormWeightLabelLb => 'Weight (optional, lb)';

  @override
  String get petsFormWeightHintKg => 'E.g. 18.4';

  @override
  String get petsFormWeightLabelG => 'Weight (optional, g)';

  @override
  String get petsFormWeightHintG => 'E.g. 35';

  @override
  String get petsFormWeightHintLb => 'E.g. 40.5';

  @override
  String get petsFormWeightInvalid => 'Enter a valid weight.';

  @override
  String get petsFormWeightPositive => 'Weight must be greater than zero.';

  @override
  String get petsFormNotesLabel => 'Notes';

  @override
  String get petsFormNotesHint =>
      'Add brief notes about diet, medicines or behavior.';

  @override
  String get petsFormSaving => 'Saving…';

  @override
  String get petsFormPhotoAdd => 'Add photo';

  @override
  String get petsFormPhotoChange => 'Change photo';

  @override
  String get petsFormPhotoRemove => 'Remove';

  @override
  String get petsFormHabitatLength => 'Length';

  @override
  String get petsFormHabitatWidth => 'Width';

  @override
  String get petsFormHabitatHeight => 'Height';

  @override
  String get petsFormHabitatUsGallons => 'US gallons';

  @override
  String get petsFormHabitatLiters => 'Liters';

  @override
  String get petsFormHabitatVolumeHint =>
      'Calculated from dimensions and editable';

  @override
  String get petsFormHabitatTemperature => 'Temperature';

  @override
  String get petsFormHabitatTemperatureHintF => 'E.g. 75-79°F';

  @override
  String get petsFormHabitatTemperatureHintC => 'E.g. 24-26°C';

  @override
  String get petsFormHabitatSubstrate => 'Substrate';

  @override
  String get petsFormHabitatSubstrateHint => 'E.g. fine gravel, coconut fiber';

  @override
  String get petsFormHabitatEquipment => 'Equipment';

  @override
  String get petsFormHabitatEquipmentHint =>
      'Filter, lighting, heater, plants, UVB lamp, perches…';

  @override
  String get petsDetailTitleFallback => 'Pet details';

  @override
  String get petsDetailGalleryTooltip => 'Photo gallery';

  @override
  String get petsDetailLoading => 'Loading pet details…';

  @override
  String get petsDetailErrorTitle => 'Pet details unavailable';

  @override
  String get petsDetailErrorDefault =>
      'This pet profile is currently unavailable.';

  @override
  String get petsDetailBackToList => 'Back to list';

  @override
  String get petsDetailEmptyTitle => 'No pet selected';

  @override
  String get petsDetailEmptySubtitle =>
      'Choose a profile from the list to view details, chats and records.';

  @override
  String get petsDetailTabReminders => 'Reminders';

  @override
  String get petsDetailTabChat => 'Chat';

  @override
  String get petsDetailTabRecords => 'Records';

  @override
  String get petsDetailTabWalks => 'Walks';

  @override
  String get petsDetailHabitatTapForDetails => 'Tap for details';

  @override
  String get petsDetailHabitatDimensions => 'Dimensions';

  @override
  String get petsDetailHabitatVolume => 'Volume';

  @override
  String get petsDetailPopulation => 'Population';

  @override
  String get petsDetailRemindersNew => 'New reminder';

  @override
  String petsDetailRemindersEmpty(String petName) {
    return 'No reminders yet for $petName.';
  }

  @override
  String get petsDetailChatNew => 'New chat';

  @override
  String petsDetailChatEmpty(String petName) {
    return 'No conversations yet for $petName.';
  }

  @override
  String petsDetailChatDeleteFailed(String error) {
    return 'Chat removed here but not from the server: $error';
  }

  @override
  String get petsDetailChatDeleteTitle => 'Delete this chat?';

  @override
  String petsDetailChatDeleteMessage(String title) {
    return '\"$title\" will be permanently deleted.';
  }

  @override
  String get petsDetailChatLimitTitle => 'Chat limit reached';

  @override
  String petsDetailChatLimitMessage(int max, String petName) {
    return 'You can have up to $max active conversations for $petName. Delete an existing chat to start a new one.';
  }

  @override
  String get petsDetailChatLimitOk => 'Got it';

  @override
  String get petsDetailRecordsSendTitle => 'Send file';

  @override
  String get petsDetailRecordsSendSubtitle =>
      'Choose a document to send by email, WhatsApp or another app.';

  @override
  String petsDetailRecordShareText(String title, String source, String date) {
    return '📄 $title\n$source · $date\n\nShared by VetApp';
  }

  @override
  String get petsDetailShareUnavailable =>
      'Sharing is unavailable on this device.';

  @override
  String get petsDetailRecordsUpload => 'Upload file';

  @override
  String get petsDetailRecordsSend => 'Send';

  @override
  String petsDetailRecordsEmpty(String petName) {
    return 'No documents yet for $petName.';
  }

  @override
  String get petsDetailRecordsLoadError =>
      'Records cannot be loaded. Check your connection and try again.';

  @override
  String petsDetailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get petsDetailWalksStart => 'Start walk';

  @override
  String get petsDetailWalksBadges => 'Badges';

  @override
  String petsDetailWalksEmpty(String petName) {
    return 'No walks yet for $petName.';
  }

  @override
  String get petsDetailWalksRecords => 'Records 🏆';

  @override
  String get petsDetailWalksFavorites => 'Favorites ⭐';

  @override
  String get petsDetailWalksRecent => 'Recent';

  @override
  String get petsDetailWalkLongest => 'Longest';

  @override
  String get petsDetailWalkLongestDuration => 'Longest duration';

  @override
  String get petsDetailWalkLongestAndDuration => 'Longest · Longest duration';

  @override
  String petsDetailWalkStatusActive(String distance, String elapsed) {
    return 'Walk in progress · $distance · $elapsed';
  }

  @override
  String petsDetailWalkStatusPaused(String distance, String elapsed) {
    return 'Paused · $distance · $elapsed';
  }

  @override
  String get petsDetailWalkUnfavoriteTitle => 'Remove from favorites?';

  @override
  String get petsDetailWalkUnfavoriteMessage =>
      'If it is not also a record or one of the last 3 walks, its map may be removed during the next automatic cleanup.';

  @override
  String get petsDetailWalkUnfavoriteConfirm => 'Remove from favorites';

  @override
  String get petsDetailWalkDeleteTitle => 'Delete this walk?';

  @override
  String petsDetailWalkDeleteMessage(String date, String distance) {
    return 'The walk on $date ($distance) will be permanently deleted.';
  }

  @override
  String petsDetailWalkSteps(int count) {
    return '~$count steps';
  }

  @override
  String get petsDetailUnsyncedBanner =>
      'Not synced: changes are only on this phone.';

  @override
  String get petsDetailUnsyncedRetryFailed =>
      'The server is still unavailable. Try again later.';

  @override
  String get petsScaffoldBadge => 'Pet';

  @override
  String get petsLoadingDefaultLabel => 'Loading pets…';

  @override
  String get petsLoadingSubtitle => 'Please wait while we prepare the screen.';

  @override
  String get petsDemoDeleteFailed =>
      'I couldn\'t delete the profile. Try again.';

  @override
  String get petsDemoNewProfileNote =>
      'Recently created profile, ready for the next visit.';

  @override
  String get petsDemoNextVisitToPlan => 'To be scheduled';

  @override
  String get petsValueSpeciesDog => 'Dog';

  @override
  String get petsValueSpeciesCat => 'Cat';

  @override
  String get petsValueSpeciesSmallMammals => 'Small mammals';

  @override
  String get petsValueSpeciesBird => 'Bird';

  @override
  String get petsValueSpeciesReptiles => 'Reptiles and amphibians';

  @override
  String get petsValueSpeciesFish => 'Fish';

  @override
  String get petsValueSpeciesOther => 'Other';

  @override
  String get petsValueSpeciesAll => 'All';

  @override
  String get petsValueSexMale => 'Male';

  @override
  String get petsValueSexFemale => 'Female';

  @override
  String get petsValueSexMaleIntact => 'Intact male';

  @override
  String get petsValueSexMaleNeutered => 'Neutered male';

  @override
  String get petsValueSexFemaleIntact => 'Intact female';

  @override
  String get petsValueSexFemaleSpayed => 'Spayed female';

  @override
  String get petsValueDogSizeToy => 'Toy';

  @override
  String get petsValueDogSizeSmall => 'Small';

  @override
  String get petsValueDogSizeMedium => 'Medium';

  @override
  String get petsValueDogSizeLarge => 'Large';

  @override
  String get petsValueDogSizeGiant => 'Giant';

  @override
  String get petsListTitle => 'Pets';

  @override
  String get petsListMemoriesTooltip => 'Memories';

  @override
  String get petsListLoading => 'Loading pet list…';

  @override
  String get petsListErrorTitle => 'Pets unavailable';

  @override
  String get petsListErrorDefault => 'Pet profiles cannot be loaded right now.';

  @override
  String get petsListEmptyTitle => 'No pets yet';

  @override
  String get petsListEmptySubtitle =>
      'Create the first profile to keep track of health, notes and deadlines.';

  @override
  String get petsListEmptyAction => 'Create pet';

  @override
  String get petsListFilterEmpty => 'No pets match this filter.';

  @override
  String get petsMemoriesRemoveTitle => 'Remove permanently?';

  @override
  String petsMemoriesRemoveBody(String name) {
    return 'The memory of \"$name\" will be deleted and cannot be recovered.';
  }

  @override
  String get petsMemoriesRemoveConfirm => 'Remove';

  @override
  String get petsMemoriesTitle => 'Memories';

  @override
  String get petsMemoriesSubtitle =>
      'Profiles of the pets that shared your journey.';

  @override
  String get petsMemoriesEmpty => 'No memories have been saved yet.';

  @override
  String petsMemoriesWithUsUntil(String date) {
    return 'With us until $date';
  }

  @override
  String petsMemoriesWithUsRange(String from, String to) {
    return 'With us from $from to $to';
  }

  @override
  String get petsMemoriesComingSoon =>
      'Coming soon: your best moments together, such as longest walks and milestones, collected here.';

  @override
  String get petsMediaGalleryTitle => 'Gallery';

  @override
  String get petsMediaFoldersLoading => 'Loading folders…';

  @override
  String get petsMediaFoldersEmpty => 'Add a pet to create their photo folder.';

  @override
  String get petsMediaFolderCounting => 'Counting photos…';

  @override
  String petsMediaCountPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
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
  String get petsMediaDeleteVideoTitle => 'Delete this video?';

  @override
  String get petsMediaDeletePhotoTitle => 'Delete this photo?';

  @override
  String get petsMediaDeleteVideoBody =>
      'The video will be permanently removed from the gallery.';

  @override
  String get petsMediaDeletePhotoBody =>
      'The photo will be permanently removed from the gallery.';

  @override
  String get petsMediaOperationFailed =>
      'The operation could not be completed. Try again.';

  @override
  String get petsMediaSetAsProfile => 'Set as profile photo';

  @override
  String get petsMediaDeleteVideoAction => 'Delete video';

  @override
  String get petsMediaDeletePhotoAction => 'Delete photo';

  @override
  String get petsMediaImportFromGallery => 'Import from gallery';

  @override
  String get petsMediaImportFromGalleryHint =>
      'Photos and videos, including multiple files';

  @override
  String get petsMediaTakePhoto => 'Take photo';

  @override
  String get petsMediaRecordVideo => 'Record video';

  @override
  String petsMediaRecordVideoLimit(int seconds) {
    return 'Up to $seconds seconds';
  }

  @override
  String petsMediaGalleryOf(String name) {
    return '$name\'s gallery';
  }

  @override
  String get petsMediaGalleryEmpty =>
      'No photos or videos yet. Use the \"Add\" button below.';

  @override
  String get petsMediaVideoPlaybackFailed => 'I can\'t play this video.';

  @override
  String get petsMediaVideoLoading => 'Loading video...';

  @override
  String get petsMediaCancelling => 'Cancelling...';

  @override
  String get petsMediaPreparingFile => 'Preparing file...';

  @override
  String petsMediaPreparingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preparing $count files...',
      one: 'Preparing file...',
    );
    return '$_temp0';
  }

  @override
  String get petsMediaUploadingFile => 'Uploading file...';

  @override
  String petsMediaUploadingProgress(int current, int total) {
    return 'Uploading $current of $total...';
  }

  @override
  String get petsMediaUploadingVideo => 'Uploading video...';

  @override
  String petsMediaUploadingVideoOf(int current, int total) {
    return 'Uploading video $current of $total...';
  }

  @override
  String petsMediaReducingVideo(int percent) {
    return 'Compressing video... $percent%';
  }

  @override
  String petsMediaReducingVideoOf(int current, int total, int percent) {
    return 'Compressing video $current of $total... $percent%';
  }

  @override
  String petsMediaImportJoin(String first, String second) {
    return '$first and $second';
  }

  @override
  String petsMediaImportDone(String list) {
    return 'Uploaded: $list';
  }

  @override
  String get petsMediaImportCancelled => 'Upload cancelled.';

  @override
  String petsMediaImportCancelledWith(String done) {
    return 'Upload cancelled. $done.';
  }

  @override
  String get petsMediaImportNothingToAdd => 'Nothing to add.';

  @override
  String petsMediaImportProblemMore(String problem, int count) {
    return '$problem ($count more not added)';
  }

  @override
  String petsMediaImportDoneWithProblem(String done, String problem) {
    return '$done. $problem';
  }

  @override
  String petsMediaPhotoAddedTo(String name) {
    return 'Photo added to $name\'s gallery';
  }

  @override
  String petsMediaVideoAddedTo(String name) {
    return 'Video added to $name\'s gallery';
  }

  @override
  String petsMediaImportFileFailed(String file) {
    return 'I couldn\'t upload $file.';
  }

  @override
  String get petsMediaImportUnnamedFile => 'a file';

  @override
  String get petsMediaPhotoSaveOffline =>
      'Photo saving is unavailable offline.';

  @override
  String get petsMediaVideoSaveOffline =>
      'Video saving is unavailable offline.';

  @override
  String petsMediaImportRefused(String file, String message) {
    return '$file: $message';
  }

  @override
  String get petsMediaVideoUnsupportedFormat =>
      'Unsupported video format: use an MP4 or MOV file.';

  @override
  String petsMediaVideoTooBigSource(int size, int max) {
    return 'Video too large ($size MB): the maximum is $max MB.';
  }

  @override
  String petsMediaVideoTooBigBrowser(int size, int max) {
    return 'Video too large ($size MB): the browser maximum is $max MB. Videos are automatically compressed in the mobile app.';
  }

  @override
  String get petsMediaVideoUnreadable => 'I can\'t read this video.';

  @override
  String petsMediaVideoTooLong(int seconds) {
    return 'Video too long: the maximum is $seconds seconds.';
  }

  @override
  String petsMediaVideoTooBigReduced(int size, int max) {
    return 'Even compressed, the video is $size MB (maximum $max MB). Try a shorter clip.';
  }

  @override
  String petsMediaVideoTooBigNotReduced(int size, int max) {
    return 'I couldn\'t compress the video and it is $size MB (maximum $max MB). Try a shorter clip.';
  }

  @override
  String petsConsentSemanticsExpanded(String name) {
    return 'Consent to reading $name\'s medical record. Tap to close the full text';
  }

  @override
  String petsConsentSemanticsCollapsed(String name) {
    return 'Consent to reading $name\'s medical record. Tap to read the full text';
  }

  @override
  String petsConsentCardTitle(String name) {
    return '$name\'s medical record';
  }

  @override
  String get petsConsentReadHow => 'Read how it is used';

  @override
  String petsConsentSwitchSemantics(String name) {
    return 'Allow the assistant to read $name\'s medical record';
  }

  @override
  String get petsConsentWithoutConsent =>
      'Without consent, the assistant sees neither report titles nor contents.';

  @override
  String get petsConsentSaveFailed =>
      'I couldn\'t save your consent. Try again.';

  @override
  String get petsConsentStatusUnavailable =>
      'Consent status unavailable: check your connection.';

  @override
  String get petsConsentSlowConnection =>
      'Slow connection. Your consent was not saved. Try again.';

  @override
  String get petsConsentOffline =>
      'You are offline: your consent was not saved. Try again with a connection.';

  @override
  String get placesDetailBarrierFence => 'Fenced';

  @override
  String get placesDetailBarrierWall => 'Enclosed by a wall';

  @override
  String get placesDetailBarrierHedge => 'Bordered by a hedge';

  @override
  String get placesDetailSurfaceGrass => 'Grass surface';

  @override
  String get placesDetailSurfaceGround => 'Earth surface';

  @override
  String get placesDetailSurfaceSand => 'Sand surface';

  @override
  String get placesDetailSurfaceGravel => 'Gravel surface';

  @override
  String get placesDetailSurfaceAsphalt => 'Asphalt surface';

  @override
  String get placesDetailSurfacePaved => 'Paved surface';

  @override
  String get placesDetailAccessFree => 'Public access';

  @override
  String get placesDetailAccessPermissive => 'Access permitted';

  @override
  String get placesDetailAccessCustomers => 'Customers only';

  @override
  String get placesDetailAccessPrivate => 'Private area';

  @override
  String get placesDetailWheelchairYes => 'Wheelchair accessible';

  @override
  String get placesDetailWheelchairLimited => 'Partially wheelchair accessible';

  @override
  String get placesDetailWheelchairNo => 'Not wheelchair accessible';

  @override
  String get placesDetailDrinkingWaterYes => 'Drinking water';

  @override
  String get placesDetailDrinkingWaterNo => 'No drinking water';

  @override
  String get placesDetailLitYes => 'Lit';

  @override
  String get placesDetailLitNo => 'Not lit';

  @override
  String get placesDetailDogUnleashed => 'Dogs allowed off leash';

  @override
  String get placesDetailAdoptionYes => 'Adoptions available';

  @override
  String get placesDetailAdoptionNo => 'No adoptions';

  @override
  String placesPendingDogPark(String progress) {
    return 'Reported by users: check that this is a public area ($progress)';
  }

  @override
  String placesPendingPlace(String progress) {
    return 'Reported by users · awaiting confirmation ($progress)';
  }

  @override
  String placesMailRemoveSubject(String id) {
    return 'Dog park to remove from radar ($id)';
  }

  @override
  String placesMailRemoveBody(String name, String position, String id) {
    return 'This user-reported area is not a public dog park.\n\nName: $name\nLocation: $position\nIdentifier: $id\n\nReason: ';
  }

  @override
  String get placesWithdrawTitle => 'Withdraw the report?';

  @override
  String get placesWithdrawBody =>
      'The report will be deleted and will no longer be visible to anyone.';

  @override
  String get placesWithdrawConfirm => 'Withdraw';

  @override
  String get placesWithdrawnSnack => 'Report withdrawn.';

  @override
  String get placesVoteConfirmedSnack => 'Thank you, confirmation recorded.';

  @override
  String get placesVoteDeniedSnack => 'Thank you, recorded.';

  @override
  String placesRatedSnack(int stars) {
    return 'Rating recorded: $stars out of 5.';
  }

  @override
  String get placesReportsInactiveSnack => 'Reports are not active right now.';

  @override
  String get placesReportProblemTitle => 'What is wrong with this place?';

  @override
  String get placesReportAlreadyKnown =>
      'It was already reported: your report counts as confirmation.';

  @override
  String get placesReportSent =>
      'Report sent. It will take effect when other users confirm it.';

  @override
  String get placesSheetPendingQuestion => 'Does this place really exist here?';

  @override
  String get placesSheetNotPublicWrite => 'Not a public area? Contact us';

  @override
  String placesSheetClosedReported(String progress) {
    return 'Reported as closed ($progress)';
  }

  @override
  String get placesSheetClosedQuestion => 'Has it really closed?';

  @override
  String placesSheetOpeningHours(String hours) {
    return 'Listed hours: $hours';
  }

  @override
  String get placesActionCall => 'Call';

  @override
  String get placesActionDirections => 'Directions';

  @override
  String get placesActionWebsite => 'Website';

  @override
  String get placesDisclaimerCommunity =>
      'Place reported by users: check before visiting.';

  @override
  String get placesDisclaimerClinic =>
      'In an emergency, call before leaving: hours and contact details come from open data and are not verified by VetApp.';

  @override
  String get placesDisclaimerGeneric =>
      'Hours and contact details come from open data and are not verified by VetApp.';

  @override
  String placesSourceLine(String source) {
    return 'Source: $source';
  }

  @override
  String placesAlsoIn(String sources) {
    return 'Also listed in: $sources';
  }

  @override
  String get placesReportProblemAction => 'Report a problem';

  @override
  String get placesBannerWithdrawing => 'Withdrawing report…';

  @override
  String get placesBannerYouReported =>
      'You reported it: confirmations from other users are needed.';

  @override
  String get placesBannerConfirmedSaving => 'You confirmed it. Saving…';

  @override
  String get placesBannerConfirmedChange =>
      'You confirmed it. You can change your mind.';

  @override
  String get placesBannerDeniedSaving =>
      'You indicated it is not correct. Saving…';

  @override
  String get placesBannerDeniedChange =>
      'You indicated it is not correct. You can change your mind.';

  @override
  String get placesBannerWithdrawButton => 'Withdraw my report';

  @override
  String get placesBannerConfirm => 'Confirm';

  @override
  String get placesBannerDeny => 'That\'s not right';

  @override
  String placesVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String placesRatingAverage(String average, String votes) {
    return 'Community rating: $average out of 5 · $votes';
  }

  @override
  String get placesRatingNone => 'Community rating: no votes yet';

  @override
  String placesRatingBelowThreshold(String votes) {
    return 'Community rating: $votes · the average appears after 3 votes';
  }

  @override
  String placesRateStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Give $count stars',
      one: 'Give 1 star',
    );
    return '$_temp0';
  }

  @override
  String placesRatingSaving(int stars) {
    return 'Your rating: $stars out of 5. Saving…';
  }

  @override
  String placesRatingYours(int stars) {
    return 'Your rating: $stars out of 5. Tap a star to change it.';
  }

  @override
  String get placesRatingPrompt =>
      'How is this dog park? Tap a star to rate it.';

  @override
  String get placesExpiryToday => 'Expires today if nobody confirms it.';

  @override
  String placesExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days if nobody confirms it.',
      one: 'Expires in 1 day if nobody confirms it.',
    );
    return '$_temp0';
  }

  @override
  String get placesProblemClosed => 'It has closed or no longer exists';

  @override
  String get placesProblemDuplicate => 'It duplicates another place';

  @override
  String get placesProblemWrongPosition => 'The position is wrong';

  @override
  String get placesCategoryVeterinary => 'Veterinarians';

  @override
  String get placesCategoryShop => 'Shops';

  @override
  String get placesCategoryDogPark => 'Dog parks';

  @override
  String get placesCategoryShelter => 'Shelters and adoptions';

  @override
  String get placesCategoryAssociation => 'Associations';

  @override
  String get placesCategoryGrooming => 'Groomers';

  @override
  String get placesCategoryHotel => 'Pet boarding';

  @override
  String get placesCategorySchool => 'Training';

  @override
  String get placesCategoryPetSitting => 'Pet sitter';

  @override
  String get placesCategoryBreeder => 'Breeders';

  @override
  String get placesCategoryOther => 'Other services';

  @override
  String get placesTypeVeterinary => 'Veterinarian';

  @override
  String get placesTypeGrooming => 'Grooming';

  @override
  String get placesTypeShop => 'Pet shop';

  @override
  String get placesTypeSchool => 'Training';

  @override
  String get placesTypePetSitting => 'Pet sitter';

  @override
  String get placesTypeBreeder => 'Breeder';

  @override
  String get placesTypeHotel => 'Pet boarding';

  @override
  String get placesTypeDogPark => 'Dog park';

  @override
  String get placesTypeShelter => 'Animal shelter';

  @override
  String get placesTypeAssociation => 'Animal association';

  @override
  String get placesTypeOther => 'Pet service';

  @override
  String get placesHours247 => 'Listed as open 24 hours';

  @override
  String get placesHoursHolidays => 'Public holidays';

  @override
  String get placesHoursClosed => 'closed';

  @override
  String get placesSourcesTitle => 'Data sources';

  @override
  String get placesSourcesIntro =>
      'Radar places come from open datasets. Each card states its source. Hours and contact details may be outdated.';

  @override
  String get placesSourcesNoContact =>
      'Found incorrect data? Use \"Report a problem\" on the place\'s card.';

  @override
  String placesSourcesContact(String email) {
    return 'Found incorrect data, or are you the owner and want a card corrected or removed? Write to $email.';
  }

  @override
  String placesSourceLicense(String license) {
    return 'License: $license';
  }

  @override
  String placesSourceVersion(String release, String date) {
    return 'Version $release, imported on $date';
  }

  @override
  String get placesSourceLicenseLink => 'License and terms';

  @override
  String get placesSourceOsmDescription =>
      'A free map maintained by volunteers. It provides dog parks and some veterinarians, shops and other services, with details entered by volunteers.';

  @override
  String get placesSourceOvertureDescription =>
      'An open business directory. It provides veterinarians, groomers, shops, boarding and trainers not listed in OpenStreetMap.';

  @override
  String get placesSourceBolognaDescription =>
      'Official list of dog exercise areas from the Municipality of Bologna.';

  @override
  String get placesSourceTorinoDescription =>
      'Official list of dog parks from the City of Turin.';

  @override
  String get placesSourceMilanoDescription =>
      'Official list of dog parks from the Municipality of Milan.';

  @override
  String get placesSourceBolognaAttribution =>
      'Municipality of Bologna, dog exercise areas (opendata.comune.bologna.it), CC BY 4.0 license';

  @override
  String get placesSourceTorinoAttribution =>
      'Municipality of Turin, dog parks (aperto.comune.torino.it), CC BY 4.0 license, 2019 data';

  @override
  String get placesSourceMilanoAttribution =>
      'Municipality of Milan, dog park locations (dati.comune.milano.it), CC BY 4.0 license. Includes processed CC BY 3.0 data from dati.gov.it';

  @override
  String get placesSourceLicenseCcBy =>
      'Creative Commons Attribution 4.0 (CC BY 4.0)';

  @override
  String get placesSourceUsersName => 'VetApp users';

  @override
  String get placesSourceUsersDescription =>
      'Places reported by users and confirmed by other users.';

  @override
  String get placesSourceUsersAttribution => 'Reported by VetApp users';

  @override
  String placesMapTitle(String radius) {
    return 'Map · $radius';
  }

  @override
  String placesMapClusterSemantics(int count) {
    return '$count nearby places';
  }

  @override
  String placesMapMarkerPending(String category, String label) {
    return '$category, awaiting confirmation: $label';
  }

  @override
  String placesMapMarker(String category, String label) {
    return '$category: $label';
  }

  @override
  String get placesReportTitle => 'Report a missing place';

  @override
  String get placesReportUnavailable =>
      'Reports are not available right now. Try again later.';

  @override
  String get placesReportWhatIs => 'What is it?';

  @override
  String get placesReportNameOptional => 'Name (optional)';

  @override
  String get placesReportNameLabel => 'Name on the sign';

  @override
  String get placesReportNameHelper =>
      'Name only: no phone numbers, addresses or people\'s names.';

  @override
  String get placesReportWhere => 'Where is it?';

  @override
  String get placesReportMapHint =>
      'Move the map until the marker is on the place. The address is derived from the position.';

  @override
  String get placesReportSubmit => 'Send report';

  @override
  String placesReportFootnote(int days) {
    return 'The report is visible to everyone as awaiting confirmation. Other users must confirm it. It is automatically deleted if nobody confirms it within $days days. You can withdraw it anytime from its card. Your name is not shown.';
  }

  @override
  String placesReportSentExpiry(int days) {
    return 'Report sent. It will be deleted if nobody confirms it within $days days.';
  }

  @override
  String get placesRulesTitle => 'Before reporting or voting';

  @override
  String get placesRulesCheckbox =>
      'I have read the rules and will report or vote in good faith.';

  @override
  String get placesRulesAccept => 'Accept';

  @override
  String get placesRulesFallback =>
      'Report only what you have verified in person. For businesses, enter only the name on the sign, without phone numbers, private addresses or other people\'s data. Reports remain pending until other users confirm them. False or repeated reports may lead to account suspension. Reports and votes are published without your name.';

  @override
  String get placesErrSignedOutContribute => 'Sign in to report or vote.';

  @override
  String get placesErrOperationFailed =>
      'The operation could not be completed. Try again.';

  @override
  String get placesErrTimeout => 'The request took too long. Try again.';

  @override
  String get placesErrNotConfigured =>
      'Preview without backend: displayed places are example data.';

  @override
  String get placesErrSignedOut => 'Sign in to see nearby pet services.';

  @override
  String get placesErrPreparing =>
      'Services for this area are still being prepared. Try again shortly.';

  @override
  String get placesErrSessionExpired =>
      'Your session is no longer valid: sign out and back in to see nearby services.';

  @override
  String get placesErrLoadFailed =>
      'I couldn\'t load nearby services. Try again.';

  @override
  String get placesBackendRulesRequired =>
      'Accept the reporting and voting rules before reporting or voting.';

  @override
  String get placesBackendReportClosed =>
      'This report has already been closed.';

  @override
  String get placesBackendReportExpired =>
      'This report expired because nobody confirmed it.';

  @override
  String get placesBackendOwnReportVote =>
      'You cannot confirm your own report.';

  @override
  String get placesBackendKindNotActive => 'This report type is not active.';

  @override
  String get placesBackendCategoryNotReportable =>
      'This category cannot be reported.';

  @override
  String get placesBackendTargetRequired =>
      'Specify the place the report concerns.';

  @override
  String get placesBackendPendingUseDeny =>
      'For a place awaiting confirmation, use \"That\'s not right\" on its card.';

  @override
  String get placesBackendAlreadyReported =>
      'You have already submitted this report.';

  @override
  String placesBackendDailyLimit(int count) {
    return 'You can submit at most $count reports per day.';
  }

  @override
  String get placesBackendReportNotFound => 'Report not found.';

  @override
  String get placesBackendWithdrawOwnOnly =>
      'You can only withdraw your own report.';

  @override
  String get placesBackendWithdrawClosed =>
      'This report is already closed and cannot be withdrawn.';

  @override
  String get placesBackendRatingsOff => 'Ratings are not active.';

  @override
  String get placesBackendRatePublicOnly =>
      'Only public dog parks can be rated.';

  @override
  String get placesBackendDogParkNotFound => 'Dog park not found.';

  @override
  String get placesBackendContributionsOff =>
      'Reporting and voting are not active yet.';

  @override
  String get placesBackendNameRequired =>
      'Enter the business name as it appears on the sign.';

  @override
  String placesBackendNameTooLong(int count) {
    return 'The name can contain at most $count characters.';
  }

  @override
  String get placesBackendNameNoContacts =>
      'Do not include phone numbers, email addresses or websites in the name.';

  @override
  String get placesBackendNameBlockedWords =>
      'The name contains prohibited words.';

  @override
  String get eventsTitle => 'Events';

  @override
  String get eventsSearching => 'Finding events…';

  @override
  String get eventsAllRegions => 'All regions';

  @override
  String get eventsAllTypes => 'All types';

  @override
  String get eventsReset => 'Reset';

  @override
  String get eventsDisclaimer =>
      'Dates and places may change: always check the organizer\'s website.';

  @override
  String get eventsPickRegionTitle => 'Region';

  @override
  String get eventsPickTypeTitle => 'Event type';

  @override
  String get eventsPickDatesHelp => 'Choose a period';

  @override
  String get eventsPickDatesSave => 'Apply';

  @override
  String get eventsStatusCancelled => 'Cancelled';

  @override
  String get eventsStatusPostponed => 'Postponed';

  @override
  String eventsOrganizedBy(String name) {
    return 'Organized by $name';
  }

  @override
  String get eventsSuggestAction => 'Suggest an event';

  @override
  String get eventsSuggestTitle => 'Suggest an event';

  @override
  String get eventsSuggestIntro =>
      'Do you know of a pet fair or event that is not listed here? Fill in the details: we will check it on the organizer\'s website before publishing it.';

  @override
  String get eventsSuggestPrivacy =>
      'Only write information about the event: no personal names, emails or phone numbers.';

  @override
  String get eventsSuggestFieldTitle => 'Event name';

  @override
  String get eventsSuggestFieldType => 'Event type';

  @override
  String get eventsSuggestFieldDates => 'Dates';

  @override
  String get eventsSuggestPickDates => 'Choose dates';

  @override
  String get eventsSuggestFieldCity => 'City';

  @override
  String get eventsSuggestFieldProvince => 'Province (code, e.g. MO)';

  @override
  String get eventsSuggestFieldVenue =>
      'Venue, for example the fairground (optional)';

  @override
  String get eventsSuggestFieldLink => 'Link to the event page';

  @override
  String get eventsSuggestRequired => 'Required field';

  @override
  String get eventsSuggestInvalidLink =>
      'Enter an address starting with http:// or https://';

  @override
  String get eventsSuggestInvalidProvince => 'Use the two-letter code';

  @override
  String get eventsSuggestSend => 'Send suggestion';

  @override
  String get eventsSuggestThanks =>
      'Thank you! We will check the event before publishing it.';

  @override
  String get eventsSuggestNeedLogin => 'Sign in to suggest an event.';

  @override
  String get eventsSuggestLimit =>
      'You have already sent your suggestions for today: try again tomorrow.';

  @override
  String get eventsSuggestError =>
      'I couldn\'t send the suggestion. Try again later.';

  @override
  String get eventsLoadError =>
      'I can\'t load events. Check your connection and try again.';

  @override
  String eventsWindowDefault(int days) {
    return 'Next $days days';
  }

  @override
  String get eventsEmptyFiltered =>
      'No events match these filters in the selected period';

  @override
  String eventsEmptyDefault(int days) {
    return 'No events in the next $days days';
  }

  @override
  String get eventsEmptyPeriod => 'No events in the selected period';

  @override
  String get eventsCountryOnlyNote =>
      'We only show events from your country, the one of the language you picked in the app.';

  @override
  String get eventsLevelLocal => 'Local';

  @override
  String get eventsLevelProvincial => 'Provincial';

  @override
  String get eventsLevelRegional => 'Regional';

  @override
  String get eventsLevelNational => 'National';

  @override
  String get eventsLevelInternational => 'International';

  @override
  String get eventsTypePetFair => 'Pet fair';

  @override
  String get eventsTypeDogShow => 'Dog show';

  @override
  String get eventsTypeBreedGathering => 'Breed gathering';

  @override
  String get eventsTypeCatShow => 'Cat show';

  @override
  String get eventsTypeWorkTrial => 'Working trial';

  @override
  String get eventsTypeDogSport => 'Dog sports';

  @override
  String get eventsTypeAdoptionDay => 'Adoption day';

  @override
  String get eventsTypeShelterOpenDay => 'Shelter open day';

  @override
  String get eventsTypeMicrochipDay => 'Microchip day';

  @override
  String get eventsTypeVaccinationCampaign => 'Vaccination campaign';

  @override
  String get eventsTypeGroupWalk => 'Group walk';

  @override
  String get eventsTypeCourseSeminar => 'Course or seminar';

  @override
  String get eventsTypeMarket => 'Market';

  @override
  String get eventsTypeCharityEvent => 'Charity event';

  @override
  String get eventsTypeAquariumExpo => 'Aquarium keeping';

  @override
  String get eventsTypeReptileExpo => 'Terrarium keeping';

  @override
  String get eventsTypeBirdShow => 'Bird keeping';

  @override
  String get eventsTypeEquestrian => 'Equestrian';

  @override
  String get eventsTypeOther => 'Other';

  @override
  String get localActivitiesKindEvent => 'Event';

  @override
  String get localActivitiesKindService => 'Service';

  @override
  String get localEventsTitle => 'Near me';

  @override
  String get localEventsLocating => 'Finding your location…';

  @override
  String get localEventsSearchingAround =>
      'Finding what is around you. The first search in an area may take up to a minute.';

  @override
  String get localEventsConsentTitle => 'Use your location?';

  @override
  String get localEventsConsentBody =>
      'VetApp uses your phone\'s location only while you use the app to show nearby services. You can enter an address instead.';

  @override
  String get localEventsConsentChooseAddress => 'Choose an address';

  @override
  String get localEventsConsentAllow => 'Allow';

  @override
  String get localEventsReportMissing => 'Report a missing place';

  @override
  String get localEventsServicesHeader => 'Services in the area';

  @override
  String get localEventsClinicsHeader => 'Clinics and practices';

  @override
  String get localEventsNoClinics => 'No clinics found with these filters.';

  @override
  String get localEventsNoServices => 'No services found with these filters.';

  @override
  String get localEventsAll => 'All';

  @override
  String get localEventsMapFullscreen => 'Open the map full screen';

  @override
  String get localEventsNoLocationTitle => 'Set a location';

  @override
  String get localEventsNoLocationBody =>
      'Your location is needed to show what is nearby. Allow location access or enter your home address in Settings → Location.';

  @override
  String get localEventsOpenSettings => 'Open Settings';

  @override
  String localEventsSearchingRadius(String radius) {
    return 'Finding services within $radius. The first search in an area may take up to a minute.';
  }

  @override
  String get localEventsSearchingNearby =>
      'Finding services in your area. The first search may take a few seconds.';

  @override
  String get localEventsCoverageLimited =>
      'The data for services in this area is still being prepared: you may see few places or wait longer.';

  @override
  String get localEventsCoverageUnsupported =>
      'The radar does not cover this country yet: you only see what OpenStreetMap knows, with no other checks.';

  @override
  String get localEventsStale =>
      'I couldn\'t update services in this area. You are seeing the last available data, which may be outdated.';

  @override
  String localEventsPartialRadius(String radius) {
    return 'Services are currently available within $radius. Try again shortly for the full radius.';
  }

  @override
  String get localEventsShowLess => 'Show less';

  @override
  String localEventsShowAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String localEventsShowAllCategory(String category, int count) {
    return 'Show all: $category ($count)';
  }

  @override
  String localEventsCategoryNone(String category, String radius) {
    return '$category: none within $radius';
  }

  @override
  String localEventsCategoryCount(String category, int count) {
    return '$category ($count)';
  }

  @override
  String localEventsSectionExpand(String section) {
    return 'Open $section';
  }

  @override
  String localEventsSectionCollapse(String section) {
    return 'Close $section';
  }

  @override
  String localEventsCallTooltip(String name) {
    return 'Call $name';
  }

  @override
  String localEventsDirectionsTooltip(String name) {
    return 'Directions to $name';
  }

  @override
  String get remindersRelativeToday => 'Today';

  @override
  String get remindersRelativeTomorrow => 'tomorrow';

  @override
  String get remindersRelativeYesterday => 'yesterday';

  @override
  String remindersRelativeInDays(int days) {
    return 'in $days days';
  }

  @override
  String remindersRelativeDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get remindersKindEvent => 'Event';

  @override
  String remindersKindRecurring(String interval, String end) {
    return 'Recurring · $interval$end';
  }

  @override
  String remindersCourseStarts(String day) {
    return 'Starts $day';
  }

  @override
  String get remindersCourseCompleted => 'Completed';

  @override
  String remindersCourseDayOf(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String remindersKindCourse(int days) {
    return 'Course · $days days';
  }

  @override
  String remindersKindCourseWithTimes(int days, String times) {
    return 'Course · $days days · $times';
  }

  @override
  String remindersIntervalEveryDays(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: '$value days',
      one: '1 day',
    );
    return 'every $_temp0';
  }

  @override
  String remindersIntervalEveryMonths(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: '$value months',
      one: '1 month',
    );
    return 'every $_temp0';
  }

  @override
  String remindersEndAfterTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count occurrences',
      one: '1 occurrence',
    );
    return ' · for $_temp0';
  }

  @override
  String remindersEndUntilDate(String date) {
    return ' · until $date';
  }

  @override
  String get remindersMenuTooltip => 'Reminder options';

  @override
  String get remindersMenuMarkDone => 'Mark as done';

  @override
  String get remindersDeleteConfirmTitle => 'Delete this reminder?';

  @override
  String remindersDeleteConfirmBody(String title) {
    return '\"$title\" will be permanently deleted.';
  }

  @override
  String get remindersErrorPetNotSynced =>
      'The pet profile is not synced with the server. Fix it before creating reminders.';

  @override
  String get remindersErrorSaveFailed =>
      'The reminder could not be saved. Try again.';

  @override
  String get remindersErrorDeleteFailed =>
      'I couldn\'t delete the reminder. Try again.';

  @override
  String get petNewsTitle => 'News';

  @override
  String get petNewsLoading => 'Loading news...';

  @override
  String get petNewsEmpty => 'No news available for this category right now.';

  @override
  String get petNewsEmptyLocal =>
      'There is no news in your language and country right now. We don\'t show news from other countries.';

  @override
  String get petNewsCategoryAll => 'All';

  @override
  String get petNewsCategoryDog => 'Dog';

  @override
  String get petNewsCategoryCat => 'Cat';

  @override
  String get petNewsCategorySmallMammals => 'Small mammals';

  @override
  String get petNewsCategoryBird => 'Bird';

  @override
  String get petNewsCategoryReptiles => 'Reptiles and amphibians';

  @override
  String get petNewsCategoryFish => 'Fish';

  @override
  String get petNewsCategoryOther => 'Other';

  @override
  String get petNewsCategoryGeneral => 'General';

  @override
  String get profileLogoutDialogTitle => 'Sign out';

  @override
  String get profileLogoutDialogBody =>
      'Do you want to sign out of this account?';

  @override
  String get profileGuestName => 'Guest';

  @override
  String get profileNoActiveSession => 'No active session';

  @override
  String profileSummaryBody(String pets) {
    return 'Owner profile linked to $pets and ready for the responsive web app.';
  }

  @override
  String profilePetCount(int count) {
    return '$count pets';
  }

  @override
  String get profileContactsTitle => 'Contacts';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePhoneLabel => 'Phone';

  @override
  String get profilePhoneNotSet => 'Not specified';

  @override
  String get profileCityLabel => 'City';

  @override
  String get profileCityNotSet => 'Not specified';

  @override
  String get profileEveningThemeTitle => 'Evening theme';

  @override
  String get profileEveningThemeBody =>
      'Preview of a softer palette for evening use.';

  @override
  String get profileAccountStatusTitle => 'Account status';

  @override
  String get profileSessionLabel => 'Session';

  @override
  String get profileSessionActive => 'Active';

  @override
  String get profilePrivacyLabel => 'Privacy';

  @override
  String get profilePrivacyUpdated => 'Updated';

  @override
  String get profileSupportLabel => 'Support';

  @override
  String get profileSupportAvailable => 'Available';

  @override
  String get profileSettingsButton => 'Settings';

  @override
  String get profileLogoutButton => 'Sign out';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileIntro =>
      'Owner details, preferences and account information in one place for the responsive web app.';

  @override
  String get profileRoadmapTitle => 'Next steps';

  @override
  String get profileRoadmapBody =>
      'Here we can expand consent preferences and account linking without changing the web flow.';

  @override
  String get activitiesTitle => 'Activities';

  @override
  String get activitiesSubtitle => 'Everything around life with your pets.';

  @override
  String get activitiesNewsSubtitle => 'Stories and updates about pets.';

  @override
  String get activitiesNearbyTitle => 'Near me';

  @override
  String get activitiesNearbySubtitle =>
      'Nearby veterinarians, shops and dog parks.';

  @override
  String get activitiesEventsTitle => 'Events';

  @override
  String get activitiesEventsSubtitle =>
      'Fairs, shows and pet initiatives in your country.';

  @override
  String get activitiesGalleryTitle => 'Gallery';

  @override
  String get activitiesGallerySubtitle =>
      'Collect photos and memories of your pets.';

  @override
  String get activitiesMarketplaceTitle => 'Second-hand marketplace';

  @override
  String get activitiesMarketplaceSubtitle =>
      'Buy, sell and exchange pet items.';

  @override
  String get activitiesPetFriendTitle => 'Pet friend';

  @override
  String get activitiesPetFriendSubtitle =>
      'Meetups and companionship for pets and owners.';

  @override
  String get activitiesComingSoonBadge => 'Coming soon';

  @override
  String get activitiesPetFriendDescription =>
      'Meet other owners and organize outings for pets with similar temperaments.';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersSubtitle =>
      'Vaccines, treatments and visits to keep track of.';

  @override
  String get remindersCreateButton => 'Create';

  @override
  String get remindersLoadingTitle => 'Loading reminders';

  @override
  String get remindersLoadingBody =>
      'Reading dates, recurrences and owner notes.';

  @override
  String get remindersSyncErrorLabel => 'Sync error';

  @override
  String get remindersSyncErrorTitle => 'Reminder synchronization failed.';

  @override
  String get remindersSyncErrorBody =>
      'The demo source is still available. Try again when the network is back.';

  @override
  String get remindersEmptyLabel => 'No reminders';

  @override
  String get remindersEmptyTitle => 'The reminder list is empty.';

  @override
  String get remindersEmptyBody =>
      'Create the first vaccine or treatment reminder to stay on track.';

  @override
  String get remindersNoMatchForFilters => 'No reminders match these filters.';

  @override
  String get remindersFilterAll => 'All';

  @override
  String get remindersFilterEvents => 'Events';

  @override
  String get remindersFilterCourses => 'Courses';

  @override
  String get remindersViewList => 'List';

  @override
  String get remindersViewCalendar => 'Calendar';

  @override
  String get remindersNothingThisDay => 'No activity on this day.';

  @override
  String get remindersTodayCapitalized => 'Today';

  @override
  String get remindersEditTitle => 'Edit reminder';

  @override
  String get remindersEditSubtitle => 'Update the type, date and notes.';

  @override
  String get remindersDosePickerHelp => 'Dose time';

  @override
  String get remindersDateRequired => 'Enter a date.';

  @override
  String get remindersDateInvalid => 'Invalid date (dd/mm/yyyy).';

  @override
  String get remindersFormKind => 'Type';

  @override
  String get remindersFormTitleLabel => 'Title';

  @override
  String get remindersFormTitleHint => 'E.g. Vaccine booster';

  @override
  String remindersFormTitleHintWithPet(String petName) {
    return 'E.g. $petName\'s vaccine booster';
  }

  @override
  String get remindersTitleRequired => 'Enter a title.';

  @override
  String get remindersFieldDate => 'Date';

  @override
  String get remindersFieldNextDue => 'Next due date';

  @override
  String get remindersFieldStartDate => 'Start date';

  @override
  String get remindersFieldTime => 'Time';

  @override
  String get remindersRepeats => 'Repeats';

  @override
  String get remindersCustomNumberHint => 'Number';

  @override
  String get remindersRecurrenceEndLabel => 'Recurrence ends';

  @override
  String get remindersOccurrenceCountHint => 'Number of times';

  @override
  String get remindersLastDate => 'Last date';

  @override
  String get remindersCourseDuration => 'Course duration';

  @override
  String get remindersDoseTimes => 'Dose times';

  @override
  String get remindersAddDoseTime => 'Add time';

  @override
  String get remindersNoDoseTimesNote =>
      'Without times, you receive one daily alert at 9:00 am.';

  @override
  String get remindersFormNote => 'Note';

  @override
  String get remindersFormNoteHint => 'E.g. Bring the health record';

  @override
  String get remindersKindOptionRecurring => 'Recurring';

  @override
  String get remindersKindOptionCourse => 'Course';

  @override
  String get remindersDatePlaceholder => 'dd/mm/yyyy';

  @override
  String get remindersPreset7Days => '7 days';

  @override
  String get remindersPreset30Days => '30 days';

  @override
  String get remindersPreset6Months => '6 months';

  @override
  String get remindersPreset12Months => '12 months';

  @override
  String get remindersPresetCustom => 'Custom';

  @override
  String get remindersEndAlways => 'Always';

  @override
  String get remindersEndAfterN => 'For N times';

  @override
  String get remindersEndUntil => 'Until a date';

  @override
  String get remindersUnitDays => 'Days';

  @override
  String get remindersUnitMonths => 'Months';

  @override
  String get remindersOneDayLess => 'One day less';

  @override
  String remindersDurationRange(int min, int max) {
    return 'From $min to $max days.';
  }

  @override
  String remindersDurationUnit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get remindersOneDayMore => 'One day more';

  @override
  String get remindersNotFoundTitle => 'Reminder not found';

  @override
  String get remindersNotFoundSubtitle =>
      'This reminder is no longer available.';

  @override
  String get remindersNotFoundLabel => 'Not found';

  @override
  String get remindersNotFoundPanelTitle => 'No reminder to show.';

  @override
  String get remindersNotFoundBody =>
      'It may have been deleted or may not be synchronized yet.';

  @override
  String get remindersBackToList => 'Back to list';

  @override
  String get remindersDetailTitle => 'Reminder details';

  @override
  String get remindersDetailSubtitle => 'Reminder type, date and notes.';

  @override
  String get remindersNoNote => 'No notes added.';

  @override
  String get remindersSummaryTitle => 'Reminder summary';

  @override
  String get remindersSummaryPet => 'Pet';

  @override
  String get remindersSummaryStatus => 'Status';

  @override
  String get remindersDeleteButton => 'Delete reminder';

  @override
  String get remindersLoadingLabel => 'Uploading';

  @override
  String get remindersWait => 'Wait';

  @override
  String get remindersCreateTitle => 'Create reminder';

  @override
  String remindersCreateTitleForPet(String petName) {
    return 'New reminder for $petName';
  }

  @override
  String get remindersCreateSubtitle => 'Choose the type, date and details.';

  @override
  String get settingsUnitSystemMetricLabel => 'Metric';

  @override
  String get settingsUnitSystemUkLabel => 'United Kingdom';

  @override
  String get settingsUnitSystemUsLabel => 'USA';

  @override
  String get settingsUnitSystemMetricDescription => 'km, kg, °C, liters';

  @override
  String get settingsUnitSystemUkDescription => 'miles, pounds, °C, liters';

  @override
  String get settingsUnitSystemUsDescription => 'miles, pounds, °F, US gallons';

  @override
  String settingsVolumeLiters(int liters) {
    return '$liters liters';
  }

  @override
  String get settingsUnitLitersName => 'Liters';

  @override
  String get settingsTextSizeSmall => 'Small';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsTextSizeExtraLarge => 'Extra large';

  @override
  String get settingsLocationPickerTitle => 'Choose on the map';

  @override
  String get settingsLocationPickerHint =>
      'Move the map until the marker is at the correct point, then confirm.';

  @override
  String get settingsLocationPickerConfirm => 'Confirm this point';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNumericDatePattern => 'dd/MM/yyyy';

  @override
  String get settingsGuestInitial => 'G';

  @override
  String get settingsGuestName => 'Guest';

  @override
  String get settingsNoActiveSession => 'No active session';

  @override
  String get settingsSectionSubscription => 'Subscription';

  @override
  String get settingsSubscriptionAndPayments => 'Subscription and payments';

  @override
  String settingsTrialExpiresOn(String date) {
    return 'Trial · expires $date';
  }

  @override
  String get settingsSectionPushNotifications => 'Push notifications';

  @override
  String get settingsNotificationsToggle => 'Notifications';

  @override
  String get settingsSectionLayout => 'Layout';

  @override
  String get settingsLayoutWeeksTitle => 'Weeks shown on Home';

  @override
  String get settingsLayoutWeeksSubtitle =>
      'How many weeks to show in the Home calendar.';

  @override
  String get settingsLayoutWeekStartTitle => 'Week starts on';

  @override
  String get settingsLayoutChatTextSizeTitle => 'Chat text size';

  @override
  String get settingsLayoutChatTextSizePreview =>
      'This is how chat messages will look.';

  @override
  String get settingsLayoutUnitsTitle => 'Measurement unit';

  @override
  String get settingsSectionPhotosVideos => 'Photos and videos';

  @override
  String get settingsGallerySaveTitle => 'Save photos to the gallery';

  @override
  String get settingsGallerySaveSubtitle =>
      'Photos and videos taken with the app camera are copied to the \"VetApp\" album on your phone.';

  @override
  String get settingsSectionLocation => 'Location';

  @override
  String get settingsLocationIntro =>
      'Used to personalize events and news for your area.';

  @override
  String get settingsLocationReferenceTitle => 'Reference location';

  @override
  String get settingsLocationModeCurrent => 'Current';

  @override
  String get settingsLocationModeHome => 'Home';

  @override
  String get settingsLocationCurrentTitle => 'Current location';

  @override
  String get settingsLocationDetecting => 'Detecting location…';

  @override
  String get settingsLocationCurrentNotSet => 'Not set yet';

  @override
  String get settingsLocationRefresh => 'Update';

  @override
  String get settingsLocationHomeTitle => 'Usual residence';

  @override
  String get settingsLocationHomeNotSet => 'Not set';

  @override
  String get settingsLocationSet => 'Set';

  @override
  String get settingsLocationErrorPermissionDenied =>
      'Location permission denied. Enable it in your device settings to use your current location.';

  @override
  String get settingsLocationErrorServiceDisabled =>
      'Location services are disabled on this device.';

  @override
  String get settingsLocationErrorTimeout =>
      'The location could not be detected in time. Try again.';

  @override
  String get settingsLocationErrorUnsupported =>
      'Location is unavailable on this device or browser.';

  @override
  String get settingsSectionPermissions => 'Permissions and consents';

  @override
  String get settingsConsentsUnavailable => 'Currently unavailable';

  @override
  String get settingsConsentsTapToRetry => 'Tap to retry';

  @override
  String get settingsConsentTerms => 'Terms of service';

  @override
  String get settingsConsentPrivacy => 'Privacy policy';

  @override
  String get settingsConsentMarketingEmail => 'Marketing emails';

  @override
  String get settingsConsentAnalytics => 'Usage analytics';

  @override
  String settingsConsentAccepted(String version, String date) {
    return 'Accepted v$version on $date';
  }

  @override
  String get settingsConsentToConfirm => 'To be confirmed';

  @override
  String get settingsClinicalConsentSection => 'Medical records and assistant';

  @override
  String get settingsPrivacyPolicyFullTitle => 'Full privacy policy';

  @override
  String get settingsPrivacyPolicyFullSubtitle =>
      'Read, download or share the text';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsHelpCenterTitle => 'Help center';

  @override
  String get settingsHelpCenterComingSoon =>
      'Frequently asked questions and quick guides will soon be available here.';

  @override
  String get settingsContactUs => 'Contact us';

  @override
  String get settingsContactUnavailable =>
      'Support contact details are unavailable right now. Try again later.';

  @override
  String settingsContactWriteTo(String email) {
    return 'Write to $email with any questions.';
  }

  @override
  String get settingsRateApp => 'Rate the app';

  @override
  String get settingsRateAppThanks => 'Thank you for your support! ⭐';

  @override
  String get settingsSectionInfo => 'Info';

  @override
  String get settingsDataSourcesTitle => 'Data sources';

  @override
  String get settingsDataSourcesSubtitle =>
      'Where Radar place information comes from';

  @override
  String get settingsAppVersion => 'App version';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get settingsLogoutConfirmBody =>
      'Do you want to sign out of this account?';

  @override
  String get settingsHomeCountryDefault => 'Italy';

  @override
  String get settingsHomeAddressNotFound =>
      'This address could not be found. Check the details and try again.';

  @override
  String get settingsHomeAddressOrType => 'Or enter the address:';

  @override
  String get settingsHomeAddressStreet => 'Address';

  @override
  String get settingsHomeAddressStreetRequired => 'Enter the address';

  @override
  String get settingsHomeAddressPostalCode => 'Postal code';

  @override
  String get settingsHomeAddressPostalCodeRequired => 'Enter the postal code';

  @override
  String get settingsHomeAddressCity => 'City';

  @override
  String get settingsHomeAddressCityRequired => 'Enter the city';

  @override
  String get settingsHomeAddressCountry => 'Country';

  @override
  String get settingsHomeAddressCountryRequired => 'Enter the country';

  @override
  String get settingsHomeAddressSearching => 'Searching…';

  @override
  String get notificationsCategoryReminders => 'Visits and vaccines';

  @override
  String get notificationsCategoryMedicines => 'Medication times';

  @override
  String get notificationsCategoryBirthdays => 'Birthdays';

  @override
  String get notificationsChannelRemindersName => 'Reminders';

  @override
  String get notificationsChannelRemindersDescription =>
      'Visits, vaccines and other reminders';

  @override
  String get notificationsChannelMedicinesName => 'Medication';

  @override
  String get notificationsChannelBirthdaysDescription => 'Pets\' birthdays';

  @override
  String notificationsReminderTodayBody(String petName, String time) {
    return '$petName · today at $time';
  }

  @override
  String notificationsReminderTomorrowTitle(String title) {
    return 'Tomorrow: $title';
  }

  @override
  String notificationsReminderTomorrowBody(String petName, String time) {
    return '$petName · at $time';
  }

  @override
  String notificationsMedicineTitle(String petName) {
    return 'Medication for $petName';
  }

  @override
  String notificationsMedicineDayBody(String title, int day, int total) {
    return '$title · day $day of $total';
  }

  @override
  String notificationsMedicineDoseBody(String title, String time) {
    return '$title · dose at $time';
  }

  @override
  String notificationsBirthdayTitle(String petName) {
    return 'Happy birthday, $petName!';
  }

  @override
  String notificationsBirthdayBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Turns $count today.',
      one: 'Turns 1 today.',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBirthdayUpcomingTitle => 'Birthday coming up';

  @override
  String notificationsBirthdayUpcomingBody(String petName) {
    return '$petName\'s birthday is in one week: think about a gift.';
  }

  @override
  String walksPageTitle(String petName) {
    return 'Walk with $petName';
  }

  @override
  String get walksStatusInProgress => 'Walk in progress';

  @override
  String get walksStatusPaused => 'Walk paused';

  @override
  String get walksStatDistance => 'Distance';

  @override
  String get walksStatDuration => 'Duration';

  @override
  String get walksStatPhotos => 'Photos';

  @override
  String walksStatPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pauses',
      one: 'Pause',
    );
    return '$_temp0';
  }

  @override
  String get walksActionPause => 'Pause';

  @override
  String get walksActionResume => 'Resume';

  @override
  String get walksActionFinish => 'Finish';

  @override
  String get walksActionSaving => 'Saving…';

  @override
  String get walksActionStarting => 'Starting…';

  @override
  String get walksActionStart => 'Start walk';

  @override
  String get walksWaitingForGps => 'Waiting for an accurate GPS signal…';

  @override
  String get walksCameraTooltip => 'Photo or video';

  @override
  String get walksCaptureTakePhoto => 'Take photo';

  @override
  String get walksCaptureRecordVideo => 'Record video';

  @override
  String walksCaptureVideoLimit(int seconds) {
    return 'Up to $seconds seconds';
  }

  @override
  String get walksErrorOtherPetActive =>
      'A walk with another pet is already in progress. Finish it before starting a new one.';

  @override
  String get walksErrorLocationUnavailable =>
      'I can\'t detect your location, which is needed to track the route. Check location permissions and try again.';

  @override
  String get walksPhotoPinSemantics => 'Photo taken during the walk';

  @override
  String walksPhotoCaption(String date) {
    return 'Walk on $date';
  }

  @override
  String get walksMapUnavailable => 'Route unavailable';

  @override
  String get walksNoMoveTitle => 'Walk without movement';

  @override
  String get walksNoMoveBody =>
      'No movement was recorded, so the walk was not saved.';

  @override
  String get walksNoMoveAck => 'Got it';

  @override
  String get walksFavoritePromptTitle => 'Save as a favorite?';

  @override
  String walksFavoritePromptBody(String distance) {
    return 'Add this walk ($distance) to your favorites ⭐?';
  }

  @override
  String get walksFavoriteNoThanks => 'No, thanks';

  @override
  String get walksFavoriteSave => 'Save ⭐';

  @override
  String get walksFavoriteEvictTitle => 'You already have 5 favorites';

  @override
  String get walksFavoriteEvictBody =>
      'Choose which favorite to remove to make room for the walk you just finished.';

  @override
  String get walksSheetOpen => 'Open walk';

  @override
  String get walksSheetFinish => 'Finish walk';

  @override
  String walksConfirmFinishTitle(String petName) {
    return 'Finish the walk with $petName?';
  }

  @override
  String get walksConfirmFinishBody =>
      'The route recorded so far will be saved.';

  @override
  String get walksSavingSnackbar => 'Saving walk…';

  @override
  String get walksNotifPermTitle => 'See your walk in notifications';

  @override
  String get walksNotifPermBody =>
      'During the walk, VetApp shows an ongoing notification with time and distance. You can pause or finish from there, even with your phone in your pocket. Notification permission is required to see it.\n\nThe walk is recorded even if you choose \"Not now\".';

  @override
  String get walksNotifPermNotNow => 'Not now';

  @override
  String get walksNotifPermAllow => 'Allow';

  @override
  String walksNotifTitleWithPet(String petName) {
    return 'Walk with $petName';
  }

  @override
  String walksNotifTitleWithPetPaused(String petName) {
    return 'Walk with $petName · paused';
  }

  @override
  String get walksNotifTitleNoPetPaused => 'Walk in progress · paused';

  @override
  String walksNotifRunningText(String distance) {
    return '$distance traveled';
  }

  @override
  String get walksNotifFallbackPausedText =>
      'Tracking is paused. Resume in the app whenever you want.';

  @override
  String get walksNotifFallbackRunningText =>
      'VetApp is tracking your walk route.';

  @override
  String get walksNotifChannelName => 'Walk tracking';

  @override
  String get walksSyncFailed => 'Sync failed: change saved only on this phone';

  @override
  String get walksFavoriteSaveFailed =>
      'I couldn\'t save the favorite. Try again.';

  @override
  String get walksFavoriteRemoveFailed =>
      'I couldn\'t remove the favorite. Try again.';

  @override
  String get walksDeleteFailed => 'I couldn\'t delete the walk. Try again.';

  @override
  String get walksHighlightLongest => 'Longest';

  @override
  String get walksHighlightMostDurable => 'Longest duration';

  @override
  String get walksHighlightFavorite => 'Favorite';

  @override
  String walksDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String walksDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get walksBadgeLabelFirstWalk => 'First walk 🐾';

  @override
  String walksBadgeLabelDistance(String km) {
    return '$km km walked 🏃';
  }

  @override
  String walksBadgeLabelWalkCount(String count) {
    return '$count walks 🎖️';
  }

  @override
  String get walksBadgeLabel30Min => '30 minutes in one walk ⏱️';

  @override
  String get walksBadgeLabel1Hour => 'One hour in one walk ⏱️';

  @override
  String get walksBadgeLabelStreak => '7 days in a row 🔥';

  @override
  String get walksBadgeLabelDawn => 'Dawn walk 🌅';

  @override
  String get walksBadgeLabelNight => 'Night walk 🌙';

  @override
  String get walksBadgeEarnedBarrier => 'Badge unlocked';

  @override
  String walksBadgeEarnedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'New badges unlocked!',
      one: 'New badge unlocked!',
    );
    return '$_temp0';
  }

  @override
  String get walksBadgeEarnedAction => 'Hooray!';

  @override
  String get walksBadgeGalleryTitle => 'Badges';

  @override
  String get walksBadgeNameFirstWalk => 'First walk';

  @override
  String get walksBadgeDescFirstWalk =>
      'Complete your first walk with this pet.';

  @override
  String walksBadgeNameKm(String km) {
    return '$km km';
  }

  @override
  String walksBadgeDescKm(String km) {
    return 'Walk $km km in total.';
  }

  @override
  String get walksBadgeName30Min => '30 minutes';

  @override
  String get walksBadgeDesc30Min => 'Take a walk lasting at least 30 minutes.';

  @override
  String get walksBadgeName1Hour => 'One hour';

  @override
  String get walksBadgeDesc1Hour => 'Take a walk lasting at least one hour.';

  @override
  String get walksBadgeNameStreak => '7 days in a row';

  @override
  String get walksBadgeDescStreak => 'Go for a walk on 7 consecutive days.';

  @override
  String get walksBadgeNameDawn => 'Dawn walk';

  @override
  String get walksBadgeDescDawn =>
      'Take a walk between 5 and 7 in the morning.';

  @override
  String get walksBadgeNameNight => 'Night walk';

  @override
  String get walksBadgeDescNight => 'Take a walk after 9 pm or before 5 am.';

  @override
  String walksBadgeNameWalkCount(String count) {
    return '$count walks';
  }

  @override
  String walksBadgeDescWalkCount(String count) {
    return 'Complete $count walks in total.';
  }

  @override
  String get settingsAccountProfile => 'Your profile';

  @override
  String get settingsAccountChangeEmail => 'Change email';

  @override
  String get settingsAccountChangePassword => 'Change password';

  @override
  String get settingsAccountSupport => 'Support';

  @override
  String get settingsAccountSupportSubtitle => 'Send us an email';

  @override
  String get settingsAccountDelete => 'Delete account';

  @override
  String get settingsAccountDeleteSubtitle =>
      'Delete your account and all your data';

  @override
  String accountSupportSubject(String version) {
    return 'VetApp support (version $version)';
  }

  @override
  String accountSupportBody(String version) {
    return 'Write your message here:\n\n\n\n—\nApp version: $version';
  }

  @override
  String get accountProfileTitle => 'Your profile';

  @override
  String get accountProfileFirstName => 'First name';

  @override
  String get accountProfileLastName => 'Last name';

  @override
  String get accountProfilePhone => 'Phone (optional)';

  @override
  String get accountProfilePhoneHint => '+39 333 1234567';

  @override
  String get accountProfileFirstNameRequired => 'Enter your first name.';

  @override
  String get accountProfileLastNameRequired => 'Enter your last name.';

  @override
  String get accountProfilePhoneInvalid => 'Invalid phone number.';

  @override
  String get accountProfilePhotoAdd => 'Add photo';

  @override
  String get accountProfilePhotoChange => 'Change photo';

  @override
  String get accountProfilePhotoRemove => 'Remove photo';

  @override
  String get accountProfilePhotoFailed =>
      'I couldn\'t upload the photo. Try again.';

  @override
  String get accountProfileSaved => 'Profile saved.';

  @override
  String get accountProfileEmailLabel => 'Email';

  @override
  String get accountProfileEmailChange => 'Change';

  @override
  String get accountEmailTitle => 'Change email';

  @override
  String get accountEmailCurrent => 'Current email';

  @override
  String get accountEmailNew => 'New email';

  @override
  String get accountEmailSame => 'This is your current email.';

  @override
  String get accountEmailSubmit => 'Change email';

  @override
  String accountEmailApplied(String email) {
    return 'Email updated: from now on you sign in with $email.';
  }

  @override
  String accountEmailConfirmationSent(String email) {
    return 'We\'ve sent a confirmation link to the new address ($email). Open it to complete the change: until then you keep signing in with your current email.';
  }

  @override
  String get accountPasswordTitle => 'Change password';

  @override
  String get accountPasswordCurrent => 'Current password';

  @override
  String get accountPasswordCurrentRequired => 'Enter your current password.';

  @override
  String get accountPasswordCurrentWrong =>
      'The current password is not correct.';

  @override
  String get accountPasswordNew => 'New password';

  @override
  String get accountPasswordRepeat => 'Repeat the new password';

  @override
  String get accountPasswordSameAsOld =>
      'The new password must be different from the current one.';

  @override
  String get accountPasswordSubmit => 'Change password';

  @override
  String get accountPasswordChanged => 'Password changed.';

  @override
  String get accountDeleteTitle => 'Delete account';

  @override
  String get accountDeleteWarningTitle => 'This action is permanent';

  @override
  String get accountDeleteWarningBody =>
      'The following will be deleted forever: your pets\' profiles, your chats with the assistant, reminders, walks, photos and videos, uploaded reports and documents, measurements, consents, your saved location and the listings you posted on the marketplace. We will not be able to recover them.';

  @override
  String get accountDeletePasswordLabel => 'Enter your password to confirm';

  @override
  String get accountDeletePasswordRequired => 'Enter your password.';

  @override
  String get accountDeleteUnderstood =>
      'I understand: my account and all my data will be deleted forever.';

  @override
  String get accountDeleteSubmit => 'Permanently delete my account';

  @override
  String get accountDeleteFailed =>
      'I couldn\'t delete the account. Try again in a moment; if the problem continues, contact support.';

  @override
  String get accountDeleteDone => 'Your account has been deleted.';

  @override
  String get accountDeleteReauth =>
      'For security, a recent confirmation is needed: enter your password again and retry.';

  @override
  String get petsValueSexUnknownShort => 'Don\'t know';

  @override
  String get petsValueActivitySedentary => 'Sedentary';

  @override
  String get petsValueActivityNormal => 'Normal';

  @override
  String get petsValueActivityActive => 'Active';

  @override
  String get petsFormSterilized => 'Spayed / neutered';

  @override
  String get petsFormMicrochipLabel => 'Microchip no.';

  @override
  String get petsFormMicrochipHint => '15 digits';

  @override
  String get petsFormMicrochipInvalid => 'A microchip has 15 digits.';

  @override
  String get petsFormCoatColorLabel => 'Coat color';

  @override
  String get petsFormCoatColorHint => 'E.g. black, brown';

  @override
  String get petsFormColorLabel => 'Color';

  @override
  String get petsFormColorHint => 'E.g. green, yellow';

  @override
  String get petsFormBodyConditionLabel => 'Body condition';

  @override
  String get petsFormBodyConditionHint => 'Select body condition';

  @override
  String get petsFormActivityLabel => 'Activity';

  @override
  String get petsFormActivityHint => 'Select activity';

  @override
  String get petsFormDogSizeLabelShort => 'Size';

  @override
  String get petsWizardNext => 'Continue';

  @override
  String get petsWizardConfirm => 'Confirm';

  @override
  String get petsWizardBack => 'Back';

  @override
  String petsWizardStepSemantics(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get petsWizardStep1Title => 'What kind of pet is it?';

  @override
  String get petsWizardStep1Subtitle =>
      'Choose the animal type and its breed or species';

  @override
  String get petsWizardStep2Title => 'Tell us about your pet';

  @override
  String get petsWizardStep2Subtitle => 'What is its name?';

  @override
  String get petsWizardStep3Title => 'General information';

  @override
  String get petsWizardStep3Subtitle => 'Tell us a bit more about your pet';

  @override
  String get petsWizardStep4Title => 'Final details';

  @override
  String get petsWizardStep4Subtitle => 'Almost done!';

  @override
  String get petsWizardPureBred => 'Purebred';

  @override
  String get petsWizardMixedBreed => 'Mixed breed';

  @override
  String get petsWizardDoneTitle => 'Profile created!';

  @override
  String petsWizardDoneMessage(String name) {
    return 'Congratulations, $name has been added to your pets.';
  }

  @override
  String get petsWizardAddAnother => 'Add another pet';

  @override
  String get petsWizardFinish => 'Done';

  @override
  String get petsDataTitle => 'Pet details';

  @override
  String get petsDataSectionIdentity => 'Identity';

  @override
  String get petsDataSectionPhysical => 'Physical traits';

  @override
  String get petsDataSectionDocuments => 'Documents';

  @override
  String get petsDataNotProvided => 'Not provided';

  @override
  String get petsDataMicrochipMissing => 'Missing';

  @override
  String get petsDataMicrochipMissingDogHint =>
      'A microchip is mandatory for dogs.';

  @override
  String get petsDataAddMicrochip => 'Add microchip';

  @override
  String get petsDataWeightLabel => 'Weight';

  @override
  String get petsDataSummarySterilized => 'neutered';

  @override
  String get monitoringTitle => 'Monitoring';

  @override
  String get petsDetailTabMonitoring => 'Monitoring';

  @override
  String get monitoringBcsGuideTitle => 'Assess body condition';

  @override
  String monitoringBcsGuideIntro(String petName) {
    return 'Weight alone is not enough to tell whether an animal is thin or well-covered: you need to feel it and look at it. Follow the three steps and choose the description that looks most like $petName.';
  }

  @override
  String get monitoringBcsStepTouch => 'Feel the ribs';

  @override
  String get monitoringBcsStepAbove => 'Look from above';

  @override
  String get monitoringBcsStepSide => 'Look from the side';

  @override
  String get monitoringBcsViewAbove => 'From above';

  @override
  String get monitoringBcsViewSide => 'From the side';

  @override
  String get monitoringBcsRowTouch => 'By touch';

  @override
  String get monitoringBcsRowAbove => 'From above';

  @override
  String get monitoringBcsRowSide => 'From the side';

  @override
  String monitoringBcsGuideScale(String range, String max) {
    return 'On the source scale: $range out of $max';
  }

  @override
  String monitoringBcsGuideChoose(String level) {
    return 'Choose: $level';
  }

  @override
  String get monitoringBcsGuideClear => 'Remove the assessment';

  @override
  String get monitoringBcsGuideDisclaimer =>
      'This is a rough guide and does not replace a veterinarian\'s examination. The illustrations are schematic and original to VetApp.';

  @override
  String monitoringBcsGuideSource(String source) {
    return 'Source: $source';
  }

  @override
  String get monitoringBcsGuideTipFurry =>
      'In dogs and cats with long or thick coats, looks can be deceiving: always feel the ribs. For example, a fluffy dog can look well-covered even if it is thin underneath, while a puppy or a very muscular dog can look \"too fit\" but be at a healthy weight.';

  @override
  String get monitoringBcsGuideTipRabbit =>
      'In rabbits, fur hides the bones: always feel the back, ribs and hips, because looking is not enough. Thick fur can make a normal rabbit look fat, or a thin one look normal.';

  @override
  String get monitoringBcsGuideAdviceTitle => 'Tips';

  @override
  String monitoringBcsGuideAdvice1(String petName) {
    return 'Weigh $petName every 2-4 weeks and write the weight down: slow changes are easier to spot in numbers than by eye.';
  }

  @override
  String get monitoringBcsGuideAdvice2 =>
      'Always assess the same way: same place, animal standing and calm, same three steps (touch, view from above, view from the side).';

  @override
  String get monitoringBcsGuideAdvice3 =>
      'If in doubt, ask the veterinarian: body condition is easier to learn when someone shows you how to feel it.';

  @override
  String get monitoringBcsGuideCaveatRabbit =>
      'For rabbits this scale is less reliable: two people can give different scores to the same rabbit. If in doubt, ask the veterinarian.';

  @override
  String get monitoringBcsSourceDog =>
      'criteria of the WSAVA Global Nutrition Committee 9-point scale for dogs (Laflamme, 1997), summarized in our own words and reduced to 5 levels by VetApp. Not official WSAVA material.';

  @override
  String get monitoringBcsSourceCat =>
      'criteria of the WSAVA Global Nutrition Committee 9-point scale for cats (Laflamme, 1997; validated by Bjornvad et al., 2011), summarized in our own words and reduced to 5 levels by VetApp. Not official WSAVA material.';

  @override
  String get monitoringBcsSourceRabbit =>
      '5-level Rabbit Size-O-Meter from the PFMA (Pet Food Manufacturers\' Association), summarized in our own words. Agreement between assessors is limited (Halck et al., Veterinary Record, 2025).';

  @override
  String get monitoringBcsNotAssessed => 'Not assessed';

  @override
  String get monitoringBcsAssess => 'Assess body condition';

  @override
  String get monitoringBcsReassess => 'Reassess body condition';

  @override
  String get monitoringBcsGuideDog1Touch =>
      'Ribs, spine and pelvic bones can be felt right under the skin: there is practically no fat and the muscles look reduced. For example: it is like touching the knuckles of a clenched fist, where the bone is right under the skin with nothing in between.';

  @override
  String get monitoringBcsGuideDog1Above =>
      'Very narrow waist, hollowed out behind the ribs; the hip and back bones stick out. Seen from above, the body looks like a very thin hourglass.';

  @override
  String get monitoringBcsGuideDog1Side =>
      'Belly tucked in a lot, the profile rises sharply toward the hind legs. The ribs may be visible even from a distance, especially in short-haired dogs.';

  @override
  String get monitoringBcsGuideDog2Touch =>
      'The ribs can be felt without pressing, with very little fat over them, and are sometimes visible. For example: running your hand along the side, you feel each rib as a separate step, without the soft layer found in a dog at a healthy weight.';

  @override
  String get monitoringBcsGuideDog2Above =>
      'Clearly marked waist behind the ribs; the pelvic bones begin to show. To find it, look at the standing dog from above: the body narrows noticeably after the last rib.';

  @override
  String get monitoringBcsGuideDog2Side =>
      'Belly clearly tucked in. In growing puppies and very athletic dogs this look can be normal: compare it with how the ribs feel.';

  @override
  String get monitoringBcsGuideDog3Touch =>
      'The ribs are easy to feel under a thin layer of fat, without having to press. For example: it is like touching the back of an open, flat hand, where you feel the tendons under the skin but not a sharp bone.';

  @override
  String get monitoringBcsGuideDog3Above =>
      'A waist is visible behind the ribs. To find it, look at the standing dog from above: between the chest and the pelvis the body narrows slightly, without bulging at the sides.';

  @override
  String get monitoringBcsGuideDog3Side =>
      'The belly rises gently from the chest toward the hind legs. In long-haired or thick-coated dogs the shape is easier to judge by running your hands over the body than by looking.';

  @override
  String get monitoringBcsGuideDog4Touch =>
      'The ribs are felt with some effort: the layer of fat is thicker, especially over the back near the tail. For example: it is like touching the back of the hand when the fingers are in a loose fist, with more flesh over the bones.';

  @override
  String get monitoringBcsGuideDog4Above =>
      'The waist is barely visible or no longer visible. From above the body looks almost rectangular, without narrowing behind the ribs.';

  @override
  String get monitoringBcsGuideDog4Side =>
      'The belly tuck is barely noticeable. Be careful not to mistake thick fur for fat: always feel the ribs before deciding.';

  @override
  String get monitoringBcsGuideDog5Touch =>
      'The ribs cannot be felt, or only with firm pressure, under a thick layer of fat; it builds up over the back and the base of the tail. For example: it is like looking for bones in the palm of the hand, where under the skin there is only a thick soft pad.';

  @override
  String get monitoringBcsGuideDog5Above =>
      'No waist: the body is broad and rounded, and the belly may look swollen. From above the dog looks wider at the hips than at the chest.';

  @override
  String get monitoringBcsGuideDog5Side =>
      'No tuck: the belly is round or hangs down. A dog like this tires quickly and struggles to move: talk to the veterinarian.';

  @override
  String get monitoringBcsGuideCat1Touch =>
      'Ribs and spine can be felt with no layer of fat at all; in short-haired cats the ribs are visible. For example: it is like touching the knuckles of a clenched fist, bones right under the skin.';

  @override
  String get monitoringBcsGuideCat1Above =>
      'Very narrow waist behind the ribs. Seen from above, the body is thin like a very narrow hourglass.';

  @override
  String get monitoringBcsGuideCat1Side =>
      'Belly tucked in a lot, no fat pad under the belly. The muscles along the spine also look reduced.';

  @override
  String get monitoringBcsGuideCat2Touch =>
      'The ribs are easy to feel with very little fat, and the vertebrae of the back are noticeable. For example: running your hand along the side, you feel each rib separately, without the soft veil found in a cat at a healthy weight.';

  @override
  String get monitoringBcsGuideCat2Above =>
      'Waist clearly visible behind the ribs. Look at it from above while it is standing: the body narrows noticeably after the rib cage.';

  @override
  String get monitoringBcsGuideCat2Side =>
      'Belly slightly tucked in, with little or no fat pad. In older cats thinness can hide a health problem: if it is recent, ask the veterinarian.';

  @override
  String get monitoringBcsGuideCat3Touch =>
      'The ribs can be felt with a thin veil of fat over them. For example: it is like touching the back of an open, flat hand, where you feel the tendons under the skin but not a sharp bone.';

  @override
  String get monitoringBcsGuideCat3Above =>
      'Well-proportioned body, with a visible waist behind the ribs. From above the cat has a slight hourglass shape, without bulging at the sides.';

  @override
  String get monitoringBcsGuideCat3Side =>
      'The belly line is soft, with just a hint of a fat pad. In long-haired cats the shape is easier to judge with your hands than with your eyes.';

  @override
  String get monitoringBcsGuideCat4Touch =>
      'The ribs are harder to feel: you have to press a little, because there is more fat. For example: it is like touching the back of the hand when the fingers are in a loose fist, with more flesh over the bones.';

  @override
  String get monitoringBcsGuideCat4Above =>
      'The waist is barely visible or not visible. From above the body looks almost rectangular, without narrowing behind the ribs.';

  @override
  String get monitoringBcsGuideCat4Side =>
      'Rounded belly, with a moderate fat pad under the belly. When the cat walks the pad swings slightly: in cats at a healthy weight it is barely noticeable.';

  @override
  String get monitoringBcsGuideCat5Touch =>
      'The ribs cannot be felt under a thick layer of fat, which also builds up over the back and, in extreme cases, on the face and legs. For example: it is like looking for bones in the palm of the hand, where there is only a soft pad.';

  @override
  String get monitoringBcsGuideCat5Above =>
      'No waist: the body is broad. From above it looks wider at the hips than at the chest.';

  @override
  String get monitoringBcsGuideCat5Side =>
      'Round or sagging belly, with an obvious fat pad. The cat struggles to groom the fur on its back and hindquarters: talk to the veterinarian.';

  @override
  String get monitoringBcsGuideRabbit1Touch =>
      'Spine, ribs and hip bones stick out and feel sharp under the skin: there is no fat and the muscles are reduced. For example: it is like touching the knuckles of a clenched fist, with the bone right under the skin.';

  @override
  String get monitoringBcsGuideRabbit1Above =>
      'Hollowed back and sides, the hip bones are noticeable. From above the body looks narrow and angular.';

  @override
  String get monitoringBcsGuideRabbit1Side =>
      'The hindquarters (rump) are hollow, curving inward. A rabbit this thin should see the veterinarian soon.';

  @override
  String get monitoringBcsGuideRabbit2Touch =>
      'Ribs, spine and hips are easy to feel, with little fat over them. For example: running your hand along the back, you feel the vertebrae as a row of small, well-defined bumps.';

  @override
  String get monitoringBcsGuideRabbit2Above =>
      'Slim sides, with the spine barely covered. From above the body is narrower than you would expect.';

  @override
  String get monitoringBcsGuideRabbit2Side =>
      'The hindquarters are flat. In long-haired rabbits the fur hides thinness: always feel the back and hips.';

  @override
  String get monitoringBcsGuideRabbit3Touch =>
      'Ribs and spine are easy to feel but have soft, rounded contours, not sharp ones. For example: it is like touching the back of an open, flat hand, where you feel the bones under soft skin.';

  @override
  String get monitoringBcsGuideRabbit3Above =>
      'Well-proportioned body, with no bulges at the sides. From above the outline is even, from neck to tail.';

  @override
  String get monitoringBcsGuideRabbit3Side =>
      'The hindquarters are flat and the belly does not stick out. The back forms a smooth curve and looks neither hollow nor puffy.';

  @override
  String get monitoringBcsGuideRabbit4Touch =>
      'You have to press to feel the ribs, spine and hips: there are layers of fat. For example: it is like touching the back of the hand when the fingers are in a loose fist, with more flesh over the bones.';

  @override
  String get monitoringBcsGuideRabbit4Above =>
      'Full, rounded sides. From above the body looks wider than you would expect.';

  @override
  String get monitoringBcsGuideRabbit4Side =>
      'The hindquarters are rounded. You can often also see a slight bulge under the chin, especially in females.';

  @override
  String get monitoringBcsGuideRabbit5Touch =>
      'The spine and hips are hard to feel and the ribs cannot be felt at all, under a thick layer of fat. For example: it is like looking for bones in the palm of the hand, where there is only a soft pad.';

  @override
  String get monitoringBcsGuideRabbit5Above =>
      'Broad, full body, with the hindquarters sticking out. From above the outline is very rounded.';

  @override
  String get monitoringBcsGuideRabbit5Side =>
      'The belly hangs down and forms a fat pad under the belly. A rabbit this well-covered struggles to clean itself and can have skin problems under the tail: ask the veterinarian.';

  @override
  String get monitoringAddMeasurement => 'New measurement';

  @override
  String get monitoringCurrentWeight => 'Current weight';

  @override
  String monitoringMeasuredOn(String date) {
    return 'Measured on $date';
  }

  @override
  String monitoringChangeSince(String change, String date) {
    return '$change since $date';
  }

  @override
  String get monitoringEmptyTitle => 'No measurements yet';

  @override
  String monitoringEmptyBody(String petName) {
    return 'Record $petName\'s weight to follow how it changes over time.';
  }

  @override
  String get monitoringBcsTitle => 'Body condition';

  @override
  String monitoringBcsAsOf(String date) {
    return 'From the measurement of $date';
  }

  @override
  String get monitoringBcsNone =>
      'Tap \"Assess body condition\" to see it here.';

  @override
  String get monitoringBcsVeryThin => 'Very thin';

  @override
  String get monitoringBcsThin => 'Thin';

  @override
  String get monitoringBcsNormal => 'Normal';

  @override
  String get monitoringBcsSlightlyOverweight => 'Slightly overweight';

  @override
  String get monitoringBcsOverweight => 'Overweight';

  @override
  String get monitoringChartTitleWeight => 'Weight trend';

  @override
  String get monitoringChartTitleGrowth => 'Growth curve';

  @override
  String monitoringChartGrowthHint(String petName) {
    return '$petName\'s weight by age, without reference curves: only their own measurements.';
  }

  @override
  String get monitoringChartSinglePoint =>
      'Add another measurement to see the trend.';

  @override
  String monitoringChartGrowthHintReference(String petName) {
    return '$petName\'s weight by age, compared with the reference area.';
  }

  @override
  String get monitoringGrowthLegend =>
      'Dark area: 25th to 75th percentile (the middle half). Light area: 3rd to 97th. Dashed line: median.';

  @override
  String monitoringGrowthSourcePuppy(String sizeLabel) {
    return 'Reference: healthy dogs with an adult weight of $sizeLabel. Derived from CC BY 4.0 data by Salt C. et al., PLOS ONE 2017; these are not the official WALTHAM curves.';
  }

  @override
  String get monitoringGrowthSourceKitten =>
      'Reference: intact domestic shorthair kittens (USA). Derived from CC BY 3.0 data by Salt C. et al., PLOS ONE 2022; these are not the official WALTHAM curves.';

  @override
  String monitoringGrowthDisclaimer(String petName) {
    return 'This is a reference, not a diagnosis: every animal grows at its own pace. If $petName\'s weight often falls outside the area or changes suddenly, talk to the veterinarian.';
  }

  @override
  String monitoringGrowthExpectedAdult(String range) {
    return 'Expected adult weight: $range';
  }

  @override
  String get monitoringGrowthChange => 'Change';

  @override
  String get monitoringGrowthPromptTitle => 'Show the reference area';

  @override
  String monitoringGrowthPromptBody(String petName) {
    return 'To compare $petName with healthy puppies we need the weight they will have as an adult: choose the most likely range (breed, parents, veterinarian).';
  }

  @override
  String get monitoringGrowthPromptButton => 'Choose adult weight';

  @override
  String get monitoringGrowthNoReferenceHeavy =>
      'There are no reliable reference curves for dogs over 40 kg: very large breeds grow in very different ways.';

  @override
  String monitoringGrowthSheetTitle(String petName) {
    return '$petName\'s expected adult weight';
  }

  @override
  String monitoringGrowthClassUnder(String max) {
    return 'Less than $max';
  }

  @override
  String monitoringGrowthClassBetween(String min, String max) {
    return '$min to $max';
  }

  @override
  String monitoringGrowthClassOver(String min) {
    return 'More than $min';
  }

  @override
  String get monitoringGrowthClassUnknown => 'I don\'t know: no reference area';

  @override
  String get monitoringAxisAgeMonths => 'Age (months)';

  @override
  String monitoringAxisWeight(String unit) {
    return 'Weight ($unit)';
  }

  @override
  String monitoringTooltipAge(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get monitoringHistoryTitle => 'History';

  @override
  String get monitoringDeleteTitle => 'Delete the measurement?';

  @override
  String monitoringDeleteMessage(String date) {
    return 'The weight from $date will be removed from the history.';
  }

  @override
  String get monitoringSheetTitleNew => 'New measurement';

  @override
  String get monitoringSheetTitleEdit => 'Edit measurement';

  @override
  String get monitoringFieldDate => 'Date';

  @override
  String get monitoringFieldWeightKg => 'Weight (kg)';

  @override
  String get monitoringFieldWeightLb => 'Weight (lb)';

  @override
  String get monitoringFieldWeightHintKg => 'E.g. 10.5';

  @override
  String get monitoringFieldWeightHintLb => 'E.g. 22.5';

  @override
  String get monitoringFieldNote => 'Note (optional)';

  @override
  String get monitoringErrorWeight =>
      'Enter a valid weight, greater than zero.';

  @override
  String get monitoringErrorDateFuture => 'The date cannot be in the future.';

  @override
  String monitoringErrorDateBirth(String petName) {
    return 'The date is earlier than $petName\'s birth.';
  }

  @override
  String get monitoringSaveFailed =>
      'I couldn\'t save the measurement: try again.';

  @override
  String get monitoringDeleteFailed =>
      'I couldn\'t delete the measurement: try again.';

  @override
  String get monitoringActivityTitle => 'Activity';

  @override
  String monitoringActivitySubtitle(String petName) {
    return '$petName\'s walks over the last few weeks.';
  }

  @override
  String get monitoringActivityDistance => 'Distance';

  @override
  String get monitoringActivityTime => 'Time';

  @override
  String get monitoringActivityStatWalks => 'Walks';

  @override
  String monitoringActivityEmpty(String petName) {
    return 'No walks in the last 3 months. Record a walk from the Walks tab to see $petName\'s activity here.';
  }

  @override
  String monitoringActivityWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String monitoringActivityWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count walks',
      one: '1 walk',
    );
    return '$_temp0';
  }

  @override
  String get medCatVisit => 'Visits';

  @override
  String get medCatExam => 'Tests';

  @override
  String get medCatVaccine => 'Vaccines';

  @override
  String get medCatTherapy => 'Therapies';

  @override
  String get medCatDocument => 'Documents';

  @override
  String get medCatCondition => 'Conditions';

  @override
  String get medCatVisitOne => 'Visit';

  @override
  String get medCatExamOne => 'Test';

  @override
  String get medCatVaccineOne => 'Vaccine';

  @override
  String get medCatTherapyOne => 'Therapy';

  @override
  String get medCatDocumentOne => 'Document';

  @override
  String medCatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recorded',
      one: '1 recorded',
    );
    return '$_temp0';
  }

  @override
  String get medSubCheckup => 'Check-up';

  @override
  String get medSubSpecialist => 'Specialist visit';

  @override
  String get medSubFirstVisit => 'First visit';

  @override
  String get medSubEmergency => 'Emergency';

  @override
  String get medSubPostSurgery => 'Post-surgery check';

  @override
  String get medSubBlood => 'Blood tests';

  @override
  String get medSubUrine => 'Urine test';

  @override
  String get medSubStool => 'Stool test';

  @override
  String get medSubXray => 'X-ray';

  @override
  String get medSubUltrasound => 'Ultrasound';

  @override
  String get medSubAntiparasitic => 'Antiparasitic';

  @override
  String get medSubMedication => 'Medication';

  @override
  String get medSubOther => 'Other';

  @override
  String get medAddTitle => 'What do you want to add?';

  @override
  String get medAddAction => 'Add';

  @override
  String get medCatConditionOne => 'Condition';

  @override
  String get medHistoryTitle => 'History';

  @override
  String get medHistorySubtitle => 'All recorded events, month by month.';

  @override
  String get medHistoryEmpty => 'No events recorded';

  @override
  String get medHistoryPrevMonth => 'Previous month';

  @override
  String get medHistoryNextMonth => 'Next month';

  @override
  String medHistoryDayTitle(String date) {
    return 'Events on $date';
  }

  @override
  String get medHistoryDayEmpty => 'No events on this day';

  @override
  String medHistoryDayA11y(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'no events',
    );
    return '$date: $_temp0';
  }

  @override
  String get medHistorySend => 'Send history';

  @override
  String get medHistorySendAll => 'Full history (PDF)';

  @override
  String get medHistorySendAllSubtitle => 'A PDF with all events in date order';

  @override
  String get medHistorySendFiles => 'Individual files';

  @override
  String get medHistoryPreparing => 'Preparing the PDF…';

  @override
  String get medHistoryExportFailed =>
      'I couldn\'t prepare the PDF. Try again.';

  @override
  String get medHistoryConditionsMissing =>
      'I couldn\'t read the conditions: they are not in the PDF.';

  @override
  String medPdfTitle(String petName) {
    return 'Clinical history of $petName';
  }

  @override
  String get medPdfSpeciesBreed => 'Species and breed';

  @override
  String get medPdfBirthDate => 'Date of birth';

  @override
  String get medPdfExportDate => 'Export date';

  @override
  String get medPdfColDate => 'Date';

  @override
  String get medPdfColCategory => 'Category';

  @override
  String get medPdfColTitle => 'Title';

  @override
  String get medPdfColNotes => 'Notes';

  @override
  String get medPdfNoDate => 'No date';

  @override
  String get medPdfEmpty => 'No events recorded.';

  @override
  String medPdfPage(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String get medPdfConditionOngoing => 'Ongoing';

  @override
  String get medPdfConditionResolved => 'Resolved';

  @override
  String medPdfConditionResolvedOn(String date) {
    return 'Resolved on $date';
  }

  @override
  String medPdfConditionTherapy(String therapy) {
    return 'Therapy: $therapy';
  }

  @override
  String get medNewVisit => 'New visit';

  @override
  String get medNewExam => 'New test';

  @override
  String get medNewVaccine => 'New vaccine';

  @override
  String get medNewTherapy => 'New therapy';

  @override
  String get medNewDocument => 'New document';

  @override
  String get medNewCondition => 'New condition';

  @override
  String get medEmptyVisitTitle => 'No visits recorded';

  @override
  String medEmptyVisitBody(String petName) {
    return 'Add $petName\'s visits to keep check-ups and the veterinarian\'s instructions in one place.';
  }

  @override
  String get medEmptyVisitAction => 'Add the first visit';

  @override
  String get medEmptyExamTitle => 'No tests recorded';

  @override
  String medEmptyExamBody(String petName) {
    return 'Upload $petName\'s tests, such as blood tests or X-rays, to always have them at hand.';
  }

  @override
  String get medEmptyExamAction => 'Add the first test';

  @override
  String get medEmptyVaccineTitle => 'No vaccines recorded';

  @override
  String medEmptyVaccineBody(String petName) {
    return 'Keep $petName\'s vaccines and boosters here, with the date of each dose.';
  }

  @override
  String get medEmptyVaccineAction => 'Add the first vaccine';

  @override
  String get medEmptyTherapyTitle => 'No therapies recorded';

  @override
  String medEmptyTherapyBody(String petName) {
    return 'Note down $petName\'s therapies: medicines, antiparasitics and ongoing or past treatments.';
  }

  @override
  String get medEmptyTherapyAction => 'Add the first therapy';

  @override
  String get medEmptyDocumentTitle => 'No documents uploaded';

  @override
  String medEmptyDocumentBody(String petName) {
    return 'Upload $petName\'s reports, certificates and other documents to share them with the veterinarian.';
  }

  @override
  String get medEmptyDocumentAction => 'Add the first document';

  @override
  String get medEmptyConditionTitle => 'No conditions recorded';

  @override
  String medEmptyConditionBody(String petName) {
    return 'Note down $petName\'s illnesses, ongoing or already resolved, with dates and therapy.';
  }

  @override
  String get medEmptyConditionAction => 'Add the first condition';

  @override
  String get medFieldTitle => 'Title';

  @override
  String get medFieldCategory => 'Category';

  @override
  String get medFieldType => 'Type';

  @override
  String get medFieldTypeNone => 'Not specified';

  @override
  String get medFieldEventDate => 'Date';

  @override
  String get medFieldNotes => 'Notes';

  @override
  String get medFieldNotesHint => 'Write an optional note.';

  @override
  String get medFieldFile => 'Attachment';

  @override
  String get medAttachAdd => 'Add file';

  @override
  String get medAttachChange => 'Change file';

  @override
  String get medEditDetailsTitle => 'Edit details';

  @override
  String get medTitleRequired => 'Enter a title or attach a file.';

  @override
  String get medDateInvalid => 'Invalid date (dd/mm/yyyy).';

  @override
  String get medDatePlaceholder => 'dd/mm/yyyy';

  @override
  String medSuggestHint(String category) {
    return 'Judging by the title, it looks like: $category. Classify it that way?';
  }

  @override
  String get medSuggestApply => 'Yes, classify';

  @override
  String medSuggestPill(String category) {
    return 'Maybe: $category';
  }

  @override
  String medActionClassifyAs(String category) {
    return 'Classify as $category';
  }

  @override
  String get medActionEditDetails => 'Edit details';

  @override
  String get medCondName => 'Name of the condition';

  @override
  String get medCondNameRequired => 'Enter the name of the condition.';

  @override
  String get medCondStarted => 'Start date';

  @override
  String get medCondStatus => 'Status';

  @override
  String get medCondOngoing => 'Ongoing';

  @override
  String get medCondResolved => 'Resolved';

  @override
  String get medCondEnded => 'End date';

  @override
  String get medCondEndBeforeStart =>
      'The end date is earlier than the start date.';

  @override
  String get medCondTherapy => 'Therapy';

  @override
  String get medCondTherapyHint => 'Medicines, doses, duration…';

  @override
  String get medCondAttachment => 'Prescription or documents';

  @override
  String medCondSince(String date) {
    return 'Since $date';
  }

  @override
  String medCondPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get medCondSaveFailed => 'I couldn\'t save the condition. Try again.';

  @override
  String get medCondDeleteFailed =>
      'I couldn\'t delete the condition. Try again.';

  @override
  String get medCondDeleteTitle => 'Delete this condition?';

  @override
  String medCondDeleteBody(String name) {
    return '\"$name\" will be deleted.';
  }

  @override
  String get medCondLoadError =>
      'I can\'t read the conditions. Check your connection and try again.';

  @override
  String get medCondUploadFailed => 'I couldn\'t upload the file. Try again.';

  @override
  String get medCondOpenFile => 'Open attachment';

  @override
  String get medicalRecordSourceFromReminder => 'From a reminder';

  @override
  String get reminderCatGrooming => 'Grooming';

  @override
  String get reminderCatOther => 'Other';

  @override
  String get remindersFormCategory => 'Category';

  @override
  String get remindersFormSubtype => 'Type';

  @override
  String get remindersFormSubtypeNone => 'None';

  @override
  String get remindersDoneTitle => 'Done?';

  @override
  String remindersDoneRecordHint(String pet) {
    return 'Record it in $pet\'s history.';
  }

  @override
  String get remindersDonePlainHint => 'Mark it as done?';

  @override
  String get remindersDoneFieldTitle => 'Title';

  @override
  String get remindersDoneFieldDate => 'When it happened';

  @override
  String get remindersDoneFieldNotes => 'Notes (optional)';

  @override
  String get remindersDoneConfirmRecord => 'Yes, record it';

  @override
  String get remindersDoneConfirmPlain => 'Yes, done';

  @override
  String get remindersDonePostpone => 'Postpone';

  @override
  String get remindersDoneNotDone => 'Not done';

  @override
  String remindersDoneRecorded(String pet) {
    return 'Recorded in $pet\'s history.';
  }

  @override
  String get remindersDoneMarked => 'Marked as done.';

  @override
  String get remindersDoneDismissed => 'Marked as not done.';

  @override
  String get remindersDonePostponed => 'I\'ll remind you again tomorrow.';

  @override
  String get remindersDoneTooltip => 'Mark as done';

  @override
  String get remindersNotifPermTitle =>
      'Would you like reminders to alert you?';

  @override
  String get remindersNotifPermBody =>
      'To alert you when a reminder is due, VetApp needs permission to send notifications. You can change this at any time in Settings.';

  @override
  String get remindersNotifPermNotNow => 'Not now';

  @override
  String get remindersNotifPermAllow => 'Allow';

  @override
  String get remindersNotifOffBanner =>
      'Notifications are turned off: reminders won\'t make a sound';

  @override
  String get remindersNotifOffAction => 'Turn on';

  @override
  String get authPhoneLabel => 'Phone number (optional)';

  @override
  String get authPhoneHelp =>
      'Optional. It stays in your profile and you can change or remove it at any time.';

  @override
  String get phonePickerTitle => 'Choose the country code';

  @override
  String phonePickerSemantics(String country, String dial) {
    return 'Country code: $country (+$dial)';
  }
}

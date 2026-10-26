// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get petsConsentFullText =>
      'Pour vous donner un conseil plus précis, l\'assistant peut lire le dossier médical de votre animal. Lorsque vous posez une question, il peut lire les trois entrées les plus récentes, avec le titre, la catégorie (visite, examen, vaccin, traitement ou document), la date de l\'événement, la description et le texte des documents joints, même s\'ils n\'ont aucun rapport avec la question. Il peut aussi lire les maladies antérieures encore en cours, avec le nom et la date de début, cinq au maximum. Si vous demandez d\'expliquer un examen, il peut lire les documents qui le concernent, deux au maximum. D\'un document très long, il ne lit que le début. Ce qu\'il lit est envoyé au fournisseur externe d\'intelligence artificielle qui rédige la réponse. VetApp ne l\'utilise que pour vous répondre. Vous pouvez retirer votre consentement à tout moment depuis la fiche de l\'animal ou les Paramètres : cela vaut pour les demandes suivantes.';

  @override
  String get appTitle => 'VET APP';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonSkip => 'Passer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonShare => 'Partager';

  @override
  String get languagePickerTitle => 'Choisissez votre langue';

  @override
  String get languagePickerSubtitle =>
      'Vous pourrez la changer à tout moment dans les Paramètres.';

  @override
  String get languageSectionTitle => 'Langue';

  @override
  String get languageSectionHint =>
      'Si vous changez de langue, les unités de mesure par défaut changent aussi, sauf si vous les avez déjà choisies.';

  @override
  String get authBannerCheckFieldsTitle => 'Vérifiez les champs';

  @override
  String get authLoginFieldsInvalidMessage =>
      'Il faut une adresse e-mail valide et un mot de passe d\'au moins 6 caractères.';

  @override
  String get authLoginLoadingTitle => 'Connexion en cours';

  @override
  String get authLoginLoadingMessage => 'Je vérifie vos identifiants.';

  @override
  String get authLoginSuccessTitle => 'Connexion réussie';

  @override
  String get authLoginSuccessMessage =>
      'La session est prête. Je vous emmène à l\'écran principal.';

  @override
  String get authLoginFailureTitle => 'Échec de la connexion';

  @override
  String get authLoginTitle => 'Bon retour parmi nous.';

  @override
  String get authLoginSubtitle =>
      'Connectez-vous pour retrouver vos animaux, vos rappels et vos documents.';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailHint => 'nom@domaine.fr';

  @override
  String get authEmailRequired => 'Saisissez votre adresse e-mail.';

  @override
  String get authEmailInvalid => 'Adresse e-mail non valide.';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authPasswordHint => '6 caractères minimum';

  @override
  String get authPasswordRequiredLogin => 'Saisissez votre mot de passe.';

  @override
  String get authPasswordRequiredNew => 'Saisissez un mot de passe.';

  @override
  String get authPasswordMinLength => '6 caractères minimum.';

  @override
  String get authPasswordShow => 'Afficher le mot de passe';

  @override
  String get authPasswordHide => 'Masquer le mot de passe';

  @override
  String get authRememberMe => 'Rester connecté';

  @override
  String get authForgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get authLoginButton => 'Se connecter';

  @override
  String get authNoAccountRegisterLink =>
      'Pas encore de compte ? Inscrivez-vous';

  @override
  String get authTermsOfServiceLabel => 'Conditions d\'utilisation';

  @override
  String get authPrivacyPolicyLabel => 'Politique de confidentialité';

  @override
  String authTermsAcceptance(String terms, String privacy) {
    return 'J\'accepte les $terms et la $privacy';
  }

  @override
  String get authRegisterCheckTitle => 'Une dernière vérification';

  @override
  String get authRegisterTermsRequired =>
      'Vous devez accepter les conditions d\'utilisation et la politique de confidentialité pour continuer.';

  @override
  String get authRegisterFieldsInvalid =>
      'Vérifiez les champs : le nom, l\'e-mail et le mot de passe doivent être valides.';

  @override
  String get authRegisterLoadingTitle => 'Création du compte';

  @override
  String get authRegisterLoadingMessage =>
      'Je crée votre compte et je prépare la session initiale.';

  @override
  String get authRegisterSuccessTitle => 'Compte prêt';

  @override
  String get authRegisterSuccessMessage =>
      'Inscription terminée. Je vous emmène à l\'accueil.';

  @override
  String get authRegisterFailureTitle => 'Compte non créé';

  @override
  String get authRegisterTitle => 'Créez votre profil.';

  @override
  String get authRegisterSubtitle =>
      'Quelques champs pour commencer à gérer la santé et les documents de vos animaux.';

  @override
  String get authNameLabel => 'Nom';

  @override
  String get authNameHint => 'Votre nom';

  @override
  String get authNameRequired => 'Saisissez votre nom.';

  @override
  String get authConfirmPasswordLabel => 'Confirmation';

  @override
  String get authConfirmPasswordHint => 'Saisissez-le à nouveau';

  @override
  String get authPasswordsMismatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get authRegisterButton => 'Créer un compte';

  @override
  String get authHaveAccountLoginLink => 'Déjà un compte ? Connectez-vous';

  @override
  String get authResetInvalidTitle => 'E-mail non valide';

  @override
  String get authResetInvalidMessage =>
      'Saisissez une adresse e-mail correcte pour continuer.';

  @override
  String get authResetLoadingTitle => 'Envoi en cours';

  @override
  String get authResetLoadingMessage =>
      'Je prépare la demande de récupération du mot de passe.';

  @override
  String get authResetSuccessTitle => 'E-mail envoyé';

  @override
  String get authResetSuccessMessage =>
      'Si le compte existe, vous recevrez le lien pour récupérer l\'accès.';

  @override
  String get authResetFailureTitle => 'Échec de l\'envoi';

  @override
  String get authResetTitle => 'Récupérez l\'accès.';

  @override
  String get authResetSubtitle =>
      'Saisissez votre e-mail : nous vous envoyons un lien pour réinitialiser le mot de passe.';

  @override
  String get authResetSendButton => 'Envoyer le lien';

  @override
  String get authBackToLoginLink => 'Retour à la connexion';

  @override
  String get authSetPasswordLoadingTitle => 'Mise à jour en cours';

  @override
  String get authSetPasswordLoadingMessage =>
      'J\'enregistre le nouveau mot de passe.';

  @override
  String get authSetPasswordFailureTitle => 'Échec de la mise à jour';

  @override
  String get authSetPasswordTitle => 'Définissez un nouveau mot de passe.';

  @override
  String get authSetPasswordSubtitle =>
      'Choisissez un nouveau mot de passe pour votre compte.';

  @override
  String get authNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authSetPasswordSaveButton => 'Enregistrer le nouveau mot de passe';

  @override
  String get authLegalShareTooltip => 'Partager ou télécharger';

  @override
  String get authLegalLoadError =>
      'Je n\'arrive pas à charger le texte pour le moment. Réessayez dans un instant.';

  @override
  String get authLegalPreparingNotice =>
      'Le texte complet de l\'information est en cours de préparation et sera bientôt disponible ici, avec la possibilité de le télécharger.';

  @override
  String get authHubTitle => 'VetApp : vos compagnons à portée de patte';

  @override
  String get authHubSubtitle =>
      'Connectez-vous à votre compte ou créez-en un nouveau en quelques secondes.';

  @override
  String get authHubCreateAccount => 'Créer un compte';

  @override
  String get authHubPrivacyNote =>
      'Vos données restent privées et nous les utilisons uniquement pour gérer le profil de votre animal.';

  @override
  String get authErrorEmailExists =>
      'Un compte existe déjà avec cette adresse e-mail. Essayez de vous connecter.';

  @override
  String get authErrorWeakPassword =>
      'Le mot de passe est trop faible : utilisez au moins 6 caractères, de préférence avec des chiffres ou des majuscules.';

  @override
  String get authErrorEmailInvalid => 'L\'adresse e-mail ne semble pas valide.';

  @override
  String get authErrorNoConnection =>
      'Pas de connexion. Vérifiez le réseau et réessayez.';

  @override
  String get authErrorLinkExpired =>
      'Le lien n\'est plus valide ou a déjà été utilisé. Demandez-en un nouveau depuis l\'écran de récupération.';

  @override
  String get authErrorRateLimit =>
      'Vous avez demandé trop d\'e-mails en peu de temps. Patientez quelques minutes et réessayez.';

  @override
  String get authErrorInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Vous devez d\'abord confirmer votre adresse e-mail : consultez votre boîte de réception et ouvrez le lien que nous vous avons envoyé.';

  @override
  String get authErrorEmailNotFound =>
      'Il n\'existe aucun compte avec cette adresse e-mail.';

  @override
  String get authErrorGeneric =>
      'Quelque chose ne s\'est pas passé comme prévu. Réessayez dans un instant.';

  @override
  String get authNetworkTimeout =>
      'La requête a pris trop de temps. Réessayez.';

  @override
  String get authNetworkUnexpected => 'Un problème est survenu. Réessayez.';

  @override
  String get consentsErrorLoad =>
      'Je n\'ai pas pu lire vos consentements. Réessayez.';

  @override
  String get consentsErrorSave =>
      'Je n\'ai pas pu enregistrer votre choix. Réessayez.';

  @override
  String get billingErrorStatus =>
      'Je n\'ai pas pu vérifier votre abonnement. Réessayez.';

  @override
  String get billingErrorSelectPlan =>
      'Je n\'ai pas pu enregistrer l\'offre choisie. Réessayez.';

  @override
  String get billingIncludedPets => 'Profils de vos animaux';

  @override
  String get billingIncludedAssistant =>
      'Assistant pour vos questions de santé, de comportement et de routine';

  @override
  String get billingIncludedChatMedia =>
      'Photos, PDF et dictée vocale dans le chat';

  @override
  String get billingIncludedReminders => 'Rappels';

  @override
  String get billingIncludedNearbyServices =>
      'Services pour animaux à proximité';

  @override
  String get billingFreePlaceholder => 'Limites de l\'offre Free : à définir';

  @override
  String get billingPlusPlaceholder =>
      'Fonctions supplémentaires de l\'offre Plus : à définir';

  @override
  String get billingProPlaceholder =>
      'Fonctions supplémentaires de l\'offre Pro : à définir';

  @override
  String get billingPlanBadgeRecommended => 'Recommandé';

  @override
  String get billingIncludedInAllPlans => 'Inclus dans toutes les offres';

  @override
  String get billingPriceFree => 'Gratuit';

  @override
  String billingPricePerMonth(String amount) {
    return '$amount/mois';
  }

  @override
  String billingPricePerMonthYearly(String amount) {
    return '$amount/mois, facturé annuellement';
  }

  @override
  String get billingTitle => 'Abonnement et paiements';

  @override
  String billingPlanSwitched(String plan) {
    return 'Vous êtes maintenant sur l\'offre $plan.';
  }

  @override
  String get billingPaymentHistory => 'Historique des paiements';

  @override
  String get billingPaymentHistoryComingSoon =>
      'Vos factures et reçus seront consultables ici.';

  @override
  String get billingComparePlans => 'Comparer les offres';

  @override
  String get billingPaymentMethodsSection => 'Moyens de paiement';

  @override
  String get billingInvoicingSection => 'Facturation';

  @override
  String get billingTrialBannerTitle => 'Essai gratuit en cours';

  @override
  String billingTrialBannerDaysLeft(int days) {
    return 'Il vous reste $days jours gratuits, sans carte bancaire. Choisissez une offre quand vous voulez, ou à la fin de l\'essai.';
  }

  @override
  String get billingTrialBannerEnding =>
      'L\'essai gratuit se termine bientôt : choisissez une offre pour continuer à utiliser VetApp.';

  @override
  String get billingDeveloperBanner =>
      'Compte développeur : accès illimité, aucune offre requise.';

  @override
  String get billingCurrentPlanLabel => 'Votre offre';

  @override
  String billingRenewalOn(String date) {
    return 'Renouvellement le $date';
  }

  @override
  String get billingCycleMonthly => 'Mensuel';

  @override
  String get billingCycleYearly => 'Annuel';

  @override
  String get billingCurrentPlanButton => 'Offre actuelle';

  @override
  String get billingBackToFree => 'Revenir à Free';

  @override
  String billingSwitchToPlan(String plan) {
    return 'Passer à $plan';
  }

  @override
  String billingCardExpires(String expiry) {
    return 'Expire le $expiry';
  }

  @override
  String billingCardExpiresDefault(String expiry) {
    return 'Expire le $expiry · Par défaut';
  }

  @override
  String get billingSetDefault => 'Définir par défaut';

  @override
  String get billingRemove => 'Retirer';

  @override
  String get billingAddPaymentMethod => 'Ajouter un moyen de paiement';

  @override
  String get billingCardBrandLabel => 'Réseau';

  @override
  String get billingCardLast4Label => '4 derniers chiffres';

  @override
  String get billingCardLast4Error => 'Saisissez 4 chiffres';

  @override
  String get billingExpiryMonthLabel => 'Mois';

  @override
  String get billingExpiryYearLabel => 'Année';

  @override
  String get billingPaywallTitle => 'Votre essai gratuit est terminé.';

  @override
  String get billingPaywallSubtitle =>
      'Choisissez comment continuer avec VetApp. Vous pouvez changer d\'offre quand vous voulez dans les Paramètres.';

  @override
  String billingChoosePlan(String plan) {
    return 'Choisir $plan';
  }

  @override
  String billingTrialDialogTitle(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Il vous reste $daysLeft jours d\'essai',
      one: 'Dernier jour d\'essai',
    );
    return '$_temp0';
  }

  @override
  String get billingTrialDialogBody =>
      'Avec l\'offre Free, certaines fonctions sont limitées. Passez à Plus ou Pro pour tout avoir sans limites à la fin de l\'essai.';

  @override
  String get billingTrialDialogLater => 'Plus tard';

  @override
  String get billingTrialDialogSeePlans => 'Voir les offres';

  @override
  String get firstRunWelcomeTitle => 'Bienvenue sur VetApp.';

  @override
  String get firstRunPlanIntroSubtitle =>
      'Choisissez comment commencer : vous pouvez tout essayer gratuitement pendant 10 jours, sans carte bancaire, ou choisir tout de suite une offre.';

  @override
  String get firstRunPlanOrChoose => 'OU CHOISISSEZ TOUT DE SUITE UNE OFFRE';

  @override
  String get firstRunTrialCardTitle => '10 jours gratuits';

  @override
  String get firstRunTrialCardBody =>
      'Aucune carte bancaire requise. À la fin des 10 jours, nous vous demanderons de choisir une offre pour continuer.';

  @override
  String get firstRunTrialStartButton => 'Commencer l\'essai gratuit';

  @override
  String get firstRunPlanSelectButton => 'Choisir';

  @override
  String get firstRunAddPetTitle => 'Ajoutez votre premier animal';

  @override
  String get firstRunAddPetBody =>
      'Il suffit de quelques minutes : nom, espèce et quelques détails. Vous pouvez aussi le faire plus tard depuis Animaux.';

  @override
  String get firstRunAddPetNow => 'Ajouter maintenant';

  @override
  String get firstRunAddPetLater => 'Passer pour l\'instant';

  @override
  String get firstRunNotificationsTitle => 'Ne manquez aucun rappel';

  @override
  String get firstRunNotificationsBody =>
      'Activez les notifications pour être prévenu des vaccins, traitements et visites à venir. Vous pouvez changer d\'avis à tout moment dans les Paramètres.';

  @override
  String get firstRunNotificationsEnable => 'Activer les notifications';

  @override
  String get firstRunNotificationsLater => 'Pas maintenant';

  @override
  String get firstRunTutorialPetsTitle => 'Un profil pour chaque animal';

  @override
  String get firstRunTutorialPetsBody =>
      'Espèce et race, poids, notes médicales et documents : tout est organisé pour chaque animal, toujours à portée de main.';

  @override
  String get firstRunTutorialAssistantTitle => 'Demandez à votre assistant';

  @override
  String get firstRunTutorialAssistantBody =>
      'Posez vos questions sur la santé de vos animaux et recevez des réponses adaptées à leur situation.';

  @override
  String get firstRunTutorialRemindersTitle => 'Plus d\'échéances oubliées';

  @override
  String get firstRunTutorialRemindersBody =>
      'Vaccins, traitements et visites : programmez un rappel et VetApp vous prévient au bon moment.';

  @override
  String get firstRunTutorialStart => 'Commencer';

  @override
  String get chatLoadingTitle => 'Ouverture de la conversation';

  @override
  String get chatLoadingSubtitle =>
      'Nous chargeons la conversation et le dernier contexte disponible.';

  @override
  String get chatEmptyTitle => 'La conversation est vide';

  @override
  String get chatEmptySubtitle =>
      'Écrivez le premier message pour commencer le dialogue avec l\'assistant.';

  @override
  String get chatEmptyAction => 'Écrire maintenant';

  @override
  String chatEmptyGreeting(String pet) {
    return 'Bonjour, j\'ai une question pour $pet.';
  }

  @override
  String get chatErrorTitle => 'Conversation indisponible';

  @override
  String get chatErrorSubtitle =>
      'Un problème est survenu lors de la récupération de la conversation.';

  @override
  String get chatErrorAction => 'Retour aux chats';

  @override
  String get chatMessageEditAction => 'Modifier le message';

  @override
  String get chatMessageEditHint =>
      'La réponse et les messages suivants seront remplacés.';

  @override
  String chatComposerHint(String pet) {
    return 'Posez une question sur $pet';
  }

  @override
  String chatNewConversationOnPet(String pet) {
    return 'Nouvelle conversation sur $pet';
  }

  @override
  String get chatNewConversationPrompt =>
      'Écrivez ci-dessous ce que vous observez : je vous réponds tout de suite.';

  @override
  String get chatTypingText => 'Rédige une réponse...';

  @override
  String get chatTypingSlowText =>
      'Cela prend plus de temps que d\'habitude, la réponse arrive dans un instant...';

  @override
  String chatDefaultTitle(String pet) {
    return 'Chat avec $pet';
  }

  @override
  String get chatListeningText => 'J\'écoute… touchez pour arrêter';

  @override
  String get chatTranscribingText => 'Transcription…';

  @override
  String get chatEditingLabel => 'Modification du message';

  @override
  String get chatListeningHint => 'J\'écoute...';

  @override
  String get chatTranscribingHint => 'Je transcris le message...';

  @override
  String get chatAddPhotoTooltip => 'Ajouter une photo';

  @override
  String get chatStopRecordingTooltip => 'Arrêter et transcrire';

  @override
  String get chatVoiceMessageTooltip => 'Message vocal';

  @override
  String get chatMicPermissionNeeded =>
      'L\'autorisation d\'utiliser le microphone est nécessaire.';

  @override
  String get chatMicStartFailed =>
      'Impossible de démarrer le microphone. Réessayez.';

  @override
  String get chatRecordingFailed => 'L\'enregistrement a échoué. Réessayez.';

  @override
  String get chatRecordingReadFailed =>
      'Je n\'ai pas pu lire l\'enregistrement. Réessayez.';

  @override
  String get chatPhotoAnalyzing => 'J\'examine la photo...';

  @override
  String get chatPhotoReady => 'Photo prête à être envoyée';

  @override
  String get chatRemovePhotoTooltip => 'Retirer la photo';

  @override
  String chatRecordingSemantics(String listening, int minutes, String seconds) {
    return '$listening, $minutes minutes et $seconds secondes';
  }

  @override
  String get chatCancelEditTooltip => 'Annuler la modification';

  @override
  String get chatMenuTooltip => 'Options du chat';

  @override
  String get chatMenuRename => 'Renommer';

  @override
  String get chatMenuExport => 'Exporter le chat';

  @override
  String get chatMenuSummary => 'Résumé';

  @override
  String get chatExportOpenFirst => 'Ouvrez le chat pour l\'exporter.';

  @override
  String get chatSenderYou => 'Vous';

  @override
  String get chatSenderAssistant => 'Assistant';

  @override
  String get chatRenameTitle => 'Renommer le chat';

  @override
  String get chatRenameFieldLabel => 'Titre';

  @override
  String get chatSummaryLoading => 'Je prépare le résumé…';

  @override
  String get chatSummaryTitle => 'Résumé pour le vétérinaire';

  @override
  String get chatSummaryDisclaimer =>
      'Ce résumé est généré automatiquement et ne constitue pas un diagnostic. Pour toute décision clinique, consultez le vétérinaire.';

  @override
  String get chatSummaryEmpty => 'Aucun résumé disponible.';

  @override
  String get chatDeleteTitle => 'Supprimer ce chat ?';

  @override
  String get chatDeleteBody =>
      'La conversation et ses messages seront supprimés.';

  @override
  String get chatFallbackPetName => 'votre animal';

  @override
  String get chatNewConversation => 'Nouvelle conversation';

  @override
  String chatNewConversationTitle(String pet) {
    return '$pet - nouvelle conversation';
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
  String get chatStatusSaved => 'Conversation enregistrée';

  @override
  String get chatStatusSent => 'Message envoyé';

  @override
  String get chatStatusEdited => 'Message modifié';

  @override
  String get chatStatusReplyReady => 'Réponse prête';

  @override
  String get chatTimeYesterday => 'hier';

  @override
  String get chatTimeNow => 'à l\'instant';

  @override
  String get chatSummaryNotYet =>
      'Le résumé sera disponible après le premier message.';

  @override
  String get chatEditMessageMissing =>
      'Ce message n\'est plus dans la conversation.';

  @override
  String get chatEmptyThreadPreview =>
      'Nouvelle conversation prête à être utilisée.';

  @override
  String chatDemoReplyAppetite(String pet) {
    return 'Pour $pet, je surveillerais l\'appétit, l\'eau et le niveau d\'énergie pendant les prochaines 24 heures. Si cela empire, mieux vaut contacter le vétérinaire.';
  }

  @override
  String get chatDemoReplyVomiting =>
      'En cas de vomissements ou de diarrhée, il convient de surveiller l\'hydratation et de contacter le vétérinaire si les symptômes se répètent ou deviennent intenses.';

  @override
  String chatDemoReplyVaccine(String pet) {
    return 'Je peux vous aider à mettre le rappel de vaccin de $pet à l\'agenda et à ajouter un rappel bien visible sur l\'accueil.';
  }

  @override
  String chatDemoReplyWeight(String pet) {
    return 'Pour le poids de $pet, nous pouvons fixer un contrôle régulier et le comparer à la dernière visite pour voir si la tendance change vraiment.';
  }

  @override
  String chatDemoReplyDefault(String pet) {
    return 'C\'est noté : je vous prépare un bref récapitulatif pour $pet, afin que vous ayez tout de suite un plan pratique et lisible.';
  }

  @override
  String get chatErrorContactAssistant =>
      'Je n\'ai pas pu joindre l\'assistant. Réessayez.';

  @override
  String get chatErrorAssistantTimeout =>
      'L\'assistant n\'a pas répondu à temps. Touchez Réessayer : si la réponse est déjà prête, je la récupère.';

  @override
  String get chatErrorGeneric => 'Un problème est survenu. Réessayez.';

  @override
  String get chatErrorRequestTimeout => 'Requête expirée. Réessayez.';

  @override
  String get chatErrorEditFailed =>
      'Je n\'ai pas pu modifier le message. Réessayez.';

  @override
  String get chatErrorEditNetwork =>
      'Je n\'ai pas pu modifier le message. Vérifiez votre connexion.';

  @override
  String chatErrorMessageTooLong(int max) {
    return 'Le message est trop long : vous pouvez écrire $max caractères au maximum. Raccourcissez-le puis renvoyez-le.';
  }

  @override
  String chatInputLimitReached(int max) {
    return 'Vous avez atteint la limite de $max caractères.';
  }

  @override
  String get chatErrorPetBootstrap =>
      'Je n\'ai pas pu préparer le profil de l\'animal.';

  @override
  String get chatErrorTitleEmpty => 'Le titre ne peut pas être vide.';

  @override
  String get chatErrorRenameFailed =>
      'Je n\'ai pas pu renommer le chat. Réessayez.';

  @override
  String get chatErrorRenameNetwork =>
      'Je n\'ai pas pu renommer le chat. Vérifiez votre connexion.';

  @override
  String get chatErrorSummaryEmpty =>
      'Écrivez au moins un message pour obtenir un résumé.';

  @override
  String get chatErrorSummaryModel =>
      'Le modèle n\'a pas répondu. Réessayez dans un instant.';

  @override
  String get chatErrorSummaryFailed =>
      'Je n\'ai pas pu préparer le résumé. Réessayez.';

  @override
  String get chatErrorSummaryNetwork =>
      'Je n\'ai pas pu préparer le résumé. Vérifiez votre connexion.';

  @override
  String get chatErrorDeleteFailed =>
      'Je n\'ai pas pu supprimer le chat sur le serveur.';

  @override
  String get chatErrorListChats => 'Je n\'ai pas pu charger vos chats.';

  @override
  String get chatErrorListPets => 'Je n\'ai pas pu charger vos animaux.';

  @override
  String chatErrorConversationLimit(String max) {
    return 'vous avez atteint le nombre maximal de conversations ($max) pour cet animal. Fermez-en une pour en créer une nouvelle.';
  }

  @override
  String get chatErrorConversationNotFound =>
      'Cette conversation n\'existe plus.';

  @override
  String get chatErrorAttachmentOffline =>
      'Vous êtes hors ligne ou la connexion n\'est pas stable. Réessayez une fois reconnecté.';

  @override
  String get chatErrorAttachmentDownload =>
      'Je n\'ai pas pu télécharger le fichier.';

  @override
  String get chatErrorAttachmentTooLarge =>
      'Le fichier est trop volumineux (4 Mo max).';

  @override
  String get chatErrorAttachmentUnsupported =>
      'Ce type de fichier n\'est pas pris en charge. Vous pouvez envoyer des photos (JPG, PNG, WEBP) ou des PDF.';

  @override
  String get chatErrorPdfTooManyPages =>
      'Le PDF dépasse les 30 pages autorisées.';

  @override
  String get chatErrorPdfUnreadable =>
      'Je n\'arrive pas à lire ce PDF : il est peut-être endommagé ou protégé par un mot de passe.';

  @override
  String get chatErrorAttachmentUpload =>
      'Je n\'ai pas pu envoyer le fichier. Réessayez.';

  @override
  String get chatErrorTranscribe =>
      'Je n\'ai pas pu transcrire le message vocal.';

  @override
  String get chatSeedConv1Title => 'Moka - appétit et contrôle';

  @override
  String get chatSeedConv1Subtitle =>
      'Légère baisse d\'appétit, surveillance et plan d\'action.';

  @override
  String get chatSeedConv1Preview =>
      'S\'il reste vif, nous pouvons observer jusqu\'à demain, mais notez l\'appétit et l\'eau.';

  @override
  String get chatSeedConv1Status => 'Contexte actif de l\'animal';

  @override
  String get chatSeedConv1Msg1 =>
      'Racontez-moi ce que vous observez : l\'appétit, l\'énergie, l\'eau et les selles nous aident à comprendre tout de suite s\'il faut une visite ou s\'il suffit de surveiller.';

  @override
  String get chatSeedConv1Msg2 =>
      'Depuis hier, il mange moins que d\'habitude mais reste vif. Dois-je m\'inquiéter tout de suite ?';

  @override
  String get chatSeedConv1Msg3 =>
      'En l\'absence de vomissements, d\'abattement ou de douleur évidente, il convient généralement de surveiller pendant 24 heures et de noter l\'appétit, l\'eau et les selles. Si quelque chose s\'aggrave, contactez le vétérinaire.';

  @override
  String get chatSeedConv1Msg4 =>
      'Par précaution, je vous laisse aussi un mini-plan : petits repas, eau toujours disponible et prise de température s\'il vous semble plus fatigué que d\'habitude.';

  @override
  String get chatSeedConv2Title => 'Moka - rappel de vaccin';

  @override
  String get chatSeedConv2Subtitle =>
      'Rappel annuel avec une note sur le rappel antiparasitaire.';

  @override
  String get chatSeedConv2Preview =>
      'J\'ai déjà programmé le rappel et le rappel de suivi pour la semaine prochaine.';

  @override
  String get chatSeedConv2Status => 'Rappel actif';

  @override
  String get chatSeedConv2Msg1 =>
      'J\'ai programmé le rappel et ajouté une note sur l\'antiparasitaire. Si vous le souhaitez, nous pouvons aussi caler la prochaine visite de contrôle.';

  @override
  String get chatSeedConv2Msg2 =>
      'Parfait, vous me prévenez aussi une semaine avant ?';

  @override
  String get chatSeedConv2Msg3 =>
      'Bien sûr. Je vous prépare aussi une note visuelle avec l\'échéance la plus proche, pour que vous la retrouviez tout de suite sur l\'accueil.';

  @override
  String get chatSeedConv3Title => 'Moka - compte rendu de visite';

  @override
  String get chatSeedConv3Subtitle =>
      'Synthèse du contrôle, traitement léger et prochaine étape.';

  @override
  String get chatSeedConv3Preview =>
      'Je peux résumer le compte rendu en trois points : état, traitement et prochain contrôle.';

  @override
  String get chatSeedConv3Status => 'Compte rendu importé';

  @override
  String get chatSeedConv3Msg1 =>
      'Je peux résumer le compte rendu en trois points : tableau clinique, traitement et prochains contrôles. Si vous le souhaitez, je prépare aussi une version courte à partager.';

  @override
  String get chatSeedConv3Msg2 => 'Oui, donnez-moi la version courte.';

  @override
  String get chatSeedConv3Msg3 =>
      'En bref : état stable, traitement léger pendant quelques jours et contrôle de suivi déjà programmé.';

  @override
  String get chatSeedAgo2Min => 'il y a 2 min';

  @override
  String get chatSeedAgo3Days => 'il y a 3 j';

  @override
  String get marketplacePermissionDenied =>
      'Seule la personne qui a publié l\'annonce peut la modifier ou la supprimer.';

  @override
  String get marketplaceCategoryKennelsCarriers => 'Paniers et transport';

  @override
  String get marketplaceCategoryLeashesCollars =>
      'Laisses, colliers et harnais';

  @override
  String get marketplaceCategoryToys => 'Jouets';

  @override
  String get marketplaceCategoryClothing => 'Vêtements';

  @override
  String get marketplaceCategoryFeeding => 'Gamelles et alimentation';

  @override
  String get marketplaceCategoryHygieneGrooming => 'Hygiène et toilettage';

  @override
  String get marketplaceCategoryAquariumsTerrariums =>
      'Aquariums et terrariums';

  @override
  String get marketplaceCategoryCagesAviaries => 'Cages et volières';

  @override
  String get marketplaceOther => 'Autre';

  @override
  String get marketplaceConditionNew => 'Neuf';

  @override
  String get marketplaceConditionLikeNew => 'Comme neuf';

  @override
  String get marketplaceConditionGood => 'Bon état';

  @override
  String get marketplaceConditionWorn => 'D\'occasion';

  @override
  String get marketplaceSpeciesAll => 'Toutes les espèces';

  @override
  String get marketplaceSpeciesDog => 'Chien';

  @override
  String get marketplaceSpeciesCat => 'Chat';

  @override
  String get marketplaceSpeciesSmallMammal => 'Petits mammifères';

  @override
  String get marketplaceSpeciesBird => 'Oiseau';

  @override
  String get marketplaceSpeciesReptileAmphibian => 'Reptiles et amphibiens';

  @override
  String get marketplaceSpeciesFish => 'Poisson';

  @override
  String get marketplacePriceGift => 'À donner';

  @override
  String get marketplaceDistanceAnywhere => 'Partout';

  @override
  String get marketplaceDemoBedTitle => 'Panier rembourré (démo)';

  @override
  String get marketplaceDemoBedDescription => 'Peu utilisé, taille moyenne.';

  @override
  String get marketplaceDemoBedArea => 'Centre, Milan';

  @override
  String get marketplaceDemoScratcherTitle =>
      'Arbre à chat à deux niveaux (démo)';

  @override
  String get marketplaceDemoScratcherArea => 'Città Studi, Milan';

  @override
  String get marketplacePageTitle => 'Marché de l\'occasion';

  @override
  String get marketplaceMapAction => 'Carte';

  @override
  String get marketplaceNewListing => 'Nouvelle annonce';

  @override
  String get marketplaceIntro =>
      'Achetez, vendez et donnez des articles pour animaux avec d\'autres propriétaires.';

  @override
  String get marketplaceDistanceNeedsLocation =>
      'Pour filtrer par distance, définissez votre position dans Paramètres → Localisation.';

  @override
  String get marketplaceEmptyFiltered =>
      'Aucune annonce avec ces filtres pour le moment.';

  @override
  String get marketplaceLoadError =>
      'Je n\'arrive pas à charger les annonces. Vérifiez votre connexion.';

  @override
  String get marketplaceFilterAllCategories => 'Toutes';

  @override
  String get marketplaceFilterAllSpecies => 'Tous les animaux';

  @override
  String get marketplaceReportListing => 'Signaler l\'annonce';

  @override
  String get marketplaceReasonSpam => 'Spam';

  @override
  String get marketplaceReasonScam => 'Arnaque';

  @override
  String get marketplaceReasonProhibitedItem => 'Article interdit';

  @override
  String get marketplaceReasonInappropriate => 'Contenu inapproprié';

  @override
  String get marketplaceReportRemoved =>
      'Merci, l\'annonce a été retirée après les signalements reçus.';

  @override
  String get marketplaceReportSent => 'Signalement envoyé, merci.';

  @override
  String get marketplaceDeleteConfirmTitle => 'Supprimer l\'annonce ?';

  @override
  String marketplaceDeleteConfirmBody(String title) {
    return '« $title » et ses photos seront supprimées. Cette action est irréversible.';
  }

  @override
  String get marketplaceDeleteFailed =>
      'Je n\'ai pas pu supprimer l\'annonce. Réessayez.';

  @override
  String get marketplaceDeleted => 'Annonce supprimée.';

  @override
  String marketplaceDetailApproxZone(String city) {
    return '$city · zone approximative';
  }

  @override
  String marketplaceDetailForSpecies(String species) {
    return 'Pour : $species';
  }

  @override
  String get marketplaceEditListing => 'Modifier l\'annonce';

  @override
  String get marketplaceDeleting => 'Suppression...';

  @override
  String get marketplaceDeleteListing => 'Supprimer l\'annonce';

  @override
  String get marketplaceReporting => 'Envoi du signalement...';

  @override
  String get marketplaceMapTitle => 'Carte du marché';

  @override
  String marketplaceListingsCount(int count) {
    return '$count annonces';
  }

  @override
  String marketplaceMapClusterTitle(int count) {
    return '$count annonces dans cette zone';
  }

  @override
  String get marketplaceMapEmpty => 'Aucune annonce avec ces filtres.';

  @override
  String marketplaceMapSummary(int count) {
    return '$count annonces · positions approximatives (environ 1 km)';
  }

  @override
  String get marketplaceLocationErrorWithHome =>
      'Je n\'arrive pas à détecter votre position. Vérifiez les autorisations de localisation ou utilisez votre domicile.';

  @override
  String get marketplaceLocationErrorNoHome =>
      'Je n\'arrive pas à détecter votre position : elle sert à afficher l\'annonce dans la bonne zone (de façon approximative). Vérifiez les autorisations de localisation et réessayez.';

  @override
  String get marketplaceCameraOpenError =>
      'Je n\'arrive pas à ouvrir l\'appareil photo.';

  @override
  String get marketplaceGalleryOpenError =>
      'Je n\'arrive pas à ouvrir la galerie.';

  @override
  String marketplacePhotosSkipped(int count) {
    return '$count photos illisibles ont été ignorées.';
  }

  @override
  String marketplacePhotosMaxReached(int max) {
    return 'Vous pouvez ajouter $max photos au maximum.';
  }

  @override
  String get marketplaceZoneWait =>
      'Attendez que la zone soit trouvée, puis réessayez.';

  @override
  String get marketplaceSaveFailed =>
      'Je n\'ai pas pu enregistrer l\'annonce. Vérifiez votre connexion et réessayez.';

  @override
  String get marketplacePriceRequired =>
      'Saisissez un prix ou choisissez « À donner »';

  @override
  String get marketplacePriceInvalid => 'Saisissez un prix valide';

  @override
  String get marketplacePriceNegative => 'Le prix ne peut pas être négatif';

  @override
  String get marketplacePriceZero => 'Pour le donner, choisissez « À donner »';

  @override
  String get marketplacePriceTooHigh => 'Prix trop élevé';

  @override
  String get marketplaceFieldTitle => 'Titre';

  @override
  String get marketplaceTitleRequired => 'Saisissez un titre';

  @override
  String get marketplaceFieldDescription => 'Description (facultative)';

  @override
  String get marketplaceFieldCategory => 'Catégorie';

  @override
  String get marketplaceCategoryRequired => 'Choisissez une catégorie';

  @override
  String get marketplaceConditionLabel => 'État';

  @override
  String get marketplaceSpeciesLabel => 'Pour quels animaux';

  @override
  String get marketplaceSpeciesRequired =>
      'Indiquez pour quels animaux, ou « Toutes les espèces »';

  @override
  String get marketplaceGiftSubtitle => 'Vous le donnez à qui en a besoin';

  @override
  String get marketplaceFieldPrice => 'Prix en €';

  @override
  String get marketplaceSaving => 'Enregistrement...';

  @override
  String get marketplaceSaveChanges => 'Enregistrer les modifications';

  @override
  String get marketplacePublish => 'Publier l\'annonce';

  @override
  String marketplacePhotosTitle(int count, int max) {
    return 'Photos ($count/$max)';
  }

  @override
  String get marketplaceTakePhoto => 'Prendre une photo';

  @override
  String get marketplaceFromGallery => 'Depuis la galerie';

  @override
  String get marketplacePhotosPrivacy =>
      'Avant l\'envoi, nous retirons des photos les données cachées (position, appareil, date).';

  @override
  String get marketplaceLocationTitle => 'Où il se trouve';

  @override
  String get marketplaceLocationKeep => 'Zone actuelle de l\'annonce';

  @override
  String get marketplaceLocationNow => 'Là où je suis';

  @override
  String get marketplaceLocationHome => 'Domicile';

  @override
  String get marketplaceLocationHomeHint =>
      'Pour utiliser votre domicile, définissez-le dans Paramètres → Localisation.';

  @override
  String get marketplaceLocationSearching => 'Je cherche votre zone...';

  @override
  String get marketplaceZoneLabel => 'Zone affichée (quartier ou commune)';

  @override
  String get marketplaceZoneHelper => 'Ni rue ni numéro';

  @override
  String get marketplacePrivacyApproxOnMap =>
      'Sur la carte, l\'annonce apparaît à un point approximatif (environ 1 km), jamais à votre adresse.';

  @override
  String get marketplacePrivacyApproxAlways =>
      'Pour votre vie privée, la position de l\'annonce est toujours approximative (environ 1 km), jamais votre adresse exacte.';

  @override
  String get medicalActionOpen => 'Ouvrir';

  @override
  String get medicalActionSend => 'Envoyer';

  @override
  String get medicalActionRename => 'Renommer';

  @override
  String get medicalFileUnavailable =>
      'Le fichier n\'est pas disponible pour le moment. Vérifiez votre connexion et réessayez.';

  @override
  String get medicalPdfOpenFailed =>
      'Je n\'ai pas pu ouvrir le PDF. Réessayez ou utilisez Envoyer.';

  @override
  String get medicalNoPdfAppTitle => 'Aucune application pour ouvrir le PDF';

  @override
  String get medicalNoPdfAppBody =>
      'Cet appareil n\'a aucune application capable d\'ouvrir les PDF. Vous pouvez envoyer le fichier à une application qui le peut.';

  @override
  String get medicalPreparingFiles => 'Je prépare les fichiers à envoyer…';

  @override
  String get medicalNoFilesToSend =>
      'Aucun fichier disponible à envoyer. Vérifiez votre connexion et réessayez.';

  @override
  String medicalFilesMissing(int count) {
    return '$count fichiers indisponibles n\'ont pas été inclus.';
  }

  @override
  String get medicalDeleteConfirmTitle => 'Supprimer ce document ?';

  @override
  String medicalDeleteConfirmBody(String title) {
    return '« $title » sera supprimé définitivement.';
  }

  @override
  String get medicalDeleting => 'Suppression du compte rendu…';

  @override
  String get medicalRenameTitle => 'Renommer le compte rendu';

  @override
  String get medicalRenameFieldLabel => 'Nom du fichier';

  @override
  String get medicalDefaultRecordTitle => 'Compte rendu clinique';

  @override
  String get medicalSaveNoSession =>
      'Accès indisponible : réessayez après vous être reconnecté.';

  @override
  String medicalSavePetNotSynced(String petName) {
    return 'Le profil de $petName n\'est pas synchronisé avec le serveur : corrigez-le avant de charger des comptes rendus.';
  }

  @override
  String get medicalSaveFailed =>
      'Je n\'ai pas pu enregistrer le compte rendu sur le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get medicalRenameFailed =>
      'Je n\'ai pas pu renommer le compte rendu. Réessayez.';

  @override
  String get medicalDeleteFailed =>
      'Je n\'ai pas pu supprimer le compte rendu. Réessayez.';

  @override
  String get medicalRecordMetaNotUploaded =>
      'Fichier non chargé sur le serveur';

  @override
  String get medicalRecordMetaAnalysisFailed =>
      'Fichier enregistré, lecture automatique impossible';

  @override
  String get medicalRecordMetaUploadedNow => 'Chargé à l\'instant par vous';

  @override
  String get medicalRecordBadgeNotUploaded => 'Non chargé';

  @override
  String get medicalRecordBadgeNew => 'Nouveau';

  @override
  String get medicalRecordSourceLocalOnly => 'Uniquement sur ce téléphone';

  @override
  String get medicalRecordSourceUploadedByYou => 'Chargé par vous';

  @override
  String get medicalTimelineImported => 'Importé';

  @override
  String get medicalTimelineUpload => 'Chargement';

  @override
  String get medicalTimelineFailed => 'Échec';

  @override
  String get medicalTimelineCompleted => 'Terminé';

  @override
  String get medicalTimelineReadyToSend => 'Prêt à envoyer';

  @override
  String get medicalTimelineAvailable => 'Disponible';

  @override
  String get medicalUploadTitle => 'Charger un document';

  @override
  String medicalUploadForPet(String petName) {
    return 'Pour $petName · PDF, JPG ou PNG';
  }

  @override
  String get medicalUploadAction => 'Charger';

  @override
  String get medicalUploadPickPrompt => 'Touchez pour choisir un fichier';

  @override
  String get medicalUploadPickHint => 'PDF, JPG ou PNG depuis votre appareil';

  @override
  String get medicalUploadChange => 'Changer';

  @override
  String get medicalUploadFailedTitle => 'Le fichier n\'a pas été chargé';

  @override
  String medicalUploadFailedBody(String reason) {
    return '$reason Vous pouvez aussi enregistrer le compte rendu uniquement sur ce téléphone : il sera marqué « Non chargé » et ne sera pas disponible sur vos autres appareils.';
  }

  @override
  String get medicalUploadFailedDefaultReason =>
      'Vérifiez votre connexion et réessayez.';

  @override
  String get medicalUploadSaveLocalOnly =>
      'Enregistrer uniquement sur le téléphone';

  @override
  String get medicalUploadDemoSubtitle =>
      'Chargez un PDF, JPG ou PNG et complétez les métadonnées.';

  @override
  String get medicalUploadDemoAction => 'Détail';

  @override
  String get medicalUploadDemoCardBody =>
      'Chargé avec succès et prêt pour la vérification des métadonnées.';

  @override
  String get medicalListTitle => 'Comptes rendus';

  @override
  String get medicalListSubtitle =>
      'Comptes rendus, notes et pièces jointes de Moka dans des archives claires.';

  @override
  String get medicalListSyncTitle => 'Synchronisation des comptes rendus';

  @override
  String get medicalListSyncBody =>
      'Je récupère les documents et les métadonnées depuis Supabase ou la source de démonstration.';

  @override
  String get medicalListLoadErrorTitle => 'Impossible de charger les archives';

  @override
  String get medicalListLoadErrorBody =>
      'Réessayez après avoir vérifié la connexion ou continuez avec le mode démo.';

  @override
  String get medicalListEmptyTitle => 'Aucun document pour l\'instant';

  @override
  String get medicalListEmptyBody =>
      'Chargez le premier compte rendu pour constituer les archives de documents.';

  @override
  String get medicalListUploadFirst => 'Charger le premier fichier';

  @override
  String medicalListSummaryAllTitle(int count) {
    return '$count documents actifs';
  }

  @override
  String medicalListSummaryPetTitle(int count, String petName) {
    return '$count documents de $petName';
  }

  @override
  String get medicalListSummaryAllBody =>
      '1 compte rendu prêt à partager, 1 examen à revoir et 1 note archivée.';

  @override
  String medicalListSummaryPetBody(String petName) {
    return 'Filtres actifs sur le profil de $petName. Ouvrez les documents les plus utiles sans fouillis.';
  }

  @override
  String get medicalListNextActionTitle => 'Prochaine action';

  @override
  String get medicalListNextActionAllBody =>
      'Ouvrez le compte rendu de vaccination de Moka et partagez-le avec Francesco.';

  @override
  String medicalListNextActionPetBody(String petName) {
    return 'Partagez le document le plus récent de $petName et conservez la note dans le profil.';
  }

  @override
  String medicalListEmptyPetTitle(String petName) {
    return 'Aucun document pour $petName';
  }

  @override
  String get medicalListEmptyPetBody =>
      'Changez de filtre ou chargez un nouveau document pour cet animal.';

  @override
  String get medicalListRemoveFilter => 'Retirer le filtre';

  @override
  String medicalFilterAll(int count) {
    return 'Tous ($count)';
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
  String get medicalStatePreviewPill => 'Aperçu';

  @override
  String get medicalStateLoadingPill => 'Chargement';

  @override
  String get medicalChecklistFormat => 'Format de fichier pris en charge';

  @override
  String get medicalChecklistMetadata => 'Métadonnées extraites';

  @override
  String get medicalChecklistLinkedPet => 'Lié à l\'animal actif';

  @override
  String get homeGreeting => 'Bonjour';

  @override
  String get homeAgendaTitle => 'Prochaines activités';

  @override
  String get homeAgendaLoadingSubtitle =>
      'Pipettes et cures, pour tous les animaux.';

  @override
  String homeAgendaSummary(int count) {
    return '$count activités dans les 10 prochains jours';
  }

  @override
  String get homeNewsTitle => 'Le saviez-vous pour vos animaux';

  @override
  String get homeNewsSubtitle =>
      'Des actualités du monde des animaux, choisies pour vous.';

  @override
  String get homeNewsUnavailable =>
      'Actualités indisponibles pour le moment. Réessayez plus tard.';

  @override
  String get homeNewsMore => 'Découvrir d\'autres actualités';

  @override
  String get homeNearbyTitle => 'Près de chez moi';

  @override
  String get homeSponsorBanner => 'Espace réservé à nos partenaires.';

  @override
  String get homeSectionLoading => 'Chargement...';

  @override
  String get shellTabHome => 'Accueil';

  @override
  String get shellTabPets => 'Animaux';

  @override
  String get shellTabActivities => 'Activités';

  @override
  String get shellTabSettings => 'Paramètres';

  @override
  String get shellRailFooter => 'Un espace clinique chaleureux';

  @override
  String get shellInterruptedWalkTitle => 'Promenade interrompue';

  @override
  String shellInterruptedWalkBody(String distance) {
    return 'Une promenade est restée en cours ($distance jusqu\'ici). Voulez-vous la reprendre ?';
  }

  @override
  String get shellInterruptedWalkDiscard => 'Abandonner';

  @override
  String get shellInterruptedWalkResume => 'Reprendre';

  @override
  String shellWalkPausedBanner(String distance) {
    return 'Promenade en pause · $distance';
  }

  @override
  String shellWalkActiveBanner(String elapsed, String distance) {
    return 'Promenade en cours · $elapsed · $distance';
  }

  @override
  String get splashMessageWalks =>
      'Enregistrez vos promenades avec votre chien !';

  @override
  String get splashMessageVet => 'Interrogez le vétérinaire virtuel, 24 h/24';

  @override
  String get splashMessageReminders =>
      'N\'oubliez plus aucune échéance : rappels et calendrier';

  @override
  String get splashMessageRecords =>
      'Gardez vos comptes rendus toujours à portée de main';

  @override
  String get splashMessageNearby =>
      'Découvrez les lieux accueillants pour les animaux près de chez vous';

  @override
  String get splashMessageNews => 'Suivez l\'actualité du monde animal';

  @override
  String get splashMessageProfiles =>
      'Un profil pour chaque ami à quatre pattes (ou à nageoires !)';

  @override
  String get splashMessageHealthBook =>
      'Le carnet de santé dans la poche, fini les papiers éparpillés';

  @override
  String get splashMessageVaccines =>
      'Vaccins, vermifuges, visites : on se charge de vous les rappeler';

  @override
  String get splashMessageSpecies =>
      'Chien, chat, lapin, perroquet ou poisson rouge : il y a de la place pour tous';

  @override
  String get sharedGuestName => 'Invité';

  @override
  String get sharedComingSoon => 'Bientôt disponible';

  @override
  String get sharedLoadingLabel => 'Chargement';

  @override
  String get sharedAttachmentTooLarge =>
      'Le fichier est trop volumineux (4 Mo max).';

  @override
  String get sharedAttachmentInvalidPdf =>
      'Ce fichier ne semble pas être un PDF valide.';

  @override
  String get sharedAiGenerated => 'Généré par l\'IA';

  @override
  String get sharedAiNotReviewed => 'Réponse automatique, non relue';

  @override
  String get petsAgeLessThanMonth => 'Moins d\'un mois';

  @override
  String petsAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '$count mois',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '$count an',
    );
    return '$_temp0';
  }

  @override
  String petsProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profils',
      one: '$count profil',
    );
    return '$_temp0';
  }

  @override
  String petsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count espèces',
      one: '$count espèce',
    );
    return '$_temp0';
  }

  @override
  String petsFishCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poissons',
      one: '$count poisson',
    );
    return '$_temp0';
  }

  @override
  String petsAquariumSummary(String species, String fish) {
    return '$species · $fish';
  }

  @override
  String get petsBreedUnspecified => 'Race non précisée';

  @override
  String get petsSpeciesUnspecified => 'Espèce non précisée';

  @override
  String petsBreedOtherWithSize(String size) {
    return 'Autre · Taille $size';
  }

  @override
  String get petsHabitatAquarium => 'Aquarium';

  @override
  String get petsHabitatTerrarium => 'Terrarium';

  @override
  String get petsHabitatAviary => 'Volière';

  @override
  String get petsHabitatGeneric => 'Habitat';

  @override
  String get petsCreateTitle => 'Créer un profil d\'animal';

  @override
  String get petsCreateLoading => 'Je prépare le formulaire de création...';

  @override
  String get petsCreateErrorTitle => 'Formulaire de création indisponible';

  @override
  String get petsCreateErrorDefault =>
      'Je n\'arrive pas à créer un nouveau profil d\'animal pour le moment.';

  @override
  String get petsCreateFormTitle => 'Nouveau profil';

  @override
  String get petsCreateSubmit => 'Enregistrer le profil';

  @override
  String get petsCreateUnsyncedSnack =>
      'Profil enregistré sur le téléphone mais pas sur le serveur. Ouvrez-le depuis la liste et touchez Réessayer.';

  @override
  String petsEditTitle(String name) {
    return 'Modifier $name';
  }

  @override
  String get petsEditLoading => 'Je charge le formulaire de modification...';

  @override
  String get petsEditErrorTitle => 'Modification indisponible';

  @override
  String get petsEditErrorDefault =>
      'Je n\'arrive pas à ouvrir ce profil d\'animal pour le modifier.';

  @override
  String get petsEditFormTitle => 'Brouillon du profil';

  @override
  String get petsEditSubmit => 'Enregistrer les modifications';

  @override
  String get petsEditUnsyncedSnack =>
      'Modifications enregistrées sur le téléphone mais pas sur le serveur. Ouvrez le profil et touchez Réessayer.';

  @override
  String get petsEditDeleteTitle => 'Supprimer ce profil ?';

  @override
  String petsEditDeleteMessage(String name) {
    return 'Le profil de « $name » sera supprimé définitivement, avec ses données.';
  }

  @override
  String get petsEditDeleteConfirm => 'Supprimer';

  @override
  String get petsEditDeleteAction => 'Supprimer le profil';

  @override
  String get petsEditMemorialTitle => 'Déplacer vers les souvenirs ?';

  @override
  String petsEditMemorialMessage(String name) {
    return '« $name » quittera la liste Animaux et sera conservé dans la section Souvenirs, avec son profil et ses photos.';
  }

  @override
  String get petsEditMemorialConfirm => 'Déplacer';

  @override
  String get petsEditMemorialAction => 'Déplacer vers les souvenirs';

  @override
  String get petsFormAddSpecies => 'Ajouter une espèce';

  @override
  String get petsFormIdentityColor => 'Couleur d\'identification';

  @override
  String get petsFormNameLabel => 'Nom';

  @override
  String get petsFormNameHint => 'Moka';

  @override
  String get petsFormNameError => 'Saisissez le nom de l\'animal.';

  @override
  String get petsFormSpeciesLabel => 'Type d\'animal';

  @override
  String get petsFormSpeciesHint => 'Choisir le type d\'animal';

  @override
  String get petsFormSpeciesError => 'Sélectionnez le type d\'animal.';

  @override
  String get petsFormProfileType => 'Que souhaitez-vous enregistrer ?';

  @override
  String get petsFormFishSingleTitle => 'Poisson';

  @override
  String get petsFormFishSingleBody =>
      'Un seul poisson, choisi par espèce (ex. combattant, poisson rouge)';

  @override
  String get petsFormFishAquariumBody =>
      'Un aquarium avec plusieurs espèces et plusieurs individus, mâles et femelles';

  @override
  String get petsFormAquariumPopulation => 'Population de l\'aquarium';

  @override
  String get petsFormNoSpeciesYet => 'Aucune espèce ajoutée pour l\'instant.';

  @override
  String get petsFormAquariumNeedsSpecies =>
      'Ajoutez au moins une espèce à l\'aquarium.';

  @override
  String get petsFormBreedLabel => 'Race';

  @override
  String get petsFormBreedSelectSpeciesFirst =>
      'Sélectionnez d\'abord le type d\'animal';

  @override
  String get petsFormBreedSpeciesLabel => 'Espèce';

  @override
  String get petsFormBreedRequired => 'Choisissez la race.';

  @override
  String get petsFormBreedSpeciesRequired => 'Choisissez l\'espèce.';

  @override
  String get petsFormBreedTextRequired => 'Saisissez la race.';

  @override
  String get petsFormBreedSpeciesTextRequired => 'Saisissez l\'espèce.';

  @override
  String get petsFormBreedSpeciesPlaceholder => 'Sélectionnez une espèce';

  @override
  String get petsFormOtherSpeciesDialogTitle => 'Quelle espèce ?';

  @override
  String get petsFormBreedPlaceholder => 'Sélectionnez une race';

  @override
  String get petsFormBreedSearchHint => 'Rechercher une race';

  @override
  String get petsFormBreedSearchHintScientific =>
      'Rechercher (aussi par nom scientifique)';

  @override
  String get petsFormOtherBreedLabel => 'Quelle race ?';

  @override
  String get petsFormOtherBreedHint => 'Ex. croisé caniche';

  @override
  String get petsFormOtherSpeciesLabel => 'Quelle espèce ?';

  @override
  String get petsFormOtherSpeciesHint => 'Ex. nom courant ou scientifique';

  @override
  String get petsFormDogSizeLabel => 'Taille (facultative)';

  @override
  String get petsFormDogSizeHint => 'Sélectionnez une taille';

  @override
  String get petsFormBirthDateLabel => 'Date de naissance';

  @override
  String get petsFormBirthDateHint => 'jj/mm/aaaa';

  @override
  String get petsFormBirthDateRequired => 'Sélectionnez la date de naissance.';

  @override
  String get petsFormBirthDateInvalid => 'Date non valide (jj/mm/aaaa).';

  @override
  String get petsFormBirthDateFuture =>
      'La date de naissance ne peut pas être dans le futur.';

  @override
  String get petsFormSexLabel => 'Sexe';

  @override
  String get petsFormSexHint => 'Sélectionnez';

  @override
  String get petsFormSexUnknown => 'Inconnu';

  @override
  String get petsFormWeightLabelKg => 'Poids (facultatif, kg)';

  @override
  String get petsFormWeightLabelLb => 'Poids (facultatif, lb)';

  @override
  String get petsFormWeightHintKg => 'Ex. 18,4';

  @override
  String get petsFormWeightLabelG => 'Poids (facultatif, g)';

  @override
  String get petsFormWeightHintG => 'Ex. 35';

  @override
  String get petsFormWeightHintLb => 'Ex. 40,5';

  @override
  String get petsFormWeightInvalid => 'Saisissez un poids valide.';

  @override
  String get petsFormWeightPositive => 'Le poids doit être supérieur à zéro.';

  @override
  String get petsFormNotesLabel => 'Notes';

  @override
  String get petsFormNotesHint =>
      'Ajoutez de courtes notes sur l\'alimentation, les traitements ou le comportement.';

  @override
  String get petsFormSaving => 'Enregistrement en cours…';

  @override
  String get petsFormPhotoAdd => 'Ajouter une photo';

  @override
  String get petsFormPhotoChange => 'Changer la photo';

  @override
  String get petsFormPhotoRemove => 'Retirer';

  @override
  String get petsFormHabitatLength => 'Longueur';

  @override
  String get petsFormHabitatWidth => 'Largeur';

  @override
  String get petsFormHabitatHeight => 'Hauteur';

  @override
  String get petsFormHabitatUsGallons => 'Gallons US';

  @override
  String get petsFormHabitatLiters => 'Litres';

  @override
  String get petsFormHabitatVolumeHint =>
      'Calculés à partir des dimensions, modifiables';

  @override
  String get petsFormHabitatTemperature => 'Température';

  @override
  String get petsFormHabitatTemperatureHintF => 'Ex. 75-79 °F';

  @override
  String get petsFormHabitatTemperatureHintC => 'Ex. 24-26 °C';

  @override
  String get petsFormHabitatSubstrate => 'Substrat';

  @override
  String get petsFormHabitatSubstrateHint => 'Ex. gravier fin, fibre de coco';

  @override
  String get petsFormHabitatEquipment => 'Équipement';

  @override
  String get petsFormHabitatEquipmentHint =>
      'Filtre, éclairage, chauffage, plantes, lampe UVB, perchoirs...';

  @override
  String get petsDetailTitleFallback => 'Fiche de l\'animal';

  @override
  String get petsDetailGalleryTooltip => 'Galerie photos';

  @override
  String get petsDetailLoading => 'Je charge la fiche de l\'animal...';

  @override
  String get petsDetailErrorTitle => 'Fiche de l\'animal indisponible';

  @override
  String get petsDetailErrorDefault =>
      'Ce profil d\'animal n\'est pas disponible pour le moment.';

  @override
  String get petsDetailBackToList => 'Retour à la liste';

  @override
  String get petsDetailEmptyTitle => 'Aucun animal sélectionné';

  @override
  String get petsDetailEmptySubtitle =>
      'Choisissez un profil dans la liste pour voir les détails, les chats et les comptes rendus.';

  @override
  String get petsDetailTabReminders => 'Rappels';

  @override
  String get petsDetailTabChat => 'Chat';

  @override
  String get petsDetailTabRecords => 'Documents';

  @override
  String get petsDetailTabWalks => 'Promenades';

  @override
  String get petsDetailHabitatTapForDetails => 'Touchez pour les détails';

  @override
  String get petsDetailHabitatDimensions => 'Dimensions';

  @override
  String get petsDetailHabitatVolume => 'Volume';

  @override
  String get petsDetailPopulation => 'Population';

  @override
  String get petsDetailRemindersNew => 'Nouveau rappel';

  @override
  String petsDetailRemindersEmpty(String petName) {
    return 'Aucun rappel pour $petName pour l\'instant.';
  }

  @override
  String get petsDetailChatNew => 'Nouveau chat';

  @override
  String petsDetailChatEmpty(String petName) {
    return 'Aucune conversation pour $petName pour l\'instant.';
  }

  @override
  String petsDetailChatDeleteFailed(String error) {
    return 'Chat retiré ici, mais pas sur le serveur : $error';
  }

  @override
  String get petsDetailChatDeleteTitle => 'Supprimer ce chat ?';

  @override
  String petsDetailChatDeleteMessage(String title) {
    return '« $title » sera supprimé définitivement.';
  }

  @override
  String get petsDetailChatLimitTitle => 'Limite de chats atteinte';

  @override
  String petsDetailChatLimitMessage(int max, String petName) {
    return 'Vous pouvez avoir au maximum $max conversations actives pour $petName. Supprimez un chat existant pour en ouvrir un nouveau.';
  }

  @override
  String get petsDetailChatLimitOk => 'J\'ai compris';

  @override
  String get petsDetailRecordsSendTitle => 'Envoyer un fichier';

  @override
  String get petsDetailRecordsSendSubtitle =>
      'Choisissez un document à envoyer par e-mail, WhatsApp ou autre.';

  @override
  String petsDetailRecordShareText(String title, String source, String date) {
    return '📄 $title\n$source · $date\n\nPartagé via VetApp';
  }

  @override
  String get petsDetailShareUnavailable =>
      'Partage indisponible sur cet appareil.';

  @override
  String get petsDetailRecordsUpload => 'Charger un fichier';

  @override
  String get petsDetailRecordsSend => 'Envoyer';

  @override
  String petsDetailRecordsEmpty(String petName) {
    return 'Aucun document pour $petName pour l\'instant.';
  }

  @override
  String get petsDetailRecordsLoadError =>
      'Je n\'arrive pas à lire les comptes rendus. Vérifiez votre connexion et réessayez.';

  @override
  String petsDetailSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '$count sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get petsDetailWalksStart => 'Démarrer une promenade';

  @override
  String get petsDetailWalksBadges => 'Badges';

  @override
  String petsDetailWalksEmpty(String petName) {
    return 'Aucune promenade pour $petName pour l\'instant.';
  }

  @override
  String get petsDetailWalksRecords => 'Records 🏆';

  @override
  String get petsDetailWalksFavorites => 'Favorites ⭐';

  @override
  String get petsDetailWalksRecent => 'Récentes';

  @override
  String get petsDetailWalkLongest => 'La plus longue';

  @override
  String get petsDetailWalkLongestDuration => 'La plus durable';

  @override
  String get petsDetailWalkLongestAndDuration =>
      'La plus longue · La plus durable';

  @override
  String petsDetailWalkStatusActive(String distance, String elapsed) {
    return 'Promenade en cours · $distance · $elapsed';
  }

  @override
  String petsDetailWalkStatusPaused(String distance, String elapsed) {
    return 'En pause · $distance · $elapsed';
  }

  @override
  String get petsDetailWalkUnfavoriteTitle => 'Retirer des favorites ?';

  @override
  String get petsDetailWalkUnfavoriteMessage =>
      'Si ce n\'est pas aussi le record ni l\'une des 3 dernières promenades, elle pourra perdre sa carte lors du prochain nettoyage automatique.';

  @override
  String get petsDetailWalkUnfavoriteConfirm => 'Retirer des favorites';

  @override
  String get petsDetailWalkDeleteTitle => 'Supprimer cette promenade ?';

  @override
  String petsDetailWalkDeleteMessage(String date, String distance) {
    return 'La promenade du $date ($distance) sera supprimée définitivement.';
  }

  @override
  String petsDetailWalkSteps(int count) {
    return '~$count pas';
  }

  @override
  String get petsDetailUnsyncedBanner =>
      'Non synchronisé : les modifications ne sont que sur ce téléphone.';

  @override
  String get petsDetailUnsyncedRetryFailed =>
      'Toujours pas de liaison avec le serveur. Réessayez plus tard.';

  @override
  String get petsScaffoldBadge => 'Animal';

  @override
  String get petsLoadingDefaultLabel => 'Chargement de l\'animal...';

  @override
  String get petsLoadingSubtitle =>
      'Patientez un instant, nous préparons l\'écran.';

  @override
  String get petsDemoDeleteFailed =>
      'Je n\'ai pas pu supprimer le profil. Réessayez.';

  @override
  String get petsDemoNewProfileNote =>
      'Profil créé récemment, prêt pour la prochaine visite.';

  @override
  String get petsDemoNextVisitToPlan => 'À planifier';

  @override
  String get petsValueSpeciesDog => 'Chien';

  @override
  String get petsValueSpeciesCat => 'Chat';

  @override
  String get petsValueSpeciesSmallMammals => 'Petits mammifères';

  @override
  String get petsValueSpeciesBird => 'Oiseau';

  @override
  String get petsValueSpeciesReptiles => 'Reptiles et amphibiens';

  @override
  String get petsValueSpeciesFish => 'Poisson';

  @override
  String get petsValueSpeciesOther => 'Autre';

  @override
  String get petsValueSpeciesAll => 'Tous';

  @override
  String get petsValueSexMale => 'Mâle';

  @override
  String get petsValueSexFemale => 'Femelle';

  @override
  String get petsValueSexMaleIntact => 'Mâle entier';

  @override
  String get petsValueSexMaleNeutered => 'Mâle castré';

  @override
  String get petsValueSexFemaleIntact => 'Femelle entière';

  @override
  String get petsValueSexFemaleSpayed => 'Femelle stérilisée';

  @override
  String get petsValueDogSizeToy => 'Toy';

  @override
  String get petsValueDogSizeSmall => 'Petite';

  @override
  String get petsValueDogSizeMedium => 'Moyenne';

  @override
  String get petsValueDogSizeLarge => 'Grande';

  @override
  String get petsValueDogSizeGiant => 'Géante';

  @override
  String get petsListTitle => 'Animaux';

  @override
  String get petsListMemoriesTooltip => 'Souvenirs';

  @override
  String get petsListLoading => 'Je charge la liste des animaux...';

  @override
  String get petsListErrorTitle => 'Animaux indisponibles';

  @override
  String get petsListErrorDefault =>
      'Je n\'arrive pas à charger les profils d\'animaux pour le moment.';

  @override
  String get petsListEmptyTitle => 'Aucun animal pour l\'instant';

  @override
  String get petsListEmptySubtitle =>
      'Créez le premier profil pour suivre la santé, les notes et les échéances.';

  @override
  String get petsListEmptyAction => 'Ajouter un animal';

  @override
  String get petsListFilterEmpty => 'Aucun animal pour ce filtre.';

  @override
  String get petsMemoriesRemoveTitle => 'Supprimer définitivement ?';

  @override
  String petsMemoriesRemoveBody(String name) {
    return 'Le souvenir de « $name » sera supprimé, sans possibilité de récupération.';
  }

  @override
  String get petsMemoriesRemoveConfirm => 'Supprimer';

  @override
  String get petsMemoriesTitle => 'Souvenirs';

  @override
  String get petsMemoriesSubtitle =>
      'Les profils des animaux qui ont partagé votre chemin.';

  @override
  String get petsMemoriesEmpty => 'Aucun souvenir conservé pour l\'instant.';

  @override
  String petsMemoriesWithUsUntil(String date) {
    return 'Avec nous jusqu\'au $date';
  }

  @override
  String petsMemoriesWithUsRange(String from, String to) {
    return 'Avec nous du $from au $to';
  }

  @override
  String get petsMemoriesComingSoon =>
      'Bientôt : vos plus beaux moments ensemble, comme les plus longues promenades ou les objectifs atteints, réunis ici.';

  @override
  String get petsMediaGalleryTitle => 'Galerie';

  @override
  String get petsMediaFoldersLoading => 'Je charge les dossiers…';

  @override
  String get petsMediaFoldersEmpty =>
      'Ajoutez un animal pour créer son dossier de photos.';

  @override
  String get petsMediaFolderCounting => 'Je compte les photos…';

  @override
  String petsMediaCountPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
    );
    return '$_temp0';
  }

  @override
  String petsMediaCountPhotosAndVideos(String photos, String videos) {
    return '$photos · $videos';
  }

  @override
  String get petsMediaVideoSemantics => 'Vidéo';

  @override
  String get petsMediaDeleteVideoTitle => 'Supprimer cette vidéo ?';

  @override
  String get petsMediaDeletePhotoTitle => 'Supprimer cette photo ?';

  @override
  String get petsMediaDeleteVideoBody =>
      'La vidéo sera définitivement retirée de la galerie.';

  @override
  String get petsMediaDeletePhotoBody =>
      'La photo sera définitivement retirée de la galerie.';

  @override
  String get petsMediaOperationFailed =>
      'Je n\'ai pas pu terminer l\'opération. Réessayez.';

  @override
  String get petsMediaSetAsProfile => 'Définir comme photo de profil';

  @override
  String get petsMediaDeleteVideoAction => 'Supprimer la vidéo';

  @override
  String get petsMediaDeletePhotoAction => 'Supprimer la photo';

  @override
  String get petsMediaImportFromGallery => 'Importer depuis la galerie';

  @override
  String get petsMediaImportFromGalleryHint =>
      'Photos et vidéos, plusieurs à la fois';

  @override
  String get petsMediaTakePhoto => 'Prendre une photo';

  @override
  String get petsMediaRecordVideo => 'Filmer une vidéo';

  @override
  String petsMediaRecordVideoLimit(int seconds) {
    return 'Jusqu\'à $seconds secondes';
  }

  @override
  String petsMediaGalleryOf(String name) {
    return 'Galerie de $name';
  }

  @override
  String get petsMediaGalleryEmpty =>
      'Aucune photo ni vidéo pour l\'instant. Utilisez le bouton « Ajouter » ci-dessous.';

  @override
  String get petsMediaVideoPlaybackFailed =>
      'Je n\'arrive pas à lire cette vidéo.';

  @override
  String get petsMediaVideoLoading => 'Chargement de la vidéo...';

  @override
  String get petsMediaCancelling => 'Annulation...';

  @override
  String get petsMediaPreparingFile => 'Préparation du fichier...';

  @override
  String petsMediaPreparingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Préparation de $count fichiers...',
      one: 'Préparation du fichier...',
    );
    return '$_temp0';
  }

  @override
  String get petsMediaUploadingFile => 'Chargement du fichier...';

  @override
  String petsMediaUploadingProgress(int current, int total) {
    return 'Chargement de $current sur $total...';
  }

  @override
  String get petsMediaUploadingVideo => 'Chargement de la vidéo...';

  @override
  String petsMediaUploadingVideoOf(int current, int total) {
    return 'Chargement de la vidéo $current sur $total...';
  }

  @override
  String petsMediaReducingVideo(int percent) {
    return 'Réduction de la vidéo... $percent %';
  }

  @override
  String petsMediaReducingVideoOf(int current, int total, int percent) {
    return 'Réduction de la vidéo $current sur $total... $percent %';
  }

  @override
  String petsMediaImportJoin(String first, String second) {
    return '$first et $second';
  }

  @override
  String petsMediaImportDone(String list) {
    return 'Chargés : $list';
  }

  @override
  String get petsMediaImportCancelled => 'Chargement annulé.';

  @override
  String petsMediaImportCancelledWith(String done) {
    return 'Chargement annulé. $done.';
  }

  @override
  String get petsMediaImportNothingToAdd => 'Rien à ajouter.';

  @override
  String petsMediaImportProblemMore(String problem, int count) {
    return '$problem ($count autres non ajoutés)';
  }

  @override
  String petsMediaImportDoneWithProblem(String done, String problem) {
    return '$done. $problem';
  }

  @override
  String petsMediaPhotoAddedTo(String name) {
    return 'Photo ajoutée à la galerie de $name';
  }

  @override
  String petsMediaVideoAddedTo(String name) {
    return 'Vidéo ajoutée à la galerie de $name';
  }

  @override
  String petsMediaImportFileFailed(String file) {
    return 'Je n\'ai pas pu charger $file.';
  }

  @override
  String get petsMediaImportUnnamedFile => 'un fichier';

  @override
  String get petsMediaPhotoSaveOffline =>
      'L\'enregistrement des photos n\'est pas disponible hors connexion.';

  @override
  String get petsMediaVideoSaveOffline =>
      'L\'enregistrement des vidéos n\'est pas disponible hors connexion.';

  @override
  String petsMediaImportRefused(String file, String message) {
    return '$file : $message';
  }

  @override
  String get petsMediaVideoUnsupportedFormat =>
      'Format vidéo non pris en charge : utilisez un fichier MP4 ou MOV.';

  @override
  String petsMediaVideoTooBigSource(int size, int max) {
    return 'Vidéo trop lourde ($size Mo) : le maximum est de $max Mo.';
  }

  @override
  String petsMediaVideoTooBigBrowser(int size, int max) {
    return 'Vidéo trop lourde ($size Mo) : depuis le navigateur, le maximum est de $max Mo. Depuis l\'application sur téléphone, les vidéos sont réduites automatiquement.';
  }

  @override
  String get petsMediaVideoUnreadable => 'Je n\'arrive pas à lire cette vidéo.';

  @override
  String petsMediaVideoTooLong(int seconds) {
    return 'Vidéo trop longue : le maximum est de $seconds secondes.';
  }

  @override
  String petsMediaVideoTooBigReduced(int size, int max) {
    return 'Même réduite, la vidéo pèse $size Mo (maximum $max Mo) : essayez avec un clip plus court.';
  }

  @override
  String petsMediaVideoTooBigNotReduced(int size, int max) {
    return 'Je n\'ai pas pu réduire la vidéo et elle pèse $size Mo (maximum $max Mo) : essayez avec un clip plus court.';
  }

  @override
  String petsConsentSemanticsExpanded(String name) {
    return 'Consentement à la lecture du dossier médical de $name. Touchez pour masquer le texte complet';
  }

  @override
  String petsConsentSemanticsCollapsed(String name) {
    return 'Consentement à la lecture du dossier médical de $name. Touchez pour lire le texte complet';
  }

  @override
  String petsConsentCardTitle(String name) {
    return 'Dossier médical de $name';
  }

  @override
  String get petsConsentReadHow => 'Lire comment il est utilisé';

  @override
  String petsConsentSwitchSemantics(String name) {
    return 'Autoriser l\'assistant à lire le dossier médical de $name';
  }

  @override
  String get petsConsentWithoutConsent =>
      'Sans consentement, l\'assistant ne voit ni les titres ni le contenu des comptes rendus.';

  @override
  String get petsConsentSaveFailed =>
      'Je n\'ai pas pu enregistrer le consentement. Réessayez.';

  @override
  String get petsConsentStatusUnavailable =>
      'État du consentement indisponible : vérifiez votre connexion.';

  @override
  String get petsConsentSlowConnection =>
      'Connexion lente. Le consentement n\'a pas été enregistré, réessayez.';

  @override
  String get petsConsentOffline =>
      'Vous êtes hors ligne : le consentement n\'a pas été enregistré. Réessayez une fois connecté.';

  @override
  String get placesDetailBarrierFence => 'Clôturé';

  @override
  String get placesDetailBarrierWall => 'Entouré d\'un mur';

  @override
  String get placesDetailBarrierHedge => 'Délimité par une haie';

  @override
  String get placesDetailSurfaceGrass => 'Sol herbeux';

  @override
  String get placesDetailSurfaceGround => 'Sol en terre';

  @override
  String get placesDetailSurfaceSand => 'Sol sableux';

  @override
  String get placesDetailSurfaceGravel => 'Sol en gravier';

  @override
  String get placesDetailSurfaceAsphalt => 'Sol goudronné';

  @override
  String get placesDetailSurfacePaved => 'Sol pavé';

  @override
  String get placesDetailAccessFree => 'Accès libre';

  @override
  String get placesDetailAccessPermissive => 'Accès autorisé';

  @override
  String get placesDetailAccessCustomers => 'Réservé aux clients';

  @override
  String get placesDetailAccessPrivate => 'Zone privée';

  @override
  String get placesDetailWheelchairYes => 'Accessible en fauteuil roulant';

  @override
  String get placesDetailWheelchairLimited =>
      'Accessibilité partielle en fauteuil roulant';

  @override
  String get placesDetailWheelchairNo => 'Non accessible en fauteuil roulant';

  @override
  String get placesDetailDrinkingWaterYes => 'Eau potable';

  @override
  String get placesDetailDrinkingWaterNo => 'Pas d\'eau potable';

  @override
  String get placesDetailLitYes => 'Éclairé';

  @override
  String get placesDetailLitNo => 'Non éclairé';

  @override
  String get placesDetailDogUnleashed => 'Chiens en liberté sans laisse';

  @override
  String get placesDetailAdoptionYes => 'Adoptions possibles';

  @override
  String get placesDetailAdoptionNo => 'Ne propose pas d\'adoptions';

  @override
  String placesPendingDogPark(String progress) {
    return 'Signalé par les utilisateurs, vérifiez qu\'il s\'agit d\'un espace public ($progress)';
  }

  @override
  String placesPendingPlace(String progress) {
    return 'Signalé par les utilisateurs · en attente de confirmation ($progress)';
  }

  @override
  String placesMailRemoveSubject(String id) {
    return 'Parc canin à retirer du radar ($id)';
  }

  @override
  String placesMailRemoveBody(String name, String position, String id) {
    return 'Cet espace signalé par les utilisateurs n\'est pas un parc canin public.\n\nNom : $name\nPosition : $position\nIdentifiant : $id\n\nMotif : ';
  }

  @override
  String get placesWithdrawTitle => 'Retirer le signalement ?';

  @override
  String get placesWithdrawBody =>
      'Le signalement est supprimé et ne sera plus visible de personne.';

  @override
  String get placesWithdrawConfirm => 'Retirer';

  @override
  String get placesWithdrawnSnack => 'Signalement retiré.';

  @override
  String get placesVoteConfirmedSnack => 'Merci, confirmation enregistrée.';

  @override
  String get placesVoteDeniedSnack => 'Merci, c\'est noté.';

  @override
  String placesRatedSnack(int stars) {
    return 'Note enregistrée : $stars sur 5.';
  }

  @override
  String get placesReportsInactiveSnack =>
      'Les signalements ne sont pas actifs pour le moment.';

  @override
  String get placesReportProblemTitle =>
      'Qu\'est-ce qui ne va pas avec ce lieu ?';

  @override
  String get placesReportAlreadyKnown =>
      'Il avait déjà été signalé : votre signalement vaut confirmation.';

  @override
  String get placesReportSent =>
      'Signalement envoyé. Il sera appliqué lorsque d\'autres utilisateurs l\'auront confirmé.';

  @override
  String get placesSheetPendingQuestion => 'Ce lieu existe-t-il vraiment ici ?';

  @override
  String get placesSheetNotPublicWrite =>
      'Ce n\'est pas un espace public ? Écrivez-nous';

  @override
  String placesSheetClosedReported(String progress) {
    return 'Signalé comme fermé ($progress)';
  }

  @override
  String get placesSheetClosedQuestion => 'A-t-il vraiment fermé ?';

  @override
  String placesSheetOpeningHours(String hours) {
    return 'Horaires indiqués : $hours';
  }

  @override
  String get placesActionCall => 'Appeler';

  @override
  String get placesActionDirections => 'Itinéraire';

  @override
  String get placesActionWebsite => 'Site web';

  @override
  String get placesDisclaimerCommunity =>
      'Lieu signalé par les utilisateurs : ce n\'est pas une garantie, vérifiez avant de vous y rendre.';

  @override
  String get placesDisclaimerClinic =>
      'En cas d\'urgence, téléphonez avant de partir : les horaires et les coordonnées proviennent de bases ouvertes et ne sont pas vérifiés par VetApp.';

  @override
  String get placesDisclaimerGeneric =>
      'Les horaires et les coordonnées proviennent de bases ouvertes et ne sont pas vérifiés par VetApp.';

  @override
  String placesSourceLine(String source) {
    return 'Source : $source';
  }

  @override
  String placesAlsoIn(String sources) {
    return 'Également présent dans : $sources';
  }

  @override
  String get placesReportProblemAction => 'Signaler un problème';

  @override
  String get placesBannerWithdrawing => 'Retrait du signalement…';

  @override
  String get placesBannerYouReported =>
      'C\'est vous qui l\'avez signalé : il faut des confirmations d\'autres utilisateurs.';

  @override
  String get placesBannerConfirmedSaving =>
      'Vous avez confirmé. Enregistrement…';

  @override
  String get placesBannerConfirmedChange =>
      'Vous avez confirmé. Vous pouvez changer d\'avis.';

  @override
  String get placesBannerDeniedSaving =>
      'Vous avez indiqué que ce n\'est pas le cas. Enregistrement…';

  @override
  String get placesBannerDeniedChange =>
      'Vous avez indiqué que ce n\'est pas le cas. Vous pouvez changer d\'avis.';

  @override
  String get placesBannerWithdrawButton => 'Retirer mon signalement';

  @override
  String get placesBannerConfirm => 'Je confirme';

  @override
  String get placesBannerDeny => 'Ce n\'est pas le cas';

  @override
  String placesVotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '$_temp0';
  }

  @override
  String placesRatingAverage(String average, String votes) {
    return 'Note de la communauté : $average sur 5 · $votes';
  }

  @override
  String get placesRatingNone =>
      'Note de la communauté : aucun vote pour l\'instant';

  @override
  String placesRatingBelowThreshold(String votes) {
    return 'Note de la communauté : $votes · la moyenne s\'affiche à partir de 3 votes';
  }

  @override
  String placesRateStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Donner $count étoiles',
      one: 'Donner $count étoile',
    );
    return '$_temp0';
  }

  @override
  String placesRatingSaving(int stars) {
    return 'Votre note : $stars sur 5. Enregistrement…';
  }

  @override
  String placesRatingYours(int stars) {
    return 'Votre note : $stars sur 5. Touchez une étoile pour la modifier.';
  }

  @override
  String get placesRatingPrompt =>
      'Comment est ce parc canin ? Touchez une étoile pour donner votre note.';

  @override
  String get placesExpiryToday =>
      'Expire aujourd\'hui si personne ne confirme.';

  @override
  String placesExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expire dans $days jours si personne ne confirme.',
      one: 'Expire dans $days jour si personne ne confirme.',
    );
    return '$_temp0';
  }

  @override
  String get placesProblemClosed => 'Il a fermé ou n\'existe plus';

  @override
  String get placesProblemDuplicate => 'C\'est un doublon d\'un autre lieu';

  @override
  String get placesProblemWrongPosition => 'La position est erronée';

  @override
  String get placesCategoryVeterinary => 'Vétérinaires';

  @override
  String get placesCategoryShop => 'Magasins';

  @override
  String get placesCategoryDogPark => 'Parcs canins';

  @override
  String get placesCategoryShelter => 'Refuges et adoptions';

  @override
  String get placesCategoryAssociation => 'Associations';

  @override
  String get placesCategoryGrooming => 'Toiletteurs';

  @override
  String get placesCategoryHotel => 'Pensions';

  @override
  String get placesCategorySchool => 'Éducation canine';

  @override
  String get placesCategoryPetSitting => 'Pet-sitters';

  @override
  String get placesCategoryBreeder => 'Élevages';

  @override
  String get placesCategoryOther => 'Autres services';

  @override
  String get placesTypeVeterinary => 'Vétérinaire';

  @override
  String get placesTypeGrooming => 'Toilettage';

  @override
  String get placesTypeShop => 'Animalerie';

  @override
  String get placesTypeSchool => 'Éducation canine';

  @override
  String get placesTypePetSitting => 'Pet-sitter';

  @override
  String get placesTypeBreeder => 'Élevage';

  @override
  String get placesTypeHotel => 'Pension pour animaux';

  @override
  String get placesTypeDogPark => 'Parc canin';

  @override
  String get placesTypeShelter => 'Refuge pour animaux';

  @override
  String get placesTypeAssociation => 'Association pour animaux';

  @override
  String get placesTypeOther => 'Service pour animaux';

  @override
  String get placesHours247 => 'Indiqué comme ouvert 24 h/24';

  @override
  String get placesHoursHolidays => 'Jours fériés';

  @override
  String get placesHoursClosed => 'fermé';

  @override
  String get placesSourcesTitle => 'Sources des données';

  @override
  String get placesSourcesIntro =>
      'Les lieux du radar proviennent de bases ouvertes, pas de VetApp. Chaque fiche indique sa source. Les horaires et les coordonnées peuvent ne pas être à jour.';

  @override
  String get placesSourcesNoContact =>
      'Vous avez trouvé une donnée erronée ? Utilisez « Signaler un problème » dans la fiche du lieu.';

  @override
  String placesSourcesContact(String email) {
    return 'Vous avez trouvé une donnée erronée, ou vous êtes le propriétaire et souhaitez qu\'une fiche soit corrigée ou retirée ? Écrivez à $email.';
  }

  @override
  String placesSourceLicense(String license) {
    return 'Licence : $license';
  }

  @override
  String placesSourceVersion(String release, String date) {
    return 'Version $release, importée le $date';
  }

  @override
  String get placesSourceLicenseLink => 'Licence et conditions';

  @override
  String get placesSourceOsmDescription =>
      'Carte libre entretenue par des bénévoles. Source des parcs canins et d\'une partie des vétérinaires, magasins et autres services, avec les détails indiqués par les bénévoles.';

  @override
  String get placesSourceOvertureDescription =>
      'Base ouverte d\'établissements commerciaux. Source de vétérinaires, toiletteurs, magasins, pensions et éducateurs que OpenStreetMap ne connaît pas.';

  @override
  String get placesSourceBolognaDescription =>
      'Liste officielle des espaces d\'ébats pour chiens de la commune de Bologne.';

  @override
  String get placesSourceTorinoDescription =>
      'Liste officielle des parcs canins de la ville de Turin.';

  @override
  String get placesSourceMilanoDescription =>
      'Liste officielle des parcs canins de la commune de Milan.';

  @override
  String get placesSourceBolognaAttribution =>
      'Comune di Bologna, Aree sgambatura cani (opendata.comune.bologna.it), licence CC BY 4.0';

  @override
  String get placesSourceTorinoAttribution =>
      'Comune di Torino, Aree Cani (aperto.comune.torino.it), licence CC BY 4.0, données de 2019';

  @override
  String get placesSourceMilanoAttribution =>
      'Comune di Milano, Territorio: localizzazione delle aree cani (dati.comune.milano.it), licence CC BY 4.0. Contient des traitements de données CC BY 3.0 issues de dati.gov.it';

  @override
  String get placesSourceLicenseCcBy =>
      'Creative Commons Attribution 4.0 (CC BY 4.0)';

  @override
  String get placesSourceUsersName => 'Utilisateurs VetApp';

  @override
  String get placesSourceUsersDescription =>
      'Lieux signalés par les utilisateurs et confirmés par d\'autres utilisateurs.';

  @override
  String get placesSourceUsersAttribution =>
      'Signalé par les utilisateurs VetApp';

  @override
  String placesMapTitle(String radius) {
    return 'Carte · $radius';
  }

  @override
  String placesMapClusterSemantics(int count) {
    return '$count lieux proches les uns des autres';
  }

  @override
  String placesMapMarkerPending(String category, String label) {
    return '$category, en attente de confirmation : $label';
  }

  @override
  String placesMapMarker(String category, String label) {
    return '$category : $label';
  }

  @override
  String get placesReportTitle => 'Signaler un lieu manquant';

  @override
  String get placesReportUnavailable =>
      'Les signalements ne sont pas disponibles pour le moment. Réessayez plus tard.';

  @override
  String get placesReportWhatIs => 'De quoi s\'agit-il ?';

  @override
  String get placesReportNameOptional => 'Nom (facultatif)';

  @override
  String get placesReportNameLabel => 'Nom sur l\'enseigne';

  @override
  String get placesReportNameHelper =>
      'Seulement le nom : ni téléphone, ni adresse, ni nom de personne.';

  @override
  String get placesReportWhere => 'Où se trouve-t-il ?';

  @override
  String get placesReportMapHint =>
      'Déplacez la carte jusqu\'à ce que le repère soit sur le lieu. L\'adresse est déduite de la position.';

  @override
  String get placesReportSubmit => 'Envoyer le signalement';

  @override
  String placesReportFootnote(int days) {
    return 'Le signalement sera visible de tous comme « en attente de confirmation » et deviendra définitif lorsque d\'autres utilisateurs l\'auront confirmé. Si personne ne le confirme sous $days jours, il est supprimé automatiquement. Vous pouvez le retirer à tout moment depuis sa fiche. Votre nom n\'apparaît pas.';
  }

  @override
  String placesReportSentExpiry(int days) {
    return 'Signalement envoyé. Si personne ne le confirme sous $days jours, il est supprimé.';
  }

  @override
  String get placesRulesTitle => 'Avant de signaler ou de voter';

  @override
  String get placesRulesCheckbox =>
      'J\'ai lu les règles et je signale ou je vote de bonne foi.';

  @override
  String get placesRulesAccept => 'J\'accepte';

  @override
  String get placesRulesFallback =>
      'Ne signalez que ce que vous avez vérifié en personne. Pour les établissements, indiquez uniquement le nom de l\'enseigne, sans téléphone, adresse privée ni données d\'autres personnes. Les signalements restent en attente tant que d\'autres utilisateurs ne les ont pas confirmés. Des signalements faux ou répétés peuvent entraîner la suspension du compte. Les signalements et les votes sont publiés sans votre nom.';

  @override
  String get placesErrSignedOutContribute =>
      'Connectez-vous pour signaler ou voter.';

  @override
  String get placesErrOperationFailed =>
      'Je n\'ai pas pu terminer l\'opération. Réessayez.';

  @override
  String get placesErrTimeout => 'La requête a pris trop de temps. Réessayez.';

  @override
  String get placesErrNotConfigured =>
      'Aperçu sans serveur : les lieux affichés sont des données d\'exemple.';

  @override
  String get placesErrSignedOut =>
      'Connectez-vous pour voir les services pour animaux près de chez vous.';

  @override
  String get placesErrPreparing =>
      'Je prépare encore les services de cette zone. Réessayez dans un instant.';

  @override
  String get placesErrSessionExpired =>
      'La session n\'est plus valide : déconnectez-vous puis reconnectez-vous pour voir les services à proximité.';

  @override
  String get placesErrLoadFailed =>
      'Je n\'ai pas pu charger les services à proximité. Réessayez.';

  @override
  String get placesBackendRulesRequired =>
      'Pour signaler ou voter, acceptez d\'abord les règles des signalements et des votes.';

  @override
  String get placesBackendReportClosed => 'Ce signalement est déjà clos.';

  @override
  String get placesBackendReportExpired =>
      'Ce signalement a expiré : personne ne l\'a confirmé.';

  @override
  String get placesBackendOwnReportVote =>
      'Vous ne pouvez pas confirmer votre propre signalement.';

  @override
  String get placesBackendKindNotActive =>
      'Ce type de signalement n\'est pas actif.';

  @override
  String get placesBackendCategoryNotReportable =>
      'Cette catégorie ne peut pas être signalée.';

  @override
  String get placesBackendTargetRequired =>
      'Indiquez le lieu concerné par le signalement.';

  @override
  String get placesBackendPendingUseDeny =>
      'Pour un lieu en attente de confirmation, utilisez « Ce n\'est pas le cas » sur sa fiche.';

  @override
  String get placesBackendAlreadyReported =>
      'Vous avez déjà fait ce signalement.';

  @override
  String placesBackendDailyLimit(int count) {
    return 'Vous pouvez faire $count signalements par jour au maximum.';
  }

  @override
  String get placesBackendReportNotFound => 'Signalement introuvable.';

  @override
  String get placesBackendWithdrawOwnOnly =>
      'Vous ne pouvez retirer que votre propre signalement.';

  @override
  String get placesBackendWithdrawClosed =>
      'Ce signalement est déjà clos : il ne peut plus être retiré.';

  @override
  String get placesBackendRatingsOff => 'Les évaluations ne sont pas actives.';

  @override
  String get placesBackendRatePublicOnly =>
      'Seuls les parcs canins publics peuvent être évalués.';

  @override
  String get placesBackendDogParkNotFound => 'Parc canin introuvable.';

  @override
  String get placesBackendContributionsOff =>
      'Les signalements et les votes ne sont pas encore actifs.';

  @override
  String get placesBackendNameRequired =>
      'Saisissez le nom de l\'établissement, tel qu\'il apparaît sur l\'enseigne.';

  @override
  String placesBackendNameTooLong(int count) {
    return 'Le nom peut comporter $count caractères au maximum.';
  }

  @override
  String get placesBackendNameNoContacts =>
      'N\'indiquez ni téléphone, ni e-mail, ni site web dans le nom.';

  @override
  String get placesBackendNameBlockedWords =>
      'Le nom contient des mots non autorisés.';

  @override
  String get eventsTitle => 'Événements';

  @override
  String get eventsSearching => 'Je cherche les événements...';

  @override
  String get eventsAllRegions => 'Toutes les régions';

  @override
  String get eventsAllTypes => 'Tous les types';

  @override
  String get eventsReset => 'Réinitialiser';

  @override
  String get eventsDisclaimer =>
      'Les dates et les lieux peuvent changer : vérifiez toujours sur le site de l\'organisateur.';

  @override
  String get eventsPickRegionTitle => 'Région';

  @override
  String get eventsPickTypeTitle => 'Type d\'événement';

  @override
  String get eventsPickDatesHelp => 'Choisissez la période';

  @override
  String get eventsPickDatesSave => 'Appliquer';

  @override
  String get eventsStatusCancelled => 'Annulé';

  @override
  String get eventsStatusPostponed => 'Reporté';

  @override
  String eventsOrganizedBy(String name) {
    return 'Organisé par $name';
  }

  @override
  String get eventsSuggestAction => 'Signaler un événement';

  @override
  String get eventsSuggestTitle => 'Signaler un événement';

  @override
  String get eventsSuggestIntro =>
      'Vous connaissez un salon ou un événement pour animaux que vous ne trouvez pas ici ? Remplissez les informations : nous le vérifions sur le site de l\'organisateur avant de le publier.';

  @override
  String get eventsSuggestPrivacy =>
      'Indiquez uniquement des informations sur l\'événement : pas de noms de personnes, d\'e-mails ni de numéros de téléphone.';

  @override
  String get eventsSuggestFieldTitle => 'Nom de l\'événement';

  @override
  String get eventsSuggestFieldType => 'Type d\'événement';

  @override
  String get eventsSuggestFieldDates => 'Dates';

  @override
  String get eventsSuggestPickDates => 'Choisir les dates';

  @override
  String get eventsSuggestFieldCity => 'Ville';

  @override
  String get eventsSuggestFieldProvince => 'Province (sigle, ex. MO)';

  @override
  String get eventsSuggestFieldVenue =>
      'Lieu, par exemple le parc des expositions (facultatif)';

  @override
  String get eventsSuggestFieldLink => 'Lien vers la page de l\'événement';

  @override
  String get eventsSuggestRequired => 'Champ obligatoire';

  @override
  String get eventsSuggestInvalidLink =>
      'Saisissez une adresse commençant par http:// ou https://';

  @override
  String get eventsSuggestInvalidProvince =>
      'Utilisez le sigle de deux lettres';

  @override
  String get eventsSuggestSend => 'Envoyer le signalement';

  @override
  String get eventsSuggestThanks =>
      'Merci ! Nous vérifierons l\'événement avant de le publier.';

  @override
  String get eventsSuggestNeedLogin =>
      'Connectez-vous pour signaler un événement.';

  @override
  String get eventsSuggestLimit =>
      'Vous avez déjà envoyé vos signalements du jour : réessayez demain.';

  @override
  String get eventsSuggestError =>
      'Je n\'ai pas pu envoyer le signalement. Réessayez plus tard.';

  @override
  String get eventsLoadError =>
      'Je n\'arrive pas à charger les événements. Vérifiez votre connexion et réessayez.';

  @override
  String eventsWindowDefault(int days) {
    return '$days prochains jours';
  }

  @override
  String get eventsEmptyFiltered =>
      'Aucun événement avec ces filtres sur la période choisie';

  @override
  String eventsEmptyDefault(int days) {
    return 'Aucun événement dans les $days prochains jours';
  }

  @override
  String get eventsEmptyPeriod => 'Aucun événement sur la période choisie';

  @override
  String get eventsLevelLocal => 'Local';

  @override
  String get eventsLevelProvincial => 'Provincial';

  @override
  String get eventsLevelRegional => 'Régional';

  @override
  String get eventsLevelNational => 'National';

  @override
  String get eventsLevelInternational => 'International';

  @override
  String get eventsTypePetFair => 'Salon des animaux';

  @override
  String get eventsTypeDogShow => 'Exposition canine';

  @override
  String get eventsTypeBreedGathering => 'Rassemblement de race';

  @override
  String get eventsTypeCatShow => 'Exposition féline';

  @override
  String get eventsTypeWorkTrial => 'Épreuve de travail';

  @override
  String get eventsTypeDogSport => 'Sports canins';

  @override
  String get eventsTypeAdoptionDay => 'Journée d\'adoption';

  @override
  String get eventsTypeShelterOpenDay => 'Portes ouvertes du refuge';

  @override
  String get eventsTypeMicrochipDay => 'Journée puce électronique';

  @override
  String get eventsTypeVaccinationCampaign => 'Campagne de vaccination';

  @override
  String get eventsTypeGroupWalk => 'Promenade de groupe';

  @override
  String get eventsTypeCourseSeminar => 'Cours ou séminaire';

  @override
  String get eventsTypeMarket => 'Marché';

  @override
  String get eventsTypeCharityEvent => 'Événement caritatif';

  @override
  String get eventsTypeAquariumExpo => 'Aquariophilie';

  @override
  String get eventsTypeReptileExpo => 'Terrariophilie';

  @override
  String get eventsTypeBirdShow => 'Ornithologie';

  @override
  String get eventsTypeEquestrian => 'Équestre';

  @override
  String get eventsTypeOther => 'Autre';

  @override
  String get localActivitiesKindEvent => 'Événement';

  @override
  String get localActivitiesKindService => 'Service';

  @override
  String get localEventsTitle => 'Près de chez moi';

  @override
  String get localEventsLocating => 'Je cherche votre position…';

  @override
  String get localEventsSearchingAround =>
      'Je cherche ce qu\'il y a autour de vous. La première fois dans une zone, cela peut prendre jusqu\'à une minute.';

  @override
  String get localEventsConsentTitle => 'Utiliser votre position ?';

  @override
  String get localEventsConsentBody =>
      'Pour vous montrer ce qu\'il y a près de chez vous, VetApp utilise la position du téléphone uniquement pendant que vous utilisez l\'application. Vous pouvez aussi indiquer une adresse.';

  @override
  String get localEventsConsentChooseAddress => 'Choisir une adresse';

  @override
  String get localEventsConsentAllow => 'Autoriser';

  @override
  String get localEventsReportMissing => 'Signalez ! Il manque un lieu';

  @override
  String get localEventsServicesHeader => 'Services dans la zone';

  @override
  String get localEventsClinicsHeader => 'Cliniques et cabinets';

  @override
  String get localEventsNoClinics =>
      'Aucune clinique trouvée avec ces filtres.';

  @override
  String get localEventsNoServices => 'Aucun service trouvé avec ces filtres.';

  @override
  String get localEventsAll => 'Tous';

  @override
  String get localEventsMapFullscreen => 'Ouvrir la carte en plein écran';

  @override
  String get localEventsNoLocationTitle => 'Définissez un lieu';

  @override
  String get localEventsNoLocationBody =>
      'Pour vous montrer ce qu\'il y a autour de vous, votre position est nécessaire. Autorisez l\'accès à la position ou indiquez votre domicile dans Paramètres → Localisation.';

  @override
  String get localEventsOpenSettings => 'Ouvrir les Paramètres';

  @override
  String localEventsSearchingRadius(String radius) {
    return 'Je cherche les services dans un rayon de $radius. La première fois dans une zone, cela peut prendre jusqu\'à une minute.';
  }

  @override
  String get localEventsSearchingNearby =>
      'Je cherche les services dans votre zone. La première fois, cela peut prendre quelques secondes.';

  @override
  String get localEventsCoverageLimited =>
      'Les données des services de cette zone sont encore en préparation : vous verrez peut-être peu de lieux ou devrez attendre plus longtemps.';

  @override
  String get localEventsCoverageUnsupported =>
      'Le radar ne couvre pas encore ce pays : vous ne voyez que ce que connaît OpenStreetMap, sans autre vérification.';

  @override
  String get localEventsStale =>
      'Je n\'ai pas pu actualiser les services de cette zone : vous voyez les dernières données disponibles, qui ne sont peut-être pas récentes.';

  @override
  String localEventsPartialRadius(String radius) {
    return 'Pour l\'instant, les services sont disponibles dans un rayon de $radius : réessayez dans un instant pour le rayon complet.';
  }

  @override
  String get localEventsShowLess => 'Afficher moins';

  @override
  String localEventsShowAllCount(int count) {
    return 'Tout afficher ($count)';
  }

  @override
  String localEventsShowAllCategory(String category, int count) {
    return 'Tout afficher : $category ($count)';
  }

  @override
  String localEventsCategoryNone(String category, String radius) {
    return '$category : aucun dans un rayon de $radius';
  }

  @override
  String localEventsCategoryCount(String category, int count) {
    return '$category ($count)';
  }

  @override
  String localEventsSectionExpand(String section) {
    return 'Ouvrir $section';
  }

  @override
  String localEventsSectionCollapse(String section) {
    return 'Fermer $section';
  }

  @override
  String localEventsCallTooltip(String name) {
    return 'Appeler $name';
  }

  @override
  String localEventsDirectionsTooltip(String name) {
    return 'Itinéraire vers $name';
  }

  @override
  String get remindersRelativeToday => 'aujourd\'hui';

  @override
  String get remindersRelativeTomorrow => 'demain';

  @override
  String get remindersRelativeYesterday => 'hier';

  @override
  String remindersRelativeInDays(int days) {
    return 'dans $days jours';
  }

  @override
  String remindersRelativeDaysAgo(int days) {
    return 'il y a $days jours';
  }

  @override
  String get remindersKindEvent => 'Événement';

  @override
  String remindersKindRecurring(String interval, String end) {
    return 'Récurrent · $interval$end';
  }

  @override
  String remindersCourseStarts(String day) {
    return 'Commence $day';
  }

  @override
  String get remindersCourseCompleted => 'Terminée';

  @override
  String remindersCourseDayOf(int day, int total) {
    return 'Jour $day sur $total';
  }

  @override
  String remindersKindCourse(int days) {
    return 'Cure · $days jours';
  }

  @override
  String remindersKindCourseWithTimes(int days, String times) {
    return 'Cure · $days jours · $times';
  }

  @override
  String remindersIntervalEveryDays(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: 'tous les $value jours',
      one: 'tous les jours',
    );
    return '$_temp0';
  }

  @override
  String remindersIntervalEveryMonths(int value) {
    String _temp0 = intl.Intl.pluralLogic(
      value,
      locale: localeName,
      other: 'tous les $value mois',
      one: 'tous les mois',
    );
    return '$_temp0';
  }

  @override
  String remindersEndAfterTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fois',
      one: '$count fois',
    );
    return ' · $_temp0';
  }

  @override
  String remindersEndUntilDate(String date) {
    return ' · jusqu\'au $date';
  }

  @override
  String get remindersMenuTooltip => 'Options du rappel';

  @override
  String get remindersMenuMarkDone => 'Marquer comme fait';

  @override
  String get remindersDeleteConfirmTitle => 'Supprimer ce rappel ?';

  @override
  String remindersDeleteConfirmBody(String title) {
    return '« $title » sera supprimé définitivement.';
  }

  @override
  String get remindersErrorPetNotSynced =>
      'Le profil de l\'animal n\'est pas synchronisé avec le serveur : corrigez-le avant de créer des rappels.';

  @override
  String get remindersErrorSaveFailed =>
      'Je n\'ai pas pu enregistrer le rappel. Réessayez.';

  @override
  String get remindersErrorDeleteFailed =>
      'Je n\'ai pas pu supprimer le rappel. Réessayez.';

  @override
  String get petNewsTitle => 'Actualités';

  @override
  String get petNewsLoading => 'Je charge les actualités...';

  @override
  String get petNewsEmpty =>
      'Aucune actualité disponible pour cette catégorie pour le moment.';

  @override
  String get petNewsCategoryAll => 'Toutes';

  @override
  String get petNewsCategoryDog => 'Chien';

  @override
  String get petNewsCategoryCat => 'Chat';

  @override
  String get petNewsCategorySmallMammals => 'Petits mammifères';

  @override
  String get petNewsCategoryBird => 'Oiseau';

  @override
  String get petNewsCategoryReptiles => 'Reptiles et amphibiens';

  @override
  String get petNewsCategoryFish => 'Poisson';

  @override
  String get petNewsCategoryOther => 'Autre';

  @override
  String get petNewsCategoryGeneral => 'Général';

  @override
  String get profileLogoutDialogTitle => 'Se déconnecter';

  @override
  String get profileLogoutDialogBody =>
      'Voulez-vous vous déconnecter de ce compte ?';

  @override
  String get profileGuestName => 'Invité';

  @override
  String get profileNoActiveSession => 'Aucune session active';

  @override
  String profileSummaryBody(String pets) {
    return 'Profil de propriétaire lié à $pets et prêt pour l\'application web adaptative.';
  }

  @override
  String profilePetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count animaux',
      one: '$count animal',
    );
    return '$_temp0';
  }

  @override
  String get profileContactsTitle => 'Contacts';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String get profilePhoneLabel => 'Téléphone';

  @override
  String get profilePhoneNotSet => 'Non renseigné';

  @override
  String get profileCityLabel => 'Ville';

  @override
  String get profileCityNotSet => 'Non renseignée';

  @override
  String get profileEveningThemeTitle => 'Thème du soir';

  @override
  String get profileEveningThemeBody =>
      'Aperçu d\'une palette plus douce pour une utilisation en soirée.';

  @override
  String get profileAccountStatusTitle => 'État du compte';

  @override
  String get profileSessionLabel => 'Session';

  @override
  String get profileSessionActive => 'Active';

  @override
  String get profilePrivacyLabel => 'Confidentialité';

  @override
  String get profilePrivacyUpdated => 'À jour';

  @override
  String get profileSupportLabel => 'Assistance';

  @override
  String get profileSupportAvailable => 'Disponible';

  @override
  String get profileSettingsButton => 'Paramètres';

  @override
  String get profileLogoutButton => 'Déconnexion';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileIntro =>
      'Données du propriétaire, préférences et détails du compte au même endroit pour l\'application web adaptative.';

  @override
  String get profileRoadmapTitle => 'Prochaines étapes';

  @override
  String get profileRoadmapBody =>
      'Ici, nous pouvons faire évoluer les consentements, les préférences et la liaison du compte sans changer le flux web.';

  @override
  String get activitiesTitle => 'Activités';

  @override
  String get activitiesSubtitle =>
      'Tout ce qui tourne autour de la vie avec vos animaux.';

  @override
  String get activitiesNewsSubtitle =>
      'Anecdotes et actualités sur les animaux de compagnie.';

  @override
  String get activitiesNearbyTitle => 'Près de chez moi';

  @override
  String get activitiesNearbySubtitle =>
      'Vétérinaires, magasins et parcs canins près de chez vous.';

  @override
  String get activitiesEventsTitle => 'Événements';

  @override
  String get activitiesEventsSubtitle =>
      'Salons, expositions et initiatives pour animaux dans toute l\'Italie.';

  @override
  String get activitiesGalleryTitle => 'Galerie';

  @override
  String get activitiesGallerySubtitle =>
      'Rassemblez les photos et les souvenirs de vos animaux.';

  @override
  String get activitiesMarketplaceTitle => 'Marché de l\'occasion';

  @override
  String get activitiesMarketplaceSubtitle =>
      'Achetez, vendez et échangez des articles pour animaux.';

  @override
  String get activitiesPetFriendTitle => 'Pet friend';

  @override
  String get activitiesPetFriendSubtitle =>
      'Rencontres et compagnie entre animaux et propriétaires.';

  @override
  String get activitiesComingSoonBadge => 'Bientôt';

  @override
  String get activitiesPetFriendDescription =>
      'Rencontrez d\'autres propriétaires et organisez des sorties entre animaux qui s\'entendent bien.';

  @override
  String get remindersTitle => 'Rappels';

  @override
  String get remindersSubtitle =>
      'Vaccins, traitements et visites à garder à l\'œil.';

  @override
  String get remindersCreateButton => 'Créer';

  @override
  String get remindersLoadingTitle => 'Chargement des rappels';

  @override
  String get remindersLoadingBody =>
      'Je lis les dates, les récurrences et les notes du propriétaire.';

  @override
  String get remindersSyncErrorLabel => 'Erreur de synchro';

  @override
  String get remindersSyncErrorTitle =>
      'Échec de la synchronisation des rappels.';

  @override
  String get remindersSyncErrorBody =>
      'La source de démonstration reste disponible. Réessayez quand le réseau reviendra.';

  @override
  String get remindersEmptyLabel => 'Aucun rappel';

  @override
  String get remindersEmptyTitle => 'La liste des rappels est vide.';

  @override
  String get remindersEmptyBody =>
      'Créez le premier rappel de vaccin ou de traitement pour rester à jour.';

  @override
  String get remindersNoMatchForFilters => 'Aucun rappel pour ces filtres.';

  @override
  String get remindersFilterAll => 'Tous';

  @override
  String get remindersFilterEvents => 'Événements';

  @override
  String get remindersFilterCourses => 'Cures';

  @override
  String get remindersViewList => 'Liste';

  @override
  String get remindersViewCalendar => 'Calendrier';

  @override
  String get remindersNothingThisDay => 'Aucune activité ce jour-là.';

  @override
  String get remindersTodayCapitalized => 'Aujourd\'hui';

  @override
  String get remindersEditTitle => 'Modifier le rappel';

  @override
  String get remindersEditSubtitle =>
      'Mettez à jour le type, la date et les notes.';

  @override
  String get remindersDosePickerHelp => 'Heure de la dose';

  @override
  String get remindersDateRequired => 'Saisissez une date.';

  @override
  String get remindersDateInvalid => 'Date non valide (jj/mm/aaaa).';

  @override
  String get remindersFormKind => 'Type';

  @override
  String get remindersFormTitleLabel => 'Titre';

  @override
  String get remindersFormTitleHint => 'Ex. Rappel de vaccin';

  @override
  String remindersFormTitleHintWithPet(String petName) {
    return 'Ex. Rappel de vaccin de $petName';
  }

  @override
  String get remindersTitleRequired => 'Saisissez un titre.';

  @override
  String get remindersFieldDate => 'Date';

  @override
  String get remindersFieldNextDue => 'Prochaine échéance';

  @override
  String get remindersFieldStartDate => 'Date de début';

  @override
  String get remindersFieldTime => 'Heure';

  @override
  String get remindersRepeats => 'Se répète';

  @override
  String get remindersCustomNumberHint => 'Nombre';

  @override
  String get remindersRecurrenceEndLabel => 'Fin de la récurrence';

  @override
  String get remindersOccurrenceCountHint => 'Nombre de fois';

  @override
  String get remindersLastDate => 'Dernière date';

  @override
  String get remindersCourseDuration => 'Durée de la cure';

  @override
  String get remindersDoseTimes => 'Heures des doses';

  @override
  String get remindersAddDoseTime => 'Ajouter une heure';

  @override
  String get remindersNoDoseTimesNote =>
      'Sans horaires, vous recevez une alerte par jour, à 9 h 00.';

  @override
  String get remindersFormNote => 'Note';

  @override
  String get remindersFormNoteHint => 'Ex. Apporter le carnet de santé';

  @override
  String get remindersKindOptionRecurring => 'Récurrent';

  @override
  String get remindersKindOptionCourse => 'Cure';

  @override
  String get remindersDatePlaceholder => 'jj/mm/aaaa';

  @override
  String get remindersPreset7Days => '7 j';

  @override
  String get remindersPreset30Days => '30 j';

  @override
  String get remindersPreset6Months => '6 mois';

  @override
  String get remindersPreset12Months => '12 mois';

  @override
  String get remindersPresetCustom => 'Personnalisé';

  @override
  String get remindersEndAlways => 'Toujours';

  @override
  String get remindersEndAfterN => 'N fois';

  @override
  String get remindersEndUntil => 'Jusqu\'à une date';

  @override
  String get remindersUnitDays => 'Jours';

  @override
  String get remindersUnitMonths => 'Mois';

  @override
  String get remindersOneDayLess => 'Un jour de moins';

  @override
  String remindersDurationRange(int min, int max) {
    return 'De $min à $max jours.';
  }

  @override
  String remindersDurationUnit(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'jours',
      one: 'jour',
    );
    return '$_temp0';
  }

  @override
  String get remindersOneDayMore => 'Un jour de plus';

  @override
  String get remindersNotFoundTitle => 'Rappel introuvable';

  @override
  String get remindersNotFoundSubtitle => 'Ce rappel n\'est plus disponible.';

  @override
  String get remindersNotFoundLabel => 'Introuvable';

  @override
  String get remindersNotFoundPanelTitle => 'Aucun rappel à afficher.';

  @override
  String get remindersNotFoundBody =>
      'Il a peut-être été supprimé ou n\'est pas encore synchronisé.';

  @override
  String get remindersBackToList => 'Retour à la liste';

  @override
  String get remindersDetailTitle => 'Détail du rappel';

  @override
  String get remindersDetailSubtitle => 'Type, date et note du rappel.';

  @override
  String get remindersNoNote => 'Aucune note ajoutée.';

  @override
  String get remindersSummaryTitle => 'Résumé du rappel';

  @override
  String get remindersSummaryPet => 'Animal';

  @override
  String get remindersSummaryStatus => 'État';

  @override
  String get remindersDeleteButton => 'Supprimer le rappel';

  @override
  String get remindersLoadingLabel => 'Chargement';

  @override
  String get remindersWait => 'Patientez';

  @override
  String get remindersCreateTitle => 'Créer un rappel';

  @override
  String remindersCreateTitleForPet(String petName) {
    return 'Nouveau rappel pour $petName';
  }

  @override
  String get remindersCreateSubtitle =>
      'Choisissez le type, la date et les détails.';

  @override
  String get settingsUnitSystemMetricLabel => 'Métrique';

  @override
  String get settingsUnitSystemUkLabel => 'Royaume-Uni';

  @override
  String get settingsUnitSystemUsLabel => 'États-Unis';

  @override
  String get settingsUnitSystemMetricDescription => 'km, kg, °C, litres';

  @override
  String get settingsUnitSystemUkDescription => 'miles, livres, °C, litres';

  @override
  String get settingsUnitSystemUsDescription => 'miles, livres, °F, gallons US';

  @override
  String settingsVolumeLiters(int liters) {
    return '$liters litres';
  }

  @override
  String get settingsUnitLitersName => 'litres';

  @override
  String get settingsTextSizeSmall => 'Petit';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Grand';

  @override
  String get settingsTextSizeExtraLarge => 'Très grand';

  @override
  String get settingsLocationPickerTitle => 'Choisir sur la carte';

  @override
  String get settingsLocationPickerHint =>
      'Déplacez la carte jusqu\'à ce que le repère soit au bon endroit, puis confirmez.';

  @override
  String get settingsLocationPickerConfirm => 'Confirmer ce point';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsNumericDatePattern => 'dd/MM/yyyy';

  @override
  String get settingsGuestInitial => 'I';

  @override
  String get settingsGuestName => 'Invité';

  @override
  String get settingsNoActiveSession => 'Aucune session active';

  @override
  String get settingsSectionSubscription => 'Abonnement';

  @override
  String get settingsSubscriptionAndPayments => 'Abonnement et paiements';

  @override
  String settingsTrialExpiresOn(String date) {
    return 'Essai · expire le $date';
  }

  @override
  String get settingsSectionPushNotifications => 'Notifications push';

  @override
  String get settingsNotificationsToggle => 'Notifications';

  @override
  String get settingsSectionLayout => 'Affichage';

  @override
  String get settingsLayoutWeeksTitle => 'Semaines affichées sur l\'accueil';

  @override
  String get settingsLayoutWeeksSubtitle =>
      'Combien de semaines afficher dans le calendrier de l\'accueil.';

  @override
  String get settingsLayoutWeekStartTitle => 'Début de la semaine';

  @override
  String get settingsLayoutChatTextSizeTitle => 'Taille du texte dans le chat';

  @override
  String get settingsLayoutChatTextSizePreview =>
      'Voici comment vous verrez les messages du chat.';

  @override
  String get settingsLayoutUnitsTitle => 'Unités de mesure';

  @override
  String get settingsSectionPhotosVideos => 'Photos et vidéos';

  @override
  String get settingsGallerySaveTitle =>
      'Enregistrer les photos dans la galerie';

  @override
  String get settingsGallerySaveSubtitle =>
      'Les photos et les vidéos prises avec l\'appareil photo de l\'application sont copiées dans l\'album « VetApp » du téléphone.';

  @override
  String get settingsSectionLocation => 'Localisation';

  @override
  String get settingsLocationIntro =>
      'Utilisée pour personnaliser les événements et les actualités selon votre zone.';

  @override
  String get settingsLocationReferenceTitle => 'Position de référence';

  @override
  String get settingsLocationModeCurrent => 'Actuelle';

  @override
  String get settingsLocationModeHome => 'Domicile';

  @override
  String get settingsLocationCurrentTitle => 'Position actuelle';

  @override
  String get settingsLocationDetecting => 'Détection en cours…';

  @override
  String get settingsLocationCurrentNotSet => 'Pas encore définie';

  @override
  String get settingsLocationRefresh => 'Actualiser';

  @override
  String get settingsLocationHomeTitle => 'Domicile habituel';

  @override
  String get settingsLocationHomeNotSet => 'Non défini';

  @override
  String get settingsLocationSet => 'Définir';

  @override
  String get settingsLocationErrorPermissionDenied =>
      'Autorisation de localisation refusée : activez-la dans les paramètres de l\'appareil pour utiliser la position actuelle.';

  @override
  String get settingsLocationErrorServiceDisabled =>
      'La localisation est désactivée sur l\'appareil.';

  @override
  String get settingsLocationErrorTimeout =>
      'Je n\'ai pas pu détecter la position à temps, réessayez.';

  @override
  String get settingsLocationErrorUnsupported =>
      'Localisation indisponible sur cet appareil ou ce navigateur.';

  @override
  String get settingsSectionPermissions => 'Autorisations et consentements';

  @override
  String get settingsConsentsUnavailable => 'Indisponibles pour le moment';

  @override
  String get settingsConsentsTapToRetry => 'Touchez pour réessayer';

  @override
  String get settingsConsentTerms => 'Conditions d\'utilisation';

  @override
  String get settingsConsentPrivacy => 'Politique de confidentialité';

  @override
  String get settingsConsentMarketingEmail => 'E-mails marketing';

  @override
  String get settingsConsentAnalytics => 'Analyse d\'utilisation';

  @override
  String settingsConsentAccepted(String version, String date) {
    return 'Accepté v$version le $date';
  }

  @override
  String get settingsConsentToConfirm => 'À confirmer';

  @override
  String get settingsClinicalConsentSection => 'Dossier médical et assistant';

  @override
  String get settingsPrivacyPolicyFullTitle =>
      'Politique de confidentialité complète';

  @override
  String get settingsPrivacyPolicyFullSubtitle =>
      'Lire, télécharger ou partager le texte';

  @override
  String get settingsSectionSupport => 'Assistance';

  @override
  String get settingsHelpCenterTitle => 'Centre d\'aide';

  @override
  String get settingsHelpCenterComingSoon =>
      'Questions fréquentes et guides rapides, bientôt disponibles directement ici.';

  @override
  String get settingsContactUs => 'Nous contacter';

  @override
  String get settingsContactUnavailable =>
      'Le contact de l\'assistance n\'est pas disponible pour le moment. Réessayez plus tard.';

  @override
  String settingsContactWriteTo(String email) {
    return 'Écrivez à $email pour toute question.';
  }

  @override
  String get settingsRateApp => 'Noter l\'application';

  @override
  String get settingsRateAppThanks => 'Merci pour votre soutien ! ⭐';

  @override
  String get settingsSectionInfo => 'Infos';

  @override
  String get settingsDataSourcesTitle => 'Sources des données';

  @override
  String get settingsDataSourcesSubtitle => 'D\'où viennent les lieux du radar';

  @override
  String get settingsAppVersion => 'Version de l\'application';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsLogout => 'Se déconnecter';

  @override
  String get settingsLogoutConfirmBody =>
      'Voulez-vous vous déconnecter de ce compte ?';

  @override
  String get settingsHomeCountryDefault => 'France';

  @override
  String get settingsHomeAddressNotFound =>
      'Je ne trouve pas cette adresse. Vérifiez les informations et réessayez.';

  @override
  String get settingsHomeAddressOrType => 'Ou saisissez l\'adresse :';

  @override
  String get settingsHomeAddressStreet => 'Adresse';

  @override
  String get settingsHomeAddressStreetRequired => 'Saisissez l\'adresse';

  @override
  String get settingsHomeAddressPostalCode => 'Code postal';

  @override
  String get settingsHomeAddressPostalCodeRequired =>
      'Saisissez le code postal';

  @override
  String get settingsHomeAddressCity => 'Ville';

  @override
  String get settingsHomeAddressCityRequired => 'Saisissez la ville';

  @override
  String get settingsHomeAddressCountry => 'Pays';

  @override
  String get settingsHomeAddressCountryRequired => 'Saisissez le pays';

  @override
  String get settingsHomeAddressSearching => 'Recherche…';

  @override
  String get notificationsCategoryReminders => 'Visites et vaccins';

  @override
  String get notificationsCategoryMedicines => 'Horaires des médicaments';

  @override
  String get notificationsCategoryBirthdays => 'Anniversaires';

  @override
  String get notificationsChannelRemindersName => 'Rappels';

  @override
  String get notificationsChannelRemindersDescription =>
      'Visites, vaccins et autres rappels';

  @override
  String get notificationsChannelMedicinesName => 'Médicaments';

  @override
  String get notificationsChannelBirthdaysDescription =>
      'Anniversaires des animaux';

  @override
  String notificationsReminderTodayBody(String petName, String time) {
    return '$petName · aujourd\'hui à $time';
  }

  @override
  String notificationsReminderTomorrowTitle(String title) {
    return 'Demain : $title';
  }

  @override
  String notificationsReminderTomorrowBody(String petName, String time) {
    return '$petName · à $time';
  }

  @override
  String notificationsMedicineTitle(String petName) {
    return 'Médicament pour $petName';
  }

  @override
  String notificationsMedicineDayBody(String title, int day, int total) {
    return '$title · jour $day sur $total';
  }

  @override
  String notificationsMedicineDoseBody(String title, String time) {
    return '$title · dose de $time';
  }

  @override
  String notificationsBirthdayTitle(String petName) {
    return 'Joyeux anniversaire, $petName !';
  }

  @override
  String notificationsBirthdayBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aujourd\'hui, $count ans !',
      one: 'Aujourd\'hui, $count an !',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBirthdayUpcomingTitle => 'Anniversaire à venir';

  @override
  String notificationsBirthdayUpcomingBody(String petName) {
    return 'Dans une semaine, c\'est l\'anniversaire de $petName : pensez à un cadeau.';
  }

  @override
  String walksPageTitle(String petName) {
    return 'Promenade de $petName';
  }

  @override
  String get walksStatusInProgress => 'Promenade en cours';

  @override
  String get walksStatusPaused => 'Promenade en pause';

  @override
  String get walksStatDistance => 'Distance';

  @override
  String get walksStatDuration => 'Durée';

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
  String get walksActionResume => 'Reprendre';

  @override
  String get walksActionFinish => 'Terminer';

  @override
  String get walksActionSaving => 'Enregistrement...';

  @override
  String get walksActionStarting => 'Démarrage...';

  @override
  String get walksActionStart => 'Démarrer la promenade';

  @override
  String get walksWaitingForGps => 'En attente d\'un signal GPS précis…';

  @override
  String get walksCameraTooltip => 'Photo ou vidéo';

  @override
  String get walksCaptureTakePhoto => 'Prendre une photo';

  @override
  String get walksCaptureRecordVideo => 'Filmer une vidéo';

  @override
  String walksCaptureVideoLimit(int seconds) {
    return 'Jusqu\'à $seconds secondes';
  }

  @override
  String get walksErrorOtherPetActive =>
      'Une promenade est déjà en cours avec un autre animal : terminez-la avant d\'en commencer une nouvelle.';

  @override
  String get walksErrorLocationUnavailable =>
      'Je n\'arrive pas à détecter votre position : elle est nécessaire pour tracer le parcours. Vérifiez les autorisations de localisation et réessayez.';

  @override
  String get walksPhotoPinSemantics => 'Photo prise pendant la promenade';

  @override
  String walksPhotoCaption(String date) {
    return 'Promenade du $date';
  }

  @override
  String get walksMapUnavailable => 'Parcours indisponible';

  @override
  String get walksNoMoveTitle => 'Promenade sans déplacement';

  @override
  String get walksNoMoveBody =>
      'Aucun déplacement n\'a été enregistré : la promenade n\'a pas été sauvegardée.';

  @override
  String get walksNoMoveAck => 'J\'ai compris';

  @override
  String get walksFavoritePromptTitle => 'Ajouter aux favorites ?';

  @override
  String walksFavoritePromptBody(String distance) {
    return 'Voulez-vous ajouter cette promenade ($distance) à vos favorites ⭐ ?';
  }

  @override
  String get walksFavoriteNoThanks => 'Non, merci';

  @override
  String get walksFavoriteSave => 'Ajouter ⭐';

  @override
  String get walksFavoriteEvictTitle => 'Vous avez déjà 5 favorites';

  @override
  String get walksFavoriteEvictBody =>
      'Choisissez laquelle retirer des favorites pour faire de la place à celle qui vient de se terminer.';

  @override
  String get walksSheetOpen => 'Ouvrir la promenade';

  @override
  String get walksSheetFinish => 'Fin de la promenade';

  @override
  String walksConfirmFinishTitle(String petName) {
    return 'Terminer la promenade avec $petName ?';
  }

  @override
  String get walksConfirmFinishBody =>
      'Le parcours enregistré jusqu\'ici sera sauvegardé.';

  @override
  String get walksSavingSnackbar => 'J\'enregistre la promenade...';

  @override
  String get walksNotifPermTitle => 'Voir la promenade dans les notifications';

  @override
  String get walksNotifPermBody =>
      'Pendant la promenade, VetApp affiche une notification fixe avec la durée et la distance : de là, vous pouvez la mettre en pause ou la terminer, même avec le téléphone dans la poche. Pour la voir, l\'autorisation de notifications est nécessaire.\n\nLa promenade est enregistrée dans tous les cas, même si vous choisissez « Pas maintenant ».';

  @override
  String get walksNotifPermNotNow => 'Pas maintenant';

  @override
  String get walksNotifPermAllow => 'Autoriser';

  @override
  String walksNotifTitleWithPet(String petName) {
    return 'Promenade avec $petName';
  }

  @override
  String walksNotifTitleWithPetPaused(String petName) {
    return 'Promenade avec $petName · en pause';
  }

  @override
  String get walksNotifTitleNoPetPaused => 'Promenade en cours · en pause';

  @override
  String walksNotifRunningText(String distance) {
    return '$distance parcourus';
  }

  @override
  String get walksNotifFallbackPausedText =>
      'Le suivi est en pause. Reprenez depuis l\'application quand vous voulez.';

  @override
  String get walksNotifFallbackRunningText =>
      'VetApp suit le parcours de la promenade.';

  @override
  String get walksNotifChannelName => 'Suivi de la promenade';

  @override
  String get walksSyncFailed =>
      'Échec de la synchronisation : modification enregistrée uniquement sur le téléphone';

  @override
  String get walksFavoriteSaveFailed =>
      'Je n\'ai pas pu enregistrer la favorite : réessayez.';

  @override
  String get walksFavoriteRemoveFailed =>
      'Je n\'ai pas pu retirer la favorite : réessayez.';

  @override
  String get walksDeleteFailed =>
      'Je n\'ai pas pu supprimer la promenade : réessayez.';

  @override
  String get walksHighlightLongest => 'La plus longue';

  @override
  String get walksHighlightMostDurable => 'La plus durable';

  @override
  String get walksHighlightFavorite => 'Favorite';

  @override
  String walksDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String walksDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get walksBadgeLabelFirstWalk => 'Première promenade 🐾';

  @override
  String walksBadgeLabelDistance(String km) {
    return '$km km parcourus 🏃';
  }

  @override
  String walksBadgeLabelWalkCount(String count) {
    return '$count sorties 🎖️';
  }

  @override
  String get walksBadgeLabel30Min => '30 minutes en une promenade ⏱️';

  @override
  String get walksBadgeLabel1Hour => '1 heure en une promenade ⏱️';

  @override
  String get walksBadgeLabelStreak => '7 jours d\'affilée 🔥';

  @override
  String get walksBadgeLabelDawn => 'Promenade à l\'aube 🌅';

  @override
  String get walksBadgeLabelNight => 'Promenade nocturne 🌙';

  @override
  String get walksBadgeEarnedBarrier => 'Badge débloqué';

  @override
  String walksBadgeEarnedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nouveaux badges débloqués !',
      one: 'Nouveau badge débloqué !',
    );
    return '$_temp0';
  }

  @override
  String get walksBadgeEarnedAction => 'Hourra !';

  @override
  String get walksBadgeGalleryTitle => 'Badges';

  @override
  String get walksBadgeNameFirstWalk => 'Première promenade';

  @override
  String get walksBadgeDescFirstWalk =>
      'Terminez votre première promenade avec cet animal.';

  @override
  String walksBadgeNameKm(String km) {
    return '$km km';
  }

  @override
  String walksBadgeDescKm(String km) {
    return 'Parcourez $km km au total.';
  }

  @override
  String get walksBadgeName30Min => '30 minutes';

  @override
  String get walksBadgeDesc30Min =>
      'Faites une promenade d\'au moins 30 minutes.';

  @override
  String get walksBadgeName1Hour => '1 heure';

  @override
  String get walksBadgeDesc1Hour =>
      'Faites une promenade d\'au moins une heure.';

  @override
  String get walksBadgeNameStreak => '7 jours d\'affilée';

  @override
  String get walksBadgeDescStreak => 'Sortez en promenade 7 jours consécutifs.';

  @override
  String get walksBadgeNameDawn => 'Promenade à l\'aube';

  @override
  String get walksBadgeDescDawn =>
      'Faites une promenade entre 5 h et 7 h du matin.';

  @override
  String get walksBadgeNameNight => 'Promenade nocturne';

  @override
  String get walksBadgeDescNight =>
      'Faites une promenade après 21 h ou avant 5 h.';

  @override
  String walksBadgeNameWalkCount(String count) {
    return '$count sorties';
  }

  @override
  String walksBadgeDescWalkCount(String count) {
    return 'Terminez $count promenades au total.';
  }

  @override
  String get settingsAccountProfile => 'Votre profil';

  @override
  String get settingsAccountChangeEmail => 'Changer l\'e-mail';

  @override
  String get settingsAccountChangePassword => 'Changer le mot de passe';

  @override
  String get settingsAccountSupport => 'Assistance';

  @override
  String get settingsAccountSupportSubtitle => 'Écrivez-nous un e-mail';

  @override
  String get settingsAccountDelete => 'Supprimer le compte';

  @override
  String get settingsAccountDeleteSubtitle =>
      'Supprimez votre compte et toutes vos données';

  @override
  String accountSupportSubject(String version) {
    return 'Assistance VetApp (version $version)';
  }

  @override
  String accountSupportBody(String version) {
    return 'Écrivez ici votre message :\n\n\n\n—\nVersion de l\'application : $version';
  }

  @override
  String get accountProfileTitle => 'Votre profil';

  @override
  String get accountProfileFirstName => 'Prénom';

  @override
  String get accountProfileLastName => 'Nom';

  @override
  String get accountProfilePhone => 'Téléphone (facultatif)';

  @override
  String get accountProfilePhoneHint => '+33 6 12 34 56 78';

  @override
  String get accountProfileFirstNameRequired => 'Saisissez votre prénom.';

  @override
  String get accountProfileLastNameRequired => 'Saisissez votre nom.';

  @override
  String get accountProfilePhoneInvalid => 'Numéro de téléphone non valide.';

  @override
  String get accountProfilePhotoAdd => 'Ajouter une photo';

  @override
  String get accountProfilePhotoChange => 'Changer la photo';

  @override
  String get accountProfilePhotoRemove => 'Retirer la photo';

  @override
  String get accountProfilePhotoFailed =>
      'Je n\'ai pas pu charger la photo. Réessayez.';

  @override
  String get accountProfileSaved => 'Profil enregistré.';

  @override
  String get accountProfileEmailLabel => 'E-mail';

  @override
  String get accountProfileEmailChange => 'Changer';

  @override
  String get accountEmailTitle => 'Changer l\'e-mail';

  @override
  String get accountEmailCurrent => 'E-mail actuel';

  @override
  String get accountEmailNew => 'Nouvel e-mail';

  @override
  String get accountEmailSame => 'C\'est votre e-mail actuel.';

  @override
  String get accountEmailSubmit => 'Changer l\'e-mail';

  @override
  String accountEmailApplied(String email) {
    return 'E-mail mis à jour : désormais, vous vous connectez avec $email.';
  }

  @override
  String accountEmailConfirmationSent(String email) {
    return 'Nous avons envoyé un lien de confirmation à la nouvelle adresse ($email). Ouvrez-le pour finaliser le changement : d\'ici là, vous continuez à vous connecter avec l\'e-mail actuel.';
  }

  @override
  String get accountPasswordTitle => 'Changer le mot de passe';

  @override
  String get accountPasswordCurrent => 'Mot de passe actuel';

  @override
  String get accountPasswordCurrentRequired =>
      'Saisissez le mot de passe actuel.';

  @override
  String get accountPasswordCurrentWrong =>
      'Le mot de passe actuel n\'est pas correct.';

  @override
  String get accountPasswordNew => 'Nouveau mot de passe';

  @override
  String get accountPasswordRepeat => 'Répétez le nouveau mot de passe';

  @override
  String get accountPasswordSameAsOld =>
      'Le nouveau mot de passe doit être différent de l\'actuel.';

  @override
  String get accountPasswordSubmit => 'Changer le mot de passe';

  @override
  String get accountPasswordChanged => 'Mot de passe modifié.';

  @override
  String get accountDeleteTitle => 'Supprimer le compte';

  @override
  String get accountDeleteWarningTitle => 'Cette action est définitive';

  @override
  String get accountDeleteWarningBody =>
      'Seront supprimés définitivement : les profils de vos animaux, les conversations avec l\'assistant, les rappels, les promenades, les photos et les vidéos, les comptes rendus et les documents chargés, les mesures, les consentements, la position enregistrée et les annonces que vous avez publiées sur le marché de l\'occasion. Nous ne pourrons pas les récupérer.';

  @override
  String get accountDeletePasswordLabel =>
      'Saisissez votre mot de passe pour confirmer';

  @override
  String get accountDeletePasswordRequired => 'Saisissez votre mot de passe.';

  @override
  String get accountDeleteUnderstood =>
      'J\'ai compris : mon compte et toutes mes données seront supprimés définitivement.';

  @override
  String get accountDeleteSubmit => 'Supprimer définitivement mon compte';

  @override
  String get accountDeleteFailed =>
      'Je n\'ai pas pu supprimer le compte. Réessayez dans un instant ; si le problème persiste, écrivez à l\'assistance.';

  @override
  String get accountDeleteDone => 'Votre compte a été supprimé.';

  @override
  String get accountDeleteReauth =>
      'Par sécurité, une confirmation récente est nécessaire : saisissez à nouveau votre mot de passe et réessayez.';

  @override
  String get petsValueSexUnknownShort => 'Je ne sais pas';

  @override
  String get petsValueActivitySedentary => 'Sédentaire';

  @override
  String get petsValueActivityNormal => 'Normale';

  @override
  String get petsValueActivityActive => 'Active';

  @override
  String get petsFormSterilized => 'Stérilisé / castré';

  @override
  String get petsFormMicrochipLabel => 'N° de puce électronique';

  @override
  String get petsFormMicrochipHint => '15 chiffres';

  @override
  String get petsFormMicrochipInvalid =>
      'La puce électronique comporte 15 chiffres.';

  @override
  String get petsFormCoatColorLabel => 'Couleur de la robe';

  @override
  String get petsFormCoatColorHint => 'Ex. noir, marron';

  @override
  String get petsFormColorLabel => 'Couleur';

  @override
  String get petsFormColorHint => 'Ex. vert, jaune';

  @override
  String get petsFormBodyConditionLabel => 'Corpulence';

  @override
  String get petsFormBodyConditionHint => 'Sélectionnez la corpulence';

  @override
  String get petsFormActivityLabel => 'Activité';

  @override
  String get petsFormActivityHint => 'Sélectionnez l\'activité';

  @override
  String get petsFormDogSizeLabelShort => 'Taille';

  @override
  String get petsWizardNext => 'Continuer';

  @override
  String get petsWizardConfirm => 'Confirmer';

  @override
  String get petsWizardBack => 'Retour';

  @override
  String petsWizardStepSemantics(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get petsWizardStep1Title => 'Quel animal est-ce ?';

  @override
  String get petsWizardStep1Subtitle =>
      'Choisissez le type d\'animal et sa race ou son espèce';

  @override
  String get petsWizardStep2Title => 'Parlez-nous de votre animal';

  @override
  String get petsWizardStep2Subtitle => 'Comment s\'appelle-t-il ?';

  @override
  String get petsWizardStep3Title => 'Informations générales';

  @override
  String get petsWizardStep3Subtitle =>
      'Dites-nous-en un peu plus sur votre animal';

  @override
  String get petsWizardStep4Title => 'Dernières informations';

  @override
  String get petsWizardStep4Subtitle => 'C\'est presque fini !';

  @override
  String get petsWizardPureBred => 'De race';

  @override
  String get petsWizardMixedBreed => 'Croisé';

  @override
  String get petsWizardDoneTitle => 'Profil créé !';

  @override
  String petsWizardDoneMessage(String name) {
    return 'Félicitations, $name a été ajouté à vos animaux.';
  }

  @override
  String get petsWizardAddAnother => 'Ajouter un autre animal';

  @override
  String get petsWizardFinish => 'Terminer';

  @override
  String get petsDataTitle => 'Données de l\'animal';

  @override
  String get petsDataSectionIdentity => 'Identité';

  @override
  String get petsDataSectionPhysical => 'Caractéristiques physiques';

  @override
  String get petsDataSectionDocuments => 'Documents';

  @override
  String get petsDataNotProvided => 'Non renseigné';

  @override
  String get petsDataMicrochipMissing => 'Manquante';

  @override
  String get petsDataMicrochipMissingDogHint =>
      'La puce électronique est obligatoire pour les chiens.';

  @override
  String get petsDataAddMicrochip => 'Ajouter la puce électronique';

  @override
  String get petsDataWeightLabel => 'Poids';

  @override
  String get petsDataSummarySterilized => 'stérilisé';

  @override
  String get monitoringTitle => 'Suivi';

  @override
  String get petsDetailTabMonitoring => 'Suivi';

  @override
  String get monitoringBcsGuideTitle => 'Évaluer la corpulence';

  @override
  String monitoringBcsGuideIntro(String petName) {
    return 'Le poids seul ne suffit pas à dire si un animal est maigre ou bien en chair : il faut le toucher et le regarder. Suivez les trois étapes et choisissez la description qui ressemble le plus à $petName.';
  }

  @override
  String get monitoringBcsStepTouch => 'Palpez les côtes';

  @override
  String get monitoringBcsStepAbove => 'Regardez de dessus';

  @override
  String get monitoringBcsStepSide => 'Regardez de profil';

  @override
  String get monitoringBcsViewAbove => 'De dessus';

  @override
  String get monitoringBcsViewSide => 'De profil';

  @override
  String get monitoringBcsRowTouch => 'Au toucher';

  @override
  String get monitoringBcsRowAbove => 'De dessus';

  @override
  String get monitoringBcsRowSide => 'De profil';

  @override
  String monitoringBcsGuideScale(String range, String max) {
    return 'Sur l\'échelle de la source : $range sur $max';
  }

  @override
  String monitoringBcsGuideChoose(String level) {
    return 'Choisir : $level';
  }

  @override
  String get monitoringBcsGuideClear => 'Retirer l\'évaluation';

  @override
  String get monitoringBcsGuideDisclaimer =>
      'C\'est une indication approximative qui ne remplace pas la consultation du vétérinaire. Les illustrations sont schématiques et originales de VetApp.';

  @override
  String monitoringBcsGuideSource(String source) {
    return 'Source : $source';
  }

  @override
  String get monitoringBcsGuideTipFurry =>
      'Chez les chiens et les chats à poil long ou épais, la vue est trompeuse : palpez toujours les côtes. Par exemple, un chien au poil épais peut sembler bien en chair alors qu\'il est maigre, tandis qu\'un chiot ou un chien très musclé peut paraître « trop athlétique » alors que son poids est correct.';

  @override
  String get monitoringBcsGuideTipRabbit =>
      'Chez les lapins, le poil cache les os : palpez toujours le dos, les côtes et la hanche, la vue seule ne suffit pas. Un poil épais peut faire paraître gras un lapin normal, ou normal un lapin maigre.';

  @override
  String get monitoringBcsGuideAdviceTitle => 'Conseils';

  @override
  String monitoringBcsGuideAdvice1(String petName) {
    return 'Pesez $petName toutes les 2 à 4 semaines et notez son poids : les variations lentes se voient mieux dans les chiffres qu\'à l\'œil nu.';
  }

  @override
  String get monitoringBcsGuideAdvice2 =>
      'Évaluez toujours de la même façon : même endroit, animal debout et calme, mêmes trois gestes (toucher, vue de dessus, vue de profil).';

  @override
  String get monitoringBcsGuideAdvice3 =>
      'En cas de doute, demandez au vétérinaire : la corpulence s\'apprend mieux avec quelqu\'un qui vous montre comment palper.';

  @override
  String get monitoringBcsGuideCaveatRabbit =>
      'Pour les lapins, cette échelle est moins fiable : deux personnes peuvent donner des notes différentes au même lapin. En cas de doute, demandez au vétérinaire.';

  @override
  String get monitoringBcsSourceDog =>
      'critères de l\'échelle à 9 points du WSAVA Global Nutrition Committee pour les chiens (Laflamme, 1997), résumés avec nos propres mots et ramenés à 5 niveaux par VetApp. Ce n\'est pas un document officiel de la WSAVA.';

  @override
  String get monitoringBcsSourceCat =>
      'critères de l\'échelle à 9 points du WSAVA Global Nutrition Committee pour les chats (Laflamme, 1997 ; validée par Bjornvad et al., 2011), résumés avec nos propres mots et ramenés à 5 niveaux par VetApp. Ce n\'est pas un document officiel de la WSAVA.';

  @override
  String get monitoringBcsSourceRabbit =>
      'Rabbit Size-O-Meter à 5 niveaux de la PFMA (Pet Food Manufacturers\' Association), résumé avec nos propres mots. La fiabilité entre évaluateurs est limitée (Halck et al., Veterinary Record, 2025).';

  @override
  String get monitoringBcsNotAssessed => 'Non évaluée';

  @override
  String get monitoringBcsAssess => 'Évaluer la corpulence';

  @override
  String get monitoringBcsReassess => 'Réévaluer la corpulence';

  @override
  String get monitoringBcsGuideDog1Touch =>
      'Les côtes, la colonne et les os du bassin se sentent tout de suite sous la peau : il n\'y a presque pas de graisse et les muscles semblent réduits. Exemple : c\'est comme toucher les articulations d\'une main fermée en poing, où l\'os est juste sous la peau et où il n\'y a rien entre les deux.';

  @override
  String get monitoringBcsGuideDog1Above =>
      'Taille très étroite et creusée derrière les côtes ; les os de la hanche et du dos ressortent. Vu de dessus, le corps rappelle un sablier très fin.';

  @override
  String get monitoringBcsGuideDog1Side =>
      'Ventre très rentré, le profil remonte nettement vers les pattes arrière. Les côtes peuvent se voir même de loin, surtout chez les chiens à poil ras.';

  @override
  String get monitoringBcsGuideDog2Touch =>
      'Les côtes se sentent sans appuyer, avec très peu de graisse dessus, et se voient parfois. Exemple : en passant la main sur le flanc, vous sentez chaque côte comme une marche distincte, sans la couche douce d\'un chien en bonne condition.';

  @override
  String get monitoringBcsGuideDog2Above =>
      'Taille bien marquée derrière les côtes ; les os du bassin commencent à se remarquer. Pour la repérer, regardez le chien debout, de dessus : le corps se rétrécit nettement après la dernière côte.';

  @override
  String get monitoringBcsGuideDog2Side =>
      'Ventre nettement rentré. Chez les chiots en croissance et les chiens très athlétiques, cet aspect peut être normal : comparez-le avec les côtes au toucher.';

  @override
  String get monitoringBcsGuideDog3Touch =>
      'Les côtes se sentent bien sous une fine couche de graisse, sans avoir à appuyer. Exemple : c\'est comme toucher le dos de la main ouverte et à plat, où l\'on sent les tendons sous la peau mais pas l\'os tranchant.';

  @override
  String get monitoringBcsGuideDog3Above =>
      'On voit une taille derrière les côtes. Pour la repérer, regardez le chien debout, de dessus : entre le thorax et le bassin, le corps se rétrécit légèrement, sans déborder sur les côtés.';

  @override
  String get monitoringBcsGuideDog3Side =>
      'Le ventre remonte en douceur de la poitrine vers les pattes arrière. Chez les chiens à poil long ou épais, la silhouette se devine mieux en passant les mains sur le corps qu\'en regardant.';

  @override
  String get monitoringBcsGuideDog4Touch =>
      'Les côtes se sentent avec un peu de peine : la couche de graisse est plus épaisse, surtout sur le dos près de la queue. Exemple : c\'est comme toucher le dos de la main quand les doigts sont fermés en poing souple, avec plus de chair sur les os.';

  @override
  String get monitoringBcsGuideDog4Above =>
      'La taille se devine à peine ou ne se voit plus. Vu de dessus, le corps paraît presque rectangulaire, sans rétrécissement derrière les côtes.';

  @override
  String get monitoringBcsGuideDog4Side =>
      'Le creux du ventre est peu marqué. Attention à ne pas confondre poil épais et graisse : palpez toujours les côtes avant de décider.';

  @override
  String get monitoringBcsGuideDog5Touch =>
      'Les côtes ne se sentent pas, ou seulement en appuyant fort, sous une grosse couche de graisse qui s\'accumule sur le dos et à la base de la queue. Exemple : c\'est comme chercher les os dans la paume de la main, où il n\'y a sous la peau qu\'un épais coussinet mou.';

  @override
  String get monitoringBcsGuideDog5Above =>
      'Aucune taille : le corps est large et arrondi, le ventre peut sembler gonflé. Vu de dessus, le chien paraît plus large aux flancs qu\'au thorax.';

  @override
  String get monitoringBcsGuideDog5Side =>
      'Aucun creux : le ventre est rond ou pend vers le bas. Un chien dans cet état se fatigue vite et a du mal à se déplacer : parlez-en au vétérinaire.';

  @override
  String get monitoringBcsGuideCat1Touch =>
      'Les côtes et les vertèbres du dos se sentent sans aucune couche de graisse ; chez les chats à poil court, les côtes se voient. Exemple : c\'est comme toucher les articulations d\'une main fermée en poing, des os juste sous la peau.';

  @override
  String get monitoringBcsGuideCat1Above =>
      'Taille très étroite derrière les côtes. Vu de dessus, le corps est fin comme un sablier très étroit.';

  @override
  String get monitoringBcsGuideCat1Side =>
      'Ventre très rentré, aucun coussinet de graisse sous le ventre. Les muscles de chaque côté de la colonne semblent eux aussi réduits.';

  @override
  String get monitoringBcsGuideCat2Touch =>
      'Les côtes se sentent facilement, avec très peu de graisse, et les vertèbres du dos se remarquent. Exemple : en passant la main sur le flanc, vous sentez chaque côte distincte, sans le voile doux d\'un chat en bonne condition.';

  @override
  String get monitoringBcsGuideCat2Above =>
      'Taille bien visible derrière les côtes. Regardez-le de dessus quand il est debout : le corps se rétrécit nettement après la cage thoracique.';

  @override
  String get monitoringBcsGuideCat2Side =>
      'Ventre un peu rentré, avec peu ou pas de coussinet de graisse. Chez les chats âgés, la maigreur peut cacher un problème de santé : si elle est récente, demandez au vétérinaire.';

  @override
  String get monitoringBcsGuideCat3Touch =>
      'Les côtes se sentent sous un léger voile de graisse. Exemple : c\'est comme toucher le dos de la main ouverte et à plat, où l\'on sent les tendons sous la peau mais pas l\'os tranchant.';

  @override
  String get monitoringBcsGuideCat3Above =>
      'Corps bien proportionné, avec une taille visible derrière les côtes. Vu de dessus, le chat dessine un léger sablier, sans déborder sur les côtés.';

  @override
  String get monitoringBcsGuideCat3Side =>
      'Le profil du ventre est souple, avec un coussinet de graisse à peine esquissé. Chez les chats à poil long, la silhouette se devine mieux avec les mains qu\'avec les yeux.';

  @override
  String get monitoringBcsGuideCat4Touch =>
      'Les côtes sont plus difficiles à sentir : il faut appuyer un peu, car il y a plus de graisse. Exemple : c\'est comme toucher le dos de la main quand les doigts sont fermés en poing souple, avec plus de chair sur les os.';

  @override
  String get monitoringBcsGuideCat4Above =>
      'La taille se voit peu ou pas du tout. Vu de dessus, le corps paraît presque rectangulaire, sans rétrécissement derrière les côtes.';

  @override
  String get monitoringBcsGuideCat4Side =>
      'Ventre arrondi, avec un coussinet de graisse modéré sous le ventre. Quand le chat marche, le coussinet oscille légèrement : chez les chats en bonne condition, il est à peine esquissé.';

  @override
  String get monitoringBcsGuideCat5Touch =>
      'Les côtes ne se sentent pas sous une grosse couche de graisse, qui s\'accumule aussi sur le dos et, dans les cas extrêmes, sur le museau et les pattes. Exemple : c\'est comme chercher les os dans la paume de la main, où il n\'y a qu\'un coussinet mou.';

  @override
  String get monitoringBcsGuideCat5Above =>
      'Aucune taille : le corps est large. Vu de dessus, il paraît plus large aux flancs qu\'au thorax.';

  @override
  String get monitoringBcsGuideCat5Side =>
      'Ventre rond ou pendant, avec un coussinet de graisse bien visible. Le chat a du mal à entretenir son pelage sur le dos et l\'arrière-train : parlez-en au vétérinaire.';

  @override
  String get monitoringBcsGuideRabbit1Touch =>
      'La colonne, les côtes et les os de la hanche ressortent et sont tranchants sous la peau : il n\'y a pas de graisse et les muscles sont réduits. Exemple : c\'est comme toucher les articulations d\'une main fermée en poing, avec l\'os juste sous la peau.';

  @override
  String get monitoringBcsGuideRabbit1Above =>
      'Dos et flancs creusés, les os de la hanche se remarquent. Vu de dessus, le corps paraît étroit et anguleux.';

  @override
  String get monitoringBcsGuideRabbit1Side =>
      'L\'arrière-train (la croupe) est creusé et s\'incurve vers l\'intérieur. Un lapin aussi maigre doit être montré rapidement au vétérinaire.';

  @override
  String get monitoringBcsGuideRabbit2Touch =>
      'Les côtes, la colonne et la hanche se sentent facilement, avec peu de graisse dessus. Exemple : en passant la main sur le dos, vous sentez les vertèbres comme une rangée de petites saillies bien distinctes.';

  @override
  String get monitoringBcsGuideRabbit2Above =>
      'Flancs minces, colonne peu recouverte. Vu de dessus, le corps est plus étroit que vous ne le penseriez.';

  @override
  String get monitoringBcsGuideRabbit2Side =>
      'L\'arrière-train est plat. Chez les lapins à poil long, le poil cache la maigreur : palpez toujours le dos et la hanche.';

  @override
  String get monitoringBcsGuideRabbit3Touch =>
      'Les côtes et la colonne se sentent facilement, mais leurs contours sont doux et arrondis, pas tranchants. Exemple : c\'est comme toucher le dos de la main ouverte et à plat, où l\'on sent les os sous une peau souple.';

  @override
  String get monitoringBcsGuideRabbit3Above =>
      'Corps bien proportionné, sans renflements aux flancs. Vu de dessus, la silhouette est uniforme, du cou à la queue.';

  @override
  String get monitoringBcsGuideRabbit3Side =>
      'L\'arrière-train est plat et le ventre ne dépasse pas. Le dos forme une courbe régulière, ni creusée ni gonflée.';

  @override
  String get monitoringBcsGuideRabbit4Touch =>
      'Pour sentir les côtes, la colonne et la hanche, il faut appuyer : il y a des couches de graisse. Exemple : c\'est comme toucher le dos de la main quand les doigts sont fermés en poing souple, avec plus de chair sur les os.';

  @override
  String get monitoringBcsGuideRabbit4Above =>
      'Flancs pleins et arrondis. Vu de dessus, le corps paraît plus large que vous ne le penseriez.';

  @override
  String get monitoringBcsGuideRabbit4Side =>
      'L\'arrière-train est arrondi. On remarque souvent aussi un léger renflement sous le menton, surtout chez les femelles.';

  @override
  String get monitoringBcsGuideRabbit5Touch =>
      'La colonne et la hanche se sentent à peine et les côtes pas du tout, sous une grosse couche de graisse. Exemple : c\'est comme chercher les os dans la paume de la main, où il n\'y a qu\'un coussinet mou.';

  @override
  String get monitoringBcsGuideRabbit5Above =>
      'Corps large et plein, avec l\'arrière-train qui déborde. Vu de dessus, la silhouette est très arrondie.';

  @override
  String get monitoringBcsGuideRabbit5Side =>
      'Le ventre descend et forme un coussinet de graisse sous le ventre. Un lapin aussi bien en chair a du mal à se nettoyer et peut avoir des problèmes de peau sous la queue : demandez au vétérinaire.';

  @override
  String get monitoringAddMeasurement => 'Nouvelle mesure';

  @override
  String get monitoringCurrentWeight => 'Poids actuel';

  @override
  String monitoringMeasuredOn(String date) {
    return 'Mesuré le $date';
  }

  @override
  String monitoringChangeSince(String change, String date) {
    return '$change depuis le $date';
  }

  @override
  String get monitoringEmptyTitle => 'Aucune mesure pour l\'instant';

  @override
  String monitoringEmptyBody(String petName) {
    return 'Enregistrez le poids de $petName pour suivre son évolution dans le temps.';
  }

  @override
  String get monitoringBcsTitle => 'Corpulence';

  @override
  String monitoringBcsAsOf(String date) {
    return 'Depuis la mesure du $date';
  }

  @override
  String get monitoringBcsNone =>
      'Touchez « Évaluer la corpulence » pour la voir ici.';

  @override
  String get monitoringBcsVeryThin => 'Très maigre';

  @override
  String get monitoringBcsThin => 'Maigre';

  @override
  String get monitoringBcsNormal => 'Normale';

  @override
  String get monitoringBcsSlightlyOverweight => 'Léger surpoids';

  @override
  String get monitoringBcsOverweight => 'Surpoids';

  @override
  String get monitoringChartTitleWeight => 'Évolution du poids';

  @override
  String get monitoringChartTitleGrowth => 'Courbe de croissance';

  @override
  String monitoringChartGrowthHint(String petName) {
    return 'Le poids de $petName selon l\'âge, sans courbes de référence : uniquement ses mesures.';
  }

  @override
  String get monitoringChartSinglePoint =>
      'Ajoutez une autre mesure pour voir l\'évolution.';

  @override
  String monitoringChartGrowthHintReference(String petName) {
    return 'Le poids de $petName selon l\'âge, comparé à la zone de référence.';
  }

  @override
  String get monitoringGrowthLegend =>
      'Zone foncée : du 25e au 75e percentile (la moitié centrale). Zone claire : du 3e au 97e. Ligne en pointillés : médiane.';

  @override
  String monitoringGrowthSourcePuppy(String sizeLabel) {
    return 'Référence : chiens en bonne santé dont le poids adulte est $sizeLabel. Dérivé de données CC BY 4.0 de Salt C. et al., PLOS ONE 2017 ; ce ne sont pas les courbes officielles WALTHAM.';
  }

  @override
  String get monitoringGrowthSourceKitten =>
      'Référence : chatons domestiques à poil court non stérilisés (États-Unis). Dérivé de données CC BY 3.0 de Salt C. et al., PLOS ONE 2022 ; ce ne sont pas les courbes officielles WALTHAM.';

  @override
  String monitoringGrowthDisclaimer(String petName) {
    return 'C\'est une référence, pas un diagnostic : chaque animal grandit à son rythme. Si le poids de $petName sort souvent de la zone ou change brusquement, parlez-en au vétérinaire.';
  }

  @override
  String monitoringGrowthExpectedAdult(String range) {
    return 'Poids adulte attendu : $range';
  }

  @override
  String get monitoringGrowthChange => 'Modifier';

  @override
  String get monitoringGrowthPromptTitle => 'Afficher la zone de référence';

  @override
  String monitoringGrowthPromptBody(String petName) {
    return 'Pour comparer $petName à des chiots en bonne santé, il faut connaître son poids à l\'âge adulte : choisissez la tranche la plus probable (race, parents, vétérinaire).';
  }

  @override
  String get monitoringGrowthPromptButton => 'Choisir le poids adulte';

  @override
  String get monitoringGrowthNoReferenceHeavy =>
      'Pour les chiens de plus de 40 kg, il n\'existe pas de courbes de référence fiables : les très grandes races grandissent de façons très différentes.';

  @override
  String monitoringGrowthSheetTitle(String petName) {
    return 'Poids adulte attendu de $petName';
  }

  @override
  String monitoringGrowthClassUnder(String max) {
    return 'Moins de $max';
  }

  @override
  String monitoringGrowthClassBetween(String min, String max) {
    return 'De $min à $max';
  }

  @override
  String monitoringGrowthClassOver(String min) {
    return 'Plus de $min';
  }

  @override
  String get monitoringGrowthClassUnknown =>
      'Je ne sais pas : pas de zone de référence';

  @override
  String get monitoringAxisAgeMonths => 'Âge (mois)';

  @override
  String monitoringAxisWeight(String unit) {
    return 'Poids ($unit)';
  }

  @override
  String monitoringTooltipAge(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months mois',
      one: '1 mois',
    );
    return '$_temp0';
  }

  @override
  String get monitoringHistoryTitle => 'Historique';

  @override
  String get monitoringDeleteTitle => 'Supprimer la mesure ?';

  @override
  String monitoringDeleteMessage(String date) {
    return 'Le poids du $date sera retiré de l\'historique.';
  }

  @override
  String get monitoringSheetTitleNew => 'Nouvelle mesure';

  @override
  String get monitoringSheetTitleEdit => 'Modifier la mesure';

  @override
  String get monitoringFieldDate => 'Date';

  @override
  String get monitoringFieldWeightKg => 'Poids (kg)';

  @override
  String get monitoringFieldWeightLb => 'Poids (lb)';

  @override
  String get monitoringFieldWeightHintKg => 'Ex. 10,5';

  @override
  String get monitoringFieldWeightHintLb => 'Ex. 22,5';

  @override
  String get monitoringFieldNote => 'Note (facultative)';

  @override
  String get monitoringErrorWeight =>
      'Saisissez un poids valide, supérieur à zéro.';

  @override
  String get monitoringErrorDateFuture =>
      'La date ne peut pas être dans le futur.';

  @override
  String monitoringErrorDateBirth(String petName) {
    return 'La date est antérieure à la naissance de $petName.';
  }

  @override
  String get monitoringSaveFailed =>
      'Je n\'ai pas pu enregistrer la mesure : réessayez.';

  @override
  String get monitoringDeleteFailed =>
      'Je n\'ai pas pu supprimer la mesure : réessayez.';

  @override
  String get monitoringActivityTitle => 'Activité';

  @override
  String monitoringActivitySubtitle(String petName) {
    return 'Les promenades de $petName ces dernières semaines.';
  }

  @override
  String get monitoringActivityDistance => 'Distance';

  @override
  String get monitoringActivityTime => 'Durée';

  @override
  String get monitoringActivityStatWalks => 'Promenades';

  @override
  String monitoringActivityEmpty(String petName) {
    return 'Aucune promenade ces 3 derniers mois. Enregistrez une promenade depuis l\'onglet Promenades pour voir ici l\'activité de $petName.';
  }

  @override
  String monitoringActivityWeekOf(String date) {
    return 'Semaine du $date';
  }

  @override
  String monitoringActivityWalkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count promenades',
      one: '1 promenade',
      zero: '0 promenade',
    );
    return '$_temp0';
  }

  @override
  String get medCatVisit => 'Visites';

  @override
  String get medCatExam => 'Examens';

  @override
  String get medCatVaccine => 'Vaccins';

  @override
  String get medCatTherapy => 'Traitements';

  @override
  String get medCatDocument => 'Documents';

  @override
  String get medCatCondition => 'Pathologies';

  @override
  String get medCatVisitOne => 'Visite';

  @override
  String get medCatExamOne => 'Examen';

  @override
  String get medCatVaccineOne => 'Vaccin';

  @override
  String get medCatTherapyOne => 'Traitement';

  @override
  String get medCatDocumentOne => 'Document';

  @override
  String medCatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrés',
      one: '1 enregistré',
      zero: '0 enregistré',
    );
    return '$_temp0';
  }

  @override
  String get medSubCheckup => 'Visite de contrôle';

  @override
  String get medSubSpecialist => 'Visite spécialisée';

  @override
  String get medSubFirstVisit => 'Première visite';

  @override
  String get medSubEmergency => 'Urgence';

  @override
  String get medSubPostSurgery => 'Contrôle postopératoire';

  @override
  String get medSubBlood => 'Analyse de sang';

  @override
  String get medSubUrine => 'Examen des urines';

  @override
  String get medSubStool => 'Examen des selles';

  @override
  String get medSubXray => 'Radiographie';

  @override
  String get medSubUltrasound => 'Échographie';

  @override
  String get medSubAntiparasitic => 'Antiparasitaire';

  @override
  String get medSubMedication => 'Médicament';

  @override
  String get medSubOther => 'Autre';

  @override
  String get medAddTitle => 'Que souhaitez-vous ajouter ?';

  @override
  String get medAddAction => 'Ajouter';

  @override
  String get medCatConditionOne => 'Pathologie';

  @override
  String get medHistoryTitle => 'Historique';

  @override
  String get medHistorySubtitle =>
      'Tous les événements enregistrés, mois par mois.';

  @override
  String get medHistoryEmpty => 'Aucun événement enregistré';

  @override
  String get medHistoryPrevMonth => 'Mois précédent';

  @override
  String get medHistoryNextMonth => 'Mois suivant';

  @override
  String medHistoryDayTitle(String date) {
    return 'Événements du $date';
  }

  @override
  String get medHistoryDayEmpty => 'Aucun événement ce jour-là';

  @override
  String medHistoryDayA11y(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
      zero: 'aucun événement',
    );
    return '$date : $_temp0';
  }

  @override
  String get medHistorySend => 'Envoyer l\'historique';

  @override
  String get medHistorySendAll => 'Tout l\'historique (PDF)';

  @override
  String get medHistorySendAllSubtitle =>
      'Un PDF avec tous les événements par ordre chronologique';

  @override
  String get medHistorySendFiles => 'Fichiers individuels';

  @override
  String get medHistoryPreparing => 'Je prépare le PDF…';

  @override
  String get medHistoryExportFailed =>
      'Je n\'ai pas pu préparer le PDF. Réessayez.';

  @override
  String get medHistoryConditionsMissing =>
      'Je n\'ai pas pu lire les pathologies : elles ne figurent pas dans le PDF.';

  @override
  String medPdfTitle(String petName) {
    return 'Historique clinique de $petName';
  }

  @override
  String get medPdfSpeciesBreed => 'Espèce et race';

  @override
  String get medPdfBirthDate => 'Date de naissance';

  @override
  String get medPdfExportDate => 'Date d\'exportation';

  @override
  String get medPdfColDate => 'Date';

  @override
  String get medPdfColCategory => 'Catégorie';

  @override
  String get medPdfColTitle => 'Titre';

  @override
  String get medPdfColNotes => 'Notes';

  @override
  String get medPdfNoDate => 'Sans date';

  @override
  String get medPdfEmpty => 'Aucun événement enregistré.';

  @override
  String medPdfPage(int page, int pages) {
    return 'Page $page sur $pages';
  }

  @override
  String get medPdfConditionOngoing => 'En cours';

  @override
  String get medPdfConditionResolved => 'Résolue';

  @override
  String medPdfConditionResolvedOn(String date) {
    return 'Résolue le $date';
  }

  @override
  String medPdfConditionTherapy(String therapy) {
    return 'Traitement : $therapy';
  }

  @override
  String get medNewVisit => 'Nouvelle visite';

  @override
  String get medNewExam => 'Nouvel examen';

  @override
  String get medNewVaccine => 'Nouveau vaccin';

  @override
  String get medNewTherapy => 'Nouveau traitement';

  @override
  String get medNewDocument => 'Nouveau document';

  @override
  String get medNewCondition => 'Nouvelle pathologie';

  @override
  String get medEmptyVisitTitle => 'Aucune visite enregistrée';

  @override
  String medEmptyVisitBody(String petName) {
    return 'Ajoutez les visites de $petName pour retrouver les contrôles et les indications du vétérinaire au même endroit.';
  }

  @override
  String get medEmptyVisitAction => 'Ajouter la première visite';

  @override
  String get medEmptyExamTitle => 'Aucun examen enregistré';

  @override
  String medEmptyExamBody(String petName) {
    return 'Chargez les examens de $petName, comme les analyses de sang ou les radiographies, pour les avoir toujours à portée de main.';
  }

  @override
  String get medEmptyExamAction => 'Ajouter le premier examen';

  @override
  String get medEmptyVaccineTitle => 'Aucun vaccin enregistré';

  @override
  String medEmptyVaccineBody(String petName) {
    return 'Gardez ici les vaccins et les rappels de $petName, avec la date de chaque administration.';
  }

  @override
  String get medEmptyVaccineAction => 'Ajouter le premier vaccin';

  @override
  String get medEmptyTherapyTitle => 'Aucun traitement enregistré';

  @override
  String medEmptyTherapyBody(String petName) {
    return 'Notez les traitements de $petName : médicaments, antiparasitaires et soins en cours ou passés.';
  }

  @override
  String get medEmptyTherapyAction => 'Ajouter le premier traitement';

  @override
  String get medEmptyDocumentTitle => 'Aucun document chargé';

  @override
  String medEmptyDocumentBody(String petName) {
    return 'Chargez les comptes rendus, certificats et autres documents de $petName pour les partager avec le vétérinaire.';
  }

  @override
  String get medEmptyDocumentAction => 'Ajouter le premier document';

  @override
  String get medEmptyConditionTitle => 'Aucune pathologie enregistrée';

  @override
  String medEmptyConditionBody(String petName) {
    return 'Notez les maladies de $petName, en cours ou déjà résolues, avec les dates et le traitement.';
  }

  @override
  String get medEmptyConditionAction => 'Ajouter la première pathologie';

  @override
  String get medFieldTitle => 'Titre';

  @override
  String get medFieldCategory => 'Catégorie';

  @override
  String get medFieldType => 'Type';

  @override
  String get medFieldTypeNone => 'Non précisé';

  @override
  String get medFieldEventDate => 'Date';

  @override
  String get medFieldNotes => 'Notes';

  @override
  String get medFieldNotesHint => 'Écrivez une note facultative.';

  @override
  String get medFieldFile => 'Pièce jointe';

  @override
  String get medAttachAdd => 'Ajouter un fichier';

  @override
  String get medAttachChange => 'Changer de fichier';

  @override
  String get medEditDetailsTitle => 'Modifier les détails';

  @override
  String get medTitleRequired => 'Saisissez un titre ou joignez un fichier.';

  @override
  String get medDateInvalid => 'Date non valide (jj/mm/aaaa).';

  @override
  String get medDatePlaceholder => 'jj/mm/aaaa';

  @override
  String medSuggestHint(String category) {
    return 'D\'après le titre, il s\'agit de : $category. Voulez-vous le classer ainsi ?';
  }

  @override
  String get medSuggestApply => 'Oui, classer';

  @override
  String medSuggestPill(String category) {
    return 'Peut-être : $category';
  }

  @override
  String medActionClassifyAs(String category) {
    return 'Classer comme $category';
  }

  @override
  String get medActionEditDetails => 'Modifier les détails';

  @override
  String get medCondName => 'Nom de la pathologie';

  @override
  String get medCondNameRequired => 'Saisissez le nom de la pathologie.';

  @override
  String get medCondStarted => 'Date de début';

  @override
  String get medCondStatus => 'État';

  @override
  String get medCondOngoing => 'En cours';

  @override
  String get medCondResolved => 'Résolue';

  @override
  String get medCondEnded => 'Date de fin';

  @override
  String get medCondEndBeforeStart =>
      'La date de fin est antérieure à la date de début.';

  @override
  String get medCondTherapy => 'Traitement';

  @override
  String get medCondTherapyHint => 'Médicaments, doses, durée…';

  @override
  String get medCondAttachment => 'Ordonnance ou documents';

  @override
  String medCondSince(String date) {
    return 'Depuis le $date';
  }

  @override
  String medCondPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String get medCondSaveFailed =>
      'Je n\'ai pas pu enregistrer la pathologie. Réessayez.';

  @override
  String get medCondDeleteFailed =>
      'Je n\'ai pas pu supprimer la pathologie. Réessayez.';

  @override
  String get medCondDeleteTitle => 'Supprimer cette pathologie ?';

  @override
  String medCondDeleteBody(String name) {
    return '« $name » sera supprimée.';
  }

  @override
  String get medCondLoadError =>
      'Je n\'arrive pas à lire les pathologies. Vérifiez votre connexion et réessayez.';

  @override
  String get medCondUploadFailed =>
      'Je n\'ai pas pu charger le fichier. Réessayez.';

  @override
  String get medCondOpenFile => 'Ouvrir la pièce jointe';

  @override
  String get medicalRecordSourceFromReminder => 'Depuis un rappel';

  @override
  String get reminderCatGrooming => 'Toilettage';

  @override
  String get reminderCatOther => 'Autre';

  @override
  String get remindersFormCategory => 'Catégorie';

  @override
  String get remindersFormSubtype => 'Type';

  @override
  String get remindersFormSubtypeNone => 'Aucun';

  @override
  String get remindersDoneTitle => 'Fait ?';

  @override
  String remindersDoneRecordHint(String pet) {
    return 'Enregistrez-le dans l\'historique de $pet.';
  }

  @override
  String get remindersDonePlainHint => 'Je le marque comme fait ?';

  @override
  String get remindersDoneFieldTitle => 'Titre';

  @override
  String get remindersDoneFieldDate => 'Quand cela a eu lieu';

  @override
  String get remindersDoneFieldNotes => 'Notes (facultatives)';

  @override
  String get remindersDoneConfirmRecord => 'Oui, enregistrer';

  @override
  String get remindersDoneConfirmPlain => 'Oui, c\'est fait';

  @override
  String get remindersDonePostpone => 'Reporter';

  @override
  String get remindersDoneNotDone => 'Pas fait';

  @override
  String remindersDoneRecorded(String pet) {
    return 'Enregistré dans l\'historique de $pet.';
  }

  @override
  String get remindersDoneMarked => 'Marqué comme fait.';

  @override
  String get remindersDoneDismissed => 'Marqué comme non fait.';

  @override
  String get remindersDonePostponed => 'Je vous le redemanderai demain.';

  @override
  String get remindersDoneTooltip => 'Marquer comme fait';
}

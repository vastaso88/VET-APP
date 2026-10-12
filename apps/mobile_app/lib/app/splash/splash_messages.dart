import '../../l10n/l10n.dart';

/// Feature teasers rotated under the splash animation while the app
/// preloads (one every ~2.5 s), in the language of [l10n].
List<String> splashMessagesFor(AppLocalizations l10n) => [
      l10n.splashMessageWalks,
      l10n.splashMessageVet,
      l10n.splashMessageReminders,
      l10n.splashMessageRecords,
      l10n.splashMessageNearby,
      l10n.splashMessageNews,
      l10n.splashMessageProfiles,
      l10n.splashMessageHealthBook,
      l10n.splashMessageVaccines,
      l10n.splashMessageSpecies,
    ];

/// The teasers in the app language, for code that has no BuildContext.
List<String> get splashMessages => splashMessagesFor(appL10n);

/// Species shown scrolling in the splash animation.
const splashAnimals = <String>['🐶', '🐱', '🐰', '🐦', '🐠', '🐹', '🐢', '🦜'];

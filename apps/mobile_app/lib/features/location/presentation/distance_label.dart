import '../../settings/data/unit_settings_store.dart';
import '../../settings/domain/unit_conversion.dart';

/// Shared "how far" formatting, used anywhere a distance-to-me is shown
/// (marketplace listings, local activities), in the owner's unit system.
String formatDistance(double distanceMeters) =>
    formatDistanceIn(distanceMeters, UnitSettingsStore.instance.system);

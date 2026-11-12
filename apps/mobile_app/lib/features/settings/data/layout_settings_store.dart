import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/l10n.dart';

enum WeekStartDay { monday, sunday }

/// Text size of the chat bubbles and the message box. [normal] is the size
/// the chat had before this setting existed; the default is one step up
/// because owners found the original small.
enum ChatTextSize {
  small(0.9),
  normal(1.0),
  large(1.15),
  extraLarge(1.3);

  const ChatTextSize(this.scale);

  final double scale;

  String get label => switch (this) {
        ChatTextSize.small => appL10n.settingsTextSizeSmall,
        ChatTextSize.normal => appL10n.settingsTextSizeNormal,
        ChatTextSize.large => appL10n.settingsTextSizeLarge,
        ChatTextSize.extraLarge => appL10n.settingsTextSizeExtraLarge,
      };

  static ChatTextSize fromName(String? name) {
    for (final size in ChatTextSize.values) {
      if (size.name == name) return size;
    }
    return ChatTextSize.large;
  }
}

class LayoutSettings {
  const LayoutSettings({
    this.weeksShown = 2,
    this.weekStartDay = WeekStartDay.monday,
    this.chatTextSize = ChatTextSize.large,
  });

  /// How many weeks the Home agenda's week-strip shows at once, 1-4.
  final int weeksShown;
  final WeekStartDay weekStartDay;
  final ChatTextSize chatTextSize;

  LayoutSettings copyWith({
    int? weeksShown,
    WeekStartDay? weekStartDay,
    ChatTextSize? chatTextSize,
  }) {
    return LayoutSettings(
      weeksShown: weeksShown ?? this.weeksShown,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      chatTextSize: chatTextSize ?? this.chatTextSize,
    );
  }
}

/// Session-lifetime, persisted (shared_preferences) store for Home layout
/// preferences. A [ChangeNotifier] singleton — same pattern as
/// ChatDemoStore/PetDemoStore — so Home reacts live when the user changes a
/// setting, instead of requiring a full app restart to take effect.
class LayoutSettingsStore extends ChangeNotifier {
  LayoutSettingsStore._();

  static final LayoutSettingsStore instance = LayoutSettingsStore._();

  static const _storageKey = 'vet_app.layout_settings';

  LayoutSettings _settings = const LayoutSettings();
  LayoutSettings get settings => _settings;

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      _settings = LayoutSettings(
        weeksShown: ((payload['weeks_shown'] as num?)?.toInt() ?? 2).clamp(1, 4),
        weekStartDay:
            payload['week_start'] == 'sunday' ? WeekStartDay.sunday : WeekStartDay.monday,
        chatTextSize: ChatTextSize.fromName(payload['chat_text_size'] as String?),
      );
      notifyListeners();
    } catch (_) {
      // Keep defaults — a corrupt or missing preference isn't fatal.
    }
  }

  Future<void> update(LayoutSettings settings) async {
    _settings = settings;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          'weeks_shown': settings.weeksShown,
          'week_start': settings.weekStartDay == WeekStartDay.sunday ? 'sunday' : 'monday',
          'chat_text_size': settings.chatTextSize.name,
        }),
      );
    } catch (_) {
      // Best-effort: the in-memory value above already applied for this
      // session even if writing the preference itself fails.
    }
  }
}

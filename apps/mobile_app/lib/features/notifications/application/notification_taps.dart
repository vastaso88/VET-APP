import 'package:flutter/foundation.dart';

import '../domain/notification_plan.dart';

/// The notification the owner last tapped, as the id of its reminder, waiting
/// to be handled once the app is up (the shell asks "Fatto?" for it). A tap
/// that started the app is kept until then.
class NotificationTaps {
  NotificationTaps._();

  static final NotificationTaps instance = NotificationTaps._();

  /// The reminder id of the pending tap, null when there is none.
  final ValueNotifier<String?> pendingReminderId = ValueNotifier<String?>(null);

  /// Called with a notification's payload; anything that does not belong to a
  /// reminder is ignored.
  void add(String? payload) {
    if (payload == null || !payload.startsWith(kReminderPayloadPrefix)) return;
    final id = payload.substring(kReminderPayloadPrefix.length);
    if (id.isEmpty) return;
    pendingReminderId.value = id;
  }

  /// Takes the pending tap (so it is handled once).
  String? take() {
    final id = pendingReminderId.value;
    pendingReminderId.value = null;
    return id;
  }
}

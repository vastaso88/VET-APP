import 'package:flutter/foundation.dart';

import '../domain/memory_notifications.dart';
import '../domain/notification_plan.dart';

/// The notification the owner last tapped, as the id of its reminder, waiting
/// to be handled once the app is up (the shell asks "Fatto?" for it). A tap
/// that started the app is kept until then.
class NotificationTaps {
  NotificationTaps._();

  static final NotificationTaps instance = NotificationTaps._();

  /// The reminder id of the pending tap, null when there is none.
  final ValueNotifier<String?> pendingReminderId = ValueNotifier<String?>(null);

  /// The memory notification (Ricordi) the owner tapped, waiting for the
  /// shell to open that pet's memorial page.
  final ValueNotifier<MemoryTap?> pendingMemory = ValueNotifier<MemoryTap?>(null);

  /// Called with a notification's payload; anything that does not belong to a
  /// reminder or a memory is ignored.
  void add(String? payload) {
    final memory = MemoryTap.parse(payload);
    if (memory != null) {
      pendingMemory.value = memory;
      return;
    }
    if (payload == null || !payload.startsWith(kReminderPayloadPrefix)) return;
    final id = payload.substring(kReminderPayloadPrefix.length);
    if (id.isEmpty) return;
    pendingReminderId.value = id;
  }

  /// Takes the pending memory tap (so it is handled once).
  MemoryTap? takeMemory() {
    final memory = pendingMemory.value;
    pendingMemory.value = null;
    return memory;
  }

  /// Takes the pending tap (so it is handled once).
  String? take() {
    final id = pendingReminderId.value;
    pendingReminderId.value = null;
    return id;
  }
}

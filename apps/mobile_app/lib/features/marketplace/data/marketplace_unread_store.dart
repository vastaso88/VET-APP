import 'package:flutter/foundation.dart';

import 'marketplace_messages_repository.dart';

/// How many Mercatino messages the owner has not read: the number on the
/// envelope. In memory only and read from the backend at each opening and every
/// [pollInterval] while a Mercatino page is open (there are no push notifications
/// yet). Emptied at sign-out by bootstrap.dart.
class MarketplaceUnreadStore {
  MarketplaceUnreadStore._();

  static final MarketplaceUnreadStore instance = MarketplaceUnreadStore._();

  static const pollInterval = Duration(seconds: 60);

  final ValueNotifier<int> count = ValueNotifier<int>(0);

  // An answer that was on its way when the owner signed out is not theirs to show.
  int _session = 0;

  /// Never throws: a wrong number on the envelope must not disturb the page.
  Future<void> refresh(MarketplaceMessagesRepository repository) async {
    final session = _session;
    try {
      final total = await repository.unreadTotal();
      if (session == _session) count.value = total;
    } on Exception {
      // Keep the last number until the next attempt.
    }
  }

  void reset() {
    _session++;
    count.value = 0;
  }
}

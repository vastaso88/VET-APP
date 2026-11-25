import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../data/marketplace_messages_repository.dart';
import '../../data/marketplace_unread_store.dart';
import '../pages/marketplace_conversations_page.dart';
import 'visibility_poller.dart';

/// The envelope in the Mercatino's bar, with the number of unread messages. It
/// asks at opening and then every minute, but only while its page is the one on
/// screen and the app is in the foreground (a covered page stays mounted: it must
/// not keep asking); it asks again at once when the owner is back. Push
/// notifications do not exist in the app yet.
class MarketplaceMessagesButton extends StatefulWidget {
  const MarketplaceMessagesButton({super.key, this.repository});

  final MarketplaceMessagesRepository? repository;

  @override
  State<MarketplaceMessagesButton> createState() => _MarketplaceMessagesButtonState();
}

class _MarketplaceMessagesButtonState extends State<MarketplaceMessagesButton> {
  late final MarketplaceMessagesRepository _repository =
      widget.repository ?? MarketplaceMessagesRepository();
  late final VisibilityPoller _poller = VisibilityPoller(
    interval: MarketplaceUnreadStore.pollInterval,
    onPoll: () => unawaited(MarketplaceUnreadStore.instance.refresh(_repository)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _poller.attach(ModalRoute.of(context));
  }

  @override
  void dispose() {
    _poller.dispose();
    super.dispose();
  }

  /// The conversations page covers this one; when it is closed the poller reads
  /// the number again at once, so the envelope matches what was just read.
  Future<void> _open() => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MarketplaceConversationsPage(repository: _repository),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MarketplaceUnreadStore.instance.count,
      builder: (context, count, _) => IconButton(
        key: const ValueKey('marketplace-messages-button'),
        tooltip: context.l10n.marketplaceMessagesOpen(count),
        onPressed: _open,
        icon: Badge(
          key: const ValueKey('marketplace-messages-badge'),
          isLabelVisible: count > 0,
          label: Text('$count', textScaler: TextScaler.noScaling),
          child: const Icon(Icons.mail_outline_rounded),
        ),
      ),
    );
  }
}

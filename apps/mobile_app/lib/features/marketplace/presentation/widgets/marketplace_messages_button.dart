import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../data/marketplace_messages_repository.dart';
import '../../data/marketplace_unread_store.dart';
import '../pages/marketplace_conversations_page.dart';

/// The envelope in the Mercatino's bar, with the number of unread messages. It
/// asks at opening and then every minute while it is on screen and the app is in
/// the foreground. Push notifications do not exist in the app yet.
class MarketplaceMessagesButton extends StatefulWidget {
  const MarketplaceMessagesButton({super.key, this.repository});

  final MarketplaceMessagesRepository? repository;

  @override
  State<MarketplaceMessagesButton> createState() => _MarketplaceMessagesButtonState();
}

class _MarketplaceMessagesButtonState extends State<MarketplaceMessagesButton> {
  late final MarketplaceMessagesRepository _repository =
      widget.repository ?? MarketplaceMessagesRepository();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(MarketplaceUnreadStore.instance.refresh(_repository));
    _timer = Timer.periodic(MarketplaceUnreadStore.pollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(MarketplaceUnreadStore.instance.refresh(_repository));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceConversationsPage(repository: _repository),
      ),
    );
    if (mounted) unawaited(MarketplaceUnreadStore.instance.refresh(_repository));
  }

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
          label: Text('$count'),
          child: const Icon(Icons.mail_outline_rounded),
        ),
      ),
    );
  }
}

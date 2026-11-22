import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_messages_repository.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_unread_store.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_conversations_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/widgets/marketplace_messages_button.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

/// QK-10: the Mercatino's two timers (the envelope and the list of conversations)
/// ask only while their page can be seen, and ask again at once when it can be
/// seen again. A simulated clock moves the minutes along.

class _Config extends AppRuntimeConfigLoader {
  const _Config();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _conversation({int unread = 0}) => {
      'id': 'c1',
      'listing_id': 'ad-1',
      'listing_title': 'Trasportino',
      'role': 'buyer',
      'unread_count': unread,
      'can_write': true,
      'closed_reason': null,
      'created_at': '2026-11-07T10:00:00+00:00',
      'last_message_at': '2026-11-07T10:00:00+00:00',
    };

/// Counts what the app asks, by kind, and lets a test hold an answer back.
class _Backend {
  int unreadCountCalls = 0;
  int listCalls = 0;
  int detailCalls = 0;
  int unread = 2;
  Completer<void>? holdList;

  MarketplaceMessagesRepository repository() => MarketplaceMessagesRepository(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/marketplace/conversations/unread-count') {
            unreadCountCalls++;
            return _json({'unread_total': unread});
          }
          if (path == '/marketplace/conversations') {
            listCalls++;
            final gate = holdList;
            if (gate != null) await gate.future;
            return _json({
              'conversations': [_conversation(unread: unread)],
              'unread_total': unread,
            });
          }
          if (path == '/marketplace/conversations/c1') {
            detailCalls++;
            return _json({'conversation': _conversation(), 'messages': <Object>[]});
          }
          return _json({'ok': true});
        }),
        configLoader: const _Config(),
        tokenProvider: () => 'jwt',
      );
}

Widget _app(MarketplaceMessagesRepository repository) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: Scaffold(
        appBar: AppBar(actions: [MarketplaceMessagesButton(repository: repository)]),
        body: const SizedBox.expand(),
      ),
    );

/// Lets the answers of the simulated server land.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // page transitions
  await tester.pump(const Duration(milliseconds: 400));
}

/// Closes the page on top, as the back button does (the test platform has no
/// iOS back button for `pageBack`).
Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
}

/// Moves the simulated clock [minutes] minutes along, one poll interval at a time.
Future<void> _wait(WidgetTester tester, int minutes) async {
  for (var i = 0; i < minutes; i++) {
    await tester.pump(MarketplaceUnreadStore.pollInterval);
  }
}

void main() {
  setUp(() => MarketplaceUnreadStore.instance.reset());

  testWidgets('the envelope asks at opening and then every minute while it is on screen',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend.repository()));
    await _settle(tester);

    expect(backend.unreadCountCalls, 1);
    expect(MarketplaceUnreadStore.instance.count.value, 2);

    await _wait(tester, 3);

    expect(backend.unreadCountCalls, 4);
  });

  testWidgets('list → detail → back: the covered widgets ask nothing, and ask again on return',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend.repository()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('marketplace-messages-button')));
    await _settle(tester);
    // The list is on top: the envelope (covered) stopped, the list asked once.
    expect(backend.listCalls, 1);
    final envelopeBeforeCover = backend.unreadCountCalls;

    // The list keeps asking while it is the page on screen...
    await _wait(tester, 2);
    expect(backend.listCalls, 3);
    expect(backend.unreadCountCalls, envelopeBeforeCover);

    // ...and stops when a conversation covers it.
    await tester.tap(find.byKey(const ValueKey('marketplace-conversation-c1')));
    await _settle(tester);
    final listWhenCovered = backend.listCalls;
    expect(backend.detailCalls, greaterThan(0));

    await _wait(tester, 5);
    expect(backend.listCalls, listWhenCovered, reason: 'the covered list must not poll');
    expect(backend.unreadCountCalls, envelopeBeforeCover, reason: 'nor the covered envelope');

    // Back to the list: it reads again at once, the envelope still waits.
    backend.unread = 0;
    await _back(tester);
    await _settle(tester);
    expect(backend.listCalls, listWhenCovered + 1);
    expect(MarketplaceUnreadStore.instance.count.value, 0);
    expect(backend.unreadCountCalls, envelopeBeforeCover);

    // Back to the first page: the envelope reads at once and its timer is back.
    backend.unread = 0;
    await _back(tester);
    await _settle(tester);
    expect(backend.unreadCountCalls, envelopeBeforeCover + 1);
    final listWhenGone = backend.listCalls;
    await _wait(tester, 2);
    expect(backend.unreadCountCalls, envelopeBeforeCover + 3);
    expect(backend.listCalls, listWhenGone, reason: 'the closed list is gone, not polling');
  });

  testWidgets('background: nothing asked while the app is away, one read when it returns',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend.repository()));
    await _settle(tester);
    final before = backend.unreadCountCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _wait(tester, 5);
    expect(backend.unreadCountCalls, before);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(backend.unreadCountCalls, before + 1);

    await _wait(tester, 1);
    expect(backend.unreadCountCalls, before + 2);
  });

  testWidgets('background while the list is open: the list is quiet, then reads on return',
      (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend.repository()));
    await tester.tap(find.byKey(const ValueKey('marketplace-messages-button')));
    await _settle(tester);
    final before = backend.listCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _wait(tester, 4);
    expect(backend.listCalls, before);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(backend.listCalls, before + 1);
  });

  testWidgets('a page that is closed stops its timer for good', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(_app(backend.repository()));
    await _settle(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox())); // the page is gone
    final before = backend.unreadCountCalls;
    await _wait(tester, 5);

    expect(backend.unreadCountCalls, before);
  });

  group('sign-out during a read', () {
    testWidgets('an answer for the owner who left does not reach the list or the envelope',
        (tester) async {
      final backend = _Backend()..holdList = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: MarketplaceConversationsPage(repository: backend.repository()),
        ),
      );
      await tester.pump();
      expect(backend.listCalls, 1); // the read is on its way

      MarketplaceUnreadStore.instance.reset(); // sign-out
      backend.holdList!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(MarketplaceUnreadStore.instance.count.value, 0);
      expect(find.textContaining('Trasportino'), findsNothing);
    });
  });
}

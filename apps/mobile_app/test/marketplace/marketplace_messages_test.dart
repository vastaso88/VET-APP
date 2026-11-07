import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_messages_repository.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_unread_store.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_conversation.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/listing_detail_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_conversation_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_conversations_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

class _ConfigWithBackend extends AppRuntimeConfigLoader {
  const _ConfigWithBackend();

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

class _ConfigWithSupabase extends AppRuntimeConfigLoader {
  const _ConfigWithSupabase();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.test',
        supabaseUrl: 'https://project.example.com',
        supabaseAnonKey: 'key',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

Map<String, dynamic> _conversation({
  String id = 'c1',
  String role = 'buyer',
  int unread = 0,
  bool canWrite = true,
  String? closedReason,
}) =>
    {
      'id': id,
      'listing_id': 'ad-1',
      'listing_title': 'Trasportino',
      'role': role,
      'unread_count': unread,
      'can_write': canWrite,
      'closed_reason': closedReason,
      'created_at': '2026-11-07T10:00:00+00:00',
      'last_message_at': '2026-11-07T10:00:00+00:00',
    };

Map<String, dynamic> _message(String body, {bool mine = true, String id = 'm1'}) => {
      'id': id,
      'body': body,
      'mine': mine,
      'created_at': '2026-11-07T10:00:00+00:00',
    };

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Records what the app asks and answers with [handler].
class _Backend {
  _Backend(this.handler);

  final http.Response Function(http.Request request) handler;
  final List<String> calls = [];
  final List<String> bodies = [];

  MarketplaceMessagesRepository repository() => MarketplaceMessagesRepository(
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.body.isNotEmpty) bodies.add(request.body);
          return handler(request);
        }),
        configLoader: const _ConfigWithBackend(),
        tokenProvider: () => 'jwt',
      );
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: home,
    );

MarketplaceListing _listing({String ownerId = 'seller', bool limited = false}) => MarketplaceListing(
      id: 'ad-1',
      ownerId: ownerId,
      title: 'Trasportino',
      category: ListingCategory.kennelsCarriers,
      condition: ListingCondition.good,
      location: const Coordinates(latitude: 45.46, longitude: 9.19),
      createdAt: DateTime(2026, 11, 7),
      updatedAt: DateTime(2026, 11, 7),
      isLimited: limited,
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => MarketplaceUnreadStore.instance.reset());

  group('repository', () {
    test('a refused message becomes the exception the page shows', () async {
      Future<Object?> outcome(http.Response answer) async {
        final repository = _Backend((_) => answer).repository();
        try {
          await repository.sendMessage('c1', 'Ciao');
          return null;
        } on Exception catch (error) {
          return error;
        }
      }

      expect(await outcome(_json({'detail': 'x'}, 404)), isA<ConversationNotFoundException>());
      expect(await outcome(_json({'detail': 'x'}, 409)), isA<ConversationClosedException>());
      expect(await outcome(_json({'detail': 'x'}, 500)), isA<MessagesUnavailableException>());
      final limit = await outcome(
        _json({'kind': 'marketplace_new_conversations', 'limit': 10}, 429),
      );
      expect((limit! as NewConversationLimitException).limit, 10);
      // The general request throttle is not the daily limit.
      expect(await outcome(_json({'detail': 'x'}, 429)), isA<MessagesUnavailableException>());
    });

    test('a real build without a session asks nothing', () async {
      final repository = MarketplaceMessagesRepository(
        httpClient: MockClient((_) async => fail('no request expected')),
        configLoader: const _ConfigWithSupabase(),
        tokenProvider: () => null,
      );

      expect(repository.unreadTotal(), throwsA(isA<MessagesUnavailableException>()));
    });

    test('local development without Supabase talks to the local backend', () async {
      String? authorization;
      final repository = MarketplaceMessagesRepository(
        httpClient: MockClient((request) async {
          authorization = request.headers['Authorization'];
          return _json({'unread_total': 4});
        }),
        configLoader: const _ConfigWithBackend(),
        tokenProvider: () => null,
      );

      expect(await repository.unreadTotal(), 4);
      expect(authorization, isNull);
    });

    test('a block made against me reads as an ordinary closed conversation', () {
      final closed = MarketplaceConversation.fromJson(
        _conversation(canWrite: false, closedReason: 'closed'),
      );
      final mine = MarketplaceConversation.fromJson(
        _conversation(canWrite: false, closedReason: 'blocked_by_me'),
      );

      expect(closed.closedReason, ConversationClosedReason.closed);
      expect(mine.closedReason, ConversationClosedReason.blockedByMe);
    });
  });

  group('unread store', () {
    test('sign-out empties it, an answer on its way does not bring it back', () async {
      final backend = _Backend((_) => _json({'unread_total': 3}));
      await MarketplaceUnreadStore.instance.refresh(backend.repository());
      expect(MarketplaceUnreadStore.instance.count.value, 3);

      final pending = MarketplaceUnreadStore.instance.refresh(backend.repository());
      MarketplaceUnreadStore.instance.reset();
      await pending;

      expect(MarketplaceUnreadStore.instance.count.value, 0);
    });

    test('a failed read keeps the last number and does not throw', () async {
      await MarketplaceUnreadStore.instance.refresh(
        _Backend((_) => _json({'unread_total': 2})).repository(),
      );
      await MarketplaceUnreadStore.instance.refresh(
        _Backend((_) => _json({'detail': 'x'}, 500)).repository(),
      );

      expect(MarketplaceUnreadStore.instance.count.value, 2);
    });
  });

  group('ad page', () {
    Future<void> pump(WidgetTester tester, MarketplaceListing listing) async {
      await tester.pumpWidget(
        _app(
          ListingDetailPage(
            listing: listing,
            repository: MarketplaceRepository.inMemory([listing]),
            currentOwnerId: 'buyer',
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a buyer can write to the seller', (tester) async {
      await pump(tester, _listing());

      expect(find.byKey(const ValueKey('marketplace-write-to-seller')), findsOneWidget);
    });

    testWidgets('the seller of the ad has no such button', (tester) async {
      await pump(tester, _listing(ownerId: 'buyer'));

      expect(find.byKey(const ValueKey('marketplace-write-to-seller')), findsNothing);
    });

    testWidgets('someone without a plan has no such button', (tester) async {
      await pump(tester, _listing(limited: true));

      expect(find.byKey(const ValueKey('marketplace-write-to-seller')), findsNothing);
    });
  });

  group('conversation page', () {
    Future<void> pump(WidgetTester tester, _Backend backend,
        {String? conversationId, String? listingId}) async {
      await tester.pumpWidget(
        _app(
          MarketplaceConversationPage(
            conversationId: conversationId,
            listingId: listingId,
            listingTitle: 'Trasportino',
            repository: backend.repository(),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('the first message opens the conversation, with the warning before it',
        (tester) async {
      final backend = _Backend((request) {
        if (request.method == 'GET') return _json({'conversation': null});
        return _json({'conversation': _conversation(), 'message': _message('Ciao')});
      });
      await pump(tester, backend, listingId: 'ad-1');

      expect(find.byKey(const ValueKey('marketplace-messages-safety-notice')), findsOneWidget);
      expect(backend.calls, ['GET /marketplace/listings/ad-1/conversation']);

      await tester.enterText(find.byKey(const ValueKey('marketplace-messages-field')), '  Ciao ');
      await tester.tap(find.byKey(const ValueKey('marketplace-messages-send')));
      await _settle(tester);

      expect(backend.calls.last, 'POST /marketplace/listings/ad-1/conversations');
      expect(jsonDecode(backend.bodies.single), {'text': 'Ciao'});
      expect(find.text('Ciao'), findsOneWidget);
      expect(find.byKey(const ValueKey('marketplace-messages-safety-notice')), findsOneWidget);
    });

    testWidgets('what people write is shown as it is', (tester) async {
      const markup = '<b>grassetto</b> <a href="https://example.com">x</a>';
      final backend = _Backend((request) {
        if (request.url.path.endsWith('/read')) return _json({'ok': true});
        if (request.url.path.endsWith('/unread-count')) return _json({'unread_total': 0});
        return _json({
          'conversation': _conversation(role: 'seller', unread: 1),
          'messages': [_message(markup, mine: false)],
        });
      });
      await pump(tester, backend, conversationId: 'c1');

      expect(find.text(markup), findsOneWidget);
      expect(backend.calls, contains('POST /marketplace/conversations/c1/read'));
    });

    testWidgets('a closed conversation stays readable and has no field', (tester) async {
      final backend = _Backend((_) => _json({
            'conversation': _conversation(canWrite: false, closedReason: 'closed'),
            'messages': [_message('Prima')],
          }));
      await pump(tester, backend, conversationId: 'c1');

      expect(find.text('Prima'), findsOneWidget);
      expect(find.byKey(const ValueKey('marketplace-messages-field')), findsNothing);
      expect(find.byKey(const ValueKey('marketplace-messages-closed')), findsOneWidget);
    });

    testWidgets('the daily limit is explained and the text is kept', (tester) async {
      final backend = _Backend((request) {
        if (request.method == 'GET') return _json({'conversation': null});
        return _json({'kind': 'marketplace_new_conversations', 'limit': 10}, 429);
      });
      await pump(tester, backend, listingId: 'ad-1');

      await tester.enterText(find.byKey(const ValueKey('marketplace-messages-field')), 'Ciao');
      await tester.tap(find.byKey(const ValueKey('marketplace-messages-send')));
      await _settle(tester);

      expect(find.textContaining('10 nuove conversazioni'), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(const ValueKey('marketplace-messages-field')));
      expect(field.controller!.text, 'Ciao');
    });

    testWidgets('blocking asks first, then closes the field', (tester) async {
      final backend = _Backend((request) {
        if (request.method == 'POST' && request.url.path.endsWith('/block')) {
          return _json({
            'conversation': _conversation(canWrite: false, closedReason: 'blocked_by_me'),
          });
        }
        return _json({'conversation': _conversation(), 'messages': [_message('Ciao')]});
      });
      await pump(tester, backend, conversationId: 'c1');

      await tester.tap(find.byKey(const ValueKey('marketplace-messages-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blocca utente'));
      await tester.pumpAndSettle();
      expect(backend.calls, isNot(contains('POST /marketplace/conversations/c1/block')));

      await tester.tap(find.byKey(const ValueKey('marketplace-messages-block-confirm')));
      await tester.pumpAndSettle();

      expect(backend.calls, contains('POST /marketplace/conversations/c1/block'));
      expect(find.byKey(const ValueKey('marketplace-messages-field')), findsNothing);
      expect(find.textContaining('Sbloccala'), findsOneWidget);
    });

    testWidgets('reporting says the team will read and sends only the reason', (tester) async {
      final backend = _Backend((request) {
        if (request.url.path.endsWith('/report')) return _json({'ok': true});
        return _json({'conversation': _conversation(), 'messages': [_message('Ciao')]});
      });
      await pump(tester, backend, conversationId: 'c1');

      await tester.tap(find.byKey(const ValueKey('marketplace-messages-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Segnala conversazione'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Il nostro team leggerà'), findsOneWidget);

      await tester.tap(find.text('Truffa'));
      await tester.pumpAndSettle();

      expect(jsonDecode(backend.bodies.single), {'reason': 'scam'});
    });
  });

  group('list of conversations', () {
    testWidgets('shows the unread number and updates the envelope', (tester) async {
      final backend = _Backend((_) => _json({
            'conversations': [
              _conversation(role: 'seller', unread: 2),
              _conversation(id: 'c2', canWrite: false, closedReason: 'closed'),
            ],
            'unread_total': 2,
          }));
      await tester.pumpWidget(
        _app(MarketplaceConversationsPage(repository: backend.repository())),
      );
      await _settle(tester);

      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('Con un acquirente'), findsOneWidget);
      expect(find.textContaining('Chiusa'), findsOneWidget);
      expect(MarketplaceUnreadStore.instance.count.value, 2);
    });

    testWidgets('an empty list says where conversations will appear', (tester) async {
      final backend = _Backend((_) => _json({'conversations': [], 'unread_total': 0}));
      await tester.pumpWidget(
        _app(MarketplaceConversationsPage(repository: backend.repository())),
      );
      await _settle(tester);

      expect(find.textContaining('Nessuna conversazione'), findsOneWidget);
    });

    testWidgets('a failed load offers to try again', (tester) async {
      final backend = _Backend((_) => _json({'detail': 'x'}, 500));
      await tester.pumpWidget(
        _app(MarketplaceConversationsPage(repository: backend.repository())),
      );
      await _settle(tester);

      expect(find.text('Riprova'), findsOneWidget);
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/app/launch/restorable_pages.dart';
import 'package:vet_app_mobile/app/launch/route_restoration.dart';
import 'package:vet_app_mobile/app/launch/warm_start_store.dart';

/// Two tabs, each with its own nested Navigator like the shell's.
class _Tabs extends StatelessWidget {
  const _Tabs(this.keys);

  final List<GlobalKey<NavigatorState>> keys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          for (var i = 0; i < keys.length; i++)
            Expanded(
              child: ShellTabScope(
                index: i,
                child: Navigator(
                  key: keys[i],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => Text('root$i')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Route<void> _page(RouteRestoration restoration, String kind, Map<String, dynamic> args, String label) {
  return MaterialPageRoute<void>(
    builder: (_) => RestorationMarker(
      restoration: restoration,
      kind: kind,
      args: () => args,
      child: Text(label),
    ),
  );
}

/// A registry whose pages describe themselves like the real ones do.
RestorablePages _registry(RouteRestoration restoration, {Set<String> unavailable = const {}}) {
  final pages = RestorablePages();
  for (final kind in ['pet_detail', 'record_category', 'chat_conversation']) {
    pages.register(kind, (args) {
      if (unavailable.contains(kind)) return null;
      return RestorationMarker(
        restoration: restoration,
        kind: kind,
        args: () => args,
        child: Text('$kind ${args['id']} ${args['tab'] ?? ''}'.trim()),
      );
    });
  }
  return pages;
}

Future<void> _runReplay(WidgetTester tester, Future<void> replay) async {
  var finished = false;
  unawaited(replay.then((_) => finished = true));
  for (var i = 0; i < 40 && !finished; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finished, isTrue, reason: 'replay did not finish');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a killed process is brought back to the pages that were open', (tester) async {
    // ---- first run: the owner opens a pet card, a category, and Mercatino.
    final firstRun = RouteRestoration(debounce: Duration.zero);
    firstRun.enablePersistence(watchLifecycle: false);
    var keys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    await tester.pumpWidget(_Tabs(keys));

    unawaited(keys[0].currentState!.push(
        _page(firstRun, 'pet_detail', {'id': 'p1', 'tab': 2}, 'pet_detail p1 2')));
    await tester.pumpAndSettle();
    unawaited(keys[0].currentState!.push(
        _page(firstRun, 'record_category', {'id': 'p1', 'tab': null}, 'record_category p1')));
    await tester.pumpAndSettle();
    unawaited(keys[1].currentState!.push(_page(firstRun, 'marketplace', {}, 'marketplace')));
    await tester.pumpAndSettle();

    await firstRun.persistNow();
    final saved = await const WarmStartStore().loadStack();
    expect(saved.map((e) => '${e['tab']}:${e['kind']}'),
        ['0:pet_detail', '0:record_category', '1:marketplace']);

    // ---- the process dies: nothing but SharedPreferences survives.
    await tester.pumpWidget(const SizedBox());
    firstRun.dispose();

    // ---- second run: a new store, a fresh shell, the saved plan.
    final secondRun = RouteRestoration(debounce: Duration.zero);
    final plan = await secondRun.loadPlan();
    expect(plan, hasLength(3));

    keys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    await tester.pumpWidget(_Tabs(keys));
    expect(find.text('root0'), findsOneWidget);

    final pages = _registry(secondRun)
      ..register('marketplace',
          (args) => RestorationMarker(restoration: secondRun, kind: 'marketplace', child: const Text('marketplace')));
    await _runReplay(
      tester,
      RouteReplayer(pages: pages).replay(
        plan: plan,
        navigatorFor: (tab) => keys[tab].currentState,
        isAlive: () => true,
      ),
    );
    await tester.pumpAndSettle();

    // Tab 0 is on the category page, with the pet card under it; tab 1 on Mercatino.
    expect(find.text('record_category p1'), findsOneWidget);
    expect(find.text('marketplace'), findsOneWidget);
    keys[0].currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('pet_detail p1 2'), findsOneWidget);
    keys[0].currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('root0'), findsOneWidget);

    // The restored pages registered themselves again: saving continues seamlessly.
    expect(secondRun.snapshot().map((e) => e.kind), ['marketplace']);
  });

  testWidgets('a page that cannot be rebuilt drops the pages above it, other tabs go on',
      (tester) async {
    final restoration = RouteRestoration(debounce: Duration.zero);
    final keys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    await tester.pumpWidget(_Tabs(keys));

    await _runReplay(
      tester,
      RouteReplayer(pages: _registry(restoration, unavailable: {'pet_detail'})).replay(
        plan: const [
          RestorableRouteEntry(tab: 0, kind: 'pet_detail', args: {'id': 'gone'}),
          RestorableRouteEntry(tab: 0, kind: 'record_category', args: {'id': 'gone'}),
          RestorableRouteEntry(tab: 1, kind: 'chat_conversation', args: {'id': 'c1'}),
          RestorableRouteEntry(tab: 1, kind: 'unknown_kind'),
        ],
        navigatorFor: (tab) => keys[tab].currentState,
        isAlive: () => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('root0'), findsOneWidget);
    expect(find.text('chat_conversation c1'), findsOneWidget);
  });

  testWidgets('a tab the owner already used is left alone', (tester) async {
    final restoration = RouteRestoration(debounce: Duration.zero);
    final keys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    await tester.pumpWidget(_Tabs(keys));
    unawaited(keys[0]
        .currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Text('already open'))));
    await tester.pumpAndSettle();

    await _runReplay(
      tester,
      RouteReplayer(pages: _registry(restoration)).replay(
        plan: const [RestorableRouteEntry(tab: 0, kind: 'pet_detail', args: {'id': 'p1'})],
        navigatorFor: (tab) => keys[tab].currentState,
        isAlive: () => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('already open'), findsOneWidget);
    expect(find.textContaining('pet_detail'), findsNothing);
  });

  testWidgets('closing a page removes it from the saved stack, args are read when saving',
      (tester) async {
    final restoration = RouteRestoration(debounce: Duration.zero);
    final keys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    await tester.pumpWidget(_Tabs(keys));
    var tab = 0;
    unawaited(keys[0].currentState!.push(MaterialPageRoute<void>(
      builder: (_) => RestorationMarker(
        restoration: restoration,
        kind: 'pet_detail',
        args: () => {'id': 'p1', 'tab': tab},
        child: const Text('pet'),
      ),
    )));
    await tester.pumpAndSettle();

    tab = 3;
    expect(restoration.snapshot().single.args, {'id': 'p1', 'tab': 3});

    keys[0].currentState!.pop();
    await tester.pumpAndSettle();
    expect(restoration.snapshot(), isEmpty);
  });

  testWidgets('forget (sign-out) clears the saved pages and drafts', (tester) async {
    const store = WarmStartStore();
    final restoration = RouteRestoration(debounce: Duration.zero);
    await store.saveStack([
      const RestorableRouteEntry(tab: 0, kind: 'pet_detail').toJson(),
    ]);
    await store.saveDraft('c1', 'ciao');

    await restoration.forget();

    expect(await store.loadStack(), isEmpty);
    expect(await store.loadDraft('c1'), isNull);
  });

  test('every default page has a rebuild recipe', () {
    final registry = RestorablePages();
    registerRestorablePages(registry);

    for (final kind in [
      'pet_detail',
      'pet_gallery',
      'record_category',
      'chat_conversation',
      'active_walk',
      'news_feed',
      'local_events',
      'events',
      'gallery_folders',
      'marketplace',
      'billing',
      'data_sources',
      'profile_edit',
    ]) {
      expect(registry.knows(kind), isTrue, reason: kind);
    }
  });

  test('a page whose data is gone is skipped, not opened empty', () async {
    final registry = RestorablePages();
    registerRestorablePages(registry);

    expect(await registry.build('pet_detail', {'petId': 'does-not-exist'}), isNull);
    expect(await registry.build('record_category', {'petId': 'does-not-exist'}), isNull);
    expect(await registry.build('chat_conversation', {'conversationId': ''}), isNull);
    expect(await registry.build('active_walk', {'petId': 'does-not-exist'}), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/home_widget_action_store.dart';

void main() {
  group('HomeWidgetAction.tryParse', () {
    test('parses the widget URIs', () {
      final walk = HomeWidgetAction.tryParse(
          Uri.parse('homewidget://start_walk?petId=abc-1'));
      expect(walk?.kind, HomeWidgetActionKind.startWalk);
      expect(walk?.petId, 'abc-1');

      final reminder = HomeWidgetAction.tryParse(
          Uri.parse('homewidget://new_reminder?petId=abc%201'));
      expect(reminder?.kind, HomeWidgetActionKind.newReminder);
      expect(reminder?.petId, 'abc 1');
    });

    test('parses the active-walk URIs', () {
      expect(
        HomeWidgetAction.tryParse(Uri.parse('homewidget://open_walk?petId=p9'))
            ?.kind,
        HomeWidgetActionKind.openWalk,
      );
      expect(
        HomeWidgetAction.tryParse(Uri.parse('homewidget://pause_walk?petId=p9'))
            ?.kind,
        HomeWidgetActionKind.pauseWalk,
      );
      final resume = HomeWidgetAction.tryParse(
          Uri.parse('homewidget://resume_walk?petId=p9'));
      expect(resume?.kind, HomeWidgetActionKind.resumeWalk);
      expect(resume?.petId, 'p9');
      expect(HomeWidgetAction.tryParse(Uri.parse('homewidget://open_walk')),
          isNull);
    });

    test('ignores unknown hosts, missing petId and null', () {
      expect(HomeWidgetAction.tryParse(null), isNull);
      expect(HomeWidgetAction.tryParse(Uri.parse('homewidget://other?petId=1')),
          isNull);
      expect(HomeWidgetAction.tryParse(Uri.parse('homewidget://start_walk')),
          isNull);
    });
  });

  group('HomeWidgetActionStore', () {
    const action = HomeWidgetAction(HomeWidgetActionKind.newReminder, 'p1');

    test('holds an action until the shell is ready, then delivers once',
        () async {
      final store = HomeWidgetActionStore();
      final delivered = <HomeWidgetAction>[];
      store.attachHandler((a) async => delivered.add(a));

      store.submit(action);
      await Future<void>.delayed(Duration.zero);
      expect(delivered, isEmpty);
      expect(store.hasPending, isTrue);

      store.shellReady();
      await Future<void>.delayed(Duration.zero);
      expect(delivered, [action]);
      expect(store.hasPending, isFalse);

      store.shellReady();
      await Future<void>.delayed(Duration.zero);
      expect(delivered, hasLength(1));
    });

    test('delivers immediately when the shell is already up', () async {
      final store = HomeWidgetActionStore();
      final delivered = <HomeWidgetAction>[];
      store.attachHandler((a) async => delivered.add(a));
      store.shellReady();

      store.submit(action);
      await Future<void>.delayed(Duration.zero);
      expect(delivered, [action]);
    });

    test('latest tap wins while waiting', () async {
      final store = HomeWidgetActionStore();
      final delivered = <HomeWidgetAction>[];
      store.attachHandler((a) async => delivered.add(a));
      const walk = HomeWidgetAction(HomeWidgetActionKind.startWalk, 'p2');

      store.submit(action);
      store.submit(walk);
      store.shellReady();
      await Future<void>.delayed(Duration.zero);
      expect(delivered, [walk]);
    });

    test('drops an action older than maxAge', () async {
      var now = DateTime(2026, 9, 30, 12);
      final store = HomeWidgetActionStore(clock: () => now);
      final delivered = <HomeWidgetAction>[];
      store.attachHandler((a) async => delivered.add(a));

      store.submit(action);
      now = now.add(const Duration(minutes: 3));
      store.shellReady();
      await Future<void>.delayed(Duration.zero);
      expect(delivered, isEmpty);
    });

    test('a failing handler does not throw or re-fire', () async {
      final store = HomeWidgetActionStore();
      var calls = 0;
      store.attachHandler((a) async {
        calls++;
        throw StateError('boom');
      });
      store.shellReady();
      store.submit(action);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(store.hasPending, isFalse);
    });
  });

  test('an open_walk tap waits for the shell like the other actions', () async {
    final store = HomeWidgetActionStore();
    final delivered = <HomeWidgetAction>[];
    store.attachHandler((a) async => delivered.add(a));
    const open = HomeWidgetAction(HomeWidgetActionKind.openWalk, 'p1');

    store.submit(open);
    store.submit(const HomeWidgetAction(HomeWidgetActionKind.pauseWalk, 'p1'));
    await Future<void>.delayed(Duration.zero);
    expect(delivered, isEmpty);

    store.shellReady();
    await Future<void>.delayed(Duration.zero);
    // Latest tap wins.
    expect(delivered.single.kind, HomeWidgetActionKind.pauseWalk);
  });
}

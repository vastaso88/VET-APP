import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/app/launch/warm_start_store.dart';

void main() {
  const store = WarmStartStore();
  final now = DateTime(2026, 10, 21, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved: no warm start', () async {
    expect(await store.hasRecentAccess('owner-1', now: now), isFalse);
  });

  test('same owner, recent access: warm start', () async {
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    expect(
      await store.hasRecentAccess('owner-1', now: now.add(const Duration(hours: 5))),
      isTrue,
    );
  });

  test('another owner or an old answer: full splash', () async {
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    expect(await store.hasRecentAccess('owner-2', now: now), isFalse);
    expect(
      await store.hasRecentAccess(
        'owner-1',
        now: now.add(WarmStartStore.accessTtl + const Duration(minutes: 1)),
      ),
      isFalse,
    );
  });

  test('a refusal forgets the cached access', () async {
    await store.saveAccess('owner-1', hasAccess: true, now: now);
    await store.saveAccess('owner-1', hasAccess: false, now: now);

    expect(await store.hasRecentAccess('owner-1', now: now), isFalse);
  });

  test('clear (sign-out) forgets everything', () async {
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    await store.clear();

    expect(await store.hasRecentAccess('owner-1', now: now), isFalse);
  });

  test('preferences left by older builds are still read (tab key ignored)', () async {
    SharedPreferences.setMockInitialValues({
      'vet_app.warm_start.tab': 3,
      'vet_app.warm_start.access_owner': 'owner-1',
      'vet_app.warm_start.access_at': now.millisecondsSinceEpoch,
    });

    expect(await store.hasRecentAccess('owner-1', now: now), isTrue);
  });

  test('sign-out also removes the legacy tab key, drafts and stack', () async {
    SharedPreferences.setMockInitialValues({
      'vet_app.warm_start.tab': 2,
      'vet_app.draft.conv-1': 'bozza',
    });
    await store.saveStack([
      {'route': 'x'},
    ]);

    await store.clear();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
  });

  test('access never creates the legacy tab key (QK-13: 0 tab writes)', () async {
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('vet_app.warm_start.tab'), isFalse);
  });
}

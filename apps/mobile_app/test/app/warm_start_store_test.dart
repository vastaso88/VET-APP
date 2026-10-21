import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/app/launch/warm_start_store.dart';

void main() {
  const store = WarmStartStore();
  final now = DateTime(2026, 10, 21, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved: no warm start', () async {
    expect(await store.warmTab('owner-1', now: now), isNull);
  });

  test('same owner, recent access: reopens the saved tab', () async {
    await store.saveTab(2);
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    expect(await store.warmTab('owner-1', now: now.add(const Duration(hours: 5))), 2);
  });

  test('another owner or an old answer: full splash', () async {
    await store.saveTab(1);
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    expect(await store.warmTab('owner-2', now: now), isNull);
    expect(
      await store.warmTab('owner-1', now: now.add(WarmStartStore.accessTtl + const Duration(minutes: 1))),
      isNull,
    );
  });

  test('a refusal forgets the cached access', () async {
    await store.saveAccess('owner-1', hasAccess: true, now: now);
    await store.saveAccess('owner-1', hasAccess: false, now: now);

    expect(await store.warmTab('owner-1', now: now), isNull);
  });

  test('clear (sign-out) forgets everything', () async {
    await store.saveTab(3);
    await store.saveAccess('owner-1', hasAccess: true, now: now);

    await store.clear();

    expect(await store.warmTab('owner-1', now: now), isNull);
  });
}

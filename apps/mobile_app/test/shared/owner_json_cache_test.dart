import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/shared/cache/owner_json_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'other.setting': 'keep'}));

  test('rows written for an owner come back for that owner only', () async {
    const cache = OwnerJsonCache('pets');
    await cache.write('owner-1', [
      {'id': 'a', 'name': 'Tobia', 'tags': [1, 2]},
    ]);

    expect(await cache.read('owner-1'), [
      {'id': 'a', 'name': 'Tobia', 'tags': [1, 2]},
    ]);
    expect(await cache.read('owner-2'), isNull);
    expect(await const OwnerJsonCache('reminders').read('owner-1'), isNull);
  });

  test('clearAll removes every cached list but nothing else', () async {
    await const OwnerJsonCache('pets').write('owner-1', [{'id': 'a'}]);
    await const OwnerJsonCache('reminders').write('owner-1', [{'id': 'b'}]);

    await OwnerJsonCache.clearAll();

    expect(await const OwnerJsonCache('pets').read('owner-1'), isNull);
    expect(await const OwnerJsonCache('reminders').read('owner-1'), isNull);
    expect((await SharedPreferences.getInstance()).getString('other.setting'), 'keep');
  });

  test('a corrupt entry is a cache miss, not an error', () async {
    SharedPreferences.setMockInitialValues({'vet_app.cache.pets.owner-1': '{not json'});

    expect(await const OwnerJsonCache('pets').read('owner-1'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';

/// Any Supabase call fails: hydration is treated as failed, never as empty.
class _FailingSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('offline');
}

void main() {
  test('demo seeds only appear without a Supabase client', () async {
    // Client present, hydration not completed/failed: no demo reminders.
    final withClient = RemindersRepository(client: _FailingSupabaseClient());
    final real = await withClient.loadReminders();
    expect(real.where((r) => r.petName == 'Moka'), isEmpty);

    // No client (offline preview): seeds are visible with zero pets, and
    // they are not tied to pet names, so a renamed pet's reminders stay too.
    final preview = RemindersRepository();
    final demo = await preview.loadReminders();
    expect(demo.where((r) => r.petName == 'Moka'), isNotEmpty);
  });
}

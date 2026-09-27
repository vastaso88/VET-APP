import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/widgets/favorite_eviction_dialog.dart';

WalkSession _favorite(String id, {required int daysAgo, double distanceMeters = 1000}) {
  return WalkSession(
    id: id,
    ownerId: 'user-1',
    petId: 'pet-1',
    status: WalkStatus.completed,
    startedAt: DateTime(2026, 1, 20).subtract(Duration(days: daysAgo)),
    distanceMeters: distanceMeters,
    isFavorite: true,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('tapping a favorite pops its id', (tester) async {
    final favorites = [
      _favorite('fav-1', daysAgo: 0, distanceMeters: 500),
      _favorite('fav-2', daysAgo: 5, distanceMeters: 2000),
    ];
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await pickFavoriteToEvict(context, favorites);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Hai già 5 preferite'), findsOneWidget);

    await tester.tap(find.textContaining('500 m'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(favorites.map((w) => w.id), contains(result));
  });

  testWidgets('cancelling returns null', (tester) async {
    final favorites = [_favorite('fav-1', daysAgo: 0)];
    String? result = 'not-yet-run';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await pickFavoriteToEvict(context, favorites);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}

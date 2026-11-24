import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

class _OfflineRepository extends RemindersRepository {
  int attempts = 0;
  bool offline = true;

  @override
  Future<void> saveReminder(ReminderEntry reminder) async {
    attempts++;
    if (offline) throw const ReminderSyncException('offline');
  }
}

Future<void> _open(WidgetTester tester, RemindersRepository repository) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ReminderCreatePage(repository: repository)),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

/// Whether a text field holds the focus (that is what opens the keyboard).
bool _typing() =>
    FocusManager.instance.primaryFocus?.context?.widget.toString().contains('EditableText') ??
    false;

void main() {
  testWidgets('a save that fails keeps the form and what was typed; a retry closes it',
      (tester) async {
    final repository = _OfflineRepository();
    await _open(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, 'Richiamo vaccino');
    final save = find.text('Salva');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.attempts, 1);
    expect(find.text('Richiamo vaccino'), findsOneWidget, reason: 'the typed title is still there');
    expect(find.text('apri'), findsNothing, reason: 'still on the form, not back on the list');

    repository.offline = false;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.attempts, 2);
    expect(find.text('apri'), findsOneWidget, reason: 'saved: the form closes');
  });

  testWidgets('after the time picker closes no text field has the focus (no keyboard over Save)',
      (tester) async {
    await _open(tester, _OfflineRepository());

    // Focus the date field (a proposal: it empties), then pick the time.
    await tester.tap(find.byType(TextFormField).at(1));
    await tester.pump();
    expect(_typing(), isTrue);

    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(_typing(), isFalse);
    // The proposed date is back in the field it was taken from.
    expect(find.textContaining('/'), findsWidgets);
  });

  Future<void> openFrom(WidgetTester tester, List<String> pets) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => openReminderCreate(
                context,
                petNames: pets,
                repository: _OfflineRepository()..offline = false,
              ),
              child: const Text('crea'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('crea'));
    await tester.pumpAndSettle();
  }

  testWidgets('create from the list: one animal is used without asking', (tester) async {
    await openFrom(tester, ['Rex']);
    expect(find.text('Per quale animale?'), findsNothing);
    expect(find.byType(ReminderCreatePage), findsOneWidget);
    expect(tester.widget<ReminderCreatePage>(find.byType(ReminderCreatePage)).petName, 'Rex');
  });

  testWidgets('create from the list: several animals, the owner picks one', (tester) async {
    await openFrom(tester, ['Rex', 'Luna']);
    expect(find.text('Per quale animale?'), findsOneWidget);
    expect(find.byType(ReminderCreatePage), findsNothing);
    await tester.tap(find.text('Luna'));
    await tester.pumpAndSettle();
    expect(tester.widget<ReminderCreatePage>(find.byType(ReminderCreatePage)).petName, 'Luna');
  });

  testWidgets('create from the list: no animal, the owner is told to add one first',
      (tester) async {
    await openFrom(tester, const []);
    expect(find.byType(ReminderCreatePage), findsNothing);
    expect(find.textContaining('Aggiungi prima un animale'), findsOneWidget);
  });
}

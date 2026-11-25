import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/chat/domain/chat_models.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:vet_app_mobile/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_calendar.dart';
import 'package:vet_app_mobile/features/reminders/presentation/widgets/reminder_page_parts.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/min_tap_target.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';

import '../features/chat/widgets/fake_dictation.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('chat composer', () {
    testWidgets('the send button has a name and a 48 px touch area, 40 px to the eye',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ChatComposer(
        hintText: 'Scrivi',
        petName: 'Rex',
        dictation: FakeDictation(),
        onSend: (text, {attachmentId, attachmentImageBytes}) {},
      )));
      await tester.pump();

      expect(find.byTooltip('Invia il messaggio'), findsOneWidget);
      final send = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
      expect(send, findsOneWidget);
      // The pressable area (the button's own render box + padded target).
      final target = tester.getSize(find.ancestor(of: send, matching: find.byType(Padding)).first);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      // The painted square stays 40 px.
      final painted = find.descendant(of: send, matching: find.byType(Material)).first;
      expect(tester.getSize(painted), const Size(40, 40));

      handle.dispose();
    });
  });

  group('chat answers', () {
    testWidgets('numbered steps are a list: number column, steps do not run together',
        (tester) async {
      await tester.pumpWidget(_app(const ChatMessageBubble(
        message: ChatMessage(
          id: '1',
          author: ChatMessageAuthor.assistant,
          text: 'Ecco cosa fare:\n1. Misura la temperatura con calma e senza forzare.\n2. Segna il valore.',
          timeLabel: '10:00',
        ),
      )));

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      final number = tester.getTopLeft(find.text('1.'));
      final text = tester.getTopLeft(find.textContaining('Misura', findRichText: true));
      expect(text.dx, greaterThan(number.dx + 20), reason: 'the text starts after the number');
      final second = tester.getTopLeft(find.textContaining('Segna', findRichText: true));
      expect(second.dx, text.dx, reason: 'same indent for every step');
    });

    testWidgets('a bubble says who is speaking', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const Column(children: [
        ChatMessageBubble(
          message: ChatMessage(
            id: '1',
            author: ChatMessageAuthor.assistant,
            text: 'Ciao',
            timeLabel: '10:00',
          ),
        ),
        ChatMessageBubble(
          message: ChatMessage(
            id: '2',
            author: ChatMessageAuthor.user,
            text: 'Salve',
            timeLabel: '10:01',
          ),
        ),
      ])));
      expect(find.bySemanticsLabel(RegExp('Assistente')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Tu')), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('a home calendar day is read as one thing: "19, 2 promemoria"', (tester) async {
    final handle = tester.ensureSemantics();
    const marker = DayMarker(color: Colors.red, shape: MarkerShape.dot);
    await tester.pumpWidget(_app(Row(children: [
      Expanded(
        child: HomeDayChip(
          day: DateTime(2026, 11, 19),
          label: 'G',
          isToday: false,
          markers: const [marker, marker],
        ),
      ),
      Expanded(
        child: HomeDayChip(day: DateTime(2026, 11, 20), label: 'V', isToday: false, markers: const []),
      ),
    ])));
    expect(find.bySemanticsLabel('19, 2 promemoria'), findsOneWidget);
    expect(find.bySemanticsLabel('20'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the loader has one spoken name, not the animal', (tester) async {
    final handle = tester.ensureSemantics();
    PetLoader.orderOf = (animals) => animals;
    await tester.pumpWidget(_app(const Center(child: PetLoader(label: 'Carico i dati'))));
    expect(find.bySemanticsLabel('Carico i dati'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('.')), findsOneWidget);
    handle.dispose();
  });

  group('MinTapTarget', () {
    testWidgets('a filter pill answers to a tap 6 px under its drawn edge', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ReminderKindChip(label: 'Tutti', selected: false, onTap: () => taps++),
          ],
        ),
      )));
      final chip = tester.getRect(find.byType(Container).last);
      expect(chip.height, lessThan(40), reason: 'the pill keeps its look');
      expect(tester.getSize(find.byType(MinTapTarget)).height, 48);

      await tester.tapAt(chip.center);
      await tester.pump();
      expect(taps, 1);
      await tester.tapAt(Offset(chip.center.dx, chip.bottom + 6));
      await tester.pump();
      expect(taps, 2, reason: 'the margin around the pill counts too');
    });
  });
}

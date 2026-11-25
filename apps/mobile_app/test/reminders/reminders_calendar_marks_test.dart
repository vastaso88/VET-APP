import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/reminder_calendar.dart';

PetProfile _pet(String id, String name) => PetProfile(
      id: id,
      name: name,
      species: 'Gatto',
      breed: '',
      birthDateLabel: '',
      sex: '',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: name[0],
      accentColor: Colors.white,
      // The same colour on purpose: the letter must tell them apart.
      identityColor: Colors.teal,
    );

ReminderEntry _reminder(String id, String petName, DateTime due, {EventKind? kind}) =>
    ReminderEntry(
      id: id,
      petName: petName,
      title: 'Visita',
      kind: kind ?? EventKind.spot,
      dueAt: due,
      courseDurationDays: kind == EventKind.course ? 3 : null,
    );

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

BoxDecoration _decoration(WidgetTester tester) => tester
    .widget<Container>(
      find.descendant(of: find.byType(DayMark), matching: find.byType(Container)).first,
    )
    .decoration! as BoxDecoration;

/// A day of the calendar is not told by the colour alone (test round, card A02).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final day = DateTime(2026, 11, 25);
  final pets = [_pet('a', 'Nonno Gigi'), _pet('b', 'Giallo'), _pet('c', 'Axel')];

  testWidgets('one activity: the initial of its animal, 12 or more', (tester) async {
    final markers = activityMarkersForDay([_reminder('1', 'Axel', day)], pets, day);
    await tester.pumpWidget(_app(DayMark(markers: markers)));
    expect(find.text('A'), findsOneWidget);
    expect(_decoration(tester).shape, BoxShape.circle);
    final text = tester.widget<Text>(find.text('A'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(12));
  });

  testWidgets('two animals on the same day: how many, in a number', (tester) async {
    final markers = activityMarkersForDay(
      [_reminder('1', 'Nonno Gigi', day), _reminder('2', 'Giallo', day)],
      pets,
      day,
    );
    await tester.pumpWidget(_app(DayMark(markers: markers)));
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a course has another shape than an event', (tester) async {
    final markers = activityMarkersForDay(
      [_reminder('1', 'Axel', day, kind: EventKind.course)],
      pets,
      day,
    );
    await tester.pumpWidget(_app(DayMark(markers: markers)));
    expect(_decoration(tester).shape, BoxShape.rectangle);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('with very large text the mark still fits a column of 320 px', (tester) async {
    final markers = activityMarkersForDay([_reminder('1', 'Axel', day)], pets, day);
    await tester.pumpWidget(_app(DayMark(markers: markers), textScale: 2.5));
    expect(tester.getSize(find.byType(DayMark)).width, lessThanOrEqualTo(34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('next to a name in a filter: the initial, not a dot', (tester) async {
    await tester.pumpWidget(_app(PetInitialMark(pet: pets.first)));
    expect(find.text('N'), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/events/data/event_submission_repository.dart';
import 'package:vet_app_mobile/features/events/domain/event_submission.dart';
import 'package:vet_app_mobile/features/events/domain/event_regions.dart';
import 'package:vet_app_mobile/features/events/presentation/pages/submit_event_page.dart';
import 'package:vet_app_mobile/features/territory/domain/territory.dart';

import '../territory/territory_test_helpers.dart';

final _draft = EventSubmissionDraft(
  title: 'Giornata dell\'adozione',
  eventType: 'adoption_day',
  startsOn: DateTime(2026, 11, 14),
  endsOn: DateTime(2026, 11, 14),
  city: 'Modena',
  sourceUrl: 'https://www.example.org/adozioni',
  provinceCode: 'MO',
);

EventSubmissionRepository _repository(
  http.Response Function(http.Request) respond, {
  String? token = 'token',
  void Function(http.Request)? onRequest,
}) {
  return EventSubmissionRepository(
    client: MockClient((request) async {
      onRequest?.call(request);
      return respond(request);
    }),
    accessToken: () => token,
  );
}

class _FakeRepository extends EventSubmissionRepository {
  _FakeRepository(this.outcome);

  final EventSubmissionOutcome outcome;
  EventSubmissionDraft? received;

  @override
  Future<EventSubmissionOutcome> submit(EventSubmissionDraft draft) async {
    received = draft;
    return outcome;
  }
}

void main() {
  tearDown(resetTerritoryForTest);

  group('the country of a suggestion', () {
    test('starts from the home of the owner, else from the country of the account', () async {
      await useLanguageVariant('de-CH');

      expect(defaultEventCountry(null), 'CH');
      expect(defaultEventCountry('fr'), 'FR');
      expect(defaultEventCountry('PT'), 'CH', reason: 'the app does not support it');
    });

    test('every region on offer belongs to a supported country', () {
      expect(knownTerritoryCodes, containsAll(eventRegionsByCountry.keys));
    });

    test('is always sent, the region only when there is one', () {
      expect(_draft.toJson()['country'], 'IT');
      expect(_draft.toJson().containsKey('region'), isFalse);
    });
  });

  group('EventSubmissionRepository', () {
    test('sends the draft with the token and reports success on 201', () async {
      http.Request? sent;
      final outcome = await _repository(
        (_) => http.Response('{"submission_id":"x","status":"pending"}', 201),
        onRequest: (request) => sent = request,
      ).submit(_draft);

      expect(outcome, isA<EventSubmissionSent>());
      expect(sent!.url.path, endsWith('/events/submissions'));
      expect(sent!.headers['Authorization'], 'Bearer token');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['starts_on'], '2026-11-14');
      expect(body['province_code'], 'MO');
      expect(body.containsKey('venue_name'), isFalse);
    });

    test('maps the server answers', () async {
      expect(
        await _repository((_) => http.Response('{}', 429)).submit(_draft),
        isA<EventSubmissionLimitReached>(),
      );
      expect(
        await _repository((_) => http.Response('{}', 401)).submit(_draft),
        isA<EventSubmissionNotSignedIn>(),
      );
      expect(
        await _repository((_) => http.Response('boom', 500)).submit(_draft),
        isA<EventSubmissionFailed>(),
      );
      final rejected = await _repository(
        (_) => http.Response('{"detail":"Titolo: campo obbligatorio"}', 400),
      ).submit(_draft);
      expect((rejected as EventSubmissionRejected).message, 'Titolo: campo obbligatorio');
    });

    test('the refusal is asked and shown in the language of the app', () async {
      await useLanguageVariant('de');
      http.Request? sent;

      final rejected = await _repository(
        (_) => http.Response.bytes(
          utf8.encode('{"detail":"Paese non riconosciuto","message":"Land ungültig"}'),
          400,
        ),
        onRequest: (request) => sent = request,
      ).submit(_draft);

      expect(sent!.headers['Accept-Language'], 'de');
      expect((rejected as EventSubmissionRejected).message, 'Land ungültig');
    });

    test('without a session it does not even call the server', () async {
      var called = false;
      final outcome = await _repository(
        (_) => http.Response('{}', 201),
        token: null,
        onRequest: (_) => called = true,
      ).submit(_draft);

      expect(outcome, isA<EventSubmissionNotSignedIn>());
      expect(called, isFalse);
    });
  });

  group('isValidEventLink', () {
    test('accepts only http(s) addresses with a domain', () {
      expect(isValidEventLink('https://www.sor.re.it/x'), isTrue);
      expect(isValidEventLink('http://example.org'), isTrue);
      expect(isValidEventLink('ftp://example.org'), isFalse);
      expect(isValidEventLink('example.org'), isFalse);
      expect(isValidEventLink('https://localhost'), isFalse);
      expect(isValidEventLink(''), isFalse);
    });
  });

  group('SubmitEventPage', () {
    Future<void> pump(WidgetTester tester, _FakeRepository repository) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SubmitEventPage(repository: repository)));
    }

    testWidgets('required fields block the submission', (tester) async {
      final repository = _FakeRepository(const EventSubmissionSent());
      await pump(tester, repository);

      await tester.tap(find.text('Invia segnalazione'));
      await tester.pump();

      expect(repository.received, isNull);
      expect(find.text('Campo obbligatorio'), findsWidgets);
    });

    testWidgets('without dates the form is not sent even if the text is filled', (tester) async {
      final repository = _FakeRepository(const EventSubmissionSent());
      await pump(tester, repository);

      await tester.enterText(find.byType(TextFormField).at(0), 'Fiera di prova');
      await tester.enterText(find.byType(TextFormField).at(1), 'Modena');
      await tester.enterText(find.byType(TextFormField).at(4), 'https://www.example.org/x');
      await tester.tap(find.text('Invia segnalazione'));
      await tester.pump();

      expect(repository.received, isNull);
      expect(find.text('Campo obbligatorio'), findsOneWidget);
    });

    Future<void> choose(WidgetTester tester, Key field, String name) async {
      await tester.tap(find.byKey(field));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the regions follow the country and only Italy has the province', (tester) async {
      await pump(tester, _FakeRepository(const EventSubmissionSent()));

      expect(find.byKey(const ValueKey('event-region-IT')), findsOneWidget);
      expect(find.textContaining('Provincia'), findsOneWidget);

      await choose(tester, const ValueKey('event-country'), 'Francia');
      expect(find.byKey(const ValueKey('event-region-FR')), findsOneWidget);
      expect(find.textContaining('Provincia'), findsNothing);

      await choose(tester, const ValueKey('event-region-FR'), 'Occitanie');
      expect(find.text('Occitanie'), findsOneWidget);

      await choose(tester, const ValueKey('event-country'), 'Svizzera');
      expect(find.textContaining('Regione'), findsNothing, reason: 'no table for Switzerland');
      expect(find.text('Occitanie'), findsNothing);
    });

    testWidgets('a link that is not http(s) is refused before sending', (tester) async {
      final repository = _FakeRepository(const EventSubmissionSent());
      await pump(tester, repository);

      await tester.enterText(find.byType(TextFormField).at(4), 'www.example.org');
      await tester.tap(find.text('Invia segnalazione'));
      await tester.pump();

      expect(find.textContaining('http://'), findsOneWidget);
      expect(repository.received, isNull);
    });
  });
}

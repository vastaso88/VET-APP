import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/data/address_geocoder.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/location/presentation/center_pin_map_picker.dart';
import 'package:vet_app_mobile/features/nearby_places/data/reverse_geocoder.dart';
import 'package:vet_app_mobile/features/settings/presentation/pages/location_picker_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// QK-24: the map with a fixed pin, shared by "Segnala un luogo mancante" and the
/// home-address picker. The report screen's own cases are in
/// test/nearby_places/radar_contributions_test.dart.

const _milan = Coordinates(latitude: 45.4642, longitude: 9.1900);

/// Answers with a fixed address and remembers the point it was asked about.
class _RecordingGeocoder extends ReverseGeocoder {
  Coordinates? asked;

  @override
  Future<String?> addressOf(Coordinates position) async {
    asked = position;
    return 'Via Esempio 10, Milano';
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The map's own drag, enough to move the centre.
Future<void> _pan(WidgetTester tester) async {
  await tester.drag(find.byType(FlutterMap), const Offset(-120, 80));
  await _settle(tester);
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: home,
    );

bool _movedFromMilan(Coordinates c) =>
    c.latitude != _milan.latitude || c.longitude != _milan.longitude;

void main() {
  testWidgets('the picker starts on the given centre and shows the pin and the map credit',
      (tester) async {
    final centres = <Coordinates>[];
    await tester.pumpWidget(
      _app(CenterPinMapPicker(initialPosition: _milan, onCenterChanged: centres.add)),
    );
    await _settle(tester);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, _milan.latitude);
    expect(map.options.initialCenter.longitude, _milan.longitude);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    final credit = tester.widget<RichAttributionWidget>(find.byType(RichAttributionWidget));
    expect(
      credit.attributions.whereType<TextSourceAttribution>().map((a) => a.text),
      contains('OpenStreetMap contributors'),
    );
  });

  testWidgets('panning the map reports the new centre; the pin stays where it is', (tester) async {
    final centres = <Coordinates>[];
    await tester.pumpWidget(
      _app(CenterPinMapPicker(initialPosition: _milan, onCenterChanged: centres.add)),
    );
    await _settle(tester);
    final pinBefore = tester.getCenter(find.byIcon(Icons.location_on));

    await _pan(tester);

    expect(centres, isNotEmpty);
    expect(_movedFromMilan(centres.last), isTrue);
    expect(tester.getCenter(find.byIcon(Icons.location_on)), pinBefore);
  });

  group('home-address picker (Impostazioni)', () {
    Future<GeocodedAddress?> openAndAct(
      WidgetTester tester,
      _RecordingGeocoder geocoder,
      Future<void> Function() act,
    ) async {
      GeocodedAddress? result;
      var closed = false;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<GeocodedAddress>(
                  MaterialPageRoute(
                    builder: (_) =>
                        LocationPickerPage(initialPosition: _milan, reverseGeocoder: geocoder),
                  ),
                );
                closed = true;
              },
              child: const Text('apri'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await act();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(closed, isTrue);
      return result;
    }

    testWidgets('confirming without moving gives the starting point', (tester) async {
      final geocoder = _RecordingGeocoder();
      final result = await openAndAct(tester, geocoder, () async {
        expect(find.byType(CenterPinMapPicker), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
      });

      expect(result!.coordinates.latitude, _milan.latitude);
      expect(result.coordinates.longitude, _milan.longitude);
      expect(result.displayLabel, 'Via Esempio 10, Milano');
    });

    testWidgets('after panning, the confirmed point is the one under the pin', (tester) async {
      final geocoder = _RecordingGeocoder();
      final result = await openAndAct(tester, geocoder, () async {
        await _pan(tester);
        await tester.tap(find.byType(FilledButton));
      });

      expect(_movedFromMilan(result!.coordinates), isTrue);
      expect(geocoder.asked!.latitude, result.coordinates.latitude);
      expect(geocoder.asked!.longitude, result.coordinates.longitude);
    });

    testWidgets('going back without confirming gives nothing and asks nothing', (tester) async {
      final geocoder = _RecordingGeocoder();
      final result = await openAndAct(tester, geocoder, () async {
        await _pan(tester);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
      });

      expect(result, isNull);
      expect(geocoder.asked, isNull);
    });

    testWidgets('the map credit is visible on this screen too', (tester) async {
      await tester.pumpWidget(
        _app(LocationPickerPage(initialPosition: _milan, reverseGeocoder: _RecordingGeocoder())),
      );
      await _settle(tester);

      expect(find.byType(RichAttributionWidget), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });
  });
}

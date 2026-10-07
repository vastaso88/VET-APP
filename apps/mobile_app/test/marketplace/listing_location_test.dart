import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/location/domain/geo_math.dart';
import 'package:vet_app_mobile/features/marketplace/data/area_label_geocoder.dart';
import 'package:vet_app_mobile/features/marketplace/data/listing_photo_store.dart';
import 'package:vet_app_mobile/features/marketplace/domain/listing_location.dart';

void main() {
  group('approximateListingLocation', () {
    test('snaps to the nearest 0.01° grid point', () {
      final approx = approximateListingLocation(
        const Coordinates(latitude: 45.46423, longitude: 9.18951),
      );
      expect(approx, const Coordinates(latitude: 45.46, longitude: 9.19));
    });

    test('never moves a position by more than half a grid cell (~700 m)', () {
      const samples = [
        Coordinates(latitude: 45.4649, longitude: 9.1949),
        Coordinates(latitude: 41.9028, longitude: 12.4964),
        Coordinates(latitude: 40.8518, longitude: 14.2681),
        Coordinates(latitude: 38.1157, longitude: 13.3615),
      ];
      for (final exact in samples) {
        final approx = approximateListingLocation(exact);
        expect(haversineMeters(exact, approx), lessThan(700));
        expect(approx, isNot(exact));
      }
    });

    test('everyone in the same cell gets the very same point', () {
      final a = approximateListingLocation(const Coordinates(latitude: 45.4612, longitude: 9.1876));
      final b = approximateListingLocation(const Coordinates(latitude: 45.4581, longitude: 9.1932));
      expect(a, b);
    });

    test('is stable: approximating twice changes nothing', () {
      final once = approximateListingLocation(const Coordinates(latitude: 45.4673, longitude: 9.2));
      expect(approximateListingLocation(once), once);
    });

    test('handles negative coordinates and the poles', () {
      expect(
        approximateListingLocation(const Coordinates(latitude: -33.8688, longitude: -70.6483)),
        const Coordinates(latitude: -33.87, longitude: -70.65),
      );
      expect(
        approximateListingLocation(const Coordinates(latitude: 89.999, longitude: 179.999)),
        const Coordinates(latitude: 90, longitude: 180),
      );
    });
  });

  group('distance', () {
    test('haversine matches known distances', () {
      const milanoDuomo = Coordinates(latitude: 45.4642, longitude: 9.1900);
      const romaColosseo = Coordinates(latitude: 41.8902, longitude: 12.4922);
      expect(haversineMeters(milanoDuomo, romaColosseo) / 1000, closeTo(477, 3));
      expect(haversineMeters(milanoDuomo, milanoDuomo), 0);
    });

    test('0.01° of latitude is ~1.1 km', () {
      expect(
        haversineMeters(
          const Coordinates(latitude: 45.46, longitude: 9.19),
          const Coordinates(latitude: 45.47, longitude: 9.19),
        ),
        closeTo(1112, 5),
      );
    });
  });

  group('areaLabelFromAddress', () {
    test('keeps neighbourhood and town, drops street and house number', () {
      final label = areaLabelFromAddress({
        'road': 'Via Roma',
        'house_number': '12',
        'postcode': '20123',
        'suburb': 'Navigli',
        'city': 'Milano',
      });
      expect(label, 'Navigli, Milano');
    });

    test('falls back to the town alone', () {
      expect(areaLabelFromAddress({'road': 'Via Verdi', 'village': 'Bellagio'}), 'Bellagio');
    });

    test('null when there is nothing but a street', () {
      expect(areaLabelFromAddress({'road': 'Via Verdi', 'house_number': '3'}), isNull);
    });
  });

  test('storagePathFromPublicUrl reads the object path of a public url', () {
    expect(
      storagePathFromPublicUrl(
        'https://x.supabase.co/storage/v1/object/public/marketplace-photos/u1/l1/p1.jpg',
      ),
      'u1/l1/p1.jpg',
    );
    expect(storagePathFromPublicUrl('memory://l1/p1'), isNull);
  });
}

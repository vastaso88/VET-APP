import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/marketplace/data/listing_photo_store.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/widgets/listing_photo.dart';

const _base = 'https://project.supabase.example.com';
const _path = 'owner-1/listing-1/photo-1.jpg';
const _link = '$_base/storage/v1/object/public/marketplace-photos/$_path';

/// K23: a photo of an ad is opened only from the app's own public bucket.
void main() {
  test('the app\'s own bucket is accepted', () {
    expect(isListingPhotoUrl(_link, supabaseUrl: _base), isTrue);
    expect(isListingPhotoUrl(_link, supabaseUrl: '$_base/'), isTrue);
  });

  for (final entry in {
    'another site': 'https://example.com/1.jpg',
    'another site with the same path':
        'https://example.com/storage/v1/object/public/marketplace-photos/$_path',
    'the address as a user name': _link.replaceFirst(_base, '$_base@example.com'),
    'the address as a subdomain': _link.replaceFirst(_base, '$_base.example.com'),
    'another port': _link.replaceFirst(_base, '$_base:8443'),
    'http': _link.replaceFirst('https', 'http'),
    'data': 'data:image/jpeg;base64,AAAA',
    'another bucket': _link.replaceFirst('marketplace-photos', 'pet-photos'),
    'up into another folder': _link.replaceFirst('listing-1', '..'),
    'up, encoded': _link.replaceFirst('listing-1', '%2e%2e'),
    'a query': '$_link?to=https://example.com',
    'another type': _link.replaceFirst('.jpg', '.svg'),
    'only a path': _path,
    'empty': '',
  }.entries) {
    test('${entry.key} is refused', () {
      expect(isListingPhotoUrl(entry.value, supabaseUrl: _base), isFalse);
    });
  }

  test('without a configured server nothing is opened', () {
    expect(isListingPhotoUrl(_link, supabaseUrl: ''), isFalse);
  });

  testWidgets('a link to another site shows the placeholder and asks nobody', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ListingPhoto(url: 'https://example.com/1.jpg')),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}

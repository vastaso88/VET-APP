import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/walk_labels.dart';

void main() {
  group('walkElapsedLabel', () {
    test('shows seconds ticking within the first minute', () {
      expect(walkElapsedLabel(0), '0:00');
      expect(walkElapsedLabel(5), '0:05');
      expect(walkElapsedLabel(59), '0:59');
    });

    test('rolls over into minutes:seconds under an hour', () {
      expect(walkElapsedLabel(60), '1:00');
      expect(walkElapsedLabel(125), '2:05');
      expect(walkElapsedLabel(3599), '59:59');
    });

    test('rolls over into hours:minutes:seconds past an hour', () {
      expect(walkElapsedLabel(3600), '1:00:00');
      expect(walkElapsedLabel(3665), '1:01:05');
    });
  });
}

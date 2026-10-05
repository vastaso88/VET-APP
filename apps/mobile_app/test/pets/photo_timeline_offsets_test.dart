import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/photo_timeline_view.dart';

void main() {
  // Viewport 390 px: content 390 - 16 - 24 = 350; tile (350 - 2*4) / 3 = 114.
  test('section heights come from photo count, columns and width', () {
    expect(timelineGridHeight(3, 350), 114); // one row
    expect(timelineGridHeight(4, 350), 114 * 2 + 4); // two rows, one gap
    expect(timelineGridHeight(0, 350), 0);
  });

  test('offsets are exact prefix sums of header, grid and gap', () {
    final offsets = timelineSectionOffsets([3, 4], 390);
    // top padding 12; section 1 = 28 + 114 + 16 = 158, so section 2 starts at 170;
    // section 2 = 28 + 232 + 16 = 276, so the list ends at 446.
    expect(offsets, [12, 170, 446]);
  });

  test('the section for an offset is the last one starting at or above it', () {
    final offsets = timelineSectionOffsets([3, 4], 390);
    expect(timelineSectionAt(offsets, 0), 0);
    expect(timelineSectionAt(offsets, 169.9), 0);
    expect(timelineSectionAt(offsets, 170), 1);
    expect(timelineSectionAt(offsets, 500), 1);
    expect(timelineSectionAt(offsets, 10000), 1);
  });

  test('an empty timeline has no sections to land on', () {
    expect(timelineSectionAt(timelineSectionOffsets(const [], 390), 50), 0);
  });
}

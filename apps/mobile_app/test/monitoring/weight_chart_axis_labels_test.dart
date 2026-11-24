import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/monitoring/presentation/widgets/weight_chart_view.dart';

void main() {
  bool fits(double v) => WeightChartView.axisLabelFits(v, minX: 3, maxX: 27, interval: 6);

  test('the two ends of the date axis are always printed', () {
    expect(fits(3), isTrue);
    expect(fits(27), isTrue);
  });

  test('a regular step too close to an end is left out (it would print over it)', () {
    expect(fits(9), isTrue);
    expect(fits(15), isTrue);
    expect(fits(21), isTrue);
    expect(fits(25), isFalse);
    expect(fits(5), isFalse);
  });
}

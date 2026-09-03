import 'package:flutter_test/flutter_test.dart';
import 'package:juntai/core/utils/geo_utils.dart';

void main() {
  test('distancia zero', () {
    expect(GeoUtils.distanceKm(-23.5, -46.6, -23.5, -46.6), closeTo(0, 0.001));
  });
}

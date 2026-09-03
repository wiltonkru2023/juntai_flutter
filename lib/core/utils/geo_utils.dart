import 'dart:math';

abstract final class GeoUtils {
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double d(double x) => x * pi / 180;
    final dLat = d(lat2 - lat1), dLon = d(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(d(lat1)) * cos(d(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

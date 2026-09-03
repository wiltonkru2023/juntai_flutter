import 'package:geolocator/geolocator.dart';
class LocationService {
  Future<bool> requestPermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition();
  Stream<Position> watchPosition() => Geolocator.getPositionStream();
}

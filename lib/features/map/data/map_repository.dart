import 'package:geolocator/geolocator.dart';
abstract class MapRepository { Future<Position> currentPosition(); double distanceMeters(double startLat,double startLng,double endLat,double endLng); }
class GeolocatorMapRepository implements MapRepository{ @override Future<Position> currentPosition()=>Geolocator.getCurrentPosition(); @override double distanceMeters(double a,double b,double c,double d)=>Geolocator.distanceBetween(a,b,c,d); }

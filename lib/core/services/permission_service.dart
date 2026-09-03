import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> notifications() async =>
      (await Permission.notification.request()).isGranted;
  Future<bool> photos() async => (await Permission.photos.request()).isGranted;
}

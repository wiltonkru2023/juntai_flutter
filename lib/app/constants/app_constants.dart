abstract final class AppConstants {
  static const appName = 'Juntaí';
  static const realMaps = bool.fromEnvironment(
    'REAL_MAPS',
    defaultValue: false,
  );
  static const maxDescription = 300;
  static const deepLinkBase = 'https://juntai-flutter.onrender.com';
}

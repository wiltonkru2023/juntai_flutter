import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void debug(String message) {
    if (kDebugMode) debugPrint('[DEBUG] $message');
  }

  static void info(String message) {
    if (kDebugMode) debugPrint('[INFO] $message');
  }

  static void warning(String message) {
    if (kDebugMode) debugPrint('[WARN] $message');
  }

  static void error(String message) {
    if (kDebugMode) debugPrint('[ERROR] $message');
  }
}

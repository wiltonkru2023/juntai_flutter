import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<bool> initialize() async {
    try {
      await Firebase.initializeApp();
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao inicializar Firebase: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
    }
  }
}

import 'package:firebase_core/firebase_core.dart';

class BootstrapResult {
  final bool firebaseReady;
  const BootstrapResult({required this.firebaseReady});
}

Future<BootstrapResult> bootstrap() async {
  try {
    await Firebase.initializeApp();
    return const BootstrapResult(firebaseReady: true);
  } catch (_) {
    return const BootstrapResult(firebaseReady: false);
  }
}

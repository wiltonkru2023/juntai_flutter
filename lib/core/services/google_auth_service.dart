import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  Future<OAuthCredential> getCredential() async {
    await _initialize();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthServiceException(
        'O login com Google não está disponível neste dispositivo.',
      );
    }

    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthServiceException(
        'O Google não retornou uma credencial válida.',
      );
    }

    return GoogleAuthProvider.credential(
      idToken: idToken,
    );
  }

  Future<UserCredential> signIn() async {
    return FirebaseAuth.instance.signInWithCredential(await getCredential());
  }

  Future<void> signOut() async {
    try {
      await _initialize();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // O usuário pode ter entrado somente com e-mail e senha.
    }
  }
}

class GoogleAuthServiceException implements Exception {
  const GoogleAuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

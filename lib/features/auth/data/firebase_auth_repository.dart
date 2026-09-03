import 'package:firebase_auth/firebase_auth.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;
  @override
  String? get currentUserId => _auth.currentUser?.uid;
  @override
  Future<void> signInWithEmail(String email, String password) async =>
      _auth.signInWithEmailAndPassword(email: email, password: password);
  @override
  Future<void> registerWithEmail(String email, String password) async =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);
  @override
  Future<void> sendPasswordReset(String email) async =>
      _auth.sendPasswordResetEmail(email: email);
  @override
  Future<void> signOut() => _auth.signOut();
}

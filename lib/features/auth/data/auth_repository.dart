abstract class AuthRepository {
  String? get currentUserId;
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

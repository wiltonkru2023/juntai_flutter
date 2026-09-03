import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';

class UsernameService {
  UsernameService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@+'), '')
      .replaceAll(RegExp(r'[^a-z0-9_.]'), '');

  static String? validate(String value) {
    final normalized = normalize(value);
    if (normalized.length < 3 || normalized.length > 20) {
      return 'Use de 3 a 20 caracteres.';
    }
    if (!RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$').hasMatch(normalized)) {
      return 'Comece com uma letra e use letras, números, ponto ou _.';
    }
    return null;
  }

  Future<bool> isAvailable(String value) async {
    final username = normalize(value);
    if (validate(username) != null) return false;
    return !(await _db.collection('usernames').doc(username).get()).exists;
  }

  Future<List<String>> suggestions(String value) async {
    var base = normalize(value);
    if (base.length < 3) base = '${base}user';
    if (!RegExp(r'^[a-z]').hasMatch(base)) base = 'user$base';
    if (base.length > 15) base = base.substring(0, 15);
    final candidates = <String>[
      '${base}1',
      '${base}2',
      '$base.sp',
      '${base}_2026',
      '$base${DateTime.now().year.toString().substring(2)}',
    ];
    final checks = await Future.wait(candidates.map(isAvailable));
    return [
      for (var i = 0; i < candidates.length; i++)
        if (checks[i]) candidates[i]
    ].take(3).toList();
  }

  Future<void> createProfileWithUsername({
    required String uid,
    required String username,
    required Map<String, dynamic> profile,
  }) async {
    final normalized = normalize(username);
    final error = validate(normalized);
    if (error != null) throw UsernameException(error);

    final userRef = _db.collection('users').doc(uid);
    try {
      await ApiService.instance.reserveUsername(normalized);
      await userRef.set({
        ...profile,
        'username': normalized,
        'usernameLower': normalized,
      });
    } on ApiException catch (error) {
      throw UsernameException(error.message);
    }
  }
}

class UsernameException implements Exception {
  const UsernameException(this.message);
  final String message;
  @override
  String toString() => message;
}

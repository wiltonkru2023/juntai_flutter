import 'package:cloud_firestore/cloud_firestore.dart';

class InterestService {
  static const canonical = <String>[
    'Futebol',
    'Corrida',
    'Pedalar',
    'Games',
    'Cinema',
    'Café',
    'Música',
    'Trilha',
    'Academia',
    'Estudos',
  ];

  static const legacy = <String, String>{
    'mãºsica': 'Música',
    'mã°sica': 'Música',
    'música': 'Música',
    'musica': 'Música',
    'cafã©': 'Café',
    'cafe': 'Café',
    'café': 'Café',
    'futebol': 'Futebol',
    'corrida': 'Corrida',
    'pedalar': 'Pedalar',
    'games': 'Games',
    'cinema': 'Cinema',
    'trilha': 'Trilha',
    'academia': 'Academia',
    'estudos': 'Estudos',
  };

  static List<String> normalizeList(Iterable<dynamic> values) {
    final result = <String>[];
    for (final raw in values) {
      final text = raw.toString().trim();
      final normalized =
          canonical.contains(text) ? text : legacy[text.toLowerCase()];
      if (normalized != null && !result.contains(normalized))
        result.add(normalized);
    }
    return result;
  }

  static Future<void> normalizeUser(String uid) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists) return;
    final raw = doc.data()?['interests'];
    final normalized = raw is List ? normalizeList(raw) : <String>[];
    final old =
        raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    if (old.length == normalized.length &&
        List.generate(old.length, (i) => old[i] == normalized[i])
            .every((e) => e)) {
      return;
    }
    await ref.set({
      'interests': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

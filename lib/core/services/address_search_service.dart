import '../services/api_service.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  factory AddressSuggestion.fromMap(Map<String, dynamic> map) {
    return AddressSuggestion(
      label: (map['label'] ?? '').toString(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }
}

class AddressSearchService {
  AddressSearchService._();

  static final AddressSearchService instance = AddressSearchService._();

  Future<List<AddressSuggestion>> search(String query) async {
    final value = query.trim();

    if (value.length < 3) {
      return const <AddressSuggestion>[];
    }

    final response = await ApiService.instance.post(
      '/address-search',
      body: {
        'query': value,
      },
    );

    final raw = response['suggestions'];

    if (raw is! List) {
      return const <AddressSuggestion>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => AddressSuggestion.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.label.isNotEmpty)
        .toList();
  }
}

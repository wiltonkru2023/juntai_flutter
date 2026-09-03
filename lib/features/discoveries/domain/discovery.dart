import 'package:cloud_firestore/cloud_firestore.dart';

class Discovery {
  const Discovery(
      {required this.id,
      required this.businessId,
      required this.businessName,
      required this.businessCategory,
      required this.businessVerified,
      required this.title,
      required this.description,
      required this.address,
      required this.latitude,
      required this.longitude,
      required this.ctaLabel,
      required this.status,
      required this.createdAt,
      this.coverUrl,
      this.websiteUrl,
      this.groupBenefit,
      this.eventStartsAt,
      this.sponsored = false,
      this.officialEvent = false,
      this.activitiesCreated = 0,
      this.views = 0,
      this.opens = 0,
      this.participantsGenerated = 0});
  final String id,
      businessId,
      businessName,
      businessCategory,
      title,
      description,
      address,
      ctaLabel,
      status;
  final bool businessVerified, sponsored, officialEvent;
  final double latitude, longitude;
  final String? coverUrl, websiteUrl, groupBenefit;
  final DateTime? eventStartsAt;
  final DateTime createdAt;
  final int activitiesCreated, views, opens, participantsGenerated;

  factory Discovery.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Discovery(
        id: doc.id,
        businessId: (d['businessId'] ?? '').toString(),
        businessName: (d['businessName'] ?? 'Local').toString(),
        businessCategory: (d['businessCategory'] ?? 'Comércio').toString(),
        businessVerified: d['businessVerified'] == true,
        title: (d['title'] ?? '').toString(),
        description: (d['description'] ?? '').toString(),
        address: (d['address'] ?? '').toString(),
        latitude: (d['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (d['longitude'] as num?)?.toDouble() ?? 0,
        coverUrl: d['coverUrl']?.toString(),
        websiteUrl: d['websiteUrl']?.toString(),
        groupBenefit: d['groupBenefit']?.toString(),
        ctaLabel: (d['ctaLabel'] ?? 'Criar atividade aqui').toString(),
        eventStartsAt: (d['eventStartsAt'] as Timestamp?)?.toDate(),
        sponsored: d['sponsored'] == true,
        officialEvent: d['officialEvent'] == true,
        status: (d['status'] ?? 'draft').toString(),
        views: (d['views'] as num?)?.toInt() ?? 0,
        opens: (d['opens'] as num?)?.toInt() ?? 0,
        activitiesCreated: (d['activitiesCreated'] as num?)?.toInt() ?? 0,
        participantsGenerated:
            (d['participantsGenerated'] as num?)?.toInt() ?? 0,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Discovery {
  const Discovery({
    required this.id,
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
    this.participantsGenerated = 0,
    this.distanceKm,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String businessCategory;
  final String title;
  final String description;
  final String address;
  final String ctaLabel;
  final String status;
  final bool businessVerified;
  final bool sponsored;
  final bool officialEvent;
  final double latitude;
  final double longitude;
  final String? coverUrl;
  final String? websiteUrl;
  final String? groupBenefit;
  final DateTime? eventStartsAt;
  final DateTime createdAt;
  final int activitiesCreated;
  final int views;
  final int opens;
  final int participantsGenerated;
  final double? distanceKm;

  Discovery copyWith({double? distanceKm}) => Discovery(
        id: id,
        businessId: businessId,
        businessName: businessName,
        businessCategory: businessCategory,
        businessVerified: businessVerified,
        title: title,
        description: description,
        address: address,
        latitude: latitude,
        longitude: longitude,
        ctaLabel: ctaLabel,
        status: status,
        createdAt: createdAt,
        coverUrl: coverUrl,
        websiteUrl: websiteUrl,
        groupBenefit: groupBenefit,
        eventStartsAt: eventStartsAt,
        sponsored: sponsored,
        officialEvent: officialEvent,
        activitiesCreated: activitiesCreated,
        views: views,
        opens: opens,
        participantsGenerated: participantsGenerated,
        distanceKm: distanceKm ?? this.distanceKm,
      );

  factory Discovery.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
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
      participantsGenerated: (d['participantsGenerated'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

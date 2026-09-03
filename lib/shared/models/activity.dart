import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/activity_category.dart';

class Activity {
  final String id;
  final String creatorId;
  final String creatorName;

  final String title;
  final String description;

  final ActivityCategory category;

  final String address;

  final double latitude;
  final double longitude;

  final String geohash;

  final DateTime startsAt;

  final int maxParticipants;
  final int participantCount;

  final bool isPrivate;

  final String? coverUrl;

  final String status;

  final double distanceKm;

  final List<String> participantNames;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourceDiscoveryId;
  final String? sourceBusinessId;
  final String? sourceBusinessName;
  final bool sourceBusinessVerified;

  const Activity({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.startsAt,
    required this.maxParticipants,
    required this.participantCount,
    required this.isPrivate,
    this.coverUrl,
    required this.status,
    required this.distanceKm,
    required this.participantNames,
    required this.createdAt,
    required this.updatedAt,
    this.sourceDiscoveryId,
    this.sourceBusinessId,
    this.sourceBusinessName,
    this.sourceBusinessVerified = false,
  });

  bool get isFull {
    return participantCount >= maxParticipants;
  }

  factory Activity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    final categoryName = (data['category'] ?? 'football').toString();

    final category = ActivityCategory.values.firstWhere(
      (item) => item.name == categoryName,
      orElse: () => ActivityCategory.football,
    );

    return Activity(
      id: document.id,
      creatorId: (data['creatorId'] ?? '').toString(),
      creatorName: (data['creatorName'] ?? 'Organizador').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: category,
      address: (data['address'] ?? '').toString(),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      geohash: (data['geohash'] ?? '').toString(),
      startsAt: (data['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 2,
      participantCount: (data['participantCount'] as num?)?.toInt() ?? 0,
      isPrivate: data['isPrivate'] == true,
      coverUrl: data['coverUrl']?.toString(),
      status: (data['status'] ?? 'active').toString(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      participantNames: data['participantNames'] is List
          ? List<String>.from(
              (data['participantNames'] as List).map((e) => e.toString()),
            )
          : <String>[],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sourceDiscoveryId: data['sourceDiscoveryId']?.toString(),
      sourceBusinessId: data['sourceBusinessId']?.toString(),
      sourceBusinessName: data['sourceBusinessName']?.toString(),
      sourceBusinessVerified: data['sourceBusinessVerified'] == true,
    );
  }

  Activity copyWith({
    String? title,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? geohash,
    DateTime? startsAt,
    int? maxParticipants,
    int? participantCount,
    bool? isPrivate,
    String? coverUrl,
    String? status,
    double? distanceKm,
    List<String>? participantNames,
  }) {
    return Activity(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      startsAt: startsAt ?? this.startsAt,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participantCount: participantCount ?? this.participantCount,
      isPrivate: isPrivate ?? this.isPrivate,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      distanceKm: distanceKm ?? this.distanceKm,
      participantNames: participantNames ?? this.participantNames,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      sourceDiscoveryId: sourceDiscoveryId,
      sourceBusinessId: sourceBusinessId,
      sourceBusinessName: sourceBusinessName,
      sourceBusinessVerified: sourceBusinessVerified,
    );
  }
}

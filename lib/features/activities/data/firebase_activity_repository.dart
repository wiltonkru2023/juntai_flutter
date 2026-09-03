import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/api_service.dart';
import '../../../shared/enums/activity_category.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/user_profile.dart';
import 'activity_repository.dart';

class FirebaseActivityRepository implements ActivityRepository {
  FirebaseActivityRepository(
    this.db, {
    ApiService? api,
  }) : _api = api ?? ApiService.instance;

  final FirebaseFirestore db;
  final ApiService _api;

  Map<String, dynamic> _toMap(Activity activity) => {
        'creatorId': activity.creatorId,
        'creatorName': activity.creatorName,
        'title': activity.title,
        'description': activity.description,
        'category': activity.category.name,
        'address': activity.address,
        'latitude': activity.latitude,
        'longitude': activity.longitude,
        'geohash': activity.geohash,
        'startsAt': Timestamp.fromDate(activity.startsAt),
        'maxParticipants': activity.maxParticipants,
        'participantCount': activity.participantCount,
        'isPrivate': activity.isPrivate,
        'coverUrl': activity.coverUrl,
        'status': activity.status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Activity _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    return Activity(
      id: document.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? 'Organizador',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: ActivityCategory.values.firstWhere(
        (item) => item.name == data['category'],
        orElse: () => ActivityCategory.football,
      ),
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      geohash: data['geohash'] ?? '',
      startsAt: (data['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxParticipants: data['maxParticipants'] ?? 2,
      participantCount: data['participantCount'] ?? 0,
      isPrivate: data['isPrivate'] ?? false,
      coverUrl: data['coverUrl'],
      status: data['status'] ?? 'active',
      distanceKm: 0,
      participantNames: data['participantNames'] is List
          ? List<String>.from(data['participantNames'])
          : const <String>[],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<String> createActivity(Activity activity) async {
    final reference = await db.collection('activities').add(_toMap(activity));
    return reference.id;
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    await _api.updateActivity(
      activityId: activity.id,
      title: activity.title,
      description: activity.description,
      category: activity.category.name,
      address: activity.address,
      latitude: activity.latitude,
      longitude: activity.longitude,
      geohash: activity.geohash,
      startsAt: activity.startsAt,
      maxParticipants: activity.maxParticipants,
      isPrivate: activity.isPrivate,
    );
  }

  @override
  Future<void> cancelActivity(String id) async {
    await _api.cancelActivity(id);
  }

  @override
  Future<void> joinActivity(String id) async {
    await _api.joinActivity(id);
  }

  @override
  Future<void> leaveActivity(String id) async {
    await _api.leaveActivity(id);
  }

  @override
  Stream<Activity?> watchActivity(String id) {
    return db
        .collection('activities')
        .doc(id)
        .snapshots()
        .map((document) => document.exists ? _fromDoc(document) : null);
  }

  @override
  Stream<List<Activity>> watchNearbyActivities({
    String? category,
    DateTime? startsAfter,
    int limit = 30,
  }) {
    Query<Map<String, dynamic>> query = db
        .collection('activities')
        .where('status', isEqualTo: 'active')
        .orderBy('startsAt')
        .limit(limit);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    if (startsAfter != null) {
      query = query.where(
        'startsAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startsAfter),
      );
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<List<Activity>> searchActivities(String query) async {
    final snapshot = await db
        .collection('activities')
        .where('status', isEqualTo: 'active')
        .limit(50)
        .get();

    final normalized = query.toLowerCase();

    return snapshot.docs
        .map(_fromDoc)
        .where(
          (activity) =>
              '${activity.title} ${activity.address} ${activity.category.label}'
                  .toLowerCase()
                  .contains(normalized),
        )
        .toList();
  }

  @override
  Stream<List<UserProfile>> watchParticipants(String id) {
    return db
        .collection('activities')
        .doc(id)
        .collection('participants')
        .snapshots()
        .asyncMap((snapshot) async {
      final output = <UserProfile>[];

      for (final participant in snapshot.docs) {
        final user = await db.collection('users').doc(participant.id).get();
        final data = user.data();

        if (data == null) continue;

        output.add(
          UserProfile(
            id: user.id,
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            city: data['city'] ?? '',
            bio: data['bio'] ?? '',
            verified: data['verified'] ?? false,
            rating: (data['rating'] ?? 0).toDouble(),
            interests: List<String>.from(
              data['interests'] ?? const <String>[],
            ),
            activitiesCreated: data['activitiesCreated'] ?? 0,
            activitiesJoined: data['activitiesJoined'] ?? 0,
            friendsCount: data['friendsCount'] ?? 0,
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
        );
      }

      return output;
    });
  }
}

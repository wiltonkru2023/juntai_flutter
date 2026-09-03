import 'package:cloud_firestore/cloud_firestore.dart';

class Discovery {
  const Discovery({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.businessCategory,
    required this.businessVerified,
    required this.type,
    required this.title,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.ctaLabel,
    required this.status,
    required this.createdAt,
    this.coverUrl,
    this.galleryUrls = const [],
    this.websiteUrl,
    this.groupBenefit,
    this.eventStartsAt,
    this.eventEndsAt,
    this.sponsored = false,
    this.sponsoredUntil,
    this.officialEvent = false,
    this.activitiesCreated = 0,
    this.views = 0,
    this.opens = 0,
    this.participantsGenerated = 0,
    this.profileVisits = 0,
    this.wantToGoClicks = 0,
    this.interestedCount = 0,
    this.shareCount = 0,
    this.groupsCreated = 0,
    this.couponUnlocks = 0,
    this.couponValidations = 0,
    this.slotsFilled = 0,
    this.price,
    this.juntaiPrice,
    this.minParticipants = 0,
    this.maxParticipants = 0,
    this.claimedParticipants = 0,
    this.benefitType,
    this.benefitValue,
    this.benefitMinParticipants = 0,
    this.benefitUnlocked = false,
    this.benefitCode,
    this.availabilitySlots = const [],
    this.distanceKm,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String businessCategory;
  final String type;
  final String title;
  final String description;
  final String address;
  final String ctaLabel;
  final String status;
  final bool businessVerified;
  final bool sponsored;
  final bool officialEvent;
  final bool benefitUnlocked;
  final double latitude;
  final double longitude;
  final String? coverUrl;
  final List<String> galleryUrls;
  final String? websiteUrl;
  final String? groupBenefit;
  final String? benefitType;
  final String? benefitCode;
  final num? benefitValue;
  final double? price;
  final double? juntaiPrice;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final DateTime? sponsoredUntil;
  final DateTime createdAt;
  final int activitiesCreated;
  final int views;
  final int opens;
  final int participantsGenerated;
  final int profileVisits;
  final int wantToGoClicks;
  final int interestedCount;
  final int shareCount;
  final int groupsCreated;
  final int couponUnlocks;
  final int couponValidations;
  final int slotsFilled;
  final int minParticipants;
  final int maxParticipants;
  final int claimedParticipants;
  final int benefitMinParticipants;
  final List<Map<String, dynamic>> availabilitySlots;
  final double? distanceKm;

  int get remainingSlots => maxParticipants <= 0
      ? 0
      : (maxParticipants - claimedParticipants).clamp(0, maxParticipants);
  bool get isFull =>
      maxParticipants > 0 && claimedParticipants >= maxParticipants;
  bool get isOpenSlots => type == 'open_slots';
  bool get isSchedule => type == 'schedule';

  Discovery copyWith({double? distanceKm}) => Discovery(
        id: id,
        businessId: businessId,
        businessName: businessName,
        businessCategory: businessCategory,
        businessVerified: businessVerified,
        type: type,
        title: title,
        description: description,
        address: address,
        latitude: latitude,
        longitude: longitude,
        ctaLabel: ctaLabel,
        status: status,
        createdAt: createdAt,
        coverUrl: coverUrl,
        galleryUrls: galleryUrls,
        websiteUrl: websiteUrl,
        groupBenefit: groupBenefit,
        eventStartsAt: eventStartsAt,
        eventEndsAt: eventEndsAt,
        sponsored: sponsored,
        sponsoredUntil: sponsoredUntil,
        officialEvent: officialEvent,
        activitiesCreated: activitiesCreated,
        views: views,
        opens: opens,
        participantsGenerated: participantsGenerated,
        profileVisits: profileVisits,
        wantToGoClicks: wantToGoClicks,
        interestedCount: interestedCount,
        shareCount: shareCount,
        groupsCreated: groupsCreated,
        couponUnlocks: couponUnlocks,
        couponValidations: couponValidations,
        slotsFilled: slotsFilled,
        price: price,
        juntaiPrice: juntaiPrice,
        minParticipants: minParticipants,
        maxParticipants: maxParticipants,
        claimedParticipants: claimedParticipants,
        benefitType: benefitType,
        benefitValue: benefitValue,
        benefitMinParticipants: benefitMinParticipants,
        benefitUnlocked: benefitUnlocked,
        benefitCode: benefitCode,
        availabilitySlots: availabilitySlots,
        distanceKm: distanceKm ?? this.distanceKm,
      );

  factory Discovery.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    DateTime? ts(String key) =>
        d[key] is Timestamp ? (d[key] as Timestamp).toDate() : null;

    final gallery = d['galleryUrls'] is List
        ? (d['galleryUrls'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final slots = d['availabilitySlots'] is List
        ? (d['availabilitySlots'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return Discovery(
      id: doc.id,
      businessId: (d['businessId'] ?? '').toString(),
      businessName: (d['businessName'] ?? 'Local').toString(),
      businessCategory: (d['businessCategory'] ?? 'Comércio').toString(),
      businessVerified: d['businessVerified'] == true,
      type: (d['type'] ?? 'experience').toString(),
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      address: (d['address'] ?? '').toString(),
      latitude: (d['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (d['longitude'] as num?)?.toDouble() ?? 0,
      coverUrl: d['coverUrl']?.toString(),
      galleryUrls: gallery,
      websiteUrl: d['websiteUrl']?.toString(),
      groupBenefit: d['groupBenefit']?.toString(),
      ctaLabel: (d['ctaLabel'] ?? 'Criar atividade aqui').toString(),
      eventStartsAt: ts('eventStartsAt'),
      eventEndsAt: ts('eventEndsAt'),
      sponsored: d['sponsored'] == true,
      sponsoredUntil: ts('sponsoredUntil'),
      officialEvent: d['officialEvent'] == true,
      status: (d['status'] ?? 'draft').toString(),
      views: (d['views'] as num?)?.toInt() ?? 0,
      opens: (d['opens'] as num?)?.toInt() ?? 0,
      activitiesCreated: (d['activitiesCreated'] as num?)?.toInt() ?? 0,
      participantsGenerated: (d['participantsGenerated'] as num?)?.toInt() ?? 0,
      profileVisits: (d['profileVisits'] as num?)?.toInt() ?? 0,
      wantToGoClicks: (d['wantToGoClicks'] as num?)?.toInt() ?? 0,
      interestedCount: (d['interestedCount'] as num?)?.toInt() ?? 0,
      shareCount: (d['shareCount'] as num?)?.toInt() ?? 0,
      groupsCreated: (d['groupsCreated'] as num?)?.toInt() ?? 0,
      couponUnlocks: (d['couponUnlocks'] as num?)?.toInt() ?? 0,
      couponValidations: (d['couponValidations'] as num?)?.toInt() ?? 0,
      slotsFilled: (d['slotsFilled'] as num?)?.toInt() ?? 0,
      price: (d['price'] as num?)?.toDouble(),
      juntaiPrice: (d['juntaiPrice'] as num?)?.toDouble(),
      minParticipants: (d['minParticipants'] as num?)?.toInt() ?? 0,
      maxParticipants: (d['maxParticipants'] as num?)?.toInt() ?? 0,
      claimedParticipants: (d['claimedParticipants'] as num?)?.toInt() ?? 0,
      benefitType: d['benefitType']?.toString(),
      benefitValue: d['benefitValue'] as num?,
      benefitMinParticipants:
          (d['benefitMinParticipants'] as num?)?.toInt() ?? 0,
      benefitUnlocked: d['benefitUnlocked'] == true,
      benefitCode: d['benefitCode']?.toString(),
      availabilitySlots: slots,
      createdAt: ts('createdAt') ?? DateTime.now(),
    );
  }
}

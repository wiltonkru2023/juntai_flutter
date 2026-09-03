class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String city;
  final String bio;
  final bool verified;
  final double rating;
  final List<String> interests;
  final int activitiesCreated;
  final int activitiesJoined;
  final int friendsCount;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.city,
    required this.bio,
    required this.verified,
    required this.rating,
    required this.interests,
    required this.activitiesCreated,
    required this.activitiesJoined,
    required this.friendsCount,
    required this.createdAt,
    this.lastSeenAt,
  });

  UserProfile copyWith({String? name, String? email, String? city, String? bio, String? photoUrl, List<String>? interests}) => UserProfile(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    photoUrl: photoUrl ?? this.photoUrl,
    city: city ?? this.city,
    bio: bio ?? this.bio,
    verified: verified,
    rating: rating,
    interests: interests ?? this.interests,
    activitiesCreated: activitiesCreated,
    activitiesJoined: activitiesJoined,
    friendsCount: friendsCount,
    createdAt: createdAt,
    lastSeenAt: lastSeenAt,
  );
}

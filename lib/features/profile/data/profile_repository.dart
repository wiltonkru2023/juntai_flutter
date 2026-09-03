import '../../../shared/models/user_profile.dart';
abstract class ProfileRepository { Stream<UserProfile?> watchProfile(String userId); Future<void> updateProfile(UserProfile profile); Future<void> blockUser(String userId); Future<void> unblockUser(String userId); }

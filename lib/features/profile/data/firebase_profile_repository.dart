import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/user_profile.dart';
import 'profile_repository.dart';
class FirebaseProfileRepository implements ProfileRepository{FirebaseProfileRepository(this.db,this.currentUid);final FirebaseFirestore db;final String currentUid;
  UserProfile _from(DocumentSnapshot<Map<String,dynamic>> d){final m=d.data()!;return UserProfile(id:d.id,name:m['name']??'',email:m['email']??'',photoUrl:m['photoUrl'],city:m['city']??'',bio:m['bio']??'',verified:m['verified']??false,rating:(m['rating']??0).toDouble(),interests:List<String>.from(m['interests']??const[]),activitiesCreated:m['activitiesCreated']??0,activitiesJoined:m['activitiesJoined']??0,friendsCount:m['friendsCount']??0,createdAt:(m['createdAt'] as Timestamp?)?.toDate()??DateTime.now(),lastSeenAt:(m['lastSeenAt'] as Timestamp?)?.toDate());}
  @override Stream<UserProfile?> watchProfile(String id)=>db.collection('users').doc(id).snapshots().map((d)=>d.exists?_from(d):null);
  @override Future<void> updateProfile(UserProfile p)=>db.collection('users').doc(currentUid).set({'name':p.name,'email':p.email,'photoUrl':p.photoUrl,'city':p.city,'bio':p.bio,'interests':p.interests,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
  @override Future<void> blockUser(String id)=>db.collection('users').doc(currentUid).collection('blocks').doc(id).set({'createdAt':FieldValue.serverTimestamp()});
  @override Future<void> unblockUser(String id)=>db.collection('users').doc(currentUid).collection('blocks').doc(id).delete();}

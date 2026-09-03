import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../shared/models/chat_message.dart';
import 'chat_repository.dart';
class FirebaseChatRepository implements ChatRepository{
  FirebaseChatRepository(this.db,this.storage,this.auth);final FirebaseFirestore db;final FirebaseStorage storage;final FirebaseAuth auth;
  CollectionReference<Map<String,dynamic>> _c(String a)=>db.collection('activities').doc(a).collection('chat');
  @override Stream<List<ChatMessage>> watchMessages(String a,{int limit=40})=>_c(a).orderBy('createdAt',descending:true).limit(limit).snapshots().map((s)=>s.docs.reversed.map((d){final m=d.data();return ChatMessage(id:d.id,senderId:m['senderId']??'',senderName:m['senderName']??'Usuário',type:m['type']??'text',text:m['text']??'',mediaUrl:m['mediaUrl'],createdAt:(m['createdAt'] as Timestamp?)?.toDate()??DateTime.now(),seenBy:List<String>.from(m['seenBy']??const[]),mine:m['senderId']==auth.currentUser?.uid);}).toList());
  @override Future<void> sendTextMessage({required String activityId,required String text})=>_c(activityId).add({'senderId':auth.currentUser!.uid,'senderName':auth.currentUser!.displayName??'Usuário','type':'text','text':text.trim(),'createdAt':FieldValue.serverTimestamp(),'seenBy':[auth.currentUser!.uid]}).then((_){});
  @override Future<void> sendImageMessage({required String activityId,required File file})async{final doc=_c(activityId).doc();final ref=storage.ref('chat/$activityId/${doc.id}.jpg');await ref.putFile(file);final url=await ref.getDownloadURL();await doc.set({'senderId':auth.currentUser!.uid,'senderName':auth.currentUser!.displayName??'Usuário','type':'image','text':'','mediaUrl':url,'createdAt':FieldValue.serverTimestamp(),'seenBy':[auth.currentUser!.uid]});}
  @override Future<void> markAsRead({required String activityId})async{final uid=auth.currentUser!.uid;final snap=await _c(activityId).where('seenBy',arrayContains:uid).limit(1).get();if(snap.docs.isNotEmpty)return;}
  @override Future<void> deleteMessage({required String activityId,required String messageId})=>_c(activityId).doc(messageId).delete();
}

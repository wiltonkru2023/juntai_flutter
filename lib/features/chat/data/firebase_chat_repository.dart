import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/api_service.dart';
import '../../../shared/models/chat_message.dart';
import 'chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository(this.db, this.storage, this.auth);

  final FirebaseFirestore db;
  final FirebaseStorage storage;
  final FirebaseAuth auth;

  CollectionReference<Map<String, dynamic>> _collection(String activityId) =>
      db.collection('activities').doc(activityId).collection('chat');

  @override
  Stream<List<ChatMessage>> watchMessages(
    String activityId, {
    int limit = 40,
  }) =>
      _collection(activityId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final uid = auth.currentUser?.uid;
        return snapshot.docs.reversed.where((doc) {
          final hidden = doc.data()['hiddenFor'];
          return !(hidden is List && uid != null && hidden.contains(uid));
        }).map((doc) {
          final data = doc.data();
          return ChatMessage(
            id: doc.id,
            senderId: (data['senderId'] ?? '').toString(),
            senderName: (data['senderName'] ?? 'Usuário').toString(),
            type: (data['type'] ?? 'text').toString(),
            text: (data['text'] ?? '').toString(),
            mediaUrl: data['mediaUrl']?.toString(),
            audioUrl: data['audioUrl']?.toString(),
            audioBase64: data['audioBase64']?.toString(),
            audioMimeType: data['audioMimeType']?.toString(),
            audioDurationMs: (data['audioDurationMs'] as num?)?.toInt() ?? 0,
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
            deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
            seenBy: List<String>.from(data['seenBy'] ?? const []),
            hiddenFor: List<String>.from(data['hiddenFor'] ?? const []),
            mine: data['senderId'] == uid,
            viewOnce: data['viewOnce'] == true,
            deletedForEveryone: data['deletedForEveryone'] == true,
          );
        }).toList();
      });

  @override
  Future<void> sendTextMessage({
    required String activityId,
    required String text,
  }) async {
    final user = auth.currentUser!;
    await _collection(activityId).add({
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Usuário',
      'type': 'text',
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': [user.uid],
      'hiddenFor': <String>[],
      'deletedForEveryone': false,
    });
  }

  @override
  Future<void> sendImageMessage({
    required String activityId,
    required File file,
  }) async {
    final user = auth.currentUser!;
    final doc = _collection(activityId).doc();
    final bytes = await file.readAsBytes();
    final upload = await ApiService.instance.post(
      '/upload-image',
      body: {
        'purpose': 'chat',
        'fileName': 'chat_${doc.id}.jpg',
        'mimeType': 'image/jpeg',
        'base64': base64Encode(bytes),
      },
    );
    final url = (upload['url'] ?? '').toString();

    await doc.set({
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Usuário',
      'type': 'image',
      'text': '',
      'mediaUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': [user.uid],
      'hiddenFor': <String>[],
      'deletedForEveryone': false,
    });
  }

  @override
  Future<void> markAsRead({required String activityId}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final messages = await _collection(activityId).limit(100).get();
    final batch = db.batch();
    var changed = false;

    for (final doc in messages.docs) {
      final data = doc.data();
      final seen = List<String>.from(data['seenBy'] ?? const []);
      if (data['senderId'] != uid && !seen.contains(uid)) {
        batch.update(doc.reference, {
          'seenBy': FieldValue.arrayUnion([uid]),
        });
        changed = true;
      }
    }

    if (changed) await batch.commit();
  }

  @override
  Future<void> deleteMessage({
    required String activityId,
    required String messageId,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _collection(activityId).doc(messageId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    if (snapshot.data()?['senderId'] == uid) {
      await ref.update({
        'deletedForEveryone': true,
        'deletedBy': uid,
        'deletedAt': FieldValue.serverTimestamp(),
        'text': '',
        'mediaUrl': null,
        'audioUrl': null,
        'audioBase64': null,
      });
    } else {
      await ref.update({
        'hiddenFor': FieldValue.arrayUnion([uid]),
      });
    }
  }
}

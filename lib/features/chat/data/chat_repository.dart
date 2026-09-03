import 'dart:io';
import '../../../shared/models/chat_message.dart';
abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String activityId, {int limit = 40});
  Future<void> sendTextMessage({required String activityId, required String text});
  Future<void> sendImageMessage({required String activityId, required File file});
  Future<void> markAsRead({required String activityId});
  Future<void> deleteMessage({required String activityId, required String messageId});
}

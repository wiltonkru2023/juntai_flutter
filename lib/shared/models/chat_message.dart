class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String type;
  final String text;
  final String? mediaUrl;
  final String? audioBase64;
  final String? audioMimeType;
  final int audioDurationMs;
  final DateTime createdAt;
  final List<String> seenBy;
  final List<String> deliveredTo;
  final bool mine;
  final bool viewOnce;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.audioBase64,
    this.audioMimeType,
    this.audioDurationMs = 0,
    required this.createdAt,
    required this.seenBy,
    this.deliveredTo = const [],
    required this.mine,
    this.viewOnce = false,
  });
}

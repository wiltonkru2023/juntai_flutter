class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String type;
  final String text;
  final String? mediaUrl;
  final String? audioUrl;
  final String? audioBase64;
  final String? audioMimeType;
  final int audioDurationMs;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final List<String> seenBy;
  final List<String> deliveredTo;
  final List<String> hiddenFor;
  final bool mine;
  final bool viewOnce;
  final bool deletedForEveryone;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.audioUrl,
    this.audioBase64,
    this.audioMimeType,
    this.audioDurationMs = 0,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    required this.seenBy,
    this.deliveredTo = const [],
    this.hiddenFor = const [],
    required this.mine,
    this.viewOnce = false,
    this.deletedForEveryone = false,
  });

  bool get canEdit {
    if (!mine || type != 'text' || deletedForEveryone) return false;
    return DateTime.now().difference(createdAt) <= const Duration(minutes: 15);
  }

  bool get canDeleteForEveryone {
    if (!mine || deletedForEveryone) return false;
    return DateTime.now().difference(createdAt) <= const Duration(hours: 48);
  }
}

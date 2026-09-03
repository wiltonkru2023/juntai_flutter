import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../shared/models/activity.dart';
import '../../../../shared/models/chat_message.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key, required this.otherUserId});
  final String otherUserId;
  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final input = TextEditingController();
  final recorder = AudioRecorder();
  Timer? recordTimer;
  bool sending = false, uploadingImage = false, recording = false;
  bool stoppingRecording = false, viewOnceAudio = false;
  int recordingSeconds = 0;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  String get conversationId {
    final ids = [uid, widget.otherUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  DocumentReference<Map<String, dynamic>> get conversation =>
      FirebaseFirestore.instance
          .collection('private_conversations')
          .doc(conversationId);

  @override
  void dispose() {
    recordTimer?.cancel();
    input.dispose();
    recorder.dispose();
    super.dispose();
  }

  Future<void> _write(Map<String, dynamic> message, String preview) async {
    final now = FieldValue.serverTimestamp();
    final exists = (await conversation.get()).exists;
    final batch = FirebaseFirestore.instance.batch();
    final messageRef = conversation.collection('messages').doc();
    batch.set(
        conversation,
        {
          'participants': [uid, widget.otherUserId],
          'updatedAt': now,
          if (!exists) 'createdAt': now,
          'lastMessage': preview,
          'lastSenderId': uid,
          'lastMessageId': messageRef.id,
        },
        SetOptions(merge: true));
    batch.set(messageRef, {
      ...message,
      'senderId': uid,
      'createdAt': now,
      'deliveredTo': [uid],
      'seenBy': [uid]
    });
    await batch.commit();
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    if (text == '/lista') {
      input.clear();
      await _chooseActivity();
      return;
    }
    setState(() => sending = true);
    try {
      await _write({'type': 'text', 'text': text}, text);
      input.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (sending || recording) return;
    setState(() {
      sending = true;
      uploadingImage = true;
    });
    try {
      final uploaded = await ImageUploadService.instance.pickFromGallery(
          purpose: 'private_chat',
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80);
      if (uploaded != null)
        await _write(
            {'type': 'image', 'text': '', 'mediaUrl': uploaded.url}, '📷 Foto');
    } catch (_) {
      if (mounted) context.snack('Não foi possível enviar a foto.');
    } finally {
      if (mounted)
        setState(() {
          sending = false;
          uploadingImage = false;
        });
    }
  }

  Future<bool> _startRecording() async {
    if (sending || recording) return false;
    try {
      if (!await recorder.hasPermission()) {
        if (mounted)
          context.snack('Permita o acesso ao microfone para gravar.');
        return false;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/juntai_private_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
          const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 32000,
              sampleRate: 22050,
              numChannels: 1),
          path: path);
      if (!mounted) {
        await recorder.cancel();
        return false;
      }
      setState(() {
        recording = true;
        recordingSeconds = 0;
      });
      recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !recording) {
          timer.cancel();
          return;
        }
        setState(() => recordingSeconds++);
        if (recordingSeconds >= 60) _stopRecording();
      });
      return true;
    } catch (_) {
      if (mounted) context.snack('Não foi possível iniciar a gravação.');
      return false;
    }
  }

  Future<void> _cancelRecording() async {
    if (!recording || stoppingRecording) return;
    stoppingRecording = true;
    recordTimer?.cancel();
    try {
      await recorder.cancel();
    } catch (_) {}
    if (mounted)
      setState(() {
        recording = false;
        recordingSeconds = 0;
      });
    stoppingRecording = false;
  }

  Future<void> _stopRecording() async {
    if (!recording || stoppingRecording) return;
    stoppingRecording = true;
    recordTimer?.cancel();
    final seconds = recordingSeconds.clamp(1, 60);
    if (mounted)
      setState(() {
        recording = false;
        sending = true;
      });
    String? path;
    try {
      path = await recorder.stop();
      if (path == null) throw Exception();
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 650 * 1024)
        throw Exception('Áudio grande demais. Grave uma mensagem menor.');
      await _write({
        'type': 'audio',
        'text': '',
        'audioBase64': base64Encode(bytes),
        'audioMimeType': 'audio/mp4',
        'audioDurationMs': seconds * 1000,
        'viewOnce': viewOnceAudio
      }, '🎤 Áudio');
    } catch (error) {
      if (mounted) context.snack('Não foi possível enviar o áudio: $error');
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          sending = false;
          recordingSeconds = 0;
          viewOnceAudio = false;
        });
      stoppingRecording = false;
    }
  }

  Future<List<Activity>> _futureActivities() async {
    final memberships = await FirebaseFirestore.instance
        .collectionGroup('participants')
        .where('userId', isEqualTo: uid)
        .get();
    final refs = memberships.docs
        .map((d) => d.reference.parent.parent)
        .whereType<DocumentReference<Map<String, dynamic>>>()
        .toSet();
    final docs = await Future.wait(refs.map((ref) => ref.get()));
    return docs
        .where((d) => d.exists)
        .map(Activity.fromFirestore)
        .where(
            (a) => a.status == 'active' && a.startsAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> _chooseActivity() async {
    final activities = await _futureActivities();
    if (!mounted || activities.isEmpty) return;
    final selected = await showModalBottomSheet<Activity>(
        context: context,
        showDragHandle: true,
        builder: (context) => ListView(shrinkWrap: true, children: [
              const ListTile(
                  title: Text('Enviar atividade',
                      style: TextStyle(fontWeight: FontWeight.w800))),
              for (final a in activities)
                ListTile(
                    leading: const Icon(Icons.event_rounded,
                        color: AppColors.primary),
                    title: Text(a.title),
                    subtitle: Text(
                        '${a.startsAt.day.toString().padLeft(2, '0')}/${a.startsAt.month.toString().padLeft(2, '0')} • ${a.address}'),
                    onTap: () => Navigator.pop(context, a)),
            ]));
    if (selected != null)
      await _write({
        'type': 'activity',
        'text': selected.title,
        'activityId': selected.id,
        'activityTitle': selected.title,
        'activityStartsAt': Timestamp.fromDate(selected.startsAt)
      }, '📅 ${selected.title}');
  }

  void _markReceived(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final pending = docs
        .where((d) =>
            d.data()['senderId'] != uid &&
            (!(d.data()['seenBy'] is List) ||
                !(d.data()['seenBy'] as List).contains(uid)))
        .toList();
    if (pending.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final doc in pending) {
        try {
          await doc.reference.update({
            'deliveredTo': FieldValue.arrayUnion([uid]),
            'seenBy': FieldValue.arrayUnion([uid])
          });
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get(),
      builder: (context, userSnapshot) {
        final name =
            (userSnapshot.data?.data()?['name'] ?? 'Usuário').toString();
        return Scaffold(
            appBar: AppBar(title: Text(name)),
            body: Column(children: [
              Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: conversation
                          .collection('messages')
                          .orderBy('createdAt')
                          .limitToLast(100)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        _markReceived(docs);
                        if (docs.isEmpty)
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                      'Envie uma mensagem ou digite /lista para compartilhar uma atividade.',
                                      textAlign: TextAlign.center)));
                        return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index], data = doc.data();
                              if (data['type'] == 'activity') {
                                final mine = data['senderId'] == uid;
                                return Align(
                                    alignment: mine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: InkWell(
                                        onTap: () => context.push(
                                            '/activity/${data['activityId']}'),
                                        child: Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            padding: const EdgeInsets.all(14),
                                            constraints: const BoxConstraints(
                                                maxWidth: 300),
                                            decoration: BoxDecoration(
                                                color: mine
                                                    ? AppColors.primaryLight
                                                    : Colors.white,
                                                border: Border.all(
                                                    color: AppColors.border),
                                                borderRadius:
                                                    BorderRadius.circular(18)),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                      '📅 Convite de atividade',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800)),
                                                  const SizedBox(height: 8),
                                                  Text((data['activityTitle'] ??
                                                          data['text'])
                                                      .toString()),
                                                  const SizedBox(height: 6),
                                                  const Text(
                                                      'Toque para ver detalhes',
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .primary)),
                                                ]))));
                              }
                              final message = ChatMessage(
                                  id: doc.id,
                                  senderId: (data['senderId'] ?? '').toString(),
                                  senderName: name,
                                  type: (data['type'] ?? 'text').toString(),
                                  text: (data['text'] ?? '').toString(),
                                  mediaUrl: data['mediaUrl']?.toString(),
                                  audioBase64: data['audioBase64']?.toString(),
                                  audioMimeType:
                                      data['audioMimeType']?.toString(),
                                  audioDurationMs:
                                      (data['audioDurationMs'] as num?)
                                              ?.toInt() ??
                                          0,
                                  createdAt: (data['createdAt'] as Timestamp?)
                                          ?.toDate() ??
                                      DateTime.now(),
                                  seenBy: List<String>.from(
                                      data['seenBy'] ?? const []),
                                  deliveredTo: List<String>.from(
                                      data['deliveredTo'] ?? const []),
                                  mine: data['senderId'] == uid,
                                  viewOnce: data['viewOnce'] == true);
                              return MessageBubble(
                                  message: message,
                                  onAudioConsumed:
                                      message.viewOnce && !message.mine
                                          ? () => doc.reference.update({
                                                'audioBase64': null,
                                                'consumedBy': uid,
                                                'consumedAt':
                                                    FieldValue.serverTimestamp()
                                              })
                                          : null);
                            });
                      })),
              SafeArea(
                  top: false,
                  child: ChatInput(
                      controller: input,
                      onSend: _send,
                      onImage: _sendImage,
                      onRecordStart: _startRecording,
                      onRecordStop: _stopRecording,
                      onRecordCancel: _cancelRecording,
                      recording: recording,
                      recordingSeconds: recordingSeconds,
                      viewOnceAudio: viewOnceAudio,
                      onViewOnceChanged: (value) =>
                          setState(() => viewOnceAudio = value),
                      sending: sending,
                      uploadingImage: uploadingImage)),
            ]));
      });
}

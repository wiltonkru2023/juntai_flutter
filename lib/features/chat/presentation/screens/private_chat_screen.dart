import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/audio_upload_service.dart';
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
  bool sending = false;
  bool uploadingImage = false;
  bool recording = false;
  bool stoppingRecording = false;
  bool viewOnceAudio = false;
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

  Future<String> _write(
    Map<String, dynamic> message,
    String preview,
  ) async {
    final result = await ApiService.instance.sendPrivateMessage(
      otherUserId: widget.otherUserId,
      message: message,
      preview: preview,
    );

    final messageId = (result['messageId'] ?? '').toString().trim();
    if (messageId.isEmpty) {
      throw const ApiException(
        message: 'O servidor nao retornou a mensagem enviada.',
        code: 'invalid-private-message-response',
      );
    }

    return messageId;
  }

  Future<void> _notifyPrivate(String messageId) async {
    try {
      await ApiService.instance.notifyPrivateMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (_) {
      // A mensagem já foi enviada; falha de push não deve duplicar envio.
    }
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
      final messageId = await _write({'type': 'text', 'text': text}, text);
      input.clear();
      await _notifyPrivate(messageId);
    } on FirebaseException catch (error) {
      if (mounted) {
        context.snack(error.message ?? 'Não foi possível enviar a mensagem.');
      }
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
        purpose: 'chat',
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (uploaded != null) {
        final messageId = await _write(
          {
            'type': 'image',
            'text': '',
            'mediaUrl': uploaded.url,
          },
          '📷 Foto',
        );
        await _notifyPrivate(messageId);
      }
    } on ApiException catch (error) {
      if (mounted) context.snack(error.message);
    } catch (_) {
      if (mounted) context.snack('Não foi possível enviar a foto.');
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
          uploadingImage = false;
        });
      }
    }
  }

  Future<bool> _startRecording() async {
    if (sending || recording) return false;

    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          context.snack('Permita o acesso ao microfone para gravar.');
        }
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
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) {
        await recorder.cancel();
        return false;
      }

      setState(() {
        recording = true;
        recordingSeconds = 0;
      });

      recordTimer?.cancel();
      recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !recording) {
          timer.cancel();
          return;
        }
        setState(() => recordingSeconds++);
        if (recordingSeconds >= 60) {
          timer.cancel();
          _stopRecording();
        }
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

    if (mounted) {
      setState(() {
        recording = false;
        recordingSeconds = 0;
      });
    }
    stoppingRecording = false;
  }

  Future<void> _stopRecording() async {
    if (!recording || stoppingRecording) return;

    stoppingRecording = true;
    recordTimer?.cancel();
    final seconds = recordingSeconds.clamp(1, 60);

    if (mounted) {
      setState(() {
        recording = false;
        sending = true;
      });
    }

    String? path;
    try {
      path = await recorder.stop();
      if (path == null) {
        throw const ApiException(
          message: 'Arquivo de áudio não encontrado.',
          code: 'audio-file-missing',
        );
      }

      final file = File(path);
      final uploaded = await AudioUploadService.instance.uploadFile(
        file,
        purpose: 'private_chat',
      );

      final messageId = await _write(
        {
          'type': 'audio',
          'text': '',
          'audioUrl': uploaded.url,
          'audioMimeType': 'audio/mp4',
          'audioDurationMs': seconds * 1000,
          'viewOnce': viewOnceAudio,
        },
        '🎤 Áudio',
      );

      await _notifyPrivate(messageId);
    } on ApiException catch (error) {
      if (mounted) context.snack(error.message);
    } catch (error) {
      if (mounted) context.snack('Não foi possível enviar o áudio: $error');
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          sending = false;
          recordingSeconds = 0;
          viewOnceAudio = false;
        });
      }
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
          (a) => a.status == 'active' && a.startsAt.isAfter(DateTime.now()),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> _chooseActivity() async {
    final activities = await _futureActivities();
    if (!mounted || activities.isEmpty) {
      if (mounted) {
        context.snack('Você não tem atividades futuras para enviar.');
      }
      return;
    }

    final selected = await showModalBottomSheet<Activity>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Enviar atividade',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          for (final a in activities)
            ListTile(
              leading: const Icon(
                Icons.event_rounded,
                color: AppColors.primary,
              ),
              title: Text(a.title),
              subtitle: Text(
                '${a.startsAt.day.toString().padLeft(2, '0')}/'
                '${a.startsAt.month.toString().padLeft(2, '0')} • ${a.address}',
              ),
              onTap: () => Navigator.pop(context, a),
            ),
        ],
      ),
    );

    if (selected != null) {
      final messageId = await _write(
        {
          'type': 'activity',
          'text': selected.title,
          'activityId': selected.id,
          'activityTitle': selected.title,
          'activityStartsAt': selected.startsAt.toUtc().toIso8601String(),
        },
        '📅 ${selected.title}',
      );
      await _notifyPrivate(messageId);
    }
  }

  void _markReceived(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final pending = docs
        .where(
          (d) =>
              d.data()['senderId'] != uid &&
              (d.data()['seenBy'] is! List ||
                  !(d.data()['seenBy'] as List).contains(uid)),
        )
        .toList();

    if (pending.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final doc in pending) {
        try {
          await doc.reference.update({
            'deliveredTo': FieldValue.arrayUnion([uid]),
            'seenBy': FieldValue.arrayUnion([uid]),
          });
        } catch (_) {}
      }
    });
  }

  Future<void> _editMessage(
    DocumentReference<Map<String, dynamic>> ref,
    ChatMessage message,
  ) async {
    if (!message.canEdit) {
      context.snack('O prazo de 15 minutos para editar terminou.');
      return;
    }

    final controller = TextEditingController(text: message.text);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(hintText: 'Mensagem'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || value == message.text) return;

    try {
      await ref.update({
        'text': value,
        'editedAt': FieldValue.serverTimestamp(),
      });

      final conversationSnapshot = await conversation.get();
      if (conversationSnapshot.data()?['lastMessageId'] == message.id) {
        await conversation.update({
          'lastMessage': value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        context.snack(error.message ?? 'Não foi possível editar a mensagem.');
      }
    }
  }

  Future<void> _deleteForMe(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.update({
        'hiddenFor': FieldValue.arrayUnion([uid]),
      });
    } on FirebaseException catch (error) {
      if (mounted) {
        context.snack(error.message ?? 'Não foi possível excluir a mensagem.');
      }
    }
  }

  Future<void> _deleteForEveryone(
    DocumentReference<Map<String, dynamic>> ref,
    ChatMessage message,
  ) async {
    if (!message.canDeleteForEveryone) {
      context.snack('O prazo para excluir para todos terminou.');
      return;
    }

    try {
      await ref.update({
        'deletedForEveryone': true,
        'deletedBy': uid,
        'deletedAt': FieldValue.serverTimestamp(),
        'text': '',
        'mediaUrl': null,
        'audioUrl': null,
        'audioBase64': null,
      });

      final conversationSnapshot = await conversation.get();
      if (conversationSnapshot.data()?['lastMessageId'] == message.id) {
        await conversation.update({
          'lastMessage': 'Mensagem apagada',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        context.snack(error.message ?? 'Não foi possível excluir para todos.');
      }
    }
  }

  Future<void> _showMessageActions(
    DocumentReference<Map<String, dynamic>> ref,
    ChatMessage message,
  ) async {
    final canEdit = message.canEdit;
    final canDeleteAll = message.canDeleteForEveryone;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar mensagem'),
                subtitle: const Text('Disponível por 15 minutos'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editMessage(ref, message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Excluir para mim'),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteForMe(ref);
              },
            ),
            if (canDeleteAll)
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Excluir para todos',
                  style: TextStyle(color: AppColors.error),
                ),
                subtitle: const Text('Disponível por até 48 horas'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteForEveryone(ref, message);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.otherUserId)
            .get(),
        builder: (context, userSnapshot) {
          final name =
              (userSnapshot.data?.data()?['name'] ?? 'Usuário').toString();

          return Scaffold(
            appBar: AppBar(title: Text(name)),
            body: Column(
              children: [
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

                      final visibleDocs = docs.where((doc) {
                        final hiddenFor = doc.data()['hiddenFor'];
                        return !(hiddenFor is List && hiddenFor.contains(uid));
                      }).toList();

                      if (visibleDocs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'Envie uma mensagem ou digite /lista para compartilhar uma atividade.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleDocs.length,
                        itemBuilder: (context, index) {
                          final doc = visibleDocs[index];
                          final data = doc.data();
                          final deleted = data['deletedForEveryone'] == true;

                          if (data['type'] == 'activity' && !deleted) {
                            final mine = data['senderId'] == uid;
                            final message = _chatMessageFromData(
                              doc,
                              data,
                              name,
                            );

                            return GestureDetector(
                              onLongPress: () =>
                                  _showMessageActions(doc.reference, message),
                              child: Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => context.push(
                                    '/activity/${data['activityId']}',
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    constraints:
                                        const BoxConstraints(maxWidth: 300),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? AppColors.primaryLight
                                          : Colors.white,
                                      border:
                                          Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '📅 Convite de atividade',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          (data['activityTitle'] ??
                                                  data['text'])
                                              .toString(),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Toque para ver detalhes',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final message = _chatMessageFromData(doc, data, name);

                          return MessageBubble(
                            message: message,
                            showDeliveryStatus: true,
                            onOptions: () =>
                                _showMessageActions(doc.reference, message),
                            onAudioConsumed: message.viewOnce && !message.mine
                                ? () => doc.reference.update({
                                      'audioUrl': null,
                                      'audioBase64': null,
                                      'consumedBy': uid,
                                      'consumedAt':
                                          FieldValue.serverTimestamp(),
                                    })
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
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
                    uploadingImage: uploadingImage,
                  ),
                ),
              ],
            ),
          );
        },
      );

  ChatMessage _chatMessageFromData(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    String otherName,
  ) {
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      senderName: otherName,
      type: (data['type'] ?? 'text').toString(),
      text: (data['text'] ?? '').toString(),
      mediaUrl: data['mediaUrl']?.toString(),
      audioUrl: data['audioUrl']?.toString(),
      audioBase64: data['audioBase64']?.toString(),
      audioMimeType: data['audioMimeType']?.toString(),
      audioDurationMs: (data['audioDurationMs'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      seenBy: List<String>.from(data['seenBy'] ?? const []),
      deliveredTo: List<String>.from(data['deliveredTo'] ?? const []),
      hiddenFor: List<String>.from(data['hiddenFor'] ?? const []),
      mine: data['senderId'] == uid,
      viewOnce: data['viewOnce'] == true,
      deletedForEveryone: data['deletedForEveryone'] == true,
    );
  }
}

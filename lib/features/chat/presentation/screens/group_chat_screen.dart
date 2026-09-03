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
import '../../../../core/services/api_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../shared/models/chat_message.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();
  final AudioRecorder recorder = AudioRecorder();

  Timer? recordTimer;
  int recordingSeconds = 0;
  bool recording = false;
  bool sending = false;
  bool uploadingImage = false;
  bool stoppingRecording = false;
  bool viewOnceAudio = false;

  DocumentReference<Map<String, dynamic>> get activityRef =>
      FirebaseFirestore.instance
          .collection('activities')
          .doc(widget.activityId);

  CollectionReference<Map<String, dynamic>> get chatRef =>
      activityRef.collection('chat');

  @override
  void dispose() {
    recordTimer?.cancel();
    input.dispose();
    scroll.dispose();
    recorder.dispose();
    super.dispose();
  }

  Future<String> _senderName(User user) async {
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return (profile.data()?['name'] ?? user.displayName ?? 'Usuário')
        .toString()
        .trim();
  }

  Future<void> _notifyMessage(String messageId) async {
    try {
      await ApiService.instance.notifyChatMessage(
        activityId: widget.activityId,
        messageId: messageId,
      );
    } on ApiException catch (error) {
      if (mounted) {
        context.snack(
          'Mensagem enviada, mas a notificação não pôde ser enviada: ${error.message}',
        );
      }
    }
  }

  Future<void> send() async {
    if (sending || recording) return;

    final text = input.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.snack('Sua sessão expirou. Entre novamente.');
      return;
    }

    setState(() => sending = true);

    try {
      final senderName = await _senderName(user);

      final messageRef = await chatRef.add({
        'senderId': user.uid,
        'senderName': senderName,
        'type': 'text',
        'text': text,
        'mediaUrl': null,
        'audioBase64': null,
        'audioMimeType': null,
        'audioDurationMs': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'seenBy': [user.uid],
      });

      input.clear();
      _scrollToBottom();
      await _notifyMessage(messageRef.id);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      if (error.code == 'permission-denied') {
        context.snack('Você não tem acesso ao chat desta atividade.');
      } else {
        context.snack(
          error.message ?? 'Não foi possível enviar a mensagem.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível enviar a mensagem.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> sendImage() async {
    if (sending || recording) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.snack('Sua sessão expirou. Entre novamente.');
      return;
    }

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

      if (uploaded == null) return;

      final senderName = await _senderName(user);

      final messageRef = await chatRef.add({
        'senderId': user.uid,
        'senderName': senderName,
        'type': 'image',
        'text': '',
        'mediaUrl': uploaded.url,
        'audioBase64': null,
        'audioMimeType': null,
        'audioDurationMs': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'seenBy': [user.uid],
      });

      _scrollToBottom();
      await _notifyMessage(messageRef.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      context.snack(
        error.message ?? 'Não foi possível enviar a foto.',
      );
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível enviar a foto.');
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
          uploadingImage = false;
        });
      }
    }
  }

  Future<bool> startRecording() async {
    if (sending || recording) return false;

    try {
      final allowed = await recorder.hasPermission();

      if (!allowed) {
        if (mounted) {
          context.snack(
            'Permita o acesso ao microfone para enviar mensagens de áudio.',
          );
        }
        return false;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/juntai_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      recordTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted || !recording) {
            timer.cancel();
            return;
          }

          setState(() => recordingSeconds++);

          if (recordingSeconds >= 60) {
            timer.cancel();
            stopRecording();
          }
        },
      );
      return true;
    } catch (_) {
      if (mounted)
        context.snack('Não foi possível iniciar a gravação de áudio.');
      return false;
    }
  }

  Future<void> cancelRecording() async {
    if (!recording || stoppingRecording) return;

    stoppingRecording = true;
    recordTimer?.cancel();

    try {
      await recorder.cancel();
    } catch (_) {
      // Ignora falha ao descartar um arquivo temporário.
    } finally {
      if (mounted) {
        setState(() {
          recording = false;
          recordingSeconds = 0;
        });
      }
      stoppingRecording = false;
    }
  }

  Future<void> stopRecording() async {
    if (!recording || stoppingRecording) return;

    stoppingRecording = true;
    recordTimer?.cancel();

    final durationSeconds = recordingSeconds.clamp(1, 60);

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
        throw Exception('Arquivo de áudio não encontrado.');
      }

      final file = File(path);
      final bytes = await file.readAsBytes();

      // Mantém cada documento bem abaixo do limite de 1 MiB do Firestore.
      if (bytes.length > 650 * 1024) {
        throw Exception(
            'O áudio ficou grande demais. Grave uma mensagem menor.');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Sua sessão expirou.');
      }

      final senderName = await _senderName(user);

      final messageRef = await chatRef.add({
        'senderId': user.uid,
        'senderName': senderName,
        'type': 'audio',
        'text': '',
        'mediaUrl': null,
        'audioBase64': base64Encode(bytes),
        'audioMimeType': 'audio/mp4',
        'audioDurationMs': durationSeconds * 1000,
        'viewOnce': viewOnceAudio,
        'createdAt': FieldValue.serverTimestamp(),
        'seenBy': [user.uid],
      });

      _scrollToBottom();
      await _notifyMessage(messageRef.id);
    } catch (error) {
      if (!mounted) return;
      context.snack('Não foi possível enviar o áudio: $error');
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;

      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _reportConversation(String reason) async {
    try {
      await ApiService.instance.reportContent(
        targetType: 'chat',
        targetId: widget.activityId,
        reason: reason,
        details: 'Conversa da atividade ${widget.activityId}',
      );

      if (!mounted) return;
      context.snack('Denúncia enviada. Obrigado por avisar.');
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível enviar a denúncia.');
    }
  }

  void _showReportConversation() {
    const reasons = [
      'Assédio',
      'Spam',
      'Conteúdo impróprio',
      'Golpe',
      'Ameaça',
      'Outro',
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Denunciar conversa',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final reason in reasons)
                ListTile(
                  title: Text(reason),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reportConversation(reason);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Faça login para acessar o chat.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Entrar'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: activityRef.snapshots(),
      builder: (context, activitySnapshot) {
        if (activitySnapshot.connectionState == ConnectionState.waiting &&
            !activitySnapshot.hasData) {
          return const SafeArea(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (activitySnapshot.hasError) {
          return SafeArea(
            child: Center(
              child: Text(
                'Não foi possível carregar o chat.\n${activitySnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (activitySnapshot.data == null || !activitySnapshot.data!.exists) {
          return const SafeArea(
            child: Center(child: Text('Atividade não encontrada.')),
          );
        }

        final activity = activitySnapshot.data!.data()!;
        final creatorId = (activity['creatorId'] ?? '').toString();
        final title = (activity['title'] ?? 'Atividade').toString();
        final participantCount =
            (activity['participantCount'] as num?)?.toInt() ?? 0;
        final maxParticipants =
            (activity['maxParticipants'] as num?)?.toInt() ?? 0;
        final isCreator = creatorId == user.uid;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              activityRef.collection('participants').doc(user.uid).snapshots(),
          builder: (context, participantSnapshot) {
            final isParticipant = participantSnapshot.data?.exists == true;
            final hasAccess = isCreator || isParticipant;

            if (participantSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !isCreator) {
              return const SafeArea(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!hasAccess) {
              return SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 56,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Chat exclusivo para participantes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Entre na atividade para conversar com o grupo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.go(
                            '/activity/${widget.activityId}',
                          ),
                          child: const Text('Ver atividade'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/chats'),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        AppAvatar(name: title, size: 48),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '$participantCount / $maxParticipants participantes',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'activity') {
                              context.go(
                                '/activity/${widget.activityId}',
                              );
                            } else if (value == 'report') {
                              _showReportConversation();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'activity',
                              child: Text('Ver atividade'),
                            ),
                            PopupMenuItem(
                              value: 'report',
                              child: Text('Denunciar conversa'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: chatRef
                          .orderBy('createdAt', descending: false)
                          .limitToLast(100)
                          .snapshots(),
                      builder: (context, messageSnapshot) {
                        if (messageSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !messageSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (messageSnapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Não foi possível carregar as mensagens.\n'
                                '${messageSnapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final documents = messageSnapshot.data?.docs ?? [];

                        final messages = documents.map((doc) {
                          final data = doc.data();

                          return ChatMessage(
                            id: doc.id,
                            senderId: (data['senderId'] ?? '').toString(),
                            senderName:
                                (data['senderName'] ?? 'Usuário').toString(),
                            type: (data['type'] ?? 'text').toString(),
                            text: (data['text'] ?? '').toString(),
                            mediaUrl: data['mediaUrl']?.toString(),
                            audioBase64: data['audioBase64']?.toString(),
                            audioMimeType: data['audioMimeType']?.toString(),
                            audioDurationMs:
                                (data['audioDurationMs'] as num?)?.toInt() ?? 0,
                            viewOnce: data['viewOnce'] == true,
                            createdAt:
                                (data['createdAt'] as Timestamp?)?.toDate() ??
                                    DateTime.now(),
                            seenBy: data['seenBy'] is List
                                ? List<String>.from(
                                    (data['seenBy'] as List)
                                        .map((item) => item.toString()),
                                  )
                                : <String>[],
                            mine: data['senderId'] == user.uid,
                          );
                        }).toList();

                        _scrollToBottom();

                        if (messages.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 48,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Nenhuma mensagem ainda.',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Seja o primeiro a falar com o grupo.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return MessageBubble(
                              message: messages[index],
                              onAudioConsumed: messages[index].viewOnce &&
                                      !messages[index].mine
                                  ? () =>
                                      chatRef.doc(messages[index].id).update({
                                        'audioBase64': null,
                                        'consumedBy': user.uid,
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
                  ChatInput(
                    controller: input,
                    onSend: send,
                    onImage: sendImage,
                    onRecordStart: startRecording,
                    onRecordStop: stopRecording,
                    onRecordCancel: cancelRecording,
                    recording: recording,
                    recordingSeconds: recordingSeconds,
                    viewOnceAudio: viewOnceAudio,
                    onViewOnceChanged: (value) =>
                        setState(() => viewOnceAudio = value),
                    sending: sending,
                    uploadingImage: uploadingImage,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

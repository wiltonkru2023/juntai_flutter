import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../widgets/conversation_tile.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final search = TextEditingController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      membershipSubscription;

  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      activitySubscriptions = {};

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      messageSubscriptions = {};

  final Map<String, _ConversationRow> rows = {};

  String query = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
        error = 'Faça login para ver suas conversas.';
      });
      return;
    }

    membershipSubscription = FirebaseFirestore.instance
        .collectionGroup('participants')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
      _syncMemberships,
      onError: (Object exception) {
        if (!mounted) return;

        setState(() {
          loading = false;
          error = 'Não foi possível carregar suas conversas.\n'
              'Atualize as regras do Firestore e tente novamente.\n\n'
              '$exception';
        });
      },
    );
  }

  void _syncMemberships(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final ids = <String>{};

    for (final participant in snapshot.docs) {
      final activity = participant.reference.parent.parent;

      if (activity != null) {
        ids.add(activity.id);
      }
    }

    final existing = activitySubscriptions.keys.toSet();
    final removed = existing.difference(ids);

    for (final id in removed) {
      activitySubscriptions.remove(id)?.cancel();
      messageSubscriptions.remove(id)?.cancel();
      rows.remove(id);
    }

    final added = ids.difference(existing);

    for (final id in added) {
      _listenActivity(id);
    }

    if (mounted) {
      setState(() {
        loading = false;
        error = null;
      });
    }
  }

  void _listenActivity(String activityId) {
    final activityRef =
        FirebaseFirestore.instance.collection('activities').doc(activityId);

    activitySubscriptions[activityId] = activityRef.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          if (mounted) {
            setState(() {
              rows.remove(activityId);
            });
          }
          return;
        }

        final data = snapshot.data()!;
        final current = rows[activityId];
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        final row = _ConversationRow(
          id: activityId,
          title: (data['title'] ?? 'Atividade').toString(),
          lastMessage: current?.lastMessage ?? 'Grupo criado',
          time: current?.time ?? createdAt,
          unread: current?.unread ?? 0,
        );

        if (mounted) {
          setState(() {
            rows[activityId] = row;
          });
        }
      },
      onError: (_) {},
    );

    messageSubscriptions[activityId] = activityRef
        .collection('chat')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        final current = rows[activityId];

        if (snapshot.docs.isEmpty) return;

        final message = snapshot.docs.first.data();
        final type = (message['type'] ?? 'text').toString();
        final text = (message['text'] ?? '').toString();
        final sender = (message['senderName'] ?? 'Usuário').toString();

        final lastMessage = switch (type) {
          'image' => '$sender enviou uma foto',
          'audio' => '$sender enviou um áudio',
          _ => text.isEmpty ? 'Nova mensagem' : '$sender: $text',
        };

        final time =
            (message['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        if (mounted) {
          setState(() {
            rows[activityId] = (current ??
                    _ConversationRow(
                      id: activityId,
                      title: 'Atividade',
                      lastMessage: '',
                      time: time,
                      unread: 0,
                    ))
                .copyWith(
              lastMessage: lastMessage,
              time: time,
            );
          });
        }
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    membershipSubscription?.cancel();

    for (final subscription in activitySubscriptions.values) {
      subscription.cancel();
    }

    for (final subscription in messageSubscriptions.values) {
      subscription.cancel();
    }

    search.dispose();
    super.dispose();
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();

    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (sameDay) {
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final conversationRows = rows.values.where((row) {
      final value = query.trim().toLowerCase();

      if (value.isEmpty) return true;

      return row.title.toLowerCase().contains(value) ||
          row.lastMessage.toLowerCase().contains(value);
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                const Text(
                  'Conversas',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppSearchField(
              controller: search,
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          _PrivateConversations(query: query),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    loading = true;
                                    error = null;
                                  });
                                  membershipSubscription?.cancel();
                                  _start();
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : conversationRows.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhuma conversa ainda.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: conversationRows.length,
                            itemBuilder: (context, index) {
                              final row = conversationRows[index];

                              return ConversationTile(
                                title: row.title,
                                lastMessage: row.lastMessage,
                                time: _formatTime(row.time),
                                unread: row.unread,
                                onTap: () => context.go(
                                  '/chat/${row.id}',
                                ),
                              );
                            },
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 84,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _PrivateConversations extends StatelessWidget {
  const _PrivateConversations({required this.query});
  final String query;

  void _markDelivered(DocumentReference<Map<String, dynamic>> conversation,
      Map<String, dynamic> data, String uid) {
    if (data['lastSenderId'] == uid) return;
    final messageId = data['lastMessageId']?.toString();
    if (messageId == null || messageId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      conversation.collection('messages').doc(messageId).update({
        'deliveredTo': FieldValue.arrayUnion([uid]),
      }).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('private_conversations')
          .where('participants', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final last =
              (doc.data()['lastMessage'] ?? '').toString().toLowerCase();
          return query.trim().isEmpty ||
              last.contains(query.trim().toLowerCase());
        }).toList();
        docs.sort((a, b) =>
            ((b.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
                .compareTo((a.data()['updatedAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0));
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Text('Mensagens privadas',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 8),
                shrinkWrap: true,
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  _markDelivered(docs[index].reference, data, uid);
                  final participants =
                      List<String>.from(data['participants'] ?? const []);
                  final other = participants.firstWhere((id) => id != uid,
                      orElse: () => '');
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(other)
                        .get(),
                    builder: (context, user) {
                      final profile =
                          user.data?.data() ?? const <String, dynamic>{};
                      final name = (profile['name'] ?? 'Usuário').toString();
                      final updated =
                          (data['updatedAt'] as Timestamp?)?.toDate() ??
                              DateTime.now();
                      return ListTile(
                        leading: CircleAvatar(
                            child: Text(
                                name.isEmpty ? '?' : name[0].toUpperCase())),
                        title: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            (data['lastMessage'] ?? 'Conversa iniciada')
                                .toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: Text(
                            '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        onTap: () => context.push('/message/$other'),
                      );
                    },
                  );
                },
              )),
        ]);
      },
    );
  }
}

class _ConversationRow {
  const _ConversationRow({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.unread,
  });

  final String id;
  final String title;
  final String lastMessage;
  final DateTime time;
  final int unread;

  _ConversationRow copyWith({
    String? title,
    String? lastMessage,
    DateTime? time,
    int? unread,
  }) {
    return _ConversationRow(
      id: id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unread: unread ?? this.unread,
    );
  }
}

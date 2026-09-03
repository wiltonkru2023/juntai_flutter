import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../activities/data/activity_participation_service.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ActivityParticipationService _participation =
      ActivityParticipationService();

  final Set<String> _busy = <String>{};

  CollectionReference<Map<String, dynamic>>? get _notificationsRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  Stream<List<NotificationModel>> get _stream {
    final ref = _notificationsRef;
    if (ref == null) return Stream.value(const <NotificationModel>[]);

    return ref
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            final data = document.data();
            return NotificationModel(
              id: document.id,
              type: (data['type'] ?? 'generic').toString(),
              title: (data['title'] ?? '').toString(),
              body: (data['body'] ?? '').toString(),
              activityId: data['activityId']?.toString(),
              actorId: data['actorId']?.toString(),
              read: data['read'] == true,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList(),
        );
  }

  Future<void> _markRead(NotificationModel notification) async {
    final ref = _notificationsRef;
    if (ref == null || notification.read) return;

    try {
      await ref.doc(notification.id).update({'read': true});
    } catch (_) {
      // A navegação ainda pode continuar mesmo se a atualização do badge falhar.
    }
  }

  Future<void> _markAllRead() async {
    final ref = _notificationsRef;
    if (ref == null) return;

    try {
      final snapshot = await ref.where('read', isEqualTo: false).get();
      final batch = FirebaseFirestore.instance.batch();

      for (final document in snapshot.docs) {
        batch.update(document.reference, {'read': true});
      }

      await batch.commit();
      await NotificationService.instance.clearDeliveredNotifications();

      if (!mounted) return;
      context.snack('Notificações marcadas como lidas.');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      context.snack(
          error.message ?? 'Não foi possível atualizar as notificações.');
    }
  }

  Future<void> _respondRequest(
    NotificationModel notification,
    bool accept,
  ) async {
    final activityId = notification.activityId;
    final actorId = notification.actorId;

    if (activityId == null || actorId == null) {
      context.snack('Essa solicitação está incompleta.');
      return;
    }

    if (_busy.contains(notification.id)) return;

    setState(() => _busy.add(notification.id));

    try {
      await _participation.respondRequest(
        activityId: activityId,
        userId: actorId,
        accept: accept,
      );

      await _markRead(notification);

      if (!mounted) return;
      context.snack(
        accept ? 'Solicitação aceita.' : 'Solicitação recusada.',
      );
    } on ActivityParticipationException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } finally {
      if (mounted) {
        setState(() => _busy.remove(notification.id));
      }
    }
  }

  Future<void> _open(NotificationModel notification) async {
    await _markRead(notification);

    if (!mounted) return;

    if (notification.type == 'private_message') {
      final actorId = notification.actorId;
      if (actorId != null && actorId.isNotEmpty) {
        context.push('/message/$actorId');
      }
      return;
    }

    final activityId = notification.activityId;
    if (activityId == null || activityId.isEmpty) return;

    if (notification.type == 'new_message') {
      context.push('/chat/$activityId');
    } else {
      context.push('/activity/$activityId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificações')),
        body: const Center(child: Text('Faça login para continuar.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notificações',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Marcar lidas'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as notificações.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? const <NotificationModel>[];

          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Nenhuma notificação.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];

              if (notification.type == 'join_request') {
                final busy = _busy.contains(notification.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: notification.read
                        ? Colors.white
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: .7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(notification.body),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => _respondRequest(
                                        notification,
                                        false,
                                      ),
                              child: const Text('Recusar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => _respondRequest(
                                        notification,
                                        true,
                                      ),
                              child: Text(busy ? 'Aguarde...' : 'Aceitar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return NotificationTile(
                notification: notification,
                onTap: () => _open(notification),
              );
            },
          );
        },
      ),
    );
  }
}
